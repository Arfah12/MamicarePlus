import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'caregiver/moving_bubbles.dart';

const Color themePurple = Color.fromARGB(255, 0, 64, 201);
const Color themeYellow = Color.fromARGB(255, 255, 181, 32);
const Color themeGreyTab = Color(0xFFE0E0E0);

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  // Di bawah controller-controller anda
bool _isAgreed = false; // Tambah ini

  Future<void> _register() async {
  if (_nameController.text.isEmpty ||
      _emailController.text.isEmpty ||
      _passwordController.text.isEmpty ||
      _confirmPasswordController.text.isEmpty) {
    _showError("Sila isi semua ruangan");
    return;
  }

if (!_isAgreed) {
    _showError("Sila setuju dengan Terma & Syarat untuk mendaftar");
    return;
  }
  if (_passwordController.text != _confirmPasswordController.text) {
    _showError("Kata laluan tidak sama");
    return;
  }

  setState(() => _loading = true);

  try {
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    await cred.user!.sendEmailVerification();

    // SIGN OUT supaya user balik ke login page
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            "Pendaftaran berjaya! Sila sahkan email sebelum login."),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pop(context); // kembali ke Login page
  } on FirebaseAuthException catch (e) {
    _showError(e.message ?? "Ralat berlaku");
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}


  

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red[400]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: themePurple,
      body: Stack(
        children: [
          const MovingBubbles(),
          _buildBackground(),

          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: height * 0.78,
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 30,
                    child: _buildTab(
                      title: "LOG MASUK",
                      active: false,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 30,
                    child: _buildTab(title: "DAFTAR", active: true),
                  ),
                  Positioned.fill(
                    top: 60,
                    child: Container(
                      padding: const EdgeInsets.all(30),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                      ),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            const SizedBox(height: 40),
                            _input("Nama Penuh", Icons.person_outline, _nameController),
                            const SizedBox(height: 20),
                            _input("Emel", Icons.email_outlined, _emailController),
                            const SizedBox(height: 20),
                            _input(
                              "Kata Laluan",
                              Icons.lock_outline,
                              _passwordController,
                              isPassword: true,
                              visible: _passwordVisible,
                              onToggle: () =>
                                  setState(() => _passwordVisible = !_passwordVisible),
                            ),
                            const SizedBox(height: 20),
                            _input(
                              "Sahkan Kata Laluan",
                              Icons.lock_clock_outlined,
                              _confirmPasswordController,
                              isPassword: true,
                              visible: _confirmPasswordVisible,
                              onToggle: () => setState(
                                  () => _confirmPasswordVisible = !_confirmPasswordVisible),
                            ),
                            const SizedBox(height: 15),
                            Row(
  children: [
    Checkbox(
      value: _isAgreed,
      activeColor: themePurple,
      onChanged: (value) {
        setState(() {
          _isAgreed = value ?? false;
        });
      },
    ),
    Expanded(
      child: GestureDetector(
        onTap: () {
          // Anda boleh letak fungsi untuk buka dialog Terma & Syarat di sini
        },
        child: const Text.rich(
          TextSpan(
            text: "Saya setuju dengan ",
            style: TextStyle(fontSize: 13),
            children: [
              TextSpan(
                text: "Terma & Syarat",
                style: TextStyle(
                  color: themePurple,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
              TextSpan(text: " serta "),
              TextSpan(
                text: "Dasar Privasi",
                style: TextStyle(
                  color: themePurple,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ],
),

const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _register,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeYellow,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                child: _loading
                                    ? const CircularProgressIndicator(
                                        color: themePurple,
                                      )
                                    : const Text(
                                        "DAFTAR SEKARANG",
                                        style: TextStyle(
                                          color: themePurple,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                              ),
                            ),
                            
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ================== WIDGET ==================

  Widget _buildBackground() {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -50,
          child: _circle(300, Colors.white.withOpacity(0.1)),
        ),
        Positioned(
          top: 100,
          left: -50,
          child: _circle(200, Colors.white.withOpacity(0.05)),
        ),
      ],
    );
  }

  Widget _buildTab({
    required String title,
    required bool active,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 140,
        height: active ? 70 : 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Colors.white : themeGreyTab,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: active ? themePurple : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _input(
    String hint,
    IconData icon,
    TextEditingController controller, {
    bool isPassword = false,
    bool visible = false,
    VoidCallback? onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && !visible,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: themePurple),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    visible ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: onToggle,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(18),
        ),
      ),
    );
  }

  Widget _circle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
