import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:mamicare_plus2/services/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

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

// VaccinesTab Widget
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
    tz.initializeTimeZones();
    NotificationService.init();
  }
void _showAddVaccineDialog(BuildContext context) {
  final nameController = TextEditingController();
  final monthController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Tambah Vaksin Baru", style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),

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
                labelText: "Bulan (Contoh: 6)",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
            ),
            onPressed: () async {
              if (nameController.text.isEmpty || monthController.text.isEmpty) {
                _showSnackBar(context, "Sila isi semua maklumat", isError: true);
                return;
              }

              // ------ SIMPAN KE FIRESTORE DALAM COLLECTION ADMIN VACCINES ------
              await FirebaseFirestore.instance.collection("vaccines").add({
                'name': nameController.text.trim(),
                'month': int.tryParse(monthController.text.trim()) ?? 0,
                'custom': true, // tanda custom
                'created_at': FieldValue.serverTimestamp(),
              });

              Navigator.pop(context);
              _showSnackBar(context, "Vaksin berjaya ditambah!");
            },
            child: const Text("Simpan", style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    },
  );
}

  void _showSnackBar(BuildContext context, String message,
      {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: isError ? Colors.red.shade700 : primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  Future<Map<String, int>> _getVaccineStatusCounts(
      CollectionReference babyVaccinesCollection) async {
    final adminVaccinesSnapshot =
        await FirebaseFirestore.instance.collection('vaccines').get();
    if (adminVaccinesSnapshot.docs.isEmpty) return {'pending': 0, 'taken': 0};

    final babyVaccinesSnapshot = await babyVaccinesCollection.get();
    final Map<String, dynamic> userVaccineData = {};
    for (var doc in babyVaccinesSnapshot.docs) {
      userVaccineData[doc.id] = doc.data() as Map<String, dynamic>;
    }

    int pendingCount = 0;
    int takenCount = 0;

    for (var vaccineDoc in adminVaccinesSnapshot.docs) {
      final vaccineId = vaccineDoc.id;
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
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/images/wallpaper1.jpg"),
          fit: BoxFit.cover,
          opacity: 0.9, // lembut
        ),
      ),

      child: StreamBuilder<QuerySnapshot>(
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
          if (user == null) return _buildAuthPlaceholder(textTheme);
          if (babiesSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryColor));
          }
          if (!babiesSnapshot.hasData || babiesSnapshot.data!.docs.isEmpty) {
            return _buildNoBabyPlaceholder(textTheme);
          }

          final babyDoc = babiesSnapshot.data!.docs.first;
          final baby = Baby.fromFirestore(babyDoc);
          final babyVaccinesCollection = FirebaseFirestore.instance
              .collection('caregivers')
              .doc(user.uid)
              .collection('babies')
              .doc(baby.id)
              .collection('vaccines');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(textTheme, baby, babyVaccinesCollection),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
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
                                if (selected) setState(() => _statusFilter = status);
                              },
                              selectedColor: secondaryColor.withOpacity(0.9),
                              backgroundColor: Colors.white,
                              elevation: 2,
                              pressElevation: 5,
                              labelStyle: TextStyle(
                                color: _statusFilter == status ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const Divider(height: 1, thickness: 1, color: Colors.grey),
                  ],
                ),
              ),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('vaccines')
                      .orderBy('name')
                      .snapshots(),

                  builder: (context, adminVaccinesSnapshot) {
                    if (adminVaccinesSnapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: primaryColor));
                    }
                    if (!adminVaccinesSnapshot.hasData ||
                        adminVaccinesSnapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          "Tiada jadual vaksin dari admin.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54),
                        ),
                      );
                    }

                    final adminVaccines = adminVaccinesSnapshot.data!.docs;

                    // Sorting ikut bulan
                    adminVaccines.sort((a, b) {
                      int monthA = int.tryParse(a['month']?.toString() ?? '0') ?? 0;
                      int monthB = int.tryParse(b['month']?.toString() ?? '0') ?? 0;
                      return monthA.compareTo(monthB);
                    });

                    return ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: adminVaccines.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final vaccine = adminVaccines[index];
                        final vaccineId = vaccine.id;
                        final vaccineName = vaccine['name'] ?? 'Nama vaksin tidak tersedia';

                        final month = int.tryParse(vaccine['month']?.toString() ?? '');

                        // Age text (Newborn / bulan)
                        final babyMonth = baby.dob != null
                            ? ((DateTime.now().year - baby.dob!.year) * 12 +
                                DateTime.now().month - baby.dob!.month)
                            : null;

                        String ageText;
                        if (month == 0 || (babyMonth != null && babyMonth < 1)) {
                          ageText = 'Waktu Cadangan: Newborn';
                        } else {
                          ageText = month != null
                              ? 'Waktu Cadangan: $month Bulan'
                              : 'Waktu Cadangan: -';
                        }

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
    floatingActionButton: FloatingActionButton.extended(
  backgroundColor: primaryColor,
  icon: const Icon(Icons.add, color: Colors.white),
  label: const Text(
    "Tambah Vaksin",
    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
  ),
  onPressed: () => _showAddVaccineDialog(context),
),
  );
}


  Widget _buildAuthPlaceholder(TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, color: Colors.blue, size: 50),
          const SizedBox(height: 10),
          Text("Sila log masuk untuk melihat rekod vaksin.",
              style: textTheme.titleMedium
                  ?.copyWith(color: Colors.black87, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildNoBabyPlaceholder(TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.child_care, color: Colors.blue, size: 50),
          const SizedBox(height: 10),
          Text("Tiada rekod bayi dijumpai.",
              style: textTheme.titleMedium
                  ?.copyWith(color: Colors.black87, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Sila tambah maklumat bayi anda terlebih dahulu.",
              style: textTheme.bodyMedium?.copyWith(color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildHeader(TextTheme textTheme, Baby baby,
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
              color: primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: primaryColor.withOpacity(0.2)),
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
            style:
                TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}

void _showGrowthDetails(BuildContext context, DocumentSnapshot vaccineDoc) async {
  // Ambil data growth dari Firestore
  final babyDoc = vaccineDoc.reference.parent.parent!; // doc bayi
  final growthSnap = await babyDoc.collection('growth_records')
      .where('vaccineId', isEqualTo: vaccineDoc.id)
      .orderBy('date', descending: true)
      .limit(1)
      .get();

  double? weight;
  double? height;
  String? note;

  if (growthSnap.docs.isNotEmpty) {
    final data = growthSnap.docs.first.data() as Map<String, dynamic>;
    weight = data['weight'];
    height = data['height'];
    note = data['note'];
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Maklumat Perkembangan Bayi",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF007BFF))),
          const SizedBox(height: 12),
          Text("Berat: ${weight?.toStringAsFixed(1) ?? '-'} kg"),
          Text("Tinggi: ${height?.toStringAsFixed(0) ?? '-'} cm"),
          Text("Nota: ${note ?? '-'}"),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Tutup"),
            ),
          ),
        ],
      ),
    ),
  );
}

// --- Vaccine Card with Age Check ---
// --- Vaccine Card with Age Check + View Note Icon ---
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
    return (now.year - dob.year) * 12 + now.month - dob.month;
  }

  bool _isVaccineAppropriate() {
    final babyMonth = _calculateBabyMonth(babyDob);
    if (babyMonth == null || recommendedMonth == null) return false;
    return (recommendedMonth! - babyMonth).abs() <= 2; // ±2 months allowed
  }

  Future<void> _pickDateTime(BuildContext context) async {
    if (!_isVaccineAppropriate()) {
      showSnackBar(context,
          "Vaksin ini belum sesuai untuk umur bayi sekarang.", isError: true);
      return;
    }

    DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );
    if (date == null) return;

    TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
    );
    if (time == null) return;

    final selected =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
    await NotificationService.scheduleNotification(
      id: notifId,
      title: "Vaksin Reminder",
      body: "Ingat! Vaksin $vaccineName pada $formattedTime",
      scheduledDate: tzDate,
    );

    await babyVaccinesCollection.doc(vaccineId).set({
      'dateScheduled': Timestamp.fromDate(selected),
      'notifId': notifId,
    }, SetOptions(merge: true));

    showSnackBar(context, "Reminder berjaya diset!");
  }

  Future<void> _toggleTaken(DocumentSnapshot? snapshot) async {
    final current = (snapshot?.data() as Map?)?['taken'] == true;
    final int notifId = vaccineId.hashCode & 0x7fffffff;
    if (!current) await NotificationService.cancelNotification(notifId);

    await babyVaccinesCollection.doc(vaccineId).set({
      'taken': !current,
      if (current) 'dateScheduled': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  void _showGrowthDetails(BuildContext context) async {
    final growthSnap = await babyVaccinesCollection
        .doc(vaccineId)
        .collection('growth_records')
        .orderBy('date', descending: true)
        .limit(1)
        .get();

    double? weight;
    double? height;
    String? note;

    if (growthSnap.docs.isNotEmpty) {
      final data = growthSnap.docs.first.data() as Map<String, dynamic>;
      weight = data['weight'];
      height = data['height'];
      note = data['note'];
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Maklumat Perkembangan Bayi",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor)),
            const SizedBox(height: 12),
            Text("Berat: ${weight?.toStringAsFixed(1) ?? '-'} kg"),
            Text("Tinggi: ${height?.toStringAsFixed(0) ?? '-'} cm"),
            Text("Nota: ${note ?? '-'}"),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Tutup"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: babyVaccinesCollection.doc(vaccineId).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        final bool taken = data?['taken'] == true;
        final DateTime? scheduled = data?['dateScheduled'] != null
            ? (data!['dateScheduled'] as Timestamp).toDate()
            : null;

        // Filter by status
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
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                      taken ? Icons.check_circle_outline : Icons.local_hospital_outlined,
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
                    // Icon nota tepi nama vaksin
                    GestureDetector(
        onTap: taken
            ? () => _showGrowthDetails(context) // hanya boleh tekan jika taken = true
            : null,
        child: CircleAvatar(
          radius: 12,
          backgroundColor: taken ? Colors.white : Colors.grey.shade400,
          child: Icon(
            Icons.note_alt,
            size: 16,
            color: taken ? Colors.blueAccent : Colors.grey.shade700,
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: taken ? Colors.green.shade100 : Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        scheduled != null
                            ? 'Tarikh: ${DateFormat('dd MMM yyyy, hh:mm a').format(scheduled)}'
                            : ageText,
                        style: TextStyle(
                          color: taken ? Colors.green.shade800 : Colors.blue.shade900,
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
                                onChanged: scheduled != null ? (value) => _toggleTaken(snap.data) : null,
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
                                ? (taken ? Colors.green.shade400 : Colors.blue.shade400)
                                : Colors.grey.shade300,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
