import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'register_page.dart'; // Pastikan laluan ini betul

// Gradient utama untuk latar belakang skrin (ringan)
const Color backgroundStart = Color(0xFFB1A1FF); 
const Color backgroundEnd = Color(0xFF4A148C); 

// Gradient butang Log Masuk (lebih berani)
const Color buttonGradientStart = Color(0xFF7F00FF); 
const Color buttonGradientEnd = Color(0xFF00BFFF); 

// Warna teks dan elemen
const Color primaryTextColor = Colors.white;
const Color secondaryTextColor = Color(0xFF4A148C); 
const Color inputFillColor = Color(0xFFF5F5F5);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _rememberMe = false;
  bool _passwordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- LOGIK FIREBASE ---

  Future<void> _checkCaregiverProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (user.email?.toLowerCase() == "arfah@gmail.com") {
      Navigator.pushReplacementNamed(context, '/admin_home');
      return;
    }

    final caregiverDoc = await FirebaseFirestore.instance
        .collection('caregivers')
        .doc(user.uid)
        .get();

    if (!caregiverDoc.exists) {
      Navigator.pushReplacementNamed(context, '/create_profile');
      return;
    }

    final babySnap = await FirebaseFirestore.instance
        .collection('caregivers')
        .doc(user.uid)
        .collection('babies')
        .limit(1)
        .get();

    if (babySnap.docs.isEmpty) {
      Navigator.pushReplacementNamed(context, '/create_profile');
    } else {
      Navigator.pushReplacementNamed(context, '/caregiver_home');
    }
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Log Masuk Firebase
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Semak Profil Firestore (PENTING: Guna await)
      await _checkCaregiverProfile(); 
      
    } on FirebaseAuthException catch (e) {
      // Kendalikan ralat pengesahan
      if (e.code == 'user-not-found') {
        _showRegisterDialog();
      } else if (e.code == 'wrong-password') {
        setState(() => _error = "Kata laluan salah. Sila cuba lagi.");
      } else if (e.code == 'network-request-failed') {
        setState(() => _error = "Ralat Rangkaian: Sila periksa sambungan internet anda.");
      } else {
        setState(() => _error = e.message);
      }
    } 
    // Tangkap sebarang ralat lain, termasuk ralat Firestore (Permission Denied)
    catch (e) {
      String errorMessage = "Ralat Data/Rangkaian: Gagal memuatkan profil. Sila semak semula sambungan dan Peraturan Keselamatan Firestore.";

      if (e.toString().contains('permission-denied')) {
        errorMessage = "Akses Ditolak: Anda berjaya log masuk, tetapi Peraturan Keselamatan Firestore menghalang akses data. (Sila semak Peraturan)";
      }

      print('Ralat Firestore/Lain-lain yang tidak dijangka: $e');
      setState(() => _error = errorMessage);
    } 
    finally {
      if (mounted) {
          setState(() => _loading = false);
      }
    }
  }

  void _showRegisterDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Akaun Tidak Dijumpai"),
        content: const Text(
            "Email ini belum didaftarkan. Adakah anda ingin mendaftar akaun baru?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterPage()),
              );
            },
            child: const Text("Daftar"),
          ),
        ],
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _loading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      await _checkCaregiverProfile();
    } catch (e) {
      // Pastikan ralat Google juga dikendalikan dengan baik
      setState(() {
        _error = 'Gagal log masuk melalui Google: Sila cuba kaedah lain.';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  // --- WIDGET MEMBINA (Diperkemas) ---

  Widget _buildLogo() {
    return Column(
      children: [
        // Sediakan fail logo.png dalam folder assets/images/
        Image.asset( 
          'assets/images/logo.png',
          width: 180,
          height: 130,
        ),
        const SizedBox(height: 1),
        const Text(
          'Selamat datang !',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: primaryTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String hintText, IconData icon, bool isPassword) {
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
      child: TextField(
        controller: controller,
        obscureText: isPassword && !_passwordVisible,
        style: const TextStyle(color: secondaryTextColor),
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
              // PEMBETULAN: Keluarkan ikon tanda semak statik
              : null, 
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return GestureDetector(
      onTap: _signInWithGoogle,
      child: Container(
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
        child: const Center(
          child: Icon(Icons.g_mobiledata, color: Colors.red, size: 30),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ketinggian Skrin Penuh (Termasuk kawasan SafeArea)
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      // resizeToAvoidBottomInset mengendalikan keyboard
      resizeToAvoidBottomInset: true, 
      body: Container(
        // FULL HEIGHT: Memastikan latar belakang mengambil keseluruhan ruang skrin
        height: screenHeight, 
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [backgroundStart, Color.fromARGB(255, 60, 20, 140)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - MediaQuery.of(context).viewInsets.bottom,
                      maxWidth: 450, // Hadkan lebar maksimum borang pada peranti besar
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
                      child: IntrinsicHeight(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center, 
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildLogo(),
                            const SizedBox(height: 20),

                            _buildTextField(_emailController, 'Emel', Icons.person_outline, false),
                            const SizedBox(height: 20),
                            _buildTextField(_passwordController, 'Kata Laluan', Icons.lock_outline, true),
                            const SizedBox(height: 10),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _rememberMe,
                                      onChanged: (bool? newValue) {
                                        setState(() {
                                          _rememberMe = newValue!;
                                        });
                                      },
                                      activeColor: backgroundStart,
                                      checkColor: primaryTextColor,
                                    ),
                                    const Text(
                                      'Ingat saya',
                                      style: TextStyle(color: primaryTextColor, fontSize: 13),
                                    ),
                                  ],
                                ),
                                TextButton(
                                  onPressed: () {},
                                  child: const Text(
                                    'Lupa kata laluan?',
                                    style: TextStyle(color: primaryTextColor, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 27),

                            Container(
                              height: 55,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                gradient: const LinearGradient(
                                  colors: [Color.fromARGB(255, 157, 0, 255), buttonGradientEnd],
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
                                  onTap: _loading ? null : _login,
                                  borderRadius: BorderRadius.circular(30),
                                  child: Center(
                                    child: _loading
                                        ? const CircularProgressIndicator(color: Colors.white)
                                        : const Text(
                                            'Log Masuk',
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
                                  "Pengguna baru? ",
                                  style: TextStyle(color: primaryTextColor),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const RegisterPage()),
                                    );
                                  },
                                  child: const Text(
                                    "Daftar akaun",
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

                            const Text(
                              'Atau',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: primaryTextColor, fontSize: 13),
                            ),
                            const SizedBox(height: 20),

                            // Google Sign-In
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildGoogleIcon(),
                              ],
                            ),

                            const SizedBox(height: 20),
                            const Text(
                              'Daftar melalui Gmail',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: primaryTextColor, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}