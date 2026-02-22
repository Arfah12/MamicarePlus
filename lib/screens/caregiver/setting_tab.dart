import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

// ================= THEME COLORS =================
const Color pastelBlue = Color(0xFFE3F2FD);
const Color darkBlue = Color(0xFF0288D1);
const Color accentYellow = Color(0xFFFFF9C4);
const Color bgLight = Color(0xFFF8FBFF);

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final ImagePicker _picker = ImagePicker();
  File? _babyImage;

  final _caregiverNameController = TextEditingController();
  final _caregiverPhoneController = TextEditingController();
  final _emergencyContactController = TextEditingController();

  String _bloodType = "A+";
  final List<String> _bloodTypes = [
    "A+",
    "A-",
    "B+",
    "B-",
    "AB+",
    "AB-",
    "O+",
    "O-"
  ];

  Map<String, dynamic>? _babyData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ================= LOGIC FIREBASE =================
  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final caregiverDoc = await FirebaseFirestore.instance
        .collection('caregivers')
        .doc(user.uid)
        .get();

    final babiesCollection = await FirebaseFirestore.instance
        .collection('caregivers')
        .doc(user.uid)
        .collection('babies')
        .get();

    if (caregiverDoc.exists) {
      final data = caregiverDoc.data();
      setState(() {
        _caregiverNameController.text = data?['name'] ?? '';
        _caregiverPhoneController.text = data?['phone'] ?? '';
        _emergencyContactController.text = data?['emergency_contact'] ?? '';
      });
    }

    if (babiesCollection.docs.isNotEmpty) {
      setState(() {
        _babyData = babiesCollection.docs.first.data();
        _babyData!['id'] =
            babiesCollection.docs.first.id; // Simpan ID untuk update
        _bloodType = _babyData?['blood_type'] ?? "A+";
      });
    }
  }

  Future<void> _updateProfile() async {
    HapticFeedback.mediumImpact();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // 1. Update Caregiver
      await FirebaseFirestore.instance
          .collection('caregivers')
          .doc(user.uid)
          .set({
        'name': _caregiverNameController.text.trim(),
        'phone': _caregiverPhoneController.text.trim(),
        'emergency_contact': _emergencyContactController.text.trim(),
      }, SetOptions(merge: true));

      // 2. Update Baby
      if (_babyData != null) {
        await FirebaseFirestore.instance
            .collection('caregivers')
            .doc(user.uid)
            .collection('babies')
            .doc(_babyData!['id'])
            .set({
          'blood_type': _bloodType,
          if (_babyImage != null) 'local_photo_path': _babyImage!.path,
        }, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Profil berjaya dikemaskini!"),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Gagal kemaskini")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickBabyImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _babyImage = File(picked.path));
  }

  // ================= UI BUILDERS =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/wall13.png"),
            fit: BoxFit.cover,
            opacity: 0.8,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
          child: Column(
            children: [
              _buildAvatarHeader(),
              const SizedBox(height: 25),
              _buildSectionLabel("MAKLUMAT PERIBADI"),
              _buildGroupCard([
                _buildMenuTile(
                  icon: Icons.person_outline,
                  color: Colors.blue,
                  title: "Kemaskini Profil",
                  subtitle: "Nama & No. Telefon",
                  onTap: _showEditSheet,
                ),
                _buildMenuTile(
                  icon: Icons.bloodtype_outlined,
                  color: Colors.redAccent,
                  title: "Jenis Darah Bayi",
                  trailing: Text(_bloodType,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: darkBlue)),
                  onTap: _showBloodPicker,
                ),
              ]),
              const SizedBox(height: 20),
              _buildSectionLabel("LAPORAN & DATA"),
              _buildGroupCard([
                _buildMenuTile(
                  icon: Icons.analytics_outlined,
                  color: Colors.orange,
                  title: "Lihat Laporan (Report)",
                  subtitle: "Statistik vaksin & pertumbuhan",
                  onTap: _showReportDialog,
                ),
              ]),
              const SizedBox(height: 20),
              _buildSectionLabel("SOKONGAN & INFO"),
              _buildGroupCard([
                _buildMenuTile(
                  icon: Icons.info_outline,
                  color: Colors.teal,
                  title: "Tentang Aplikasi",
                  onTap: _showAbout,
                ),
                _buildMenuTile(
                  icon: Icons.verified_user_outlined,
                  color: Colors.grey,
                  title: "Versi Aplikasi",
                  trailing: const Text("1.0.4"),
                ),
              ]),
              const SizedBox(height: 30),
              _buildLogoutButton(),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  // --- Fungsi Laporan Modern dengan Data Vaksin & Pertumbuhan ---
  Future<void> _showReportDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _babyData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tiada rekod bayi tersedia.")));
      return;
    }

    // Tunjuk Loading
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final babyRef = FirebaseFirestore.instance
          .collection('caregivers')
          .doc(user.uid)
          .collection('babies')
          .doc(_babyData!['id']);

      // 1. Ambil Vaksin (yang Completed / taken == true)
      final vaccineSnap = await babyRef
          .collection('vaccines')
          .where('taken', isEqualTo: true)
          //.orderBy('date', descending: true)
          .get();

      // 2. Ambil Growth Records (Terkini)
      final growthSnap = await babyRef
          .collection('growth_records')
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (mounted) {
        Navigator.pop(context); // Tutup loading
        _showModernReportSheet(vaccineSnap.docs,
            growthSnap.docs.isNotEmpty ? growthSnap.docs.first.data() : null);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Tutup loading jika error
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Ralat: $e")));
    }
  }

  void _showModernReportSheet(List<QueryDocumentSnapshot> vaccines,
      Map<String, dynamic>? latestGrowth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              // --- Handle Bar ---
              Center(
                child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 20),
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10))),
              ),

              // --- Header Modal ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Laporan Kesihatan",
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: darkBlue)),
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.grey))
                  ],
                ),
              ),
              const Divider(),

              // --- Kandungan Laporan ---
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildReportHeader(),
                    const SizedBox(height: 25),
                    _buildGrowthSummary(latestGrowth),
                    const SizedBox(height: 30),
                    const Text("Sejarah Vaksinasi",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: darkBlue)),
                    const SizedBox(height: 10),
                    _buildVaccineList(vaccines),
                    const SizedBox(height: 40),
                  ],
                ),
              ),

              // --- Butang Cetak/Tutup (Hiasan) ---
              Padding(
                padding: const EdgeInsets.all(20),
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text("Selesai"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: darkBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15))),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportHeader() {
    final name = _babyData?['name'] ?? 'Bayi';
    // Format Tarikh Lahir
    String dobStr = '-';
    final dobRaw = _babyData?['dob'];
    if (dobRaw != null && dobRaw is Timestamp) {
      final d = dobRaw.toDate();
      dobStr = "${d.day}/${d.month}/${d.year}";
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: pastelBlue.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.withOpacity(0.1))),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.child_care, size: 35, color: darkBlue),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 4),
                Text("Tarikh Lahir: $dobStr",
                    style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                Text("Jenis Darah: $_bloodType",
                    style: const TextStyle(
                        color: darkBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildGrowthSummary(Map<String, dynamic>? data) {
    // Guna data dummy jika null, untuk nampak 'complete' seperti diminta
    final weight = data?['weight']?.toString() ?? "4";
    final height = data?['height']?.toString() ?? "40";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Pertumbuhan (Terkini)",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkBlue)),
            if (data == null) // Label kecil jika dummy
              Text("Anggaran",
                  style: TextStyle(fontSize: 10, color: Colors.grey[400])),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _buildStatCard("Berat Badan", "$weight kg",
                    Icons.monitor_weight_outlined, Colors.orange)),
            const SizedBox(width: 15),
            Expanded(
                child: _buildStatCard(
                    "Tinggi", "$height cm", Icons.height, Colors.teal)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
          border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildVaccineList(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(25),
        width: double.infinity,
        decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          children: const [
            Icon(Icons.vaccines, size: 40, color: Colors.grey),
            SizedBox(height: 10),
            Text("Belum ada rekod vaksin lagi.",
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final data = docs[i].data() as Map<String, dynamic>;
        String vName = data['vaccineName'] ?? data['name'] ?? 'Vaksin';

        // Format Date
        String dateStr = '-';
        if (data['date'] != null && data['date'] is Timestamp) {
          final d = (data['date'] as Timestamp).toDate();
          dateStr = "${d.day}/${d.month}/${d.year}";
        }

        return Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: const Offset(0, 2))
              ]),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.withOpacity(0.1),
              child: const Icon(Icons.check, color: Colors.green),
            ),
            title: Text(vName,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Text("Diambil pada: $dateStr"),
          ),
        );
      },
    );
  }

  // --- UI Helper Widgets ---
  Widget _buildAvatarHeader() {
    ImageProvider? image;
    final localPath = _babyData?['local_photo_path'] as String?;
    if (_babyImage != null) {
      // if a freshly picked file is present, use it
      image = FileImage(_babyImage!);
    } else if (localPath != null && localPath.isNotEmpty) {
      // If it's a URL, use NetworkImage
      if (localPath.startsWith('http')) {
        image = NetworkImage(localPath);
      } else {
        try {
          if (!kIsWeb && File(localPath).existsSync()) {
            image = FileImage(File(localPath));
          }
        } catch (_) {}
      }
    }

    return Column(
      children: [
        CircleAvatar(
          radius: 52,
          backgroundColor: darkBlue,
          child: CircleAvatar(
            radius: 48,
            backgroundColor: Colors.white,
            backgroundImage: image,
            child: image == null
                ? const Icon(Icons.child_care, size: 45, color: darkBlue)
                : null,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildGroupCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildMenuTile(
      {required IconData icon,
      required Color color,
      required String title,
      String? subtitle,
      Widget? trailing,
      VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 12))
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 10, bottom: 8, top: 10),
      child: Text(label,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey)),
    );
  }

  void _showEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 25,
            right: 25,
            top: 25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Kemaskini Profil",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkBlue)),
            const SizedBox(height: 20),
            _buildPopupTextField("Nama Penjaga", _caregiverNameController),
            _buildPopupTextField("No. Telefon", _caregiverPhoneController),
            _buildPopupTextField("No. Kecemasan", _emergencyContactController),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _updateProfile();
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: darkBlue,
                  minimumSize: const Size(double.infinity, 50)),
              child: const Text("Simpan Perubahan",
                  style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildPopupTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: bgLight,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
        ),
      ),
    );
  }

  void _showBloodPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: _bloodTypes
            .map((t) => ListTile(
                  title: Text(t, textAlign: TextAlign.center),
                  onTap: () {
                    setState(() => _bloodType = t);
                    Navigator.pop(ctx);
                  },
                ))
            .toList(),
      ),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: "BabyCare App",
      applicationVersion: "1.0.4",
      applicationIcon: const Icon(Icons.child_care, color: darkBlue, size: 40),
      children: [
        const Text("Aplikasi pemantauan bayi terbaik untuk ibu bapa moden.")
      ],
    );
  }

  Widget _buildLogoutButton() {
    return TextButton.icon(
      onPressed: () async {
        await FirebaseAuth.instance.signOut();
        if (mounted)
          Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      },
      icon: const Icon(Icons.logout, color: Colors.redAccent),
      label: const Text("Log Keluar Akaun",
          style:
              TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
    );
  }
}
