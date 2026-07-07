import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:math_manager/firebase_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Test Firestore connection and streams', () async {
    print('Initializing Firebase...');
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.web,
      );
      print('Firebase Initialized successfully.');
      
      final collections = ['students', 'attendances', 'homeworks', 'exam_records', 'exams', 'schedules'];
      for (final col in collections) {
        print('Reading collection: $col...');
        try {
          final snap = await FirebaseFirestore.instance.collection(col).limit(5).get();
          print('Collection $col read successful! Found ${snap.docs.length} documents.');
        } catch (e, st) {
          print('Error reading collection $col: $e');
          print('Stack trace: $st');
        }
      }
    } catch (e, st) {
      print('Firebase initialization failed: $e');
      print('Initialization Stack trace: $st');
    }
  });
}
