import * as admin from 'firebase-admin';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

function toLegacyStatus(raw: string): string {
  switch (raw.toLowerCase()) {
    case 'presente':
    case 'present':
      return 'present';
    case 'tarde':
    case 'late':
      return 'late';
    case 'ausente':
    case 'absent':
      return 'absent';
    default:
      return 'present';
  }
}

function dayKeyFromAny(value: any): string {
  if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return value;
  }

  const date =
    value?.toDate instanceof Function
      ? value.toDate()
      : value instanceof Date
      ? value
      : null;

  if (!date) {
    const now = new Date();
    return now.toISOString().split('T')[0];
  }

  return date.toISOString().split('T')[0];
}

// Mantiene sincronizada la colección raíz `attendance` para compatibilidad.
export const syncClassroomAttendanceToRoot = onDocumentWritten(
  'classrooms/{classroomId}/attendance/{docId}',
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) {
      return;
    }

    const data = after.data() as Record<string, any>;
    const classroomId = event.params.classroomId as string;
    const studentId = (data.studentId ?? '').toString().trim();
    if (!studentId) {
      console.warn('syncClassroomAttendanceToRoot: studentId ausente, skip.');
      return;
    }

    const dateKey = dayKeyFromAny(data.date ?? data.timestamp ?? data.entryAt);
    const rootDocId = `${studentId}_${dateKey}`;

    await db
      .collection('attendance')
      .doc(rootDocId)
      .set(
        {
          classroomId,
          studentId,
          studentName: data.studentName ?? null,
          status: toLegacyStatus((data.status ?? 'present').toString()),
          date: dateKey,
          timestamp: data.timestamp ?? admin.firestore.FieldValue.serverTimestamp(),
          entryAt:
            data.entryAt ??
            data.timestamp ??
            admin.firestore.FieldValue.serverTimestamp(),
          exitAt: data.exitAt ?? null,
          exitSource: data.exitSource ?? null,
          source: data.source ?? 'attendance_event',
          eventDriven: data.eventDriven ?? true,
          sessionId: data.sessionId ?? null,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
  },
);
