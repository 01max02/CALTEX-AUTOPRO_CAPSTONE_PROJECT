import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'firebase_options.dart';
import 'login.dart';
import 'welcome_screen.dart';
import 'staff_dashboard.dart';
import 'background_dss.dart';

// ── Workmanager task name ──
const _kDSSTaskName   = 'dss_background_check';
const _kDSSTaskUnique = 'dss_periodic';

/// Top-level callback required by workmanager.
/// Runs in a separate isolate — must be a top-level function.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == _kDSSTaskName) {
      return runBackgroundDSSCheck();
    }
    return true;
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ── OneSignal: initialize and request permission (skip on web for now) ──
  if (!kIsWeb) {
    OneSignal.initialize('c4f82ac7-5340-4e7a-877d-1d38a6f6f8ea');
    await OneSignal.Notifications.requestPermission(true);

    // If user is already logged in (app restart), re-link UID with OneSignal
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      OneSignal.login(user.uid);
      debugPrint('✅ OneSignal auto-login with UID: ${user.uid}');
      // Save subscription ID after a short delay to let OneSignal register
      Future.delayed(const Duration(seconds: 3), () async {
        try {
          final subId = OneSignal.User.pushSubscription.id;
          if (subId != null && subId.isNotEmpty) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({'oneSignalId': subId});
            debugPrint('✅ OneSignal subscription ID saved on restart: $subId');
          }
        } catch (e) {
          debugPrint('⚠️ Could not save OneSignal ID on restart: $e');
        }
      });
    }

    // ── Workmanager: register background DSS check (mobile only) ──
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
    await Workmanager().registerPeriodicTask(
      _kDSSTaskUnique,
      _kDSSTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
    debugPrint('✅ Background DSS task registered (every 15 min)');
  } else {
    debugPrint('ℹ️ Running on web — OneSignal and Workmanager disabled');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JA Noble',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE8001C)),
        fontFamily: 'Roboto',
      ),
      home: const WelcomeScreen(),
      routes: {
        '/welcome': (_) => const WelcomeScreen(),
        '/login': (_) => const LoginScreen(),
        '/staff': (_) => const StaffDashboard(),
      },
    );
  }
}
