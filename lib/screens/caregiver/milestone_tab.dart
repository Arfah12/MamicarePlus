import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
// confetti removed — not used in this tab

// ================== MYSEJAHTERA THEME COLORS ==================
const Color primaryColor = Color(0xFF007AFF); // Biru Kuat
const Color accentColor = Color(0xFF34C759); // Hijau
const Color errorColor = Color(0xFFFF3B30); // Merah
const Color backgroundColor = Color(0xFFF5F7FA);
const Color cardColor = Colors.white;
const Color textColor = Color(0xFF1C1C1E);
const Color lightGrey = Color(0xFFE5E5EA);
// ===============================================================

/// Model Milestone
class Milestone {
  final String id;
  final String name;
  final String category;
  final int ageFrom;
  final int ageTo;
  final String description;

  Milestone({
    required this.id,
    required this.name,
    required this.category,
    required this.ageFrom,
    required this.ageTo,
    required this.description,
  });

  factory Milestone.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Milestone(
      id: doc.id,
      name: data['name'] ?? 'Tiada Tajuk',
      category: data['category'] ?? 'Am',
      // Pastikan data umur diolah dengan betul sebagai integer (menggunakan num? untuk melindungi dari jenis data yang salah)
      ageFrom: (data['age_from'] as num?)?.toInt() ?? 0,
      ageTo: (data['age_to'] as num?)?.toInt() ?? 999,
      description: data['description'] ?? 'Tiada huraian disediakan.',
    );
  }
}

/// Model Baby (untuk header)
class Baby {
  final String id;
  final String name;
  final DateTime dateOfBirth;
  final String? photoUrl;

  Baby(
      {required this.id,
      required this.name,
      required this.dateOfBirth,
      this.photoUrl});

  factory Baby.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Baby(
      id: doc.id,
      name: data['name'] ?? 'Bayi Saya',
      // Mengambil 'date_of_birth' yang mungkin disimpan sebagai FieldValue.serverTimestamp() atau Timestamp
      dateOfBirth: (data['dob'] as Timestamp?)?.toDate() ?? DateTime.now(),
      photoUrl: data['photo_url'],
    );
  }
}

// ================== MILESTONE TAB ==================
class MilestoneTab extends StatefulWidget {
  const MilestoneTab({super.key});

  @override
  State<MilestoneTab> createState() => _MilestoneTabState();
}

class _MilestoneTabState extends State<MilestoneTab> {
  int selectedIndex = 0;

  // Daftar Julat Bulan
  final List<Map<String, dynamic>> months = [
    {"label": "0–2", "from": 0, "to": 2},
    {"label": "3–4", "from": 3, "to": 4},
    {"label": "5–6", "from": 5, "to": 6},
    {"label": "9–10", "from": 9, "to": 10},
    {"label": "12–15", "from": 12, "to": 15},
  ];

  // Kategori yang dijangkakan dalam Koleksi Master
  final List<String> categories = [
    'Kognitif',
    'Komunikasi',
    'Sosial',
    'Pergerakan'
  ];

  final CollectionReference milestonesCollection =
      FirebaseFirestore.instance.collection('milestones');

  Map<String, Color> categoryColors = {
    'kognitif': const Color(0xFF32ADE6),
    'komunikasi': const Color(0xFFFF9500),
    'sosial': const Color(0xFFFFCC00),
    'pergerakan': accentColor,
    'lain-lain': const Color(0xFFA2845E),
  };

  Color _getCategoryColor(String category) {
    return categoryColors[category.toLowerCase()] ??
        categoryColors['lain-lain']!;
  }

  // Future untuk memegang data Master Milestone
  late Future<List<Milestone>> _masterMilestonesFuture;

  @override
  void initState() {
    super.initState();
    // Inisialisasi Future untuk memuatkan data master sekali sahaja
    _masterMilestonesFuture = _fetchMasterMilestones();
  }

  Widget _buildHeaderVibrant(
  TextTheme textTheme,
  Baby baby,
  int babyAgeInMonths,
  Map<String, double> categoryProgress,
) {
  return Container(
    margin: const EdgeInsets.fromLTRB(16, 50, 16, 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.9),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Pencapaian ${baby.name}",
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor.withOpacity(0.6),
                  ),
                ),
                Text(
                  "$babyAgeInMonths Bulan",
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            const CircleAvatar(
              radius: 25,
              backgroundColor: Color(0xFFE1E9FF),
              child: Icon(Icons.child_care, color: primaryColor, size: 30),
            )
          ],
        ),
        const SizedBox(height: 20),
        const Divider(height: 1),
        const SizedBox(height: 20),
        
        // Grid untuk progress kategori
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.5,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: categoryProgress.length,
          itemBuilder: (context, index) {
            String cat = categoryProgress.keys.elementAt(index);
            double progress = categoryProgress[cat]!;
            Color color = _getCategoryColor(cat);
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(cat, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text("${(progress * 100).toInt()}%", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: color.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'kognitif':
        return Icons.psychology;
      case 'komunikasi':
        return Icons.record_voice_over;
      case 'sosial':
        return Icons.groups;
      case 'pergerakan':
        return Icons.directions_run;
      default:
        return Icons.star;
    }
  }

  // milestone indicators removed — UI now shows filtered milestones only

  // ============== LOGIK TOGGLE ACHIEVED BARU/DIUBAH ==============

  /// Menukar status capaian milestone.
  Future<void> _toggleAchieved({
    required String babyId,
    required String milestoneId,
    required bool currentlyAchieved,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('caregivers')
        .doc(user.uid)
        .collection('babies')
        .doc(babyId)
        .collection('milestones')
        .doc(milestoneId);

    try {
      if (currentlyAchieved) {
        // Jika sudah dicapai, PADAM rekod
        await docRef.delete();
      } else {
        // Jika belum dicapai, TAMBAH rekod
        await docRef.set({
          'achieved': true,
          'achieved_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(context, 'Ralat: Gagal kemas kini status milestone.',
            isError: true);
      }
    }
  }

  // Fungsi asal dengan tarikh (dikekalkan, tetapi tidak digunakan)
  Future<void> _toggleAchievedWithDate({
    required String babyId,
    required String milestoneId,
    required DateTime achievedDate,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('caregivers')
        .doc(user.uid)
        .collection('babies')
        .doc(babyId)
        .collection('milestones')
        .doc(milestoneId);

    await docRef.set({
      'achieved': true,
      'achieved_at': Timestamp.fromDate(achievedDate),
    }, SetOptions(merge: true));
  }

  // ============== FUTURE DATA & LOGIK PERKIRAAN ==============

  // Ganti Stream dengan Future untuk memuatkan data master sekali sahaja.
  Future<List<Milestone>> _fetchMasterMilestones() async {
    // Memuatkan SEMUA Milestone dari Koleksi Master
    final snapshot = await milestonesCollection.orderBy('age_from').get();

    // Ini menangkap jika tiada dokumen yang dibenarkan untuk dibaca oleh Firestore Rules
    if (snapshot.docs.isEmpty) {
      throw Exception(
          "Tiada milestone master ditemui atau akses dinafikan. Pastikan Firestore Rules membenarkan 'read' oleh isAuthenticated().");
    }

    return snapshot.docs.map((d) => Milestone.fromFirestore(d)).toList();
  }

  double _calculateCategoryProgress(String category,
      Map<String, bool> achievedMap, List<Milestone> allMilestones) {
    final selectedFrom = months[selectedIndex]['from'] as int;
    final selectedTo = months[selectedIndex]['to'] as int;

    // Tapis milestone mengikut julat umur semasa yang dipilih
    final filteredMilestones = allMilestones
        .where((m) => m.ageFrom <= selectedTo && m.ageTo >= selectedFrom)
        .toList();

    // Tapis mengikut kategori
    final catMilestones = filteredMilestones
        .where((m) => m.category.toLowerCase() == category.toLowerCase())
        .toList();

    if (catMilestones.isEmpty) return 0.0;

    final achievedCount =
        catMilestones.where((m) => achievedMap[m.id] == true).length;
    return achievedCount / catMilestones.length;
  }

  void _showSnackBar(BuildContext context, String message,
      {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: isError ? errorColor : primaryColor,
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  // ============== WIDGET BUILDER ==============

  Widget _buildMonthSelectorSliver(TextTheme textTheme) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Text(
            'Fasa Umur',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textColor),
          ),
        ),
        SizedBox(
          height: 45,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16),
            itemCount: months.length,
            itemBuilder: (context, index) {
              final selected = selectedIndex == index;
              return GestureDetector(
                onTap: () => setState(() => selectedIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: selected ? primaryColor : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: selected 
                      ? [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
                      : [],
                    border: Border.all(
                      color: selected ? primaryColor : lightGrey,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      "${months[index]["label"]} bln",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: selected ? Colors.white : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/wall13.png"),
            fit: BoxFit.cover,
            opacity: 0.9, // lembut
          ),
        ),

        // ================== BODY MULA SINI ==================
        child: user == null
            ? Center(child: _authPlaceholder(textTheme))
            : StreamBuilder<QuerySnapshot>(
                // Stream 1: Dapatkan data Bayi (untuk babyId)
                stream: FirebaseFirestore.instance
                    .collection('caregivers')
                    .doc(user.uid)
                    .collection('babies')
                    .orderBy('created_at', descending: true)
                    .limit(1)
                    .snapshots(),
                builder: (context, babySnap) {
                  if (babySnap.connectionState == ConnectionState.waiting) {
                    return Center(
                        child: CircularProgressIndicator(color: primaryColor));
                  }
                  if (!babySnap.hasData || babySnap.data!.docs.isEmpty) {
                    return Center(child: _noBabyPlaceholder(textTheme));
                  }

                  final babyDoc = babySnap.data!.docs.first;
                  final baby = Baby.fromFirestore(babyDoc);
                  final babyId = babyDoc.id;

                  final now = DateTime.now();
                  final ageDiff = now.difference(baby.dateOfBirth);
                  final babyAgeInMonths = (ageDiff.inDays / 30.4375).round();

                  // Stream 2: Dapatkan rekod Milestone yang dicapai oleh Bayi ini
                  final babyMilestonesStream = FirebaseFirestore.instance
                      .collection('caregivers')
                      .doc(user.uid)
                      .collection('babies')
                      .doc(babyId)
                      .collection('milestones')
                      .snapshots();

                  // Future 3: Dapatkan SEMUA Milestone Master dari Admin (Sekali sahaja)
                  return FutureBuilder<List<Milestone>>(
                    // Menggunakan Future yang diinisialisasi dalam initState
                    future: _masterMilestonesFuture,
                    builder: (context, milestoneSnap) {
                      if (milestoneSnap.connectionState ==
                          ConnectionState.waiting) {
                        return Center(
                            child:
                                CircularProgressIndicator(color: primaryColor));
                      }
                      // Menangani Ralat atau Tiada Data Master
                      if (milestoneSnap.hasError || !milestoneSnap.hasData) {
                        // Paparkan Ralat (contohnya, tiada kebenaran/akses)
                        final errorMessage = milestoneSnap.error
                                .toString()
                                .contains('not found')
                            ? 'Ralat: Tiada milestone Master dijumpai.'
                            : 'Ralat memuatkan Master Milestone: ${milestoneSnap.error}';
                        return Center(
                            child: Text(errorMessage,
                                style: textTheme.titleMedium));
                      }

                      // Data Master Milestone yang dimuatkan dari Future
                      final allMilestones = milestoneSnap.data!;

                      final selectedFrom = months[selectedIndex]['from'] as int;
                      final selectedTo = months[selectedIndex]['to'] as int;

                      // Tapis Milestone mengikut Julat Umur yang Dipilih
                      final filteredMilestones = allMilestones
                          .where((m) =>
                              m.ageFrom <= selectedTo &&
                              m.ageTo >= selectedFrom)
                          .toList();

                      // Kumpulkan Milestone mengikut Kategori
                      final Map<String, List<Milestone>> grouped = {};
                      for (var cat in categories) {
                        grouped[cat] = [];
                      }
                      for (var m in filteredMilestones) {
                        final key = categories.firstWhere(
                          (c) => c.toLowerCase() == m.category.toLowerCase(),
                          orElse: () => 'Lain-lain',
                        );
                        if (grouped.containsKey(key)) {
                          grouped[key]!.add(m);
                        } else {
                          // Ini mungkin berlaku jika ada kategori baru dalam master yang tiada dalam list categories
                          grouped[key] = [m];
                        }
                      }

                      // Stream 4: Menggabungkan data Master dan status Capaian Bayi
                      return StreamBuilder<QuerySnapshot>(
                        stream:
                            babyMilestonesStream, // Stream yang dimuatkan dari Stream 1
                        builder: (context, babyMilestoneSnap) {
                          // Data status capaian (achievedMap dan achievedDateMap)
                          final Map<String, bool> achievedMap = {};
                          final Map<String, DateTime?> achievedDateMap = {};

                          if (babyMilestoneSnap.hasData) {
                            for (var doc in babyMilestoneSnap.data!.docs) {
                              final data = doc.data() as Map<String, dynamic>?;
                              // ID dokumen dalam subkoleksi adalah ID Milestone Master
                              achievedMap[doc.id] = data?['achieved'] == true;

                              final Timestamp? ts =
                                  data?['achieved_at'] as Timestamp?;
                              achievedDateMap[doc.id] = ts?.toDate();
                            }
                          }

                          // Kira Progress Kategori
                          final Map<String, double> categoryProgress = {};
                          for (var cat in categories) {
                            categoryProgress[cat] = _calculateCategoryProgress(
                                cat, achievedMap, allMilestones);
                          }

                          // ============== Paparan Akhir ==============
                          return CustomScrollView(
                            slivers: [
                              SliverToBoxAdapter(
                                  child: _buildHeaderVibrant(textTheme, baby,
                                      babyAgeInMonths, categoryProgress)),
                              SliverToBoxAdapter(
                                  child: _buildMonthSelectorSliver(textTheme)),
                              // milestone indicators removed — show filtered milestones only
                              if (filteredMilestones.isEmpty)
                                SliverFillRemaining(
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                            Icons
                                                .sentiment_dissatisfied_rounded,
                                            color: lightGrey,
                                            size: 48),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Tiada milestone dicadangkan untuk ${months[selectedIndex]["label"]} bulan.',
                                          textAlign: TextAlign.center,
                                          style: textTheme.titleMedium
                                              ?.copyWith(color: Colors.black54),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                SliverList(
                                  delegate: SliverChildListDelegate([
                                    for (var cat in categories) ...[
                                      if ((grouped[cat] ?? []).isNotEmpty)
                                        // Header Kategori (untuk estetika)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              top: 16,
                                              bottom: 8,
                                              left: 16,
                                              right: 16),
                                          child: Text(cat,
                                              style: textTheme.titleLarge
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                color: textColor,
                                                fontSize: 18,
                                              )),
                                        ),
                                      ...grouped[cat]!.map(
                                        (milestone) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 6),
                                          child: _MilestoneCardDataViz(
                                            milestone: milestone,
                                            achieved:
                                                achievedMap[milestone.id] ??
                                                    false,
                                            achievedAt:
                                                achievedDateMap[milestone.id],
                                            categoryColor:
                                                _getCategoryColor(cat),
                                            babyMonth:
                                                ((selectedFrom + selectedTo) /
                                                    2),
                                            // Memanggil fungsi toggle dengan babyId yang diperolehi
                                            onToggle: () async {
                                              final isCurrentlyAchieved =
                                                  achievedMap[milestone.id] ??
                                                      false;
                                              await _toggleAchieved(
                                                babyId: babyId,
                                                milestoneId: milestone.id,
                                                currentlyAchieved:
                                                    isCurrentlyAchieved,
                                              );
                                              _showSnackBar(
                                                  context,
                                                  isCurrentlyAchieved
                                                      ? 'Milestone dibatalkan.'
                                                      : 'Milestone dicapai!',
                                                  isError: isCurrentlyAchieved);
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 24),
                                  ]),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  Widget _authPlaceholder(TextTheme textTheme) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline,
              color: primaryColor.withOpacity(0.5), size: 48),
          const SizedBox(height: 12),
          Text('Sila log masuk untuk lihat milestone.',
              style: textTheme.titleMedium?.copyWith(color: Colors.black54)),
        ],
      );

  Widget _noBabyPlaceholder(TextTheme textTheme) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.child_care, color: accentColor, size: 48),
            const SizedBox(height: 12),
            Text('Tiada rekod bayi dijumpai.',
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 8),
            Text('Sila tambah maklumat bayi untuk mula menjejak milestone.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: Colors.black54)),
          ],
        ),
      );
}

// ================== MILESTONE CARD WIDGET ==================

class _MilestoneCardDataViz extends StatelessWidget {
  final Milestone milestone;
  final bool achieved;
  final Color categoryColor;
  final double babyMonth;
  final DateTime? achievedAt;
  final VoidCallback onToggle;

  const _MilestoneCardDataViz({
    required this.milestone,
    required this.achieved,
    required this.categoryColor,
    required this.babyMonth,
    required this.onToggle,
    this.achievedAt,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      // Gunakan Margin supaya kad tidak rapat dengan tepi skrin
      margin: const EdgeInsets.symmetric(vertical: 4), 
      padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
      decoration: BoxDecoration(
        // PENYELESAIAN UTAMA: 
        // Jika siap, campurkan warna kategori (12%) dengan putih pepejal.
        // Ini memastikan wallpaper di belakang tidak mengganggu penglihatan teks.
        color: achieved 
            ? Color.alphaBlend(categoryColor.withOpacity(0.12), Colors.white) 
            : Colors.white,
        
        borderRadius: BorderRadius.circular(16), // Lebih moden (curvy)
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: achieved
              ? categoryColor.withOpacity(0.5)
              : Colors.grey.withOpacity(0.2),
          width: achieved ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Garisan Warna Penanda Kategori
          Container(
            width: 6,
            height: 60, // Pendekkan sedikit supaya lebih kemas
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: categoryColor,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        milestone.name,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            // Pastikan teks sentiasa gelap untuk kontras tinggi
                            color: achieved ? textColor : textColor.withOpacity(0.8)),
                      ),
                    ),
                    if (achieved)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade500,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Selesai',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  milestone.description,
                  style: TextStyle(
                    color: achieved ? Colors.black87 : Colors.black54, 
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      'Fasa: ${milestone.ageFrom}-${milestone.ageTo} bln',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                if (achievedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, size: 14, color: Colors.green),
                        const SizedBox(width: 6),
                        Text(
                          'Dicapai: ${DateFormat('dd/MM/yy').format(achievedAt!)}',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // ============== BUTANG TOGGLE (TICK) ==============
          IconButton(
            icon: Icon(
              achieved
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: achieved ? Colors.green : Colors.grey.shade400,
              size: 32,
            ),
            onPressed: onToggle,
          ),
        ],
      ),
    );
  }
}