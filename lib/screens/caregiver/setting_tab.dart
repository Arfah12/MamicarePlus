import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

// === TEMA BIRU-PUTIH ===
const Color primaryColor = Color(0xFF007BFF); // biru utama
const Color secondaryColor = Color(0xFF66B2FF); // biru lembut / accent
const Color backgroundColor = Color(0xFFF5F7FA);

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
  final List<String> _bloodTypes = ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"];

  Map<String, dynamic>? _caregiverData;
  Map<String, dynamic>? _babyData;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final caregiverDoc =
        await FirebaseFirestore.instance.collection('caregivers').doc(user.uid).get();
    final babiesCollection =
        await FirebaseFirestore.instance.collection('caregivers').doc(user.uid).collection('babies').get();

    if (caregiverDoc.exists) {
      setState(() {
        _caregiverData = caregiverDoc.data();
      });
    }

    if (babiesCollection.docs.isNotEmpty) {
      setState(() {
        _babyData = babiesCollection.docs.first.data();
      });
    }
  }

  Future<void> _pickBabyImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _babyImage = File(picked.path));
  }

  Future<void> _updateProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('caregivers').doc(user.uid).set({
        'name': _caregiverNameController.text.trim(),
        'phone': _caregiverPhoneController.text.trim(),
        'emergency_contact': _emergencyContactController.text.trim(),
      }, SetOptions(merge: true));

      if (_babyData != null) {
        final babyDocRef = FirebaseFirestore.instance
            .collection('caregivers')
            .doc(user.uid)
            .collection('babies')
            .doc(_babyData!['id'] ?? _babyData!['docId']);

        await babyDocRef.set({
          'blood_type': _bloodType,
          'local_photo_path': _babyImage != null ? _babyImage!.path : _babyData!['local_photo_path'],
        }, SetOptions(merge: true));
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profil berjaya dikemaskini.")));
        _loadProfile();
      }
    } catch (e) {
      print("Error update profile: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal kemaskini profil.")));
    }
  }

  void _openEditProfile() {
    if (_caregiverData == null || _babyData == null) return;

    _caregiverNameController.text = _caregiverData!['name'] ?? '';
    _caregiverPhoneController.text = _caregiverData!['phone'] ?? '';
    _emergencyContactController.text = _caregiverData!['emergency_contact'] ?? '';
    _bloodType = _babyData!['blood_type'] ?? "A+";

    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Kemaskini Profil",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _pickBabyImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _babyImage != null
                        ? FileImage(_babyImage!)
                        : (_babyData!['local_photo_path'] != null && _babyData!['local_photo_path'] != ''
                            ? FileImage(File(_babyData!['local_photo_path']))
                            : null) as ImageProvider?,
                    child: _babyImage == null &&
                            (_babyData!['local_photo_path'] == null ||
                                _babyData!['local_photo_path'] == '')
                        ? Icon(Icons.camera_alt, size: 40, color: primaryColor)
                        : null,
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _caregiverNameController,
                  decoration: InputDecoration(
                      labelText: "Nama Penjaga",
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: primaryColor))),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _caregiverPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                      labelText: "No Telefon",
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: primaryColor))),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _emergencyContactController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                      labelText: "No Kecemasan",
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: primaryColor))),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _bloodType,
                  items: _bloodTypes
                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (val) => setState(() => _bloodType = val!),
                  decoration: InputDecoration(
                      labelText: "Jenis Darah",
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: primaryColor))),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _updateProfile,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      minimumSize: const Size(double.infinity, 50)),
                  child: const Text("Simpan", style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsHeader(TextTheme textTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "Tetapan Aplikasi",
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: primaryColor,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Urus profil, versi & log keluar",
            style: textTheme.bodyMedium?.copyWith(
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }



 @override
Widget build(BuildContext context) {
  final textTheme = Theme.of(context).textTheme;

  return Scaffold(
    backgroundColor: backgroundColor,

    // ==== WALLPAPER BACKGROUND ====
    body: Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/images/wallpaper1.jpg"),
          fit: BoxFit.cover,
          opacity: 0.9,
        ),
      ),

      child: SafeArea(
        child: Column(
          children: [
            _buildSettingsHeader(textTheme),
            const SizedBox(height: 20),

            // ==========================
            //         CONTENT
            // ==========================
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ListTile(
                    leading: const Icon(Icons.person, color: primaryColor),
                    title: const Text("Profil Saya"),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _openEditProfile,
                  ),

                  ListTile(
                    leading: const Icon(Icons.info_outline, color: primaryColor),
                    title: const Text("Versi Aplikasi"),
                    trailing: const Text("1.0.2"),
                  ),

                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text("Log Keluar"),
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/login',
                          (route) => false,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}