//Pedro Andre do Carmo Chavier -25018639

import 'package:cloud_functions/cloud_functions.dart'; //Acesso as claude functions
import 'package:firebase_app_check/firebase_app_check.dart'; //proteções contra requisições nao autorizadas
import 'package:firebase_core/firebase_core.dart';//inicialização do firebase

import 'package:flutter/foundation.dart'; // kIsWeb, kReleaseMode, defaultTargetPlatform
import 'package:flutter/material.dart'; 

import 'package:intl/date_symbol_data_local.dart'; // Formatação de datas
import 'package:mescla_invest/screens/initial/splash_screen.dart'; 

import 'firebase_options.dart'; // configurações geradas automaticamente pelo Flutter fire

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); //Prepara o flutter

  // Inicializa os dados de localização, para formatar datas em pt 
  await initializeDateFormatting('pt_BR', null); 

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, //configuraçoes da plataforma atual (android/ios/web)
  );

  _configureLocalEmulators(); //conecta ao emulador local

  //App Check: bloqueia requisições de apps não autorizados
  if (kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      providerWeb: ReCaptchaV3Provider('recaptcha-chave-teste'),
    );
  } else {
    await FirebaseAppCheck.instance.activate();
  }

  runApp(const MyApp());
}


//redireciona as chamadas das cloud functions para o emulador local
void _configureLocalEmulators() {
  if (kReleaseMode) return; //em produção, nao faz nada

  // Android emulador não acessa localhost — usa 10.0.2.2 (aponta para a máquina host)
  final host = switch (defaultTargetPlatform) {
    TargetPlatform.android => '10.0.2.2',
    _ => '127.0.0.1',
  };

  FirebaseFunctions.instance.useFunctionsEmulator(host, 5001); //porta padrao do emulador
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
