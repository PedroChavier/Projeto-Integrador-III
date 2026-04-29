import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'screens/initial/splash_screen.dart';
//import 'screens/authentication/reset_password_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

await FirebaseAppCheck.instance.activate(
  webProvider: ReCaptchaV3Provider('recaptcha-chave-teste'),
);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
      // home: const RedefinirNovaSenhaScreen(
      //   email: "p.chvr.commerce2208@gmail.com",
      //   code: "123456",
      // ),
    );
  }
}