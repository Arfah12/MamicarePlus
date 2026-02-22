import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'register_page.dart';
import 'caregiver/moving_bubbles.dart';
import 'caregiver/caregiver_home.dart';
import 'caregiver/create_profile.dart';
import 'admin/admin_home.dart';

const Color themePurple = Color.fromARGB(255, 0, 64, 201);
const Color themeYellow = Color.fromARGB(255, 255, 181, 32);
const Color themeGreyTab = Color(0xFFE0E0E0);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool _loading = false;
  bool _loadingGoogle = false;

  Future<void> _checkProfileAndNavigate(User user) async {
    // 1. Admin Check
    if (user.email != null && user.email!.toLowerCase() == 'arfah@gmail.com') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AdminHomePage()),
      );
      return;
    }

    // 2. Caregiver Profile Check
    final doc = await FirebaseFirestore.instance
        .collection('caregivers')
        .doc(user.uid)
        .get();

    if (!mounted) return;

    if (doc.exists) {
      // Profile wujud -> Caregiver Home
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const CaregiverHomePage()),
      );
    } else {
      // Profile tiada -> Create Profile
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const CreateProfilePage()),
      );
    }
  }

  // ---------------- Google Sign-In ----------------
  Future<void> _signInWithGoogle() async {
    setState(() => _loadingGoogle = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // user cancel

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Berjaya sign-in dengan Google!")),
      );

      // Check Profile and Navigate
      if (userCred.user != null) {
        await _checkProfileAndNavigate(userCred.user!);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Google Sign-In gagal: $e")),
      );
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
    }
  }

  // ---------------- Email & Password Login ----------------
  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sila isi semua ruangan"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Login berjaya!"),
          backgroundColor: Colors.green,
        ),
      );

      if (cred.user != null) {
        await _checkProfileAndNavigate(cred.user!);
      }

      // TODO: Redirect ke home page
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? "Ralat berlaku"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  // ---------------- Resend Verification Email ----------------
  Future<void> _resendEmailVerification() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Verification email telah dihantar semula"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal hantar verification email: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _forgotPassword() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sila masukkan emel dahulu"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Email reset kata laluan telah dihantar"),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? "Ralat berlaku"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: themePurple,
      body: Stack(
        children: [
          const MovingBubbles(), // bubble bergerak
          _buildBackground(),

          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: height * 0.78,
              child: Stack(
                children: [
                  /// TAB DAFTAR
                  Positioned(
                    top: 0,
                    right: 30,
                    child: _buildTab(
                      title: "DAFTAR",
                      active: false,
                      onTap: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            transitionDuration:
                                const Duration(milliseconds: 300),
                            pageBuilder: (_, __, ___) => const RegisterPage(),
                          ),
                        );
                      },
                    ),
                  ),

                  /// TAB LOG MASUK
                  Positioned(
                    top: 0,
                    left: 30,
                    child: _buildTab(title: "LOG MASUK", active: true),
                  ),

                  /// CARD UTAMA
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
                            _input("Emel", Icons.email_outlined),
                            const SizedBox(height: 20),
                            _input("Kata Laluan", Icons.lock_outline,
                                isPassword: true),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: _forgotPassword,
                                child: const Text(
                                  "Lupa kata laluan?",
                                  style: TextStyle(
                                    color: themePurple,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeYellow,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                child: _loading
                                    ? const CircularProgressIndicator(
                                        color: themePurple)
                                    : const Text(
                                        "LOG MASUK",
                                        style: TextStyle(
                                          color: themePurple,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 30),
                            const Text("ATAU",
                                style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 20),

                            // Google Sign-In Button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _socialIcon(
                                  "https://upload.wikimedia.org/wikipedia/commons/0/09/IOS_Google_icon.png",
                                  onTap:
                                      _loadingGoogle ? null : _signInWithGoogle,
                                ),
                              ],
                            ),
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

  /// ================= WIDGETS =================
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

  Widget _buildTab(
      {required String title, required bool active, VoidCallback? onTap}) {
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
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _input(String hint, IconData icon, {bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: isPassword ? _passwordController : _emailController,
        obscureText: isPassword && !_passwordVisible,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: themePurple),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(_passwordVisible
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () =>
                      setState(() => _passwordVisible = !_passwordVisible),
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
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
    );
  }

  Widget _socialIcon(String url, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        child: Center(
          child: Image.network(
            url,
            width: 40,
            height: 40,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
