import 'package:cloud_firestore/cloud_firestore.dart';

class BabyService {
  final CollectionReference babiesCollection =
      FirebaseFirestore.instance.collection('babies');

  // Dapatkan semua bayi untuk caregiver tertentu
  Stream<QuerySnapshot> getBabies(String caregiverId) {
    return babiesCollection
        .where('caregiver_id', isEqualTo: caregiverId)
        .snapshots();
  }

  // Tambah bayi baru
  Future<void> addBaby({
    required String caregiverId,
    required String name,
    required String dob,
    String? weight,
    String? height,
  }) async {
    await babiesCollection.add({
      'caregiver_id': caregiverId,
      'name': name,
      'dob': dob,
      'weight': weight ?? '',
      'height': height ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
