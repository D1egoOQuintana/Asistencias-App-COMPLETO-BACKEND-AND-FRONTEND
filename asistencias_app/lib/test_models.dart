import 'models/classroom_model.dart';

void main() {
  // Test simple para verificar que el modelo se puede importar
  final classroom = ClassroomModel(
    name: 'Test',
    grade: '1',
    section: 'A',
    capacity: 30,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  print('Classroom created: ${classroom.fullName}');
}
