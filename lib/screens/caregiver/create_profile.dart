import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'caregiver_home.dart';

// Modern Blue Theme
const Color kPrimaryColor = Color(0xFF00A3FF);
const Color kBackgroundColor = Color(0xFFF0F7FF);
const Color kSurfaceColor = Colors.white;
const Color kTextColor = Color(0xFF1B1B1F);

class CreateProfilePage extends StatefulWidget {
  const CreateProfilePage({super.key});

  @override
  State<CreateProfilePage> createState() => _CreateProfilePageState();
}

class _CreateProfilePageState extends State<CreateProfilePage> {
  int _currentStep = 0;

  // ================= CAREGIVER (IBU) =================
  final _caregiverName = TextEditingController();
  final _caregiverPhone = TextEditingController();
  final _emergencyContact = TextEditingController();
  String _relationship = "Ibu";
  final _relationships = ["Ibu", "Bapa", "Penjaga"];

  // ================= BABY (ANAK) =================
  final _babyName = TextEditingController();
  DateTime? _babyDob;
  String _babyGender = "Lelaki";
  File? _babyImage;

  // ================= VACCINE =================
  final ImagePicker _picker = ImagePicker();
  List<String> _vaccines = [];
  final Map<String, DateTime?> _selectedVaccines = {};

  @override
  void initState() {
    super.initState();
    _fetchVaccines();
  }

  Future<void> _fetchVaccines() async {
    final snap = await FirebaseFirestore.instance.collection('vaccines').get();
    setState(() {
      _vaccines = snap.docs.map((e) => e['name'].toString()).toList();
      for (var v in _vaccines) {
        _selectedVaccines[v] = null;
      }
    });
  }

  Future<void> _pickImage() async {
    final XFile? picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
    if (picked == null) return;

    try {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        final dir = await getTemporaryDirectory();
        final file = File(
            '${dir.path}/baby_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(bytes);
        if (mounted) setState(() => _babyImage = file);
        return;
      }

      final candidate = File(picked.path);
      if (await candidate.exists()) {
        if (mounted) setState(() => _babyImage = candidate);
        return;
      }

      final bytes = await picked.readAsBytes();
      final dir = await getTemporaryDirectory();
      final file =
          File('${dir.path}/baby_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      if (mounted) setState(() => _babyImage = file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuatkan gambar: $e')),
        );
      }
    }
  }

  Future<void> _pickDate(Function(DateTime) onPick) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: kPrimaryColor),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) onPick(picked);
  }

  Future<String?> _saveLocalImage(File image) async {
    try {
      if (!await image.exists()) return null;
      final dir = await getApplicationDocumentsDirectory();
      final file = await image.copy(
          '${dir.path}/baby_${DateTime.now().millisecondsSinceEpoch}.png');
      return file.path;
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveProfile() async {
    // Validasi ringkas
    if (_caregiverName.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sila isi nama ibu/penjaga')));
      return;
    }
    if (_babyName.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sila isi nama bayi')));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1️⃣ CAREGIVER
    await FirebaseFirestore.instance
        .collection('caregivers')
        .doc(user.uid)
        .set({
      'name': _caregiverName.text,
      'phone': _caregiverPhone.text,
      'relationship': _relationship,
      'emergency_contact': _emergencyContact.text,
      'role': 'user', // Default role for safety
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2️⃣ BABY
    String? imgPath;
    if (_babyImage != null) imgPath = await _saveLocalImage(_babyImage!);

    final babyRef = FirebaseFirestore.instance
        .collection('caregivers')
        .doc(user.uid)
        .collection('babies')
        .doc();

    await babyRef.set({
      'name': _babyName.text,
      'dob': _babyDob ?? DateTime.now(),
      'gender': _babyGender,
      'local_photo_path': imgPath,
      'created_at': FieldValue.serverTimestamp(),
    });

    // 3️⃣ VACCINES
    for (var entry in _selectedVaccines.entries) {
      if (entry.value != null) {
        final adminSnap = await FirebaseFirestore.instance
            .collection('vaccines')
            .where('name', isEqualTo: entry.key)
            .limit(1)
            .get();

        if (adminSnap.docs.isNotEmpty) {
          await babyRef
              .collection('vaccines')
              .doc(adminSnap.docs.first.id)
              .set({
            'taken': true,
            'date': Timestamp.fromDate(entry.value!),
            'vaccineName': entry.key, // Store name for easier display
          });
        }
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profil berjaya dicipta!")),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CaregiverHomePage()),
    );
  }

  void _next() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _saveProfile();
    }
  }

  void _back() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  // --- UI COMPONENTS ---

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _stepItem(0, "Ibu/Bapa"),
          _stepLine(0),
          _stepItem(1, "Bayi"),
          _stepLine(1),
          _stepItem(2, "Vaksin"),
        ],
      ),
    );
  }

  Widget _stepItem(int index, String label) {
    bool isActive = _currentStep == index;
    bool isCompleted = _currentStep > index;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: (isActive || isCompleted)
                ? kPrimaryColor
                : Colors.grey.shade200,
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                        color: kPrimaryColor.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4))
                  ]
                : [],
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                    "${index + 1}",
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: (isActive || isCompleted) ? kPrimaryColor : Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _stepLine(int index) {
    bool isCompleted = _currentStep > index;
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 15),
      color: isCompleted ? kPrimaryColor : Colors.grey.shade300,
    );
  }

  Widget _buildModernField(TextEditingController c, String label, IconData icon,
      {TextInputType type = TextInputType.text}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: TextField(
        controller: c,
        keyboardType: type,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: kPrimaryColor.withOpacity(0.7)),
          labelText: label,
          floatingLabelStyle: const TextStyle(color: kPrimaryColor),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _content() {
    if (_currentStep == 0) {
      return Column(children: [
        const SizedBox(height: 10),
        const Text(
          "Maklumat Ibu/Penjaga",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text("Sila isi butiran anda untuk rekod perubatan.",
            style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 30),
        _buildModernField(_caregiverName, "Nama Penuh", Icons.person),
        _buildModernField(_caregiverPhone, "No. Telefon", Icons.phone,
            type: TextInputType.phone),
        _buildModernField(
            _emergencyContact, "No. Kecemasan", Icons.contact_phone,
            type: TextInputType.phone),
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _relationship,
              icon: const Icon(Icons.arrow_drop_down, color: kPrimaryColor),
              isExpanded: true,
              items: _relationships
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _relationship = v!),
            ),
          ),
        ),
      ]);
    }

    if (_currentStep == 1) {
      return Column(children: [
        const SizedBox(height: 10),
        const Text(
          "Maklumat Bayi",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text("Muat naik gambar bayi untuk profil comel!",
            style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 30),
        GestureDetector(
          onTap: _pickImage,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kPrimaryColor, width: 3),
                  boxShadow: [
                    BoxShadow(
                        color: kPrimaryColor.withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 6)),
                  ],
                ),
                child: CircleAvatar(
                  radius: 65,
                  backgroundColor: Colors.white,
                  backgroundImage:
                      _babyImage != null ? FileImage(_babyImage!) : null,
                  child: _babyImage == null
                      ? Icon(Icons.camera_alt_rounded,
                          size: 40, color: Colors.grey.shade400)
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: kPrimaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 20),
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 30),
        _buildModernField(_babyName, "Nama Bayi", Icons.child_care),
        GestureDetector(
          onTap: () => _pickDate((d) => setState(() => _babyDob = d)),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today,
                    color: kPrimaryColor.withOpacity(0.7)),
                const SizedBox(width: 14),
                Text(
                  _babyDob == null
                      ? "Pilih Tarikh Lahir"
                      : DateFormat('dd MMM yyyy').format(_babyDob!),
                  style: TextStyle(
                    fontSize: 16,
                    color: _babyDob == null ? Colors.grey.shade600 : kTextColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _babyGender,
              icon: const Icon(Icons.arrow_drop_down, color: kPrimaryColor),
              isExpanded: true,
              items: ["Lelaki", "Perempuan"]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _babyGender = v!),
            ),
          ),
        ),
      ]);
    }

    return Column(
      children: [
        const SizedBox(height: 10),
        const Text(
          "Sejarah Vaksin",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text("Tandakan vaksin yang SUDAH diambil.",
            style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 20),
        if (_vaccines.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _vaccines.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final v = _vaccines[i];
              final checked = _selectedVaccines[v] != null;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color:
                      checked ? kPrimaryColor.withOpacity(0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: checked ? kPrimaryColor : Colors.grey.shade200,
                  ),
                ),
                child: CheckboxListTile(
                  activeColor: kPrimaryColor,
                  title: Text(v,
                      style: TextStyle(
                          fontWeight:
                              checked ? FontWeight.bold : FontWeight.normal,
                          color: checked ? kPrimaryColor : Colors.black87)),
                  subtitle: checked
                      ? Text(
                          "Tarikh: ${DateFormat('dd/MM/yyyy').format(_selectedVaccines[v]!)}",
                          style: TextStyle(
                              color: kPrimaryColor.withOpacity(0.7),
                              fontSize: 12))
                      : null,
                  value: checked,
                  onChanged: (val) {
                    if (val == true) {
                      _pickDate(
                          (d) => setState(() => _selectedVaccines[v] = d));
                    } else {
                      setState(() => _selectedVaccines[v] = null);
                    }
                  },
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildStepIndicator(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return SlideTransition(
                      position: Tween<Offset>(
                              begin: const Offset(0.2, 0), end: Offset.zero)
                          .animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<int>(_currentStep),
                    child: _content(),
                  ),
                ),
              ),
            ),

            // BOTTOM BUTTONS
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4))
              ]),
              child: Row(children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                        onPressed: _back,
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            side: const BorderSide(color: Colors.grey)),
                        child: const Text("Kembali",
                            style: TextStyle(color: Colors.black87))),
                  ),
                if (_currentStep > 0) const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    onPressed: _next,
                    child: Text(
                      _currentStep < 2 ? "Seterusnya" : "Selesai",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                )
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
