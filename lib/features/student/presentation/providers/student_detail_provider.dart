import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'student_list_provider.dart';
import '../../domain/models/student_detail_data.dart';

final studentDetailStreamProvider = StreamProvider.family<StudentDetailData, String>((ref, id) {
  final repository = ref.watch(studentRepositoryProvider);
  return repository.watchStudentDetail(id);
});
