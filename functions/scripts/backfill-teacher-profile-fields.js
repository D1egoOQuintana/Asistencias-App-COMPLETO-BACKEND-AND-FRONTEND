/**
 * Migración idempotente: agrega phone, subject e isActive a docs de docentes
 * en la colección `users` (role == 'docente' | 'teacher').
 *
 * Uso:
 *   node scripts/backfill-teacher-profile-fields.js                 # dry-run (default)
 *   node scripts/backfill-teacher-profile-fields.js --dry-run --limit=10
 *   node scripts/backfill-teacher-profile-fields.js --dry-run --userId=UID
 *   node scripts/backfill-teacher-profile-fields.js --write --yes
 *
 * Credenciales:
 *   Requiere GOOGLE_APPLICATION_CREDENTIALS apuntando a un service account JSON
 *   FUERA del repositorio:
 *     $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\credentials\sa-asistencia.json"
 *
 * Garantías:
 *   - NO toca Firebase Auth, NO toca custom claims, NO toca updatedAt.
 *   - NO sobrescribe phone, subject, isActive si ya existen.
 *   - NO toca usuarios que no sean docentes.
 */

'use strict';

const admin = require('firebase-admin');

// ─── Parseo de flags ────────────────────────────────────────────────────────
const args = process.argv.slice(2);
const isDryRun = !args.includes('--write');
const hasYes   = args.includes('--yes');
const limitArg = args.find(a => a.startsWith('--limit='));
const idArg    = args.find(a => a.startsWith('--userId='));
const LIMIT    = limitArg ? parseInt(limitArg.split('=')[1], 10) : Infinity;
const SINGLE_ID = idArg ? idArg.split('=')[1] : null;
const BATCH_SIZE = 450;

// ─── Validación de modo escritura ────────────────────────────────────────────
if (!isDryRun && !hasYes) {
  console.error('\n[ERROR] Para escribir en Firestore debes pasar: --write --yes');
  console.error('        Esto evita escrituras accidentales.\n');
  process.exit(1);
}

// ─── Init Firebase Admin ─────────────────────────────────────────────────────
if (!admin.apps.length) {
  if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    console.error('\n[ERROR] GOOGLE_APPLICATION_CREDENTIALS no está definida.');
    console.error('        Ejemplo PowerShell:');
    console.error('          $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\\credentials\\sa.json"');
    console.error('        El archivo JSON debe estar FUERA del repositorio.\n');
    process.exit(1);
  }
  admin.initializeApp({ credential: admin.credential.applicationDefault() });
}

const db = admin.firestore();

const TEACHER_ROLES = new Set(['docente', 'teacher']);

// ─── Contadores ──────────────────────────────────────────────────────────────
const stats = {
  read_users: 0,
  read_teachers: 0,
  candidates: 0,
  updated: 0,
  unchanged: 0,
  ignored_non_teacher_role: 0,
  errors: 0,
  missing_phone: 0,
  missing_subject: 0,
  missing_isActive: 0,
};

const examples = []; // máx 10

// ─── Evaluación ──────────────────────────────────────────────────────────────
function evaluate(data) {
  const role = data.role;

  if (!role || !TEACHER_ROLES.has(role)) {
    return { action: 'ignore', reason: 'ignored_non_teacher_role' };
  }

  const update = {};

  // Caso A: phone ausente → ""
  if (!('phone' in data)) {
    update.phone = '';
    stats.missing_phone++;
  }

  // Caso B: subject ausente → ""
  if (!('subject' in data)) {
    update.subject = '';
    stats.missing_subject++;
  }

  // Caso C: isActive ausente → true (por default, activamos)
  if (!('isActive' in data)) {
    update.isActive = true;
    stats.missing_isActive++;
  }

  if (Object.keys(update).length === 0) {
    return { action: 'unchanged' };
  }

  return { action: 'update', update };
}

// ─── Main ────────────────────────────────────────────────────────────────────
async function run() {
  console.log('\n========================================');
  console.log('  Backfill: teacher profile fields');
  console.log('========================================');
  console.log(`  Colección  : users (role: docente | teacher)`);
  console.log(`  Modo       : ${isDryRun ? 'DRY-RUN (sin escritura)' : '⚠️  WRITE (escritura real)'}`);
  if (SINGLE_ID) console.log(`  User ID    : ${SINGLE_ID}`);
  if (LIMIT !== Infinity) console.log(`  Límite     : ${LIMIT}`);
  console.log('----------------------------------------\n');

  // Cargar docs
  let docs;
  if (SINGLE_ID) {
    const snap = await db.collection('users').doc(SINGLE_ID).get();
    docs = snap.exists ? [snap] : [];
  } else {
    // Lee todos los users (no filtra en query para reportar también ignored)
    const snap = await db.collection('users').get();
    docs = snap.docs;
  }

  if (docs.length === 0) {
    console.log('[INFO] No se encontraron documentos.\n');
    printStats();
    return;
  }

  // Si hay LIMIT, lo aplicamos sobre docentes (no sobre users totales)
  // para que --limit=10 signifique "10 docentes evaluados".
  const toUpdate = [];
  let teachersEvaluated = 0;

  for (const doc of docs) {
    stats.read_users++;
    const data = doc.data();
    const result = evaluate(data);

    if (result.action === 'ignore') {
      stats[result.reason]++;
      continue;
    }

    // Es docente
    stats.read_teachers++;
    teachersEvaluated++;

    if (result.action === 'unchanged') {
      stats.unchanged++;
    } else {
      stats.candidates++;
      toUpdate.push({ docId: doc.id, update: result.update });
      if (isDryRun && examples.length < 10) {
        examples.push({ docId: doc.id, update: result.update });
      }
    }

    if (LIMIT !== Infinity && teachersEvaluated >= LIMIT) break;
  }

  // ── Dry-run
  if (isDryRun) {
    if (examples.length > 0) {
      console.log(`[DRY-RUN] Ejemplos de cambios propuestos (${examples.length}):`);
      for (const ex of examples) {
        console.log(`  • ${ex.docId}`);
        for (const [k, v] of Object.entries(ex.update)) {
          console.log(`      ${k}: ${JSON.stringify(v)}`);
        }
      }
    } else {
      console.log('[DRY-RUN] No hay cambios necesarios.');
    }
    if (stats.missing_isActive > 0) {
      console.log(`\n[ATENCIÓN] ${stats.missing_isActive} docente(s) sin isActive serán activados por default.`);
      console.log('           Revisa la lista antes de ejecutar --write --yes.');
    }
    console.log('');
    printStats();
    return;
  }

  // ── Write
  if (toUpdate.length === 0) {
    console.log('[INFO] No hay documentos que actualizar.\n');
    printStats();
    return;
  }

  const chunks = [];
  for (let i = 0; i < toUpdate.length; i += BATCH_SIZE) {
    chunks.push(toUpdate.slice(i, i + BATCH_SIZE));
  }

  console.log(`[WRITE] ${toUpdate.length} documentos en ${chunks.length} batch(es)...`);

  for (let ci = 0; ci < chunks.length; ci++) {
    const batch = db.batch();
    for (const { docId, update } of chunks[ci]) {
      // NO escribe updatedAt, NO toca role/email/uid/createdAt/etc.
      batch.update(db.collection('users').doc(docId), update);
    }
    try {
      await batch.commit();
      stats.updated += chunks[ci].length;
      console.log(`  Batch ${ci + 1}/${chunks.length} → ${chunks[ci].length} docs OK`);
    } catch (err) {
      stats.errors += chunks[ci].length;
      console.error(`  Batch ${ci + 1}/${chunks.length} FALLÓ: ${err.message}`);
    }
  }

  printStats();
}

function printStats() {
  console.log('─── Resumen ────────────────────────────');
  console.log(`  Users leídos              : ${stats.read_users}`);
  console.log(`  Docentes evaluados        : ${stats.read_teachers}`);
  console.log(`  Candidatos a actualizar   : ${stats.candidates}`);
  console.log(`  Actualizados              : ${stats.updated}`);
  console.log(`  Sin cambios               : ${stats.unchanged}`);
  console.log(`  Ignorados (no docente)    : ${stats.ignored_non_teacher_role}`);
  console.log(`  Sin phone                 : ${stats.missing_phone}`);
  console.log(`  Sin subject               : ${stats.missing_subject}`);
  console.log(`  Sin isActive              : ${stats.missing_isActive}`);
  console.log(`  Errores                   : ${stats.errors}`);
  console.log('────────────────────────────────────────\n');
}

run().catch(err => {
  console.error('\n[FATAL]', err.message);
  process.exit(1);
});
