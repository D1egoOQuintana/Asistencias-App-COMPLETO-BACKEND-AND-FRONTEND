/**
 * Sembrado de asistencias para un aula durante un mes (default: junio 2026).
 *
 * Escribe en classrooms/{classroomId}/attendance/{studentId}_{dateKey} con el
 * MISMO contrato que el flujo QR (status en inglés, date string, entryAt/exitAt
 * Timestamp). docId determinístico → idempotente: re-correr no duplica.
 * Marca source:'seed' para poder distinguir/limpiar luego.
 *
 * Uso:
 *   node scripts/seed-attendance-june.js                       # dry-run (default)
 *   node scripts/seed-attendance-june.js --dry-run
 *   node scripts/seed-attendance-june.js --write --yes
 *
 * Selección de aula (en este orden de prioridad):
 *   --classroomId=ID                       (directo)
 *   --teacherUid=UID [--grade=4 --section=A]  (busca por docente)
 *   Default teacherUid: EO1XUzsF1GNrk6HVvnzwTujGNAY2 (Luis Quintana)
 *
 * Periodo:
 *   --year=2026 --month=6   (month 1-12; default junio 2026)
 *
 * Distribución (defaults realistas, ajustables):
 *   --absentRate=0.08 --lateRate=0.12   (resto = present)
 *
 * Credenciales:
 *   $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\credentials\sa.json"  (FUERA del repo)
 */

'use strict';

const admin = require('firebase-admin');

// ─── Flags ───────────────────────────────────────────────────────────────────
const args = process.argv.slice(2);
const isDryRun = !args.includes('--write');
const hasYes = args.includes('--yes');
const flag = (name, def) => {
  const a = args.find((x) => x.startsWith(`--${name}=`));
  return a ? a.split('=')[1] : def;
};

const TEACHER_UID = flag('teacherUid', 'EO1XUzsF1GNrk6HVvnzwTujGNAY2');
const CLASSROOM_ID = flag('classroomId', null);
const GRADE = flag('grade', null);
const SECTION = flag('section', null);
const YEAR = parseInt(flag('year', '2026'), 10);
const MONTH = parseInt(flag('month', '6'), 10); // 1-12
const ABSENT_RATE = parseFloat(flag('absentRate', '0.08'));
const LATE_RATE = parseFloat(flag('lateRate', '0.12'));
const BATCH_SIZE = 450;

const DEFAULT_START = '08:00';
const DEFAULT_MAXLATE = '08:15';
const DEFAULT_END = '13:00';

if (!isDryRun && !hasYes) {
  console.error('\n[ERROR] Para escribir debes pasar: --write --yes\n');
  process.exit(1);
}

if (!admin.apps.length) {
  if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    console.error('\n[ERROR] GOOGLE_APPLICATION_CREDENTIALS no está definida.');
    console.error('  PowerShell: $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\\credentials\\sa.json"');
    console.error('  El JSON debe estar FUERA del repositorio.\n');
    process.exit(1);
  }
  admin.initializeApp({ credential: admin.credential.applicationDefault() });
}

const db = admin.firestore();

// ─── Helpers ───────────────────────────────────────────────────────────────
const WEEKDAY_KEYS = [
  'sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday',
]; // JS Date.getDay(): 0=Sun..6=Sat

function pad(n) { return n.toString().padStart(2, '0'); }
function dateKeyOf(d) { return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`; }

// PRNG determinístico (mulberry32) sembrado por string → el dry-run coincide
// con el write y re-correr produce los mismos estados (estable, no aleatorio
// entre ejecuciones).
function seededRandom(seedStr) {
  let h = 1779033703 ^ seedStr.length;
  for (let i = 0; i < seedStr.length; i++) {
    h = Math.imul(h ^ seedStr.charCodeAt(i), 3432918353);
    h = (h << 13) | (h >>> 19);
  }
  let a = h >>> 0;
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function hhmmToMinutes(hhmm) {
  const [h, m] = hhmm.split(':').map((x) => parseInt(x, 10));
  return h * 60 + m;
}
function minutesToDate(year, monthIndex, day, minutes) {
  return new Date(year, monthIndex, day, Math.floor(minutes / 60), minutes % 60);
}

// ─── Stats ───────────────────────────────────────────────────────────────────
const stats = {
  classroom: null,
  students: 0,
  schoolDays: 0,
  present: 0,
  late: 0,
  absent: 0,
  toWrite: 0,
  written: 0,
  errors: 0,
};

async function resolveClassroom() {
  if (CLASSROOM_ID) {
    const snap = await db.collection('classrooms').doc(CLASSROOM_ID).get();
    if (!snap.exists) throw new Error(`Aula ${CLASSROOM_ID} no existe`);
    return snap;
  }
  // Buscar por teacherUid (principal). Fallback a teacherUids (polidocente).
  let q = await db.collection('classrooms')
    .where('teacherUid', '==', TEACHER_UID).get();
  let docs = q.docs;
  if (docs.length === 0) {
    q = await db.collection('classrooms')
      .where('teacherUids', 'array-contains', TEACHER_UID).get();
    docs = q.docs;
  }
  // Filtros opcionales grade/section.
  if (GRADE) docs = docs.filter((d) => `${d.data().grade}` === `${GRADE}`);
  if (SECTION) {
    docs = docs.filter(
      (d) => `${d.data().section}`.toUpperCase() === `${SECTION}`.toUpperCase()
    );
  }
  if (docs.length === 0) {
    throw new Error(
      `No se encontró aula para teacherUid=${TEACHER_UID}` +
      (GRADE ? ` grade=${GRADE}` : '') + (SECTION ? ` section=${SECTION}` : '')
    );
  }
  if (docs.length > 1) {
    console.error('\n[ERROR] Varias aulas coinciden. Especifica --classroomId:');
    for (const d of docs) {
      const x = d.data();
      console.error(`  ${d.id} → ${x.name} ${x.grade}°${x.section}`);
    }
    process.exit(1);
  }
  return docs[0];
}

async function run() {
  console.log('\n========================================');
  console.log('  Seed asistencias por mes');
  console.log('========================================');
  console.log(`  Modo    : ${isDryRun ? 'DRY-RUN (sin escritura)' : '⚠️  WRITE'}`);
  console.log(`  Periodo : ${pad(MONTH)}/${YEAR}`);
  console.log('----------------------------------------');

  const classroomSnap = await resolveClassroom();
  const classroom = classroomSnap.data();
  const classroomId = classroomSnap.id;
  stats.classroom = `${classroom.name} ${classroom.grade}°${classroom.section} (${classroomId})`;
  console.log(`  Aula    : ${stats.classroom}`);

  // Schedule del aula (sub-mapa). Determina días lectivos y horas.
  const schedule = classroom.schedule || {};
  const hasSchedule = Object.keys(schedule).length > 0;
  console.log(`  Horario : ${hasSchedule ? Object.keys(schedule).join(', ') : 'sin horario → Lun-Vie default'}`);

  // Estudiantes activos del aula.
  const studentsSnap = await db.collection('students')
    .where('classroomId', '==', classroomId)
    .where('isActive', '==', true)
    .get();
  const students = studentsSnap.docs.map((d) => {
    const s = d.data();
    const name = `${(s.firstName || '').trim()} ${(s.lastName || '').trim()}`.trim();
    return { id: (s.uid || d.id), name };
  });
  stats.students = students.length;
  console.log(`  Alumnos : ${students.length}`);
  if (students.length === 0) {
    console.log('\n[INFO] El aula no tiene estudiantes activos. Nada que sembrar.\n');
    return;
  }

  const monthIndex = MONTH - 1;
  const daysInMonth = new Date(YEAR, MONTH, 0).getDate();

  const ops = []; // {ref, data, status}
  for (let day = 1; day <= daysInMonth; day++) {
    const d = new Date(YEAR, monthIndex, day);
    const dow = d.getDay(); // 0=Sun..6=Sat
    const key = WEEKDAY_KEYS[dow];

    // Día lectivo: si hay horario, solo días presentes en él; si no, Lun-Vie.
    const isSchoolDay = hasSchedule
      ? Object.prototype.hasOwnProperty.call(schedule, key)
      : (dow >= 1 && dow <= 5);
    if (!isSchoolDay) continue;
    stats.schoolDays++;

    const daySchedule = schedule[key] || {};
    const startM = hhmmToMinutes(daySchedule.startTime || DEFAULT_START);
    const maxLateM = hhmmToMinutes(daySchedule.maxLateTime || DEFAULT_MAXLATE);
    const endM = hhmmToMinutes(daySchedule.endTime || DEFAULT_END);
    const dKey = dateKeyOf(d);

    for (const student of students) {
      const rng = seededRandom(`${student.id}_${dKey}`);
      const roll = rng();

      let status;
      let entryM;
      if (roll < ABSENT_RATE) {
        status = 'absent';
      } else if (roll < ABSENT_RATE + LATE_RATE) {
        status = 'late';
        // Llega entre maxLate+1 y un poco antes del fin.
        const span = Math.max(5, endM - 60 - maxLateM);
        entryM = maxLateM + 1 + Math.floor(rng() * span);
      } else {
        status = 'present';
        // Llega entre 12 min antes del inicio y maxLate.
        const lo = startM - 12;
        const hi = maxLateM;
        entryM = lo + Math.floor(rng() * Math.max(1, hi - lo));
      }

      if (status === 'absent') stats.absent++;
      else if (status === 'late') stats.late++;
      else stats.present++;

      const ref = db.collection('classrooms').doc(classroomId)
        .collection('attendance').doc(`${student.id}_${dKey}`);

      const data = {
        classroomId,
        studentId: student.id,
        studentName: student.name,
        status,
        date: dKey,
        source: 'seed',
      };

      if (status === 'absent') {
        // Ausente: timestamp al inicio de la jornada (consistente con auto_absent).
        data.timestamp = admin.firestore.Timestamp.fromDate(
          minutesToDate(YEAR, monthIndex, day, startM)
        );
      } else {
        const entryAt = minutesToDate(YEAR, monthIndex, day, entryM);
        // Salida cerca del fin (entre end-20 y end).
        const exitM = endM - Math.floor(rng() * 20);
        const exitAt = minutesToDate(YEAR, monthIndex, day, exitM);
        data.timestamp = admin.firestore.Timestamp.fromDate(entryAt);
        data.entryAt = admin.firestore.Timestamp.fromDate(entryAt);
        data.exitAt = admin.firestore.Timestamp.fromDate(exitAt);
        data.exitSource = 'seed';
      }

      ops.push({ ref, data, status });
    }
  }

  stats.toWrite = ops.length;

  if (isDryRun) {
    console.log('----------------------------------------');
    console.log('[DRY-RUN] Ejemplos (primeros 8):');
    for (const o of ops.slice(0, 8)) {
      console.log(`  ${o.data.date}  ${o.status.padEnd(7)}  ${o.data.studentName}`);
    }
    printStats();
    return;
  }

  // Write en batches.
  for (let i = 0; i < ops.length; i += BATCH_SIZE) {
    const chunk = ops.slice(i, i + BATCH_SIZE);
    const batch = db.batch();
    for (const o of chunk) batch.set(o.ref, o.data, { merge: true });
    try {
      await batch.commit();
      stats.written += chunk.length;
      console.log(`  Batch ${Math.floor(i / BATCH_SIZE) + 1} → ${chunk.length} docs OK`);
    } catch (err) {
      stats.errors += chunk.length;
      console.error(`  Batch falló: ${err.message}`);
    }
  }
  printStats();
}

function printStats() {
  console.log('\n─── Resumen ────────────────────────────');
  console.log(`  Aula           : ${stats.classroom}`);
  console.log(`  Alumnos        : ${stats.students}`);
  console.log(`  Días lectivos  : ${stats.schoolDays}`);
  console.log(`  Presentes      : ${stats.present}`);
  console.log(`  Tardanzas      : ${stats.late}`);
  console.log(`  Ausentes       : ${stats.absent}`);
  console.log(`  Docs a escribir: ${stats.toWrite}`);
  console.log(`  Escritos       : ${stats.written}`);
  console.log(`  Errores        : ${stats.errors}`);
  console.log('────────────────────────────────────────\n');
}

run().catch((err) => {
  console.error('\n[FATAL]', err.message);
  process.exit(1);
});
