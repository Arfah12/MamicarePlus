// lib/models/baby.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Baby {
  String? id;
  String? nama;
  DateTime? tarikhLahir;
  String? jantina;
  double? berat;
  double? tinggi;
  String? jenisDarah;
  List<String>? vaksinSelesai;

  Baby({
    this.id,
    this.nama,
    this.tarikhLahir,
    this.jantina,
    this.berat,
    this.tinggi,
    this.jenisDarah,
    this.vaksinSelesai,
  });

  Map<String, dynamic> toMap() {
    return {
      'nama': nama ?? '',
      'tarikhLahir': tarikhLahir != null ? Timestamp.fromDate(tarikhLahir!) : null,
      'jantina': jantina ?? '',
      'berat': berat ?? 0,
      'tinggi': tinggi ?? 0,
      'jenisDarah': jenisDarah ?? '',
      'vaksinSelesai': vaksinSelesai ?? [],
    }..removeWhere((key, value) => value == null);
  }

  factory Baby.fromMap(String id, Map<String, dynamic> map) {
    DateTime? parsedDate;
    final raw = map['tarikhLahir'];
    if (raw != null) {
      if (raw is Timestamp) {
        parsedDate = raw.toDate();
      } else if (raw is String && raw.isNotEmpty) {
        parsedDate = DateTime.tryParse(raw);
      }
    }

    return Baby(
      id: id,
      nama: map['nama'] as String?,
      tarikhLahir: parsedDate,
      jantina: map['jantina'] as String?,
      berat: (map['berat'] ?? 0).toDouble(),
      tinggi: (map['tinggi'] ?? 0).toDouble(),
      jenisDarah: map['jenisDarah'] as String?,
      vaksinSelesai: List<String>.from(map['vaksinSelesai'] ?? []),
    );
  }
}
