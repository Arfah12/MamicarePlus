import 'package:cloud_firestore/cloud_firestore.dart';

class Milestone {
  final String id;
  final String title;
  final String category;
  final DateTime dateAchieved;

  Milestone({
    required this.id,
    required this.title,
    required this.category,
    required this.dateAchieved,
  });

  factory Milestone.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Milestone(
      id: doc.id,
      title: data['title'] ?? '',
      category: data['category'] ?? '',
      dateAchieved: (data['dateAchieved'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category,
      'dateAchieved': Timestamp.fromDate(dateAchieved),
    };
  }
}
  