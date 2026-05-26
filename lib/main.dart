import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
//import 'package:mescla_invest/screens/authentication/password_recovery_screen.dart';
import 'package:mescla_invest/screens/initial/splash_screen.dart';

import 'firebase_options.dart';
//import 'screens/home/home_screen.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('pt_BR', null);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  _configureLocalEmulators();

  if (kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      providerWeb: ReCaptchaV3Provider('recaptcha-chave-teste'),
    );
  } else {
    await FirebaseAppCheck.instance.activate();
  }

  runApp(const MyApp());
}

void _configureLocalEmulators() {
  if (kReleaseMode) return;

  final host = switch (defaultTargetPlatform) {
    TargetPlatform.android => '10.0.2.2',
    _ => '127.0.0.1',
  };

  FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}
