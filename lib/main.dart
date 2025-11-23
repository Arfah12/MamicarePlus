import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mamicare_plus2/firebase_options.dart';
import 'package:mamicare_plus2/services/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;

// Screens
import 'screens/login_page.dart';
import 'screens/register_page.dart';
import 'screens/admin/admin_home.dart';
import 'screens/caregiver/caregiver_home.dart';
import 'screens/caregiver/create_profile.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init timezone
  tz.initializeTimeZones();

  // Init notifications
  await NotificationService.init();

  // Android 13+ notification permission
  if (Platform.isAndroid) {
    final androidPlugin =
        NotificationService.instance.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  // Init Firebase (safe check, prevents double init)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // OPTIONAL: Disable App Check warnings
  // (since you are not using Firebase App Check)
  FirebaseAuth.instance.setLanguageCode('en');

  runApp(const MamiCarePlusApp());
}

class MamiCarePlusApp extends StatelessWidget {
  const MamiCarePlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MamiCare+',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.pink),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/create_profile': (context) => const CreateProfilePage(),
        '/caregiver_home': (context) => const CaregiverHomePage(),
      },
    );
  }
}

//
// AUTH WRAPPER
//
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<bool> hasBabyProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final babiesSnap = await FirebaseFirestore.instance
        .collection('caregivers')
        .doc(user.uid)
        .collection('babies')
        .limit(1)
        .get();

    return babiesSnap.docs.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Not logged in → login page
        if (!snapshot.hasData) return const LoginPage();

        final user = snapshot.data!;

        // Admin login
        if (user.email != null &&
            user.email!.toLowerCase() == 'arfah@gmail.com') {
          return const AdminHomePage();
        }

        // Caregiver flow
        return FutureBuilder<bool>(
          future: hasBabyProfile(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (snap.data == true) {
              return const CaregiverHomePage();
            }

            return const CreateProfilePage();
          },
        );
      },
    );
  }
}
