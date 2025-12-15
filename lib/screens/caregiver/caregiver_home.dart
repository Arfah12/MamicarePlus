import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

// PASTIKAN ANDA MEMPUNYAI FAIL-FAIL INI DI LOKASI YANG BETUL
import 'milestone_tab.dart';
import 'vaccines_tab.dart';
import 'tips_tab.dart';
import 'setting_tab.dart';
import 'package:confetti/confetti.dart';

// ===================== MINIMALIST MODERN THEME COLORS & DESIGN =====================
const Color primaryColor = Color(0xFF007AFF); // Azure Blue (Modern Blue)
const Color secondaryColor = Color(0xFF34C759); // Green (for progress/status)
const Color backgroundColor = Color(0xFFF9F9F9); // Very Light Gray background
const Color cardColor = Colors.white; // Clean white for cards
const Color textColor = Color(0xFF1C1C1E); // Dark text

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

class CaregiverHomePage extends StatefulWidget {
  const CaregiverHomePage({super.key});

  @override
  State<CaregiverHomePage> createState() => _CaregiverHomePageState();
}

class _CaregiverHomePageState extends State<CaregiverHomePage> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

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

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'kognitif':
        return Icons.lightbulb_outline;
      case 'komunikasi':
        return Icons.record_voice_over_outlined;
      case 'sosial':
      case 'sosial-emosi':
        return Icons.people_outline;
      case 'pergerakan':
      case 'motor-kasar':
      case 'motor-halus':
        return Icons.directions_walk_outlined;
      default:
        return Icons.star_border;
    }
  }

  // ===================== WIDGET UTAMA (GABUNGAN NAMA, GAMBAR & UMUR) =====================
  Widget _buildBabyHeaderCard(String babyName, String ageText, String? localPhotoPath) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            // Gambar Bayi/Avatar
            CircleAvatar(
              radius: 35,
              backgroundColor: primaryColor.withOpacity(0.1),
              backgroundImage: localPhotoPath != null && localPhotoPath.isNotEmpty ? FileImage(File(localPhotoPath)) as ImageProvider : null,
              child: localPhotoPath == null || localPhotoPath.isEmpty
                  ? Icon(Icons.face_unlock_outlined, size: 35, color: primaryColor)
                  : null,
            ),
            const SizedBox(width: 15),
            
            // Nama Bayi & Umur Semasa
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    babyName,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.cake_outlined, color: primaryColor, size: 18),
                      const SizedBox(width: 5),
                      Text(
                        "Umur: $ageText",
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade400, size: 18),
          ],
        ),
      ),
    );
  }

  // ===================== MILESTONE PROGRESS INDICATORS =====================
  Widget _buildMilestonesIndicators(String babyId) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return const SizedBox();

  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('milestones').orderBy('age_from').snapshots(),
    builder: (context, milestoneSnap) {
      if (!milestoneSnap.hasData) {
        return Center(child: CircularProgressIndicator(color: primaryColor));
      }

      final allMilestones = milestoneSnap.data!.docs.map((d) => Milestone.fromFirestore(d)).toList();

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
              achievedMap[doc.id] = (doc.data() as Map<String, dynamic>)['achieved'] == true;
            }
          }

          final categories = ['Kognitif', 'Komunikasi', 'Sosial', 'Pergerakan'];
          final List<Map<String, dynamic>> progressList = categories.map((cat) {
            final catMilestones = allMilestones
                .where((m) => m.category.toLowerCase().contains(cat.toLowerCase().substring(0, 3)))
                .toList();

            final achievedCount = catMilestones.where((m) => achievedMap[m.id] == true).length;
            final progress = catMilestones.isEmpty ? 0.0 : achievedCount / catMilestones.length;

            return {
              "name": cat,
              "progress": progress,
              "icon": _getCategoryIcon(cat),
              "controller": ConfettiController(duration: const Duration(seconds: 1))
            };
          }).toList();

          return SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: progressList.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final milestone = progressList[index];
                final progress = milestone["progress"] as double;

                // 🎉 Confetti trigger bila 100%
                if (progress == 1.0) {
                  (milestone["controller"] as ConfettiController).play();
                }

                return Stack(
                  children: [
                    // 🎉 Confetti animation
                    Positioned.fill(
                      child: ConfettiWidget(
                        confettiController: milestone["controller"],
                        blastDirectionality: BlastDirectionality.explosive,
                        emissionFrequency: 0.4,
                        numberOfParticles: 8,
                        maxBlastForce: 10,
                        minBlastForce: 4,
                        gravity: 0.3,
                      ),
                    ),

                    // 🔥 Main Card with animation
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, animatedProgress, _) {
                        return AnimatedScale(
                          scale: 1.0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutBack,
                          child: Container(
                            width: 110,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.07),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 55,
                                      height: 55,
                                      child: CircularProgressIndicator(
                                        value: animatedProgress,
                                        strokeWidth: 6,
                                        backgroundColor: primaryColor.withOpacity(0.15),
                                        valueColor: AlwaysStoppedAnimation<Color>(secondaryColor),
                                      ),
                                    ),
                                    AnimatedScale(
                                      scale: animatedProgress == 1.0 ? 1.2 : 1.0,
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeOutBack,
                                      child: Icon(
                                        milestone["icon"] as IconData,
                                        size: 26,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                Text(
                                  milestone["name"] as String,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                Text(
                                  "${(animatedProgress * 100).toInt()}%",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: secondaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          );
        },
      );
    },
  );
}

  // ===================== UPCOMING MILESTONES LIST (Dibiarkan sama) =====================
  Widget _buildMonthlyMilestones(String babyId, DateTime dob) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return const SizedBox();

  int currentAgeMonths = (DateTime.now().year - dob.year) * 12 +
      (DateTime.now().month - dob.month);
  if (DateTime.now().day < dob.day) {
    currentAgeMonths -= 1;
  }

  final caregiverDoc = FirebaseFirestore.instance.collection('caregivers').doc(user.uid);

  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('milestones')
        .where('age_from', isLessThanOrEqualTo: currentAgeMonths)
        .where('age_to', isGreaterThanOrEqualTo: currentAgeMonths)
        .orderBy('age_from')
        .snapshots(),
    builder: (context, milestoneSnap) {
      if (!milestoneSnap.hasData) return const Center(child: CircularProgressIndicator());

      final milestones = milestoneSnap.data!.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return {
          'id': d.id,
          'name': data['name'] ?? '-',
          'category': data['category'] ?? 'lain-lain',
        };
      }).toList();

      return StreamBuilder<QuerySnapshot>(
        stream: caregiverDoc
            .collection('babies')
            .doc(babyId)
            .collection('milestones')
            .snapshots(),
        builder: (context, babyMilestoneSnap) {
          Map<String, dynamic> achievedMap = {};
          if (babyMilestoneSnap.hasData) {
            for (var doc in babyMilestoneSnap.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              achievedMap[doc.id] = {
                'achieved': data['achieved'] ?? false,
                'achieved_at': (data['achieved_at'] as Timestamp?)?.toDate()

              };
            }
          }

          if (milestones.isEmpty) {
            return const Text(
              "Tiada milestone untuk bulan ini",
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            );
          }

          return ListView.separated(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  itemCount: milestones.length,
  separatorBuilder: (_, __) => const SizedBox(height: 8),
  itemBuilder: (context, index) {
    final milestone = milestones[index];
    final achievedData = achievedMap[milestone['id']] ?? {'achieved': false, 'date': null};
    final achieved = achievedData['achieved'] as bool;
    final achievedDate = achievedData['achieved_at'] as DateTime?;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, animation) => RotationTransition(turns: animation, child: child),
            child: Icon(
              achieved ? Icons.check_circle : Icons.circle_outlined,
              key: ValueKey(achieved),
              color: achieved ? Colors.green : Colors.grey,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  milestone['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                if (achievedDate != null)
                  Text(
                    "Dicapai pada: ${achievedDate.day}/${achievedDate.month}/${achievedDate.year}",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
          IconButton(
  icon: Icon(
    achieved ? Icons.remove_circle_outline : Icons.check,
    color: achieved ? Colors.orange : Colors.green,
    size: 28,
  ),
  tooltip: achieved ? "Batal capai" : "Tandakan selesai",
  onPressed: () async {
    if (!achieved) {
      // Papar DatePicker
      DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
      );

      if (pickedDate != null) {
        // Update Firestore dengan tarikh yang dipilih
        await caregiverDoc
            .collection('babies')
            .doc(babyId)
            .collection('milestones')
            .doc(milestone['id'])
            .set({
          'achieved': true,
          'achieved_at': Timestamp.fromDate(pickedDate),

        }, SetOptions(merge: true));
      }
    } else {
      // Batalkan pencapaian
      await caregiverDoc
          .collection('babies')
          .doc(babyId)
          .collection('milestones')
          .doc(milestone['id'])
          .set({
        'achieved': false,
        'achieved_at': null,

      }, SetOptions(merge: true));
    }
  },
),

        ],
      ),
    );
  },
);

        },
      );
    },
  );
}


  // ===================== UPCOMING VACCINES LIST (Dibiarkan sama) =====================
Widget _buildUpcomingVaccines(
  String babyId, DocumentReference caregiverDoc) {

  final babyVaccinesCol = caregiverDoc
      .collection('babies')
      .doc(babyId)
      .collection('vaccines');

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
            padding: EdgeInsets.only(left: 16.0), // Padding untuk selaras dengan item list
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
              final vaccineName =
                  vaccineInfo?['name'] ?? "Vaksin Tidak Ditemui";

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
                                ],
                              ),
                            ),

                            // ================= BUTTON BEFORE TICK =================
                            if (!done)
                              InkWell(
                                onTap: () async {
  // 1️⃣ Tunjuk modal input growth
  await _showGrowthFormDialog(context, caregiverDoc
      .collection('babies').doc(babyId), vaccineId, vaccineName);

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
      keyboardType: label.contains('(kg)') || label.contains('(cm)') ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: const Color(0xFF4A148C).withOpacity(0.8)),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        border: InputBorder.none,
      ),
    ),
  );
}


  // ===================== HOME TAB CONTENT (Menggunakan Imej Latar Belakang) =====================
  Widget _buildHomeTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text("Sila log masuk", style: TextStyle(color: textColor)));

    final caregiverDoc = FirebaseFirestore.instance.collection('caregivers').doc(user.uid);
    final babiesCollection = caregiverDoc.collection('babies');

    return Container(
      // === KUNCI: BACKGROUND IMAGE DI SINI ===
      decoration: BoxDecoration(
         // Warna sandaran
        image: DecorationImage(
          image: AssetImage('assets/images/wallpaper1.jpg'), // Laluan imej yang diminta
          fit: BoxFit.cover, // Untuk mengisi keseluruhan ruang
          colorFilter: ColorFilter.mode(
            Colors.white.withOpacity(0.5), // Tambah sedikit keputihan untuk kontras teks
            BlendMode.lighten,
          ),
        ),
        color: backgroundColor, // Background fallback
      ),
      child: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: babiesCollection.orderBy('created_at', descending: true).snapshots(),
          builder: (context, babiesSnapshot) {
            if (babiesSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: primaryColor));
            }
            if (!babiesSnapshot.hasData || babiesSnapshot.data!.docs.isEmpty) {
              return const Center(child: Text("Tiada bayi lagi", style: TextStyle(color: textColor)));
            }

            final babies = babiesSnapshot.data!.docs;
            final caregiverName = user.displayName ?? "Penjaga";
            final baby = babies.first;
            final babyName = baby['name'] ?? "Bayi Anda";
            final localPhotoPath = baby['local_photo_path'] as String?;
            DateTime dob = (baby['dob'] as Timestamp).toDate();
            final ageText = _calculateAge(dob);
            // final currentAgeMonths = (DateTime.now().year - dob.year) * 12 + (DateTime.now().month - dob.month);

            return CustomScrollView(
              slivers: [
                // --- Custom Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Text(
                      "Selamat Datang, $caregiverName",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                
                SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      // --- KAD GABUNGAN BAYI ---
                      _buildBabyHeaderCard(babyName, ageText, localPhotoPath),

                      // --- PROGRESS INDICATORS ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          "Progres Pencapaian Kategori",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildMilestonesIndicators(baby.id),

                      const SizedBox(height: 30),

                      // --- UPCOMING MILESTONES ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Pencapaian Akan Datang",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                            ),
                            const SizedBox(height: 16),
                           _buildMonthlyMilestones(baby.id, dob)

                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // --- UPCOMING VACCINES ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Vaksin Akan Datang",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                            ),
                            const SizedBox(height: 16),
                            _buildUpcomingVaccines(baby.id, caregiverDoc),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ===================== MAIN BUILD METHOD =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Background Transparent sebab PageView/HomeTab menguruskan latar belakang.
      backgroundColor: Colors.transparent, 
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildHomeTab(), // 0: Utama (Home)
          // Tab lain dibiarkan tanpa background image
          MilestoneTab(), 
          VaccinesTab(), 
          TipsTab(),      
          SettingsTab(),  
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cardColor,
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent, 
          elevation: 0, 
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          selectedItemColor: primaryColor, 
          unselectedItemColor: Colors.grey, 
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          onTap: (index) {
            setState(() {
              _currentIndex = index;
              _pageController.jumpToPage(index);
            });
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: "Utama"),
            BottomNavigationBarItem(icon: Icon(Icons.timeline_outlined), label: "Pencapaian"),
            BottomNavigationBarItem(icon: Icon(Icons.local_hospital_outlined), label: "Vaksin"),
            BottomNavigationBarItem(icon: Icon(Icons.menu_book_outlined), label: "Tips"),
            BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: "Tetapan"),
          ],
        ),
      ),
    );
  }
}
