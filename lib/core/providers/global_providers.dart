import 'package:flutter_riverpod/flutter_riverpod.dart';

// null means '전체' (All grades), 1-6 represents 초1-초6, 7-9 represents 중1-중3.
final globalGradeFilterProvider = StateProvider<int?>((ref) => null);
