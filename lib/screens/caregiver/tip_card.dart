import 'package:cloud_firestore/cloud_firestore.dart';

// HANYA takrifkan kelas Tip di sini
class Tip {
  final String id;
  final String title;
  final String content;
  final String category;

  Tip({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
  });

  factory Tip.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Tip(
      id: doc.id,
      title: data['title'] ?? 'Tiada Tajuk',
      content: data['content'] ?? 'Tiada kandungan disediakan.',
      category: data['category'] ?? 'Umum',
    );
  }
}