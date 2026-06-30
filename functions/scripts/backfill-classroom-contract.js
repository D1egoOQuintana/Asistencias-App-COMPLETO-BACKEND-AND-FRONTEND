/**
 * Migración idempotente: agrega teacherUids e isPolidocente a docs de classrooms.
 *
 * Uso:
 *   node scripts/backfill-classroom-contract.js                 # dry-run (default)
 *   node scripts/backfill-classroom-contract.js --dry-run --limit=10
 *   node scripts/backfill-classroom-contract.js --dry-run --classroomId=ID
 *   node scripts/backfill-classroom-contract.js --write --yes
 *
 * Credenciales:
 *   Requiere variable de entorno GOOGLE_APPLICATION_CREDENTIALS apuntando
 *   a un service account JSON fuera del repositorio, por ejemplo:
 *     $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\credentials\sa-asistencia.json"
 *   El archivo JSON NUNCA debe estar dentro del repo.
 */

'use strict';

const admin = require('firebase-admin');

// ─── Parseo de flags ────────────────────────────────────────────────────────
const args = process.argv.slice(2);
const isDryRun = !args.includes('--write');       // dry-run por defecto
const hasYes   = args.includes('--yes');
const limitArg = args.find(a => a.startsWith('--limit='));
const idArg    = args.find(a => a.startsWith('--classroomId='));
const LIMIT    = limitArg ? parseInt(limitArg.split('=')[1], 10) : Infinity;
const SINGLE_ID = idArg ? idArg.split('=')[1] : null;
const BATCH_SIZE = 450; // Firestore batch limit es 500; margen de seguridad

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

// ─── Contadores ──────────────────────────────────────────────────────────────
const stats = {
  read: 0,
  candidates: 0,
  updated: 0,
  unchanged: 0,
  skipped_missing_teacherUid: 0,
  skipped_invalid_teacherUids: 0,
  errors: 0,
};

const dryRunExamples = [];  // máx 10 ejemplos en dry-run

// ─── Evaluación de un documento ──────────────────────────────────────────────
function evaluate(docId, data) {
  const teacherUid = data.teacherUid;

  // Caso D: sin teacherUid válido → skip
  if (!teacherUid || typeof teacherUid !== 'string' || teacherUid.trim() === '') {
    return { action: 'skip', reason: 'skipped_missing_teacherUid' };
  }

  // Caso E: teacherUids existe pero no es array → skip
  if ('teacherUids' in data && !Array.isArray(data.teacherUids)) {
    return { action: 'skip', reason: 'skipped_invalid_teacherUids', docId };
  }

  const update = {};

  // Casos A y B: teacherUids
  if (!('teacherUids' in data)) {
    // Caso A: campo ausente
    update.teacherUids = [teacherUid];
  } else {
    const list = data.teacherUids; // es array (validado arriba)
    if (!list.includes(teacherUid)) {
      // Caso B: lista existe pero teacherUid no está
      update.teacherUids = [...list, teacherUid];
    }
    // Si ya lo contiene: no cambiar nada en este campo
  }

  // Caso C y F: isPolidocente
  if (!('isPolidocente' in data)) {
    // Caso C: campo ausente
    update.isPolidocente = false;
  }
  // Caso F: campo existe → no tocar

  if (Object.keys(update).length === 0) {
    return { action: 'unchanged' };
  }

  return { action: 'update', update };
}

// ─── Lógica principal ─────────────────────────────────────────────────────────
async function run() {
  // ── Cabecera informativa
  console.log('\n========================================');
  console.log('  Backfill: classroom contract fields');
  console.log('========================================');
  console.log(`  Colección  : classrooms`);
  console.log(`  Modo       : ${isDryRun ? 'DRY-RUN (sin escritura)' : '⚠️  WRITE (escritura real)'}`);
  if (SINGLE_ID) console.log(`  Doc ID     : ${SINGLE_ID}`);
  if (LIMIT !== Infinity) console.log(`  Límite     : ${LIMIT}`);
  console.log('----------------------------------------\n');

  // ── Cargar documentos
  let query = SINGLE_ID
    ? db.collection('classrooms').doc(SINGLE_ID)
    : db.collection('classrooms');

  let docs;
  if (SINGLE_ID) {
    const snap = await db.collection('classrooms').doc(SINGLE_ID).get();
    docs = snap.exists ? [snap] : [];
  } else {
    const snap = await db.collection('classrooms').get();
    docs = snap.docs;
  }

  if (docs.length === 0) {
    console.log('[INFO] No se encontraron documentos.\n');
    printStats();
    return;
  }

  // ── Aplicar límite
  const target = docs.slice(0, LIMIT === Infinity ? docs.length : LIMIT);

  // ── Evaluar documentos
  const toUpdate = []; // [{docId, update}]

  for (const doc of target) {
    stats.read++;
    const data = doc.data();
    const result = evaluate(doc.id, data);

    if (result.action === 'skip') {
      stats[result.reason]++;
      if (result.reason === 'skipped_invalid_teacherUids') {
        console.log(`[SKIP] ${doc.id} — teacherUids existe pero no es array`);
      }
    } else if (result.action === 'unchanged') {
      stats.unchanged++;
    } else {
      stats.candidates++;
      toUpdate.push({ docId: doc.id, update: result.update });
      if (isDryRun && dryRunExamples.length < 10) {
        dryRunExamples.push({ docId: doc.id, update: result.update });
      }
    }
  }

  // ── Dry-run: mostrar ejemplos
  if (isDryRun) {
    if (dryRunExamples.length > 0) {
      console.log(`[DRY-RUN] Ejemplos de cambios propuestos (${dryRunExamples.length}):`);
      for (const ex of dryRunExamples) {
        console.log(`  • ${ex.docId}`);
        for (const [k, v] of Object.entries(ex.update)) {
          console.log(`      ${k}: ${JSON.stringify(v)}`);
        }
      }
    } else {
      console.log('[DRY-RUN] No hay cambios necesarios.\n');
    }
    printStats();
    return;
  }

  // ── Write: batch commits
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
      // NO escribe updatedAt, NO toca schedule, teacherUid, teacherName
      batch.update(db.collection('classrooms').doc(docId), update);
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
  console.log('\n─── Resumen ────────────────────────────');
  console.log(`  Leídos                  : ${stats.read}`);
  console.log(`  Candidatos a actualizar : ${stats.candidates}`);
  console.log(`  Actualizados            : ${stats.updated}`);
  console.log(`  Sin cambios             : ${stats.unchanged}`);
  console.log(`  Skip (sin teacherUid)   : ${stats.skipped_missing_teacherUid}`);
  console.log(`  Skip (teacherUids inv.) : ${stats.skipped_invalid_teacherUids}`);
  console.log(`  Errores                 : ${stats.errors}`);
  console.log('────────────────────────────────────────\n');
}

run().catch(err => {
  console.error('\n[FATAL]', err.message);
  process.exit(1);
});
