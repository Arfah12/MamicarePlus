import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:mamicare_plus2/services/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class AppCSS {
  static const double radius = 12;
  static const double radiusLarge = 16;
  static const Color primary = Color(0xFF007AFF);
  static const Color secondary = Color(0xFF34C759);
  static const Color bgLight = Color(0xFFF5F7FA);

  static BoxDecoration detailCard({Color? color}) {
    return BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(radiusLarge),
      border: Border.all(color: Colors.grey.shade300),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // Text style untuk title & content
  static TextStyle titleText() {
    return const TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 18,
      color: Colors.black87,
    );
  }

  static TextStyle contentText() {
    return const TextStyle(
      fontSize: 14,
      color: Colors.black87,
    );
  }

  // Button style
  static ButtonStyle closeButton() {
    return TextButton.styleFrom(
      foregroundColor: primary,
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
    );
  }

  // Input Decoration untuk growth form / note
  static InputDecoration growthInput(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: primary) : null,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
    );
  }

  // Button style untuk growth form
  static ButtonStyle growthButton({Color? bgColor}) {
    return ElevatedButton.styleFrom(
      backgroundColor: bgColor ?? primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
    );
  }

  // Card decoration untuk growth form / note
  static BoxDecoration growthCard({Color? color}) {
    return BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(radiusLarge),
      border: Border.all(color: Colors.grey.shade300),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

// Colors
const Color primaryColor = Color(0xFF007AFF);
const Color secondaryColor = Color(0xFF34C759);
const Color backgroundColor = Color(0xFFF5F7FA);

// Baby Model
class Baby {
  final String id;
  final String name;
  final DateTime? dob;
  final String? photoUrl;

  Baby({required this.id, required this.name, this.dob, this.photoUrl});

  factory Baby.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Baby(
      id: doc.id,
      name: data['name'] ?? 'Anak Anda',
      dob: (data['dob'] as Timestamp?)?.toDate(),
      photoUrl: data['photoUrl'] as String?,
    );
  }
}

// =====================================================================
// VACCINESTAB WIDGET
// =====================================================================
class VaccinesTab extends StatefulWidget {
  const VaccinesTab({super.key});

  @override
  State<VaccinesTab> createState() => _VaccinesTabState();
}

class _VaccinesTabState extends State<VaccinesTab> {
  String _statusFilter = 'Semua';
  final List<String> statusOptions = ['Semua', 'Belum Selesai', 'Selesai'];

  @override
  void initState() {
    super.initState();
    // Inisialisasi time zone dan notifikasi
    tz.initializeTimeZones();
    NotificationService.init();
  }

  void _showAddVaccineDialog(BuildContext context) {
    final nameController = TextEditingController();
    final monthController = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;

    // Peraturan Keselamatan: Hanya Admin yang boleh tambah vaksin ke koleksi master
    if (user == null || user.uid != "YmMzPJ24Y2XDth6SGCJJ9wfEdxE2") {
      _showSnackBar(
          context, "Anda tiada kebenaran untuk menambah vaksin master.",
          isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Tambah Vaksin Baru",
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Nama Vaksin",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: monthController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Bulan Cadangan (Contoh: 6)",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
              ),
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    monthController.text.isEmpty) {
                  _showSnackBar(context, "Sila isi semua maklumat",
                      isError: true);
                  return;
                }

                // SIMPAN KE FIRESTORE DALAM COLLECTION ADMIN VACCINES
                try {
                  await FirebaseFirestore.instance.collection("vaccines").add({
                    'name': nameController.text.trim(),
                    'month': int.tryParse(monthController.text.trim()) ?? 0,
                    'custom': true, // tanda custom
                    'created_at': FieldValue.serverTimestamp(),
                  });

                  if (mounted) {
                    Navigator.pop(dialogContext);
                    _showSnackBar(context, "Vaksin berjaya ditambah!");
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(dialogContext);
                    _showSnackBar(context,
                        "Gagal menambah vaksin. Sila semak kebenaran: $e",
                        isError: true);
                  }
                }
              },
              child:
                  const Text("Simpan", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showAddCustomVaccineDialog(BuildContext context, Baby baby) {
    final nameController = TextEditingController();
    DateTime? selectedDate;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Rekod Vaksin Tambahan",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Vaccine Name Input
                  Container(
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: "Nama Vaksin",
                        prefixIcon: Icon(Icons.local_hospital,
                            color: primaryColor, size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        labelStyle: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Date Picker Button
                  GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2015),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        (context as Element).markNeedsBuild();
                        selectedDate = date;
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              color: primaryColor, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              selectedDate == null
                                  ? "Pilih Tarikh Vaksin"
                                  : DateFormat('dd MMM yyyy')
                                      .format(selectedDate!),
                              style: TextStyle(
                                fontSize: 16,
                                color: selectedDate == null
                                    ? Colors.grey.shade600
                                    : Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              color: Colors.grey.shade400),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                          ),
                          child: Text(
                            "Batal",
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (nameController.text.isEmpty ||
                                selectedDate == null) {
                              _showSnackBar(context,
                                  "Sila isi semua maklumat", isError: true);
                              return;
                            }

                            await FirebaseFirestore.instance
                                .collection('caregivers')
                                .doc(user.uid)
                                .collection('babies')
                                .doc(baby.id)
                                .collection('vaccine_records_custom')
                                .add({
                              'vaccineName': nameController.text.trim(),
                              'dateTaken': Timestamp.fromDate(selectedDate!),
                              'createdAt': FieldValue.serverTimestamp(),
                            });

                            if (context.mounted) {
                              Navigator.pop(context);
                              _showSnackBar(context,
                                  "Rekod vaksin berjaya disimpan");
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Simpan",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSnackBar(BuildContext context, String message,
      {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: isError ? Colors.red.shade700 : primaryColor,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(10),
        ),
      );
    }
  }

  // Fungsi untuk mendapatkan kiraan status vaksin
  Future<Map<String, int>> _getVaccineStatusCounts(
      CollectionReference babyVaccinesCollection) async {
    // 1. Ambil semua vaksin master (admin)
    final adminVaccinesSnapshot =
        await FirebaseFirestore.instance.collection('vaccines').get();

    // 2. Ambil rekod vaksin bayi
    final babyVaccinesSnapshot = await babyVaccinesCollection.get();
    final Map<String, dynamic> userVaccineData = {};
    for (var doc in babyVaccinesSnapshot.docs) {
      userVaccineData[doc.id] = doc.data() as Map<String, dynamic>;
    }

    int pendingCount = 0;
    int takenCount = 0;

    // 3. Bandingkan
    for (var vaccineDoc in adminVaccinesSnapshot.docs) {
      final vaccineId = vaccineDoc.id;
      // Semak rekod pengguna
      final data = userVaccineData[vaccineId];
      final bool taken = data != null ? (data['taken'] ?? false) : false;

      if (taken) {
        takenCount++;
      } else {
        pendingCount++;
      }
    }

    return {'pending': pendingCount, 'taken': takenCount};
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/wall13.png"),
            fit: BoxFit.cover,
            opacity: 0.9,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          // Mendapatkan rekod bayi yang paling baru (had 1)
          stream: user != null
              ? FirebaseFirestore.instance
                  .collection('caregivers')
                  .doc(user.uid)
                  .collection('babies')
                  .orderBy('created_at', descending: true)
                  .limit(1)
                  .snapshots()
              : const Stream.empty(),
          builder: (context, babiesSnapshot) {
            if (user == null)
              return _buildAuthPlaceholder(textTheme); // DIPERBAIKI
            if (babiesSnapshot.connectionState == ConnectionState.waiting) {
              return Center(
                  child: CircularProgressIndicator(color: primaryColor));
            }
            if (!babiesSnapshot.hasData || babiesSnapshot.data!.docs.isEmpty) {
              return _buildNoBabyPlaceholder(textTheme); // DIPERBAIKI
            }

            final babyDoc = babiesSnapshot.data!.docs.first;
            final baby = Baby.fromFirestore(babyDoc);

            // RUJUKAN KEPADA SUBKOLEKSI VAKSIN BAYI
            final babyVaccinesCollection = FirebaseFirestore.instance
                .collection('caregivers')
                .doc(user.uid)
                .collection('babies')
                .doc(baby.id)
                .collection('vaccine_records');

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, textTheme, baby, babyVaccinesCollection),

                // Penapis Status
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tapis Mengikut Status:',
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: statusOptions.map((status) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(status),
                                selected: _statusFilter == status,
                                onSelected: (selected) {
                                  if (selected)
                                    setState(() => _statusFilter = status);
                                },
                                selectedColor: secondaryColor.withAlpha(230),
                                backgroundColor: Colors.white,
                                elevation: 2,
                                pressElevation: 5,
                                labelStyle: TextStyle(
                                  color: _statusFilter == status
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const Divider(
                          height: 1, thickness: 1, color: Colors.grey),
                    ],
                  ),
                ),

                // Senarai Vaksin Master
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('vaccines') // Koleksi Master
                        .orderBy('month') // Sorting ikut bulan cadangan
                        .snapshots(),
                    builder: (context, adminVaccinesSnapshot) {
                      if (adminVaccinesSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return Center(
                            child:
                                CircularProgressIndicator(color: primaryColor));
                      }
                      if (!adminVaccinesSnapshot.hasData ||
                          adminVaccinesSnapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text(
                            "Tiada jadual vaksin master dijumpai.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black54),
                          ),
                        );
                      }

                      final adminVaccines =
                          adminVaccinesSnapshot.data!.docs.toList()
                            ..sort((a, b) {
                              int getMonth(dynamic value) {
                                if (value == null) return 999;
                                if (value is int) return value;
                                if (value is String)
                                  return int.tryParse(value) ?? 999;
                                return 999;
                              }

                              final int monthA = getMonth(a['month']);
                              final int monthB = getMonth(b['month']);

                              return monthA.compareTo(monthB);
                            });

                      return ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: adminVaccines.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final vaccine = adminVaccines[index];
                          final vaccineId = vaccine.id;
                          final vaccineName =
                              vaccine['name'] ?? 'Nama vaksin tidak tersedia';
                          final month =
                              int.tryParse(vaccine['month']?.toString() ?? '');

                          // Kira Umur Bayi dalam Bulan
                          final babyMonth = baby.dob != null
                              ? ((DateTime.now().year - baby.dob!.year) * 12 +
                                  DateTime.now().month -
                                  baby.dob!.month)
                              : null;

                          // Teks Umur Cadangan
                          String ageText;
                          if (month == 0 ||
                              (babyMonth != null && babyMonth < 1)) {
                            ageText = 'Waktu Cadangan: Newborn (Bulan 0)';
                          } else {
                            ageText = month != null
                                ? 'Waktu Cadangan: $month Bulan'
                                : 'Waktu Cadangan: -';
                          }

                          // PAPARKAN KAD VAKSIN
                          return _VaccineCard(
                            vaccineId: vaccineId,
                            vaccineName: vaccineName,
                            recommendedMonth: month,
                            ageText: ageText,
                            babyDob: baby.dob,
                            babyVaccinesCollection: babyVaccinesCollection,
                            showSnackBar: _showSnackBar,
                            primaryColor: primaryColor,
                            secondaryColor: secondaryColor,
                            textTheme: textTheme,
                            statusFilter: _statusFilter,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('caregivers')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .collection('babies')
            .orderBy('created_at', descending: true)
            .limit(1)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const SizedBox.shrink();
          }

          final baby = Baby.fromFirestore(snap.data!.docs.first);

          return FloatingActionButton.extended(
            backgroundColor: primaryColor,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              "Tambah Vaksin Lain",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            onPressed: () => _showAddCustomVaccineDialog(context, baby),
          );
        },
      ),
    );
  }

  // =====================================================================
  // FUNGSI BUILDER YANG HILANG (DIPERBAIKI)
  // =====================================================================

  Widget _buildAuthPlaceholder(TextTheme textTheme) {
    // DIPERBAIKI: Pindahkan ke dalam State
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, color: primaryColor, size: 50),
          const SizedBox(height: 10),
          Text("Sila log masuk untuk melihat rekod vaksin.",
              style: textTheme.titleMedium?.copyWith(
                  color: Colors.black87, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildNoBabyPlaceholder(TextTheme textTheme) {
    // DIPERBAIKI: Pindahkan ke dalam State
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.child_care, color: primaryColor, size: 50),
          const SizedBox(height: 10),
          Text("Tiada rekod bayi dijumpai.",
              style: textTheme.titleMedium?.copyWith(
                  color: Colors.black87, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Sila tambah maklumat bayi anda terlebih dahulu.",
              style: textTheme.bodyMedium?.copyWith(color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, TextTheme textTheme, Baby baby,
      CollectionReference babyVaccinesCollection) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(35), bottomRight: Radius.circular(35)),
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 25, offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text('Jadual Imunisasi Anak',
                style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: primaryColor,
                    fontSize: 24)),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              // DIPERBAIKI: Membuang argumen 'color' yang berulang
              borderRadius: BorderRadius.circular(15),
              color: primaryColor.withAlpha(25),
              border: Border.all(color: primaryColor.withAlpha(50)),
            ),
            child: FutureBuilder<Map<String, int>>(
              future: _getVaccineStatusCounts(babyVaccinesCollection),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                      child: CircularProgressIndicator(color: primaryColor));
                }

                final counts = snapshot.data ?? {'pending': 0, 'taken': 0};
                final pendingCount = counts['pending']!;
                final takenCount = counts['taken']!;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatusItem('Belum Selesai', pendingCount.toString(),
                        Icons.calendar_today_rounded, primaryColor),
                    _buildStatusItem('Selesai', takenCount.toString(),
                        Icons.verified_user_rounded, secondaryColor),
                  ],
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatusItem(
      String title, String count, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 4),
            Text(count,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w900, fontSize: 20)),
          ],
        ),
        const SizedBox(height: 4),
        Text(title,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}

// =====================================================================
// VACCINE CARD WIDGET
// =====================================================================
class _VaccineCard extends StatelessWidget {
  final String vaccineId;
  final String vaccineName;
  final int? recommendedMonth;
  final String ageText;
  final DateTime? babyDob;
  final CollectionReference babyVaccinesCollection;
  final Function(BuildContext, String, {bool isError}) showSnackBar;
  final Color primaryColor;
  final Color secondaryColor;
  final TextTheme textTheme;
  final String statusFilter;

  const _VaccineCard({
    required this.vaccineId,
    required this.vaccineName,
    required this.recommendedMonth,
    required this.ageText,
    required this.babyDob,
    required this.babyVaccinesCollection,
    required this.showSnackBar,
    required this.primaryColor,
    required this.secondaryColor,
    required this.textTheme,
    required this.statusFilter,
  });

  int? _calculateBabyMonth(DateTime? dob) {
    if (dob == null) return null;
    final now = DateTime.now();
    // Mengira perbezaan bulan
    return (now.year - dob.year) * 12 + now.month - dob.month;
  }

  bool _isVaccineAppropriate() {
    final babyMonth = _calculateBabyMonth(babyDob);
    if (babyMonth == null || recommendedMonth == null) return false;
    // Benarkan vaksin diambil dalam julat ±2 bulan dari waktu cadangan
    return (recommendedMonth! - babyMonth).abs() <= 2;
  }

  Future<void> _pickDateTime(BuildContext context) async {
    if (!_isVaccineAppropriate()) {
      showSnackBar(context,
          "Vaksin ini belum sesuai untuk umur bayi sekarang. Rujuk jadual cadangan.",
          isError: true);
      return;
    }

    // Pemilihan Tarikh
    DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );
    if (date == null || !context.mounted) return;

    // Pemilihan Masa
    TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
    );
    if (time == null || !context.mounted) return;

    final selected =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);

    // Set Timezone untuk Notifikasi
    final malayTimeZone = tz.getLocation('Asia/Kuala_Lumpur');
    final tzDate = tz.TZDateTime(
      malayTimeZone,
      selected.year,
      selected.month,
      selected.day,
      selected.hour,
      selected.minute,
    );

    if (tzDate.isBefore(tz.TZDateTime.now(tz.local))) {
      showSnackBar(context, "Sila pilih masa yang akan datang.", isError: true);
      return;
    }

    final int notifId = vaccineId.hashCode & 0x7fffffff;
    await NotificationService.cancelNotification(notifId);

    final formattedTime = DateFormat('dd MMM yyyy, hh:mm a').format(tzDate);
    // Jadualkan Notifikasi
    await NotificationService.scheduleNotification(
      id: notifId,
      title: "Vaksin Reminder",
      body: "Ingat! Vaksin $vaccineName dijadualkan pada $formattedTime",
      scheduledDate: tzDate,
    );

    // Simpan ke Firestore
    await babyVaccinesCollection.doc(vaccineId).set({
      'dateScheduled': Timestamp.fromDate(selected), // Disimpan!
      'notifId': notifId,
      'taken': false, // Pastikan set ke false
      'vaccineName': vaccineName,
      'recommendedMonth': recommendedMonth,
    }, SetOptions(merge: true));

    if (context.mounted) {
      showSnackBar(context, "Reminder berjaya diset untuk $formattedTime!");
    }
  }

  Future<void> _showGrowthForm(
      BuildContext context,
      CollectionReference babyVaccinesCollection,
      DocumentSnapshot? snapshot) async {
    final weightController = TextEditingController();
    final heightController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Maklumat Perkembangan Bayi"),
        content: Container(
          decoration: AppCSS.growthCard(), // Card style
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: weightController,
                keyboardType: TextInputType.number,
                decoration: AppCSS.growthInput("Berat (kg)",
                    icon: Icons.monitor_weight),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: heightController,
                keyboardType: TextInputType.number,
                decoration:
                    AppCSS.growthInput("Tinggi (cm)", icon: Icons.height),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteController,
                decoration: AppCSS.growthInput("Nota", icon: Icons.note_alt),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Batal"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: AppCSS.growthButton(bgColor: AppCSS.secondary),
            child: const Text("Simpan"),
            onPressed: () async {
              if (weightController.text.isEmpty ||
                  heightController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Sila isi berat dan tinggi")),
                );
                return;
              }

              await babyVaccinesCollection.doc(vaccineId).set({
                'taken': true,
                'dateTaken': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

              await babyVaccinesCollection
                  .doc(vaccineId)
                  .collection('growth_records')
                  .add({
                'weight': double.tryParse(weightController.text),
                'height': double.tryParse(heightController.text),
                'note': noteController.text.trim(),
                'date': FieldValue.serverTimestamp(),
              });

              if (context.mounted) {
                Navigator.pop(context);
                showSnackBar(context, "Rekod perkembangan berjaya disimpan!");
              }
            },
          ),
        ],
      ),
    );
  }

  void _showGrowthDetails(BuildContext context) async {
    final growthSnap = await babyVaccinesCollection
        .doc(vaccineId)
        .collection('growth_records')
        .orderBy('date', descending: true)
        .limit(1)
        .get();

    if (growthSnap.docs.isEmpty) {
      showSnackBar(context, "Tiada rekod perkembangan ditemui", isError: true);
      return;
    }

    final data = growthSnap.docs.first.data();
    final weight = (data['weight'] as num?)?.toDouble();
    final height = (data['height'] as num?)?.toDouble();
    final note = data['note'] as String?;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppCSS.radiusLarge),
        ),
        backgroundColor: AppCSS.bgLight,
        title: Text("Maklumat Perkembangan Bayi", style: AppCSS.titleText()),
        content: Container(
          decoration: AppCSS.detailCard(),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Berat: ${weight ?? '-'} kg", style: AppCSS.contentText()),
              const SizedBox(height: 6),
              Text("Tinggi: ${height ?? '-'} cm", style: AppCSS.contentText()),
              const SizedBox(height: 6),
              Text("Nota: ${note ?? '-'}", style: AppCSS.contentText()),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Tutup"),
            style: AppCSS.closeButton(),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleTaken(
      BuildContext context, DocumentSnapshot? snapshot) async {
    final current = (snapshot?.data() as Map?)?['taken'] == true;
    final bool nextTakenState = !current;
    final int notifId = vaccineId.hashCode & 0x7fffffff;

    if (nextTakenState) {
      // Jika ditandakan SELESAI
      await NotificationService.cancelNotification(notifId);
      await babyVaccinesCollection.doc(vaccineId).set({
        'taken': true,
        'dateTaken': FieldValue.serverTimestamp(), // Tarikh selesai
      }, SetOptions(merge: true));

      if (context.mounted) {
        showSnackBar(context, "Vaksin $vaccineName telah ditandakan selesai.");
      }
    } else {
      // Jika dibatalkan tanda SELESAI
      await babyVaccinesCollection.doc(vaccineId).set({
        'taken': false,
        'dateTaken': FieldValue.delete(), // Buang tarikh selesai
      }, SetOptions(merge: true));

      if (context.mounted) {
        showSnackBar(context, "Tanda selesai $vaccineName telah dibatalkan.",
            isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // StreamBuilder untuk mendengar perubahan pada dokumen rekod vaksin bayi
    return StreamBuilder<DocumentSnapshot>(
      stream: babyVaccinesCollection.doc(vaccineId).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        final bool taken = data?['taken'] == true;

        // Ambil tarikh dijadualkan
        final DateTime? scheduled = data?['dateScheduled'] != null
            ? (data!['dateScheduled'] as Timestamp).toDate()
            : null;

        // Ambil tarikh diambil
        final DateTime? dateTaken = data?['dateTaken'] != null
            ? (data!['dateTaken'] as Timestamp).toDate()
            : null;

        // Logik Penapis Status
        if ((statusFilter == 'Belum Selesai' && taken) ||
            (statusFilter == 'Selesai' && !taken)) {
          return const SizedBox.shrink();
        }

        final isButtonActive = _isVaccineAppropriate();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: taken ? Colors.green.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: taken ? Colors.green.shade200 : Colors.blue.shade200,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: taken ? Colors.green.shade300 : Colors.blue.shade300,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      taken
                          ? Icons.check_circle_outline
                          : Icons.local_hospital_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        vaccineName,
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    // Icon nota tepi nama vaksin (Hanya aktif jika taken=true)
                    GestureDetector(
                      onTap: taken ? () => _showGrowthDetails(context) : null,
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor:
                            taken ? Colors.white : Colors.grey.shade400,
                        child: Icon(
                          Icons.note_alt,
                          size: 16,
                          color:
                              taken ? Colors.blueAccent : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tarikh / Umur
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: taken
                            ? Colors.green.shade100
                            : Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        taken
                            ? 'Selesai: ${dateTaken != null ? DateFormat('dd MMM yyyy').format(dateTaken) : '-'}'
                            : scheduled != null
                                ? 'Dijadualkan: ${DateFormat('dd MMM yyyy, hh:mm a').format(scheduled)}'
                                : ageText, // Jika tiada rekod, guna teks umur cadangan
                        style: TextStyle(
                          color: taken
                              ? Colors.green.shade800
                              : Colors.blue.shade900,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Checkbox & Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              height: 20,
                              width: 20,
                              child: Checkbox(
                                value: taken,
                                activeColor: Colors.green.shade600,
                                checkColor: Colors.white,
                                // Boleh tekan jika scheduled sudah ada, atau jika ianya sudah taken (untuk un-check)
                                onChanged: scheduled != null && !taken
                                    ? (value) => _showGrowthForm(context,
                                        babyVaccinesCollection, snap.data)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              scheduled == null
                                  ? isButtonActive
                                      ? "Sila pilih tarikh dahulu"
                                      : "Vaksin belum sesuai"
                                  : taken
                                      ? "Vaksin Selesai Diambil"
                                      : "Tandakan Selesai",
                              style: TextStyle(
                                color: scheduled == null
                                    ? isButtonActive
                                        ? Colors.red
                                        : Colors.orange
                                    : taken
                                        ? Colors.green.shade800
                                        : Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => _pickDateTime(context),
                          style: TextButton.styleFrom(
                            backgroundColor: isButtonActive
                                ? (taken
                                    ? Colors.green.shade400
                                    : Colors.blue.shade400)
                                : Colors.grey.shade300,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            minimumSize: const Size(90, 32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            scheduled == null ? "Pilih Tarikh" : "Ubah Tarikh",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
