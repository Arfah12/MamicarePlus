import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:async';
// removed unused imports
import '../../services/notification_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:ui';
// PASTIKAN ANDA MEMPUNYAI FAIL-FAIL INI DI LOKASI YANG BETUL
import 'milestone_tab.dart';
import 'vaccines_tab.dart';
import 'tips_tab.dart';
import 'setting_tab.dart';

// ===================== THEME COLORS (Bold & Cheerful) =====================
const Color primaryColor = Color(0xFF00A3FF); // Vibrant cyan/blue
const Color secondaryColor = Color.fromARGB(255, 0, 144, 247); // Bright coral
const Color accentColor = Color(0xFFFFC857); // Sunny yellow for CTAs
const Color backgroundColor = Color(0xFFFFFBF6); // Warm off-white background
const Color cardColor = Colors.white; // Card surface
const Color textColor = Color(0xFF1B1B1F); // Strong dark text

// ===================== MILESTONE MODEL =====================
class Milestone {
  final String id;
  final String name;
  final String category;
  final int ageFrom;
  final int ageTo;

  Milestone({
    required this.id,
    required this.name,
    required this.category,
    required this.ageFrom,
    required this.ageTo,
  });

  factory Milestone.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Milestone(
      id: doc.id,
      name: data['name'] ?? '-',
      category: data['category'] ?? 'lain-lain',
      ageFrom: data['age_from'] ?? 0,
      ageTo: data['age_to'] ?? 0,
    );
  }
}

// Small widget that finds the next scheduled vaccine for a
class _NextVaccineCard extends StatelessWidget {
  final DocumentReference caregiverDoc;
  final String babyId;

  const _NextVaccineCard({required this.caregiverDoc, required this.babyId});

  @override
  Widget build(BuildContext context) {
    final colA = caregiverDoc
        .collection('babies')
        .doc(babyId)
        .collection('vaccines')
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: colA,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        List<QueryDocumentSnapshot> docs = [];
        if (snap.hasData) {
          docs = snap.data!.docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return _isUpcomingVaccine(data);
          }).toList();
        }

        if (docs.isEmpty) {
          // fallback to vaccine_records
          final colB = caregiverDoc
              .collection('babies')
              .doc(babyId)
              .collection('vaccine_records')
              .snapshots();

          return StreamBuilder<QuerySnapshot>(
            stream: colB,
            builder: (context, snapB) {
              if (snapB.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              List<QueryDocumentSnapshot> docsB = [];
              if (snapB.hasData) {
                docsB = snapB.data!.docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return data['dateScheduled'] != null && data['taken'] != true;
                }).toList();
              }

              if (docsB.isEmpty) {
                return Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primaryColor.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                            child: Icon(Icons.vaccines,
                                color: primaryColor, size: 48)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Tiada vaksin dijadualkan',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 6),
                            Text('Sila tetapkan tarikh di tab Vaksin',
                                style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      Icon(Icons.more_horiz, color: Colors.grey.shade500),
                    ],
                  ),
                );
              }

              docsB.sort((a, b) {
                final da = (a['dateScheduled'] as Timestamp).toDate();
                final db = (b['dateScheduled'] as Timestamp).toDate();
                return da.compareTo(db);
              });

              final next = docsB.first;
              final nextData = next.data() as Map<String, dynamic>;
              final scheduledDate =
                  (nextData['dateScheduled'] as Timestamp).toDate();
              final vaccineName =
                  nextData['vaccineName'] ?? nextData['name'] ?? next.id;

              return _buildCardRow(context, vaccineName, scheduledDate,
                  onDone: () async {
                await next.reference.update({'taken': true});
              });
            },
          );
        }

        // we have docs from primary collection
        docs.sort((a, b) {
          final da = (a['dateScheduled'] as Timestamp).toDate();
          final db = (b['dateScheduled'] as Timestamp).toDate();
          return da.compareTo(db);
        });

        final next = docs.first;
        final nextData = next.data() as Map<String, dynamic>;
        final scheduledDate = (nextData['dateScheduled'] as Timestamp).toDate();
        final vaccineName =
            nextData['vaccineName'] ?? nextData['name'] ?? next.id;

        return _buildCardRow(context, vaccineName, scheduledDate,
            onDone: () async {
          await next.reference.update({'taken': true});
        });
      },
    );
  }

  Widget _buildCardRow(
      BuildContext context, String vaccineName, DateTime scheduledDate,
      {required VoidCallback onDone}) {
    // 1. Helper date formatting (Malay)
    final List<String> months = [
      'Jan',
      'Feb',
      'Mac',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Ogo',
      'Sep',
      'Okt',
      'Nov',
      'Dis'
    ];
    final List<String> days = [
      'Isnin',
      'Selasa',
      'Rabu',
      'Khamis',
      'Jumaat',
      'Sabtu',
      'Ahad'
    ];

    final int weekdayIndex = scheduledDate.weekday - 1; // 1-7 -> 0-6
    final String dayName = days[weekdayIndex];
    final String dayNum = scheduledDate.day.toString();
    final String monthName = months[scheduledDate.month - 1];
    final String fullDate =
        "$dayName, $dayNum $monthName ${scheduledDate.year}";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT: Big Date Block
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  dayNum,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dayName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // RIGHT: Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top small date
                Text(
                  fullDate,
                  style: const TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),

                // Title
                Text(
                  vaccineName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B1B1F),
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 16),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text("Sila ke tab Vaksin untuk ubah tarikh")),
                        );
                      },
                      child: Text(
                        "Tangguh",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: onDone,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        child: const Text(
                          "Selesai",
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    )
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isUpcomingVaccine(Map<String, dynamic> data) {
    if (data['dateScheduled'] == null) return false;
    final scheduled = (data['dateScheduled'] as Timestamp).toDate();
    return scheduled.isAfter(DateTime.now()) && data['taken'] != true;
  }
}

Widget milestoneCard({
  required String title,
  required String category,
  required bool achieved,
  DateTime? achievedDate,
  required VoidCallback onTap,
}) {
  // warna & icon ikut kategori
  final Map<String, Color> categoryColors = {
    "Motor": Colors.green.shade400,
    "Sosial": Colors.orange.shade400,
    "Bahasa": Colors.blue.shade400,
    "Kognitif": Colors.purple.shade400,
    "lain-lain": Colors.grey.shade400,
  };

  final Map<String, IconData> categoryIcons = {
    "Motor": Icons.directions_run,
    "Sosial": Icons.group,
    "Bahasa": Icons.chat_bubble,
    "Kognitif": Icons.psychology,
    "lain-lain": Icons.star,
  };

  final Color color = categoryColors[category] ?? Colors.grey.shade400;
  final IconData icon = categoryIcons[category] ?? Icons.star;

  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: achieved
            ? LinearGradient(
                colors: [color, Colors.yellow.shade300],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [Colors.white, Colors.white],
              ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: achieved ? Colors.transparent : color.withOpacity(0.3),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: achieved ? Colors.white24 : color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                achieved ? Icons.check_circle : icon,
                color: achieved ? Colors.yellow.shade300 : color,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: achieved ? Colors.white : color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  achievedDate != null
                      ? "Dicapai: ${achievedDate.day}/${achievedDate.month}/${achievedDate.year}"
                      : "Belum dicapai",
                  style: TextStyle(
                    fontSize: 12,
                    color: achieved ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              achieved ? Icons.undo : Icons.check,
              color: achieved ? Colors.white : color,
            ),
            onPressed: onTap,
            tooltip: achieved ? "Batal capai" : "Tandakan selesai",
          ),
        ],
      ),
    ),
  );
}

IconData _getCategoryIcon(String category) {
  final c = category.toLowerCase();
  if (c.contains('kogn')) return Icons.psychology;
  if (c.contains('kom') || c.contains('komu')) return Icons.chat_bubble;
  if (c.contains('sos')) return Icons.group;
  if (c.contains('per') || c.contains('perg')) return Icons.directions_run;
  return Icons.star;
}

Color _getCategoryColor(String category) {
  switch (category.toLowerCase()) {
    case 'kognitif':
      return Colors.purple; // Ungu
    case 'komunikasi':
      return Colors.orangeAccent; // Oren
    case 'sosial':
      return Colors.greenAccent.shade700; // Hijau
    case 'pergerakan':
      return const Color.fromARGB(255, 73, 7, 255); // Kuning
    default:
      return Colors.blue;
  }
}

Widget _buildMilestonesIndicators(String babyId) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return const SizedBox();

  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('milestones')
        .orderBy('age_from')
        .snapshots(),
    builder: (context, milestoneSnap) {
      if (!milestoneSnap.hasData) {
        return const Center(child: CupertinoActivityIndicator());
      }

      final allMilestones = milestoneSnap.data!.docs
          .map((d) => Milestone.fromFirestore(d))
          .toList();

      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('caregivers')
            .doc(user.uid)
            .collection('babies')
            .doc(babyId)
            .collection('milestones')
            .snapshots(),
        builder: (context, babyMilestoneSnap) {
          final Map<String, bool> achievedMap = {};
          if (babyMilestoneSnap.hasData) {
            for (var doc in babyMilestoneSnap.data!.docs) {
              achievedMap[doc.id] =
                  (doc.data() as Map<String, dynamic>)['achieved'] == true;
            }
          }

          final categories = ['Kognitif', 'Komunikasi', 'Sosial', 'Pergerakan'];
          final List<Map<String, dynamic>> progressList = categories.map((cat) {
            final catMilestones = allMilestones
                .where((m) => m.category
                    .toLowerCase()
                    .contains(cat.toLowerCase().substring(0, 3)))
                .toList();

            final achievedCount =
                catMilestones.where((m) => achievedMap[m.id] == true).length;
            final progress = catMilestones.isEmpty
                ? 0.0
                : achievedCount / catMilestones.length;

            return {
              "name": cat,
              "progress": progress,
              "icon": _getCategoryIcon(cat),
              "color": _getCategoryColor(cat),
            };
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              // Ketinggian dikecilkan kepada 130 untuk design compact
              SizedBox(
                height: 130,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  itemCount: progressList.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final milestone = progressList[index];
                    final progress = milestone["progress"] as double;
                    final Color baseColor = milestone["color"] as Color;

                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return Container(
                          width: 130, // Saiz kotak lebih kecil
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: baseColor, // WARNA BOLD & TERANG
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: baseColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Ikon dan Peratus di baris atas
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(
                                    milestone["icon"] as IconData,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  Text(
                                    "${(value * 100).toInt()}%",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              // Nama Kategori (Teks Putih)
                              Text(
                                milestone["name"] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              // Linear Progress Bar yang nipis & moden
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: value,
                                  minHeight: 5,
                                  backgroundColor:
                                      Colors.white.withOpacity(0.3),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

class CaregiverHomePage extends StatefulWidget {
  const CaregiverHomePage({super.key});

  @override
  _CaregiverHomePageState createState() => _CaregiverHomePageState();
}

bool _isUpcomingVaccine(Map<String, dynamic> data) {
  final hasDate =
      data.containsKey('dateScheduled') && data['dateScheduled'] != null;

  final notTaken = !data.containsKey('taken') || data['taken'] == false;

  return hasDate && notTaken;
}

class _CaregiverHomePageState extends State<CaregiverHomePage> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'kognitif':
        return Colors.purple; // Ungu
      case 'komunikasi':
        return Colors.orangeAccent; // Oren
      case 'sosial':
        return Colors.greenAccent.shade700; // Hijau
      case 'pergerakan':
        return const Color.fromARGB(255, 6, 16, 215); // Kuning
      default:
        return Colors.blue;
    }
  }

  Widget _buildMonthlyMilestones(String babyId, DateTime dob) {
    final int currentAgeMonths = (DateTime.now().year - dob.year) * 12 +
        (DateTime.now().month - dob.month) -
        (DateTime.now().day < dob.day ? 1 : 0);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('milestones')
          .orderBy('age_from')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryColor));
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text('Tiada pencapaian tersedia',
                style: TextStyle(color: Colors.grey.shade700)),
          );
        }

        final matching = snap.data!.docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final af = (data['age_from'] ?? 0) as int;
          final at = (data['age_to'] ?? 0) as int;
          return currentAgeMonths >= af && currentAgeMonths <= at;
        }).toList();

        if (matching.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text('Tiada pencapaian untuk julat umur ini.',
                style: TextStyle(color: Colors.grey.shade700)),
          );
        }

        return Column(
          children: matching.map((d) {
            final data = d.data() as Map<String, dynamic>;
            return milestoneCard(
              title: data['name'] ?? '-',
              category: data['category'] ?? 'lain-lain',
              achieved: false,
              achievedDate: null,
              onTap: () {},
            );
          }).toList(),
        );
      },
    );
  }

// ===================== TIPS PREVIEW (Admin upload, user display via URL) =====================

// Helper method untuk build baby avatar (USER upload - local storage)
  Widget _buildBabyAvatar(String? photoPath) {
    // Jika tiada gambar, tunjukkan icon default
    if (photoPath == null || photoPath.isEmpty) {
      return CircleAvatar(
        radius: 42,
        backgroundColor: Colors.blue.shade100,
        child: Icon(
          Icons.baby_changing_station_rounded,
          size: 40,
          color: Colors.blue.shade700,
        ),
      );
    }

    // Untuk Web - show placeholder
    if (kIsWeb) {
      debugPrint('Web detected - showing placeholder for baby photo');
      return CircleAvatar(
        radius: 42,
        backgroundColor: Colors.blue.shade100,
        child: Icon(
          Icons.baby_changing_station_rounded,
          size: 40,
          color: Colors.blue.shade700,
        ),
      );
    }

    // Untuk Mobile - guna FileImage dari local path
    try {
      final file = File(photoPath);

      // Check if file exists
      if (!file.existsSync()) {
        debugPrint('❌ Baby photo not found at path: $photoPath');
        return CircleAvatar(
          radius: 42,
          backgroundColor: Colors.blue.shade100,
          child: Icon(
            Icons.baby_changing_station_rounded,
            size: 40,
            color: Colors.blue.shade700,
          ),
        );
      }

      debugPrint('✅ Loading baby photo from: $photoPath');
      return CircleAvatar(
        radius: 42,
        backgroundColor: Colors.blue.shade100,
        backgroundImage: FileImage(file),
        onBackgroundImageError: (exception, stackTrace) {
          debugPrint('❌ Error loading baby photo: $exception');
        },
      );
    } catch (e) {
      debugPrint('❌ Exception accessing baby photo file: $e');

      // Fallback jika ada error
      return CircleAvatar(
        radius: 42,
        backgroundColor: Colors.blue.shade100,
        child: Icon(
          Icons.baby_changing_station_rounded,
          size: 40,
          color: Colors.blue.shade700,
        ),
      );
    }
  }

// ...existing code...

  void _showVaccineAlert(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Peringatan Vaksin"),
        content: const Text(
            "Terdapat vaksin yang telah dijadualkan untuk si manja anda. Sila semak jadual di bawah."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _showNotificationsDialog(BuildContext context,
      DocumentReference caregiverDoc, String babyId) async {
    final vacSnap = await caregiverDoc
        .collection('babies')
        .doc(babyId)
        .collection('vaccines')
        .get();

    final msSnap = await caregiverDoc
        .collection('babies')
        .doc(babyId)
        .collection('milestones')
        .get();

    final List<Map<String, dynamic>> items = [];

    for (var doc in vacSnap.docs) {
      final data = doc.data();
      if (data['dateScheduled'] != null &&
          data['taken'] != true &&
          data['notif_seen'] != true) {
        final DateTime scheduled =
            (data['dateScheduled'] as Timestamp).toDate();
        final formatted =
            '${scheduled.day.toString().padLeft(2, "0")}/${scheduled.month.toString().padLeft(2, "0")}/${scheduled.year}';
        items.add({
          'type': 'vaccine',
          'title': data['vaccineName'] ?? data['name'] ?? doc.id,
          'subtitle': 'Tarikh: $formatted',
          'docId': doc.id,
        });
      }
    }

    for (var doc in msSnap.docs) {
      final data = doc.data();
      if (data['achieved'] == true && data['notif_seen'] != true) {
        String achievedAt = 'Dicapai';
        if (data.containsKey('achieved_at') && data['achieved_at'] != null) {
          final a = data['achieved_at'];
          DateTime dt;
          if (a is Timestamp)
            dt = a.toDate();
          else if (a is DateTime)
            dt = a;
          else
            dt = DateTime.now();
          achievedAt =
              'Dicapai: ${dt.day.toString().padLeft(2, "0")}/${dt.month.toString().padLeft(2, "0")}/${dt.year}';
        }

        items.add({
          'type': 'milestone',
          'title': data['name'] ?? doc.id,
          'subtitle': achievedAt,
          'docId': doc.id,
        });
      }
    }

    // Mark items as seen in Firestore so bell disappears after viewing
    for (var it in items) {
      try {
        if (it['type'] == 'vaccine') {
          await caregiverDoc
              .collection('babies')
              .doc(babyId)
              .collection('vaccines')
              .doc(it['docId'])
              .update({'notif_seen': true});
        } else if (it['type'] == 'milestone') {
          await caregiverDoc
              .collection('babies')
              .doc(babyId)
              .collection('milestones')
              .doc(it['docId'])
              .update({'notif_seen': true});
        }
      } catch (e) {
        // ignore errors
      }
    }

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Notifikasi'),
        content: SizedBox(
          width: double.maxFinite,
          height: 320,
          child: items.isEmpty
              ? const Center(child: Text('Tiada notifikasi'))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final it = items[index];
                    return ListTile(
                      leading: Icon(
                        it['type'] == 'vaccine'
                            ? Icons.vaccines
                            : Icons.celebration,
                        color: it['type'] == 'vaccine'
                            ? primaryColor
                            : Colors.orange,
                      ),
                      title: Text(it['title'] ?? '-'),
                      subtitle: Text(it['subtitle'] ?? ''),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup')),
        ],
      ),
    );
  }

  void _showTipDialogLocal(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text(content, style: TextStyle(color: Colors.grey.shade800)),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('TUTUP')),
              )
            ],
          ),
        ),
      ),
    );
  }

  // ===================== UTILITY FUNCTIONS =====================
  String _calculateAge(DateTime dob) {
    final now = DateTime.now();
    final months = (now.year - dob.year) * 12 + now.month - dob.month;
    final totalDaysInCurrentMonth = DateTime(now.year, now.month + 1, 0).day;
    final actualDays = (now.day >= dob.day)
        ? now.day - dob.day
        : (totalDaysInCurrentMonth - dob.day) + now.day;

    // Logik tambahan: Jika 0 bulan, paparkan hari sahaja.
    if (months < 1) {
      return "$actualDays hari";
    }
    return "$months bulan $actualDays hari";
  }

  // ===================== WIDGET UTAMA (GABUNGAN NAMA, GAMBAR & UMUR) =====================
  // ...existing code...

  Widget buildHeaderWithBubbles(String babyName, String ageText,
      String? photoPath, bool hasNotification, VoidCallback onNotificationTap) {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade300,
            Colors.blue.shade500,
            Colors.blue.shade700,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // BUBBLE DEKORASI (Modern Soft Look)
            Positioned(
              top: -20,
              right: -20,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white.withOpacity(0.12),
              ),
            ),
            Positioned(
              bottom: -10,
              left: 50,
              child: CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withOpacity(0.08),
              ),
            ),
            Positioned(
              top: 15,
              right: 15,
              child: InkWell(
                onTap: onNotificationTap,
                child: Stack(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.notifications_active_outlined,
                          color: Colors.white, size: 28),
                    ),
                    if (hasNotification)
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          height: 12,
                          width: 12,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.blue.shade500, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // CONTENT HEADER
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  // Gambar Bayi dengan Ring Putih
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: _buildBabyAvatar(photoPath),
                  ),
                  const SizedBox(width: 20),

                  // Teks Nama & Umur
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Halo, Si Comel!",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          babyName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),

                        // Badge Umur (Glassmorphism effect)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_awesome,
                                  color: Colors.yellowAccent, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                ageText,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

// Helper method untuk build avatar dengan proper image handling
// ...existing code...
  // ===================== UPCOMING VACCINES LIST (Dibiarkan sama) =====================
  Widget _buildUpcomingVaccines(String babyId, DocumentReference caregiverDoc) {
    final babyVaccinesCol =
        caregiverDoc.collection('babies').doc(babyId).collection('vaccines');

    return StreamBuilder<QuerySnapshot>(
      stream: babyVaccinesCol.snapshots(),
      builder: (context, babyVaccineSnap) {
        if (!babyVaccineSnap.hasData) return const SizedBox();

        final scheduledVaccines = babyVaccineSnap.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['dateScheduled'] != null && data['taken'] != true;
        }).toList();

        if (scheduledVaccines.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(
                left: 16.0), // Padding untuk selaras dengan item list
            child: Text(
              "Tiada vaksin yang dijadualkan lagi.",
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          );
        }

        scheduledVaccines.sort((a, b) {
          final da = (a['dateScheduled'] as Timestamp).toDate();
          final db = (b['dateScheduled'] as Timestamp).toDate();
          return da.compareTo(db);
        });

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('vaccines').snapshots(),
          builder: (context, adminSnap) {
            if (!adminSnap.hasData) return const SizedBox();

            final adminData = {for (var d in adminSnap.data!.docs) d.id: d};

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: scheduledVaccines.length,
              itemBuilder: (context, index) {
                final doc = scheduledVaccines[index];
                final vaccineId = doc.id;
                final scheduledDate =
                    (doc['dateScheduled'] as Timestamp).toDate();

                final vaccineInfo = adminData[vaccineId];
                final babyDocData = doc.data() as Map<String, dynamic>;
                final vaccineName = babyDocData['vaccineName'] ??
                    vaccineInfo?['name'] ??
                    "Vaksin Tidak Ditemui";

                return StatefulBuilder(
                  builder: (context, setStateItem) {
                    double opacity = 1.0;
                    double offsetX = 0.0;
                    bool done = false;

                    Future<void> runAnimationAndUpdate() async {
                      // fade & slide out
                      setStateItem(() {
                        offsetX = 40.0;
                        opacity = 0.0;
                        done = true;
                      });

                      await Future.delayed(const Duration(milliseconds: 400));

                      // Firestore update
                      await caregiverDoc
                          .collection('babies')
                          .doc(babyId)
                          .collection('completed_vaccines')
                          .doc(vaccineId)
                          .set({
                        'completed': true,
                        'completed_at': Timestamp.now(),
                        'name': vaccineName,
                      });

                      await babyVaccinesCol.doc(vaccineId).update({
                        'taken': true,
                      });
                    }

                    return AnimatedOpacity(
                      duration: const Duration(milliseconds: 400),
                      opacity: opacity,
                      child: Transform.translate(
                        offset: Offset(offsetX, 0),
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: primaryColor.withOpacity(0.4),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.shade100.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.vaccines,
                                  color: primaryColor, size: 28),
                              const SizedBox(width: 16),

                              // Info teks
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      vaccineName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      "Tarikh: ${scheduledDate.day}/${scheduledDate.month}/${scheduledDate.year}",
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _formatRemainingText(scheduledDate),
                                      style: TextStyle(
                                          color: Colors.orange.shade700,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),

                              // ================= BUTTON BEFORE TICK =================
                              if (!done)
                                InkWell(
                                  onTap: () async {
                                    // 1️⃣ Tunjuk modal input growth
                                    await _showGrowthFormDialog(
                                        context,
                                        caregiverDoc
                                            .collection('babies')
                                            .doc(babyId),
                                        vaccineId,
                                        vaccineName);

                                    // 2️⃣ Jalankan animation & update vaksin completed
                                    await runAnimationAndUpdate();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: primaryColor, // 💙 BIRU
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: const Text(
                                      "Done",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),

                              // ================= ICON TICK AFTER DONE =================
                              if (done)
                                const Icon(Icons.check_circle,
                                    color: Colors.green, size: 32),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  // Helper: format remaining time until scheduled date (Malay)
  String _formatRemainingText(DateTime scheduled) {
    final now = DateTime.now();
    final diff = scheduled.difference(now);
    if (diff.inSeconds <= 0) {
      return 'Terlambat';
    }

    final days = diff.inDays;
    final hours = diff.inHours.remainder(24);
    final minutes = diff.inMinutes.remainder(60);

    if (days > 0) {
      return 'Dalam ${days} hari ${hours} jam';
    } else if (hours > 0) {
      return 'Dalam ${hours} jam ${minutes} min';
    } else {
      return 'Dalam ${minutes} minit';
    }
  }

  Future<void> _showGrowthFormDialog(
    BuildContext context,
    DocumentReference babyDocRef,
    String vaccineId,
    String vaccineName,
  ) async {
    final weightController = TextEditingController();
    final heightController = TextEditingController();
    final noteController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // supaya rounded effect keluar
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Maklumat Perkembangan Bayi",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: const Color(0xFF007BFF)),
            ),
            const SizedBox(height: 16),

            // Berat
            _buildStyledTextField(weightController, "Berat (kg)"),
            // Tinggi
            _buildStyledTextField(heightController, "Tinggi (cm)"),
            // Nota
            _buildStyledTextField(noteController, "Nota (jika ada)"),

            const SizedBox(height: 20),
            // Button simpan
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  colors: [Color(0xFF7F00FF), Color(0xFF00BFFF)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 3))
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () async {
                    double? weight = double.tryParse(weightController.text);
                    double? height = double.tryParse(heightController.text);
                    String note = noteController.text;

                    await babyDocRef.collection('growth_records').doc().set({
                      'weight': weight,
                      'height': height,
                      'note': note,
                      'vaccineId': vaccineId,
                      'vaccineName': vaccineName,
                      'date': Timestamp.now(),
                    });

                    Navigator.pop(ctx);
                  },
                  child: const Center(
                    child: Text(
                      "Simpan",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Reusable styled TextField
  Widget _buildStyledTextField(TextEditingController controller, String label) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 3))
        ],
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Color(0xFF4A148C)),
        keyboardType: label.contains('(kg)') || label.contains('(cm)')
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              TextStyle(color: const Color(0xFF4A148C).withOpacity(0.8)),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          border: InputBorder.none,
        ),
      ),
    );
  }

  // Show modal to manage vaccine dates and schedule a reminder 1 day before
  Future<void> _showVaccineScheduler(BuildContext context,
      DocumentReference caregiverDoc, String babyId) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
            top: 12, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Jadual Vaksin',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            Flexible(
              child: StreamBuilder<QuerySnapshot>(
                stream: caregiverDoc
                    .collection('babies')
                    .doc(babyId)
                    .collection('vaccines')
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData)
                    return const SizedBox(
                        height: 120,
                        child: Center(child: CircularProgressIndicator()));
                  final docs = snap.data!.docs;
                  if (docs.isEmpty)
                    return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text('Tiada rekod vaksin.'));

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      DateTime? scheduled;
                      if (data['dateScheduled'] is Timestamp) {
                        scheduled =
                            (data['dateScheduled'] as Timestamp).toDate();
                      } else if (data['dateScheduled'] is DateTime) {
                        scheduled = data['dateScheduled'] as DateTime;
                      }

                      return ListTile(
                        title:
                            Text(data['vaccineName'] ?? data['name'] ?? doc.id),
                        subtitle: Text(scheduled != null
                            ? '${scheduled.day}/${scheduled.month}/${scheduled.year}'
                            : 'Belum dijadualkan'),
                        trailing: TextButton(
                          child: const Text('Tetapkan'),
                          onPressed: () async {
                            final now = DateTime.now();
                            final initial =
                                scheduled ?? now.add(const Duration(days: 7));
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: initial,
                              firstDate: now,
                              lastDate: DateTime(now.year + 3),
                            );
                            if (picked != null) {
                              // assume default vaccination time 14:00; store with time
                              final scheduledDateTime = DateTime(
                                  picked.year, picked.month, picked.day, 14, 0);

                              // update Firestore with datetime and reset notif flag
                              await caregiverDoc
                                  .collection('babies')
                                  .doc(babyId)
                                  .collection('vaccines')
                                  .doc(doc.id)
                                  .update({
                                'dateScheduled':
                                    Timestamp.fromDate(scheduledDateTime),
                                'notif_seen': false,
                              });

                              // schedule local notification 5 hours before
                              final reminderDateTime = tz.TZDateTime.from(
                                  scheduledDateTime
                                      .subtract(const Duration(hours: 5)),
                                  tz.local);
                              final nid = doc.id.hashCode & 0x7fffffff;
                              await NotificationService.scheduleNotification(
                                id: nid,
                                title: 'Peringatan Vaksin',
                                body:
                                    'Ingat vaksinasi si comel hari ini pukul 14:00 - ${data['vaccineName'] ?? data['name'] ?? 'Vaksin'}',
                                scheduledDate: reminderDateTime,
                              );

                              Navigator.pop(ctx);
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Stream<bool> _hasNotificationsStream(
      DocumentReference caregiverDoc, String babyId) {
    final controller = StreamController<bool>.broadcast();
    bool lastHas = false;

    void computeAndAdd() async {
      try {
        bool has = false;
        String? foundType;
        String? foundTitle;
        DateTime? foundScheduled;

        final vacSnap = await caregiverDoc
            .collection('babies')
            .doc(babyId)
            .collection('vaccines')
            .get();

        for (var doc in vacSnap.docs) {
          final data = doc.data();
          if (data['dateScheduled'] != null &&
              data['taken'] != true &&
              data['notif_seen'] != true) {
            final scheduled = (data['dateScheduled'] as Timestamp).toDate();
            if (!scheduled.isBefore(DateTime.now())) {
              has = true;
              foundType = 'vaccine';
              foundTitle = (data as Map)['vaccineName'] ??
                  (data as Map)['name'] ??
                  doc.id;
              foundScheduled = scheduled;
              break;
            }
          }
        }

        if (!has) {
          final msSnap = await caregiverDoc
              .collection('babies')
              .doc(babyId)
              .collection('milestones')
              .get();

          for (var doc in msSnap.docs) {
            final data = doc.data();
            if (data['achieved'] == true && data['notif_seen'] != true) {
              has = true;
              foundType = 'milestone';
              foundTitle = data['name'] ?? doc.id;
              break;
            }
          }
        }

        if (!controller.isClosed) controller.add(has);

        // show one-time immediate local notification when became true
        if (has == true && lastHas == false) {
          final nid = ("notif_" + babyId).hashCode & 0x7fffffff;
          if (foundType == 'vaccine' && foundScheduled != null) {
            final hh = foundScheduled.hour.toString().padLeft(2, '0');
            final mm = foundScheduled.minute.toString().padLeft(2, '0');
            await NotificationService.showImmediateNotification(
                id: nid,
                title: 'Peringatan Vaksin',
                body:
                    'Ingat vaksinasi si comel hari ini pukul $hh:$mm — $foundTitle');
          } else if (foundType == 'milestone') {
            await NotificationService.showImmediateNotification(
                id: nid,
                title: 'Ukur Perkembangan',
                body:
                    'Mari ukur perkembangan bayi — jangan lupa kemaskini milestone.');
          } else {
            await NotificationService.showImmediateNotification(
                id: nid,
                title: 'Pemberitahuan Baru',
                body: 'Terdapat notifikasi vaksin/milestone untuk bayi anda.');
          }
        }
        lastHas = has;
      } catch (e) {
        if (!controller.isClosed) controller.add(false);
      }
    }

    final vaccinesSub = caregiverDoc
        .collection('babies')
        .doc(babyId)
        .collection('vaccines')
        .snapshots()
        .listen((_) => computeAndAdd());

    final milestonesSub = caregiverDoc
        .collection('babies')
        .doc(babyId)
        .collection('milestones')
        .snapshots()
        .listen((_) => computeAndAdd());

    // initial computation
    computeAndAdd();

    controller.onCancel = () {
      vaccinesSub.cancel();
      milestonesSub.cancel();
      controller.close();
    };

    return controller.stream;
  }

  // ===================== HOME TAB CONTENT (Menggunakan Imej Latar Belakang) =====================
  Widget _buildHomeTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
          child: Text("Sila log masuk", style: TextStyle(color: textColor)));
    }

    final caregiverDoc =
        FirebaseFirestore.instance.collection('caregivers').doc(user.uid);
    final babiesCollection = caregiverDoc.collection('babies');

    return Container(
      color: Colors.transparent,
      child: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: babiesCollection
              .orderBy('created_at', descending: true)
              .snapshots(),
          builder: (context, babiesSnapshot) {
            if (babiesSnapshot.connectionState == ConnectionState.waiting) {
              return Center(
                  child: CircularProgressIndicator(color: primaryColor));
            }
            if (!babiesSnapshot.hasData || babiesSnapshot.data!.docs.isEmpty) {
              return const Center(
                  child: Text("Tiada bayi lagi",
                      style: TextStyle(color: textColor)));
            }

            final baby = babiesSnapshot.data!.docs.first;
            final babyId = baby.id;
            final babyName = baby['name'] ?? "Bayi Anda";
            final localPhotoPath = baby['local_photo_path'] as String?;
            DateTime dob = (baby['dob'] as Timestamp).toDate();
            final ageText = _calculateAge(dob);

            // 👉 TAMBAH STREAM KEDUA UNTUK SEMAK VAKSIN
            return StreamBuilder<QuerySnapshot>(
              stream: babiesCollection
                  .doc(babyId)
                  .collection('vaccines')
                  .snapshots(),
              builder: (context, vaccineSnapshot) {
                // Logik: Adakah terdapat vaksin yang sudah diset tarikh tetapi belum diambil?
                bool hasNotification = false;
                if (vaccineSnapshot.hasData) {
                  hasNotification = vaccineSnapshot.data!.docs.any((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['dateScheduled'] != null &&
                        data['taken'] == false;
                  });
                }

                return CustomScrollView(
                  slivers: [
                    // HEADER DENGAN LOGIK NOTIFIKASI
                    SliverToBoxAdapter(
                      child: StreamBuilder<bool>(
                        stream: _hasNotificationsStream(caregiverDoc, babyId),
                        initialData: false,
                        builder: (context, snapshot) {
                          final hasNotification = snapshot.data ?? false;

                          return buildHeaderWithBubbles(
                            babyName,
                            ageText,
                            localPhotoPath,
                            hasNotification,
                            () => _showNotificationsDialog(
                                context, caregiverDoc, babyId),
                          );
                        },
                      ), // <== pastikan bracket ini tutup StreamBuilder
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 20),
                        child: _buildMilestonesIndicators(babyId),
                      ),
                    ),
                    // 2. TAJUK SEKSYEN VAKSIN
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, 10, 20, 5),
                        child: Text(
                          "Vaksin Akan Datang",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),

                    // 3. 👉 INI CARA PANGGIL WIDGET VAKSIN TERSEBUT
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: _NextVaccineCard(
                          caregiverDoc: caregiverDoc,
                          babyId: babyId,
                        ),
                      ),
                    ),

                    // 4. MILESTONES
// 4. TIPS HARI INI
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                        child: Text(
                          "Tips Hari Ini",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),

                    // 5. Hardcoded Tips (Tummy Time)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                'assets/images/tummy.jpg',
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      "Tummy Time",
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    "Manfaat Tummy Time untuk Bayi",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Kuatkan otot leher dan bahu si manja.",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Rotated wallpaper filling the background for all tabs
          Positioned.fill(
            child: Image.asset(
              'assets/images/wall13.png',
              fit: BoxFit.cover,
            ),
          ),

          // Main content over the wallpaper
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildHomeTab(), // 0: Utama (Home)
              MilestoneTab(),
              VaccinesTab(),
              TipsTab(),
              SettingsTab(),
            ],
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cardColor,
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.grey,
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          onTap: (index) {
            setState(() {
              _currentIndex = index;
              _pageController.jumpToPage(index);
            });
          },
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined), label: "Utama"),
            BottomNavigationBarItem(
                icon: Icon(Icons.timeline_outlined), label: "Pencapaian"),
            BottomNavigationBarItem(
                icon: Icon(Icons.local_hospital_outlined), label: "Vaksin"),
            BottomNavigationBarItem(
                icon: Icon(Icons.menu_book_outlined), label: "Tips"),
            BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined), label: "Tetapan"),
          ],
        ),
      ),
    );
  }
}
