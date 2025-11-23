import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// === TEMA MOFINOW (Gradient Ungu-Biru) - MESTI SAMA DENGAN LOGIN PAGE ===
const Color backgroundStart = Color(0xFFB1A1FF); // Lavender/Light Purple
const Color backgroundEnd = Color(0xFF4A148C); // Deep Violet
const Color buttonGradientStart = Color(0xFF7F00FF); // Medium Violet
const Color buttonGradientEnd = Color(0xFF00BFFF); // Deep Sky Blue

const Color primaryTextColor = Colors.white;
const Color secondaryTextColor = Color(0xFF4A148C); 
const Color inputFillColor = Color(0xFFF5F5F5); // Light grey for input fields

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  String? _error;
  bool _passwordVisible = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Simpan data pengguna ke Firestore
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': 'caregiver',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pendaftaran berjaya! Sila log masuk.')),
        );
        // Navigasi kembali ke halaman login
        Navigator.pop(context); 
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        setState(() => _error = 'Email ini sudah didaftarkan. Sila log masuk.');
      } else {
        setState(() => _error = e.message);
      }
    } catch (e) {
      setState(() => _error = "Ralat tidak dijangka: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // Widget untuk ikon sosial media
  Widget _buildSocialIcon(IconData icon, Color color) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: inputFillColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: color),
    );
  }

  // Widget untuk TextField dengan reka bentuk moden
  Widget _buildTextField(String hintText, IconData icon, TextEditingController controller, {bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(
        color: inputFillColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && !_passwordVisible,
        style: const TextStyle(color: secondaryTextColor),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Sila masukkan $hintText';
          if (isPassword && v.length < 6) return 'Kata laluan sekurang-kurangnya 6 aksara';
          return null;
        },
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: secondaryTextColor.withOpacity(0.6)),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          prefixIcon: Icon(icon, color: secondaryTextColor.withOpacity(0.8)),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _passwordVisible ? Icons.visibility : Icons.visibility_off,
                    color: secondaryTextColor.withOpacity(0.6),
                  ),
                  onPressed: () {
                    setState(() {
                      _passwordVisible = !_passwordVisible;
                    });
                  },
                )
              : null,
          border: InputBorder.none, // Hilangkan border asal
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: primaryTextColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true, // Untuk membenarkan gradient di belakang AppBar
      body: Container(
  height: MediaQuery.of(context).size.height, // pastikan penuh skrin
  decoration: const BoxDecoration(
    gradient: LinearGradient(
      colors: [backgroundStart, backgroundEnd],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  ),
  child: SafeArea(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 10.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20), // jarak atas sedikit
              const Text(
                'Cipta Akaun Baru',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Daftar dan jejak perkembangan anak anda dengan mudah.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 40),

              // Input fields
              _buildTextField("Nama Penuh", Icons.person_outline, _nameController),
              const SizedBox(height: 20),
              _buildTextField("Emel", Icons.email_outlined, _emailController),
              const SizedBox(height: 20),
              _buildTextField("No Telefon", Icons.phone_outlined, _phoneController),
              const SizedBox(height: 20),
              _buildTextField("Kata Laluan", Icons.lock_outline, _passwordController, isPassword: true),
              const SizedBox(height: 30),

              // Button Daftar
              Container(
                height: 55,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: const LinearGradient(
                    colors: [buttonGradientStart, buttonGradientEnd],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _loading ? null : _register,
                    borderRadius: BorderRadius.circular(30),
                    child: Center(
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Daftar',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryTextColor,
                              ),
                            ),
                    ),
                  ),
                ),
              ),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                ),

              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Sudah ada akaun? ",
                    style: TextStyle(color: primaryTextColor),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      "Log masuk",
                      style: TextStyle(
                        color: primaryTextColor,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                        decorationColor: primaryTextColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    ),
  ),
),
    );
  }
} 