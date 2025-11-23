import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'caregiver_home.dart';

const Color backgroundStart = Color(0xFFB1A1FF);
const Color backgroundEnd = Color(0xFF4A148C);
const Color buttonGradientStart = Color(0xFF7F00FF);
const Color buttonGradientEnd = Color(0xFF00BFFF);
const Color primaryTextColor = Colors.white;
const Color secondaryTextColor = Color(0xFF4A148C);
const Color inputFillColor = Color(0xFFF5F5F5);

class CreateProfilePage extends StatefulWidget {
  const CreateProfilePage({super.key});

  @override
  State<CreateProfilePage> createState() => _CreateProfilePageState();
}

class _CreateProfilePageState extends State<CreateProfilePage> {
  int _currentStep = 0;

  // Step 1: Baby info
  final TextEditingController _babyNameController = TextEditingController();
  DateTime? _babyDob;
  String _babyGender = "Lelaki";
  File? _babyImage;

  // Step 2: Growth info
  double _babyWeight = 2.5;
  double _babyHeight = 44;
  String _bloodType = "A+";
  final List<String> _bloodTypes = ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"];

  // Step 3: Vaccines
  List<String> _vaccines = [];
  final Map<String, DateTime?> _selectedVaccines = {};

  // Step 4: Caregiver info
  final TextEditingController _caregiverNameController = TextEditingController();
  final TextEditingController _caregiverPhoneController = TextEditingController();
  final TextEditingController _emergencyContactController = TextEditingController();
  String _relationship = "Ibu";
  final List<String> _relationships = ["Ibu", "Bapa", "Nenek", "Lain-lain"];

  final ImagePicker _picker = ImagePicker();

  String? _tempBabyDocId;

  @override
  void initState() {
    super.initState();
    _fetchVaccines();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _caregiverNameController.text = user.displayName ?? '';
      _caregiverPhoneController.text = user.phoneNumber ?? '';
    }
  }

  Future<void> _fetchVaccines() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('vaccines').get();
      setState(() {
        _vaccines = snapshot.docs.map((doc) => doc['name'].toString()).toList();
        for (var vaccine in _vaccines) {
          _selectedVaccines[vaccine] = null;
        }
      });
    } catch (e) {
      print("Error fetch vaccines: $e");
      setState(() {
        _vaccines = ["BCG", "Hepatitis B", "DTaP", "Polio", "MMR"];
        _selectedVaccines.clear();
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (picked != null) setState(() => _babyImage = File(picked.path));
  }

  Future<void> _pickDate(Function(DateTime) onDateSelected,
      {DateTime? initialDate, DateTime? firstDate, DateTime? lastDate}) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? now,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: backgroundEnd,
              onPrimary: Colors.white,
              onSurface: secondaryTextColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) onDateSelected(picked);
  }

  Future<String> _saveImageLocally(File image) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'baby_${DateTime.now().millisecondsSinceEpoch}.png';
      final savedImage = await image.copy('${appDir.path}/$fileName');
      return savedImage.path;
    } catch (e) {
      print('Error saving image locally: $e');
      return '';
    }
  }

 Future<void> _saveProfile() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  if (_babyNameController.text.isEmpty || _babyDob == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Sila lengkapkan nama bayi dan tarikh lahir."),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  if (_caregiverNameController.text.isEmpty || _emergencyContactController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Sila lengkapkan butiran Penjaga."),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  String? localImagePath;
  if (_babyImage != null) localImagePath = await _saveImageLocally(_babyImage!);

  try {
    // 1️⃣ Simpan data bayi
    final babyDocRef = FirebaseFirestore.instance
        .collection('caregivers')
        .doc(user.uid)
        .collection('babies')
        .doc(); // auto generate baby ID

    await babyDocRef.set({
      'name': _babyNameController.text,
      'dob': _babyDob,
      'local_photo_path': localImagePath ?? "",
      'created_at': FieldValue.serverTimestamp(),
    });

    // 2️⃣ Simpan vaksin yang dipilih dengan doc ID sama seperti admin vaccine
    for (var entry in _selectedVaccines.entries) {
      final vaccineName = entry.key;
      final date = entry.value;

      if (date != null) {
        // Dapatkan vaccine ID dari admin collection
        final adminVaccineSnapshot = await FirebaseFirestore.instance
            .collection('vaccines')
            .where('name', isEqualTo: vaccineName)
            .limit(1)
            .get();

        if (adminVaccineSnapshot.docs.isNotEmpty) {
          final vaccineId = adminVaccineSnapshot.docs.first.id;

          await babyDocRef.collection('vaccines').doc(vaccineId).set({
            'taken': true,
            'dateScheduled': Timestamp.fromDate(date),
          });
        }
      }
    }

    // Paparkan SnackBar & redirect
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profil bayi berjaya dicipta!"),
          backgroundColor: Colors.green,
        ),
      );

      Future.delayed(const Duration(milliseconds: 500), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CaregiverHomePage()),
        );
      });
    }
  } catch (e) {
    print('Error saveProfile: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal simpan profil: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  void _nextStep() {
    if (_currentStep == 0 && (_babyNameController.text.isEmpty || _babyDob == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Sila lengkapkan Nama Bayi dan Tarikh Lahir."),
            backgroundColor: Colors.orange),
      );
      return;
    }
    _currentStep < 3 ? setState(() => _currentStep++) : _saveProfile();
  }

  void _backStep() => _currentStep > 0 ? setState(() => _currentStep--) : null;

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        bool isActive = index <= _currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? backgroundEnd : Colors.white,
            border: Border.all(
                color: isActive ? backgroundEnd : backgroundStart.withOpacity(0.5)),
            boxShadow: isActive
                ? [BoxShadow(color: backgroundEnd.withOpacity(0.5), blurRadius: 4)]
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildModernTextField(TextEditingController controller, String label,
      {TextInputType keyboardType = TextInputType.text, Widget? suffixIcon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: inputFillColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 3))
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: secondaryTextColor),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: secondaryTextColor.withOpacity(0.8)),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          border: InputBorder.none,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  Widget _buildModernDropdown<T>(T value, List<T> items, String label, Function(T?) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: inputFillColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 3))
        ],
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: secondaryTextColor.withOpacity(0.8)),
            border: InputBorder.none),
        dropdownColor: Colors.white,
        style: const TextStyle(color: secondaryTextColor),
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item.toString())))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _stepContent() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 10,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Step 0: Baby info
            if (_currentStep == 0) ...[
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: backgroundStart.withOpacity(0.2),
                  backgroundImage: _babyImage != null ? FileImage(_babyImage!) : null,
                  child: _babyImage == null ? Icon(Icons.camera_alt, size: 40, color: backgroundEnd) : null,
                ),
              ),
              const SizedBox(height: 20),
              _buildModernTextField(_babyNameController, "Nama Bayi"),
              OutlinedButton(
                onPressed: () => _pickDate((date) => setState(() => _babyDob = date),
                  initialDate: _babyDob ?? DateTime.now().subtract(const Duration(days: 180)),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: backgroundEnd.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today, color: backgroundEnd),
                    const SizedBox(width: 10),
                    Text(_babyDob != null
                        ? "Tarikh Lahir: ${DateFormat('dd MMM yyyy').format(_babyDob!)}"
                        : "Pilih Tarikh Lahir",
                        style: TextStyle(color: backgroundEnd, fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildModernDropdown<String>(_babyGender, ["Lelaki", "Perempuan"], "Jantina Bayi",
                      (val) => setState(() => _babyGender = val!)),
            ] 
            // Step 1: Growth
            else if (_currentStep == 1) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text("Berat Semasa (kg): ${_babyWeight.toStringAsFixed(1)}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: secondaryTextColor)),
              ),
              Slider(
                min: 1.0,
                max: 10.0,
                value: _babyWeight,
                onChanged: (val) => setState(() => _babyWeight = val),
                activeColor: buttonGradientStart,
                inactiveColor: backgroundStart.withOpacity(0.5),
                thumbColor: backgroundEnd,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text("Tinggi Semasa (cm): ${_babyHeight.toStringAsFixed(0)}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: secondaryTextColor)),
              ),
              Slider(
                min: 40,
                max: 100,
                value: _babyHeight,
                onChanged: (val) => setState(() => _babyHeight = val),
                activeColor: buttonGradientStart,
                inactiveColor: backgroundStart.withOpacity(0.5),
                thumbColor: backgroundEnd,
              ),
              _buildModernDropdown<String>(_bloodType, _bloodTypes, "Jenis Darah", (val) => setState(() => _bloodType = val!)),
            ]
            // Step 2: Vaccines
            else if (_currentStep == 2) ...[
              Align(alignment: Alignment.centerLeft, child: Text("Vaksin Yang Telah Diambil", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: secondaryTextColor))),
              const SizedBox(height: 10),
              ..._vaccines.map((vaccineName) {
                final isChecked = _selectedVaccines[vaccineName] != null;
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    title: Text(vaccineName, style: TextStyle(color: secondaryTextColor)),
                    subtitle: isChecked ? Text("Tarikh: ${DateFormat('dd MMM yyyy').format(_selectedVaccines[vaccineName]!)}", style: const TextStyle(color: Color(0xFF1ABC9C), fontWeight: FontWeight.bold)) : null,
                    trailing: Checkbox(
                      activeColor: backgroundEnd,
                      value: isChecked,
                      onChanged: (val) async {
                        if (val == true) {
                          _pickDate((date) async {
                            setState(() => _selectedVaccines[vaccineName] = date);
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null && _tempBabyDocId != null) {
                              await FirebaseFirestore.instance
                                  .collection('caregivers')
                                  .doc(user.uid)
                                  .collection('babies')
                                  .doc(_tempBabyDocId)
                                  .collection('vaccines')
                                  .doc(vaccineName)
                                  .set({
                                'name': vaccineName,
                                'dateScheduled': Timestamp.fromDate(date),
                                'taken': true,
                              }, SetOptions(merge: true));
                            }
                          });
                        } else {
                          setState(() => _selectedVaccines[vaccineName] = null);
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null && _tempBabyDocId != null) {
                            await FirebaseFirestore.instance
                                .collection('caregivers')
                                .doc(user.uid)
                                .collection('babies')
                                .doc(_tempBabyDocId)
                                .collection('vaccines')
                                .doc(vaccineName)
                                .delete();
                          }
                        }
                      },
                    ),
                  ),
                );
              }).toList(),
            ]
            // Step 3: Caregiver
            else if (_currentStep == 3) ...[
              _buildModernTextField(_caregiverNameController, "Nama Penjaga"),
              _buildModernTextField(_caregiverPhoneController, "No Telefon Penjaga", keyboardType: TextInputType.phone),
              _buildModernDropdown<String>(_relationship, _relationships, "Hubungan", (val) => setState(() => _relationship = val!)),
              _buildModernTextField(_emergencyContactController, "No Kecemasan", keyboardType: TextInputType.phone),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, automaticallyImplyLeading: false),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [backgroundStart, backgroundEnd], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: 8),
                    Expanded(
  child: Center(
    child: Text(
      _currentStep == 0
          ? "1. Butiran Bayi"
          : _currentStep == 1
              ? "2. Perkembangan Bayi"
              : _currentStep == 2
                  ? "3. Vaksin"
                  : "4. Butiran Penjaga",
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: primaryTextColor,
      ),
    ),
  ),
),

                  ],
                ),
                
                const SizedBox(height: 20),
                _buildStepIndicator(),
                const SizedBox(height: 20),
                Expanded(child: SingleChildScrollView(child: _stepContent())),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _backStep,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text("Kembali", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 55,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: const LinearGradient(colors: [buttonGradientStart, buttonGradientEnd], begin: Alignment.centerLeft, end: Alignment.centerRight),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _nextStep,
                            borderRadius: BorderRadius.circular(30),
                            child: Center(child: Text(_currentStep < 3 ? "Seterusnya" : "Selesai", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor))),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
