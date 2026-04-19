import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic> _defaultMedicalInfo() {
    return {
      'biologicalSex': 'male',
      'weightKg': null,
      'heightCm': null,
      'systolicPressure': null,
      'diastolicPressure': null,
      'bloodGlucose': null,
      'isPregnant': false,
      'isBreastfeeding': false,
    };
  }

  Future<void> createUserProfile({
    required String uid,
    required String username,
    required String email,
    required List<String> chronicDiseases,
    required int age,
    Map<String, dynamic>? medicalInfo,
    List<String>? drugAllergies,
  }) async {
    await _firestore.collection('Users').doc(uid).set({
      'username': username,
      'email': email,
      'age': age,
      'chronicDiseases': chronicDiseases,
      'drugAllergies': drugAllergies ?? [],
      'medicalInfo': {..._defaultMedicalInfo(), ...?medicalInfo},
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getUserProfile({required String uid}) async {
    final doc = await _firestore.collection('Users').doc(uid).get();

    if (!doc.exists) return null;

    return doc.data();
  }

  Future<void> updateUserProfile({
    required String uid,
    required String username,
    required int age,
    required List<String> chronicDiseases,
    required List<String> drugAllergies,
    required Map<String, dynamic> medicalInfo,
  }) async {
    await _firestore.collection('Users').doc(uid).set({
      'username': username,
      'age': age,
      'chronicDiseases': chronicDiseases,
      'drugAllergies': drugAllergies,
      'medicalInfo': {..._defaultMedicalInfo(), ...medicalInfo},
    }, SetOptions(merge: true));
  }
}
