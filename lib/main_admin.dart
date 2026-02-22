import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/admin/admin_home.dart';
import 'screens/admin/admin_login.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    try {
      await dotenv.load(fileName: "assets/.env");
    } catch (_) {
      // ignore and continue
      // ignore: avoid_print
      print('dotenv load failed for admin: $e');
    }
  }
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const AdminWebApp());
}

class AdminWebApp extends StatelessWidget {
  const AdminWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MamiCare+ Admin',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const EntryPoint(),
    );
  }
}

/// Decide whether to show login or dashboard
class EntryPoint extends StatelessWidget {
  const EntryPoint({super.key});

  @override
  Widget build(BuildContext context) {
    // Cek jika admin sudah login
    User? user = FirebaseAuth.instance.currentUser;
    const adminUID = "YmMzPJ24Y2XDth6SGCJJ9wfEdxE2";

    if (user != null && user.uid == adminUID) {
      return const AdminHomePage();
    } else {
      return const AdminLoginPage();
    }
  }
}
