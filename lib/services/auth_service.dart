<<<<<<< HEAD
import 'package:cloud_firestore/cloud_firestore.dart';
=======
import 'dart:async';
>>>>>>> 16d285de933d85594cbc18736b2b49adf2dbbf7f
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'two_factor_auth_service.dart';
import '../models/two_factor_auth_settings.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
<<<<<<< HEAD
  final FirebaseFirestore _firestore;
=======
  final TwoFactorAuthService _twoFactorService = TwoFactorAuthService();
>>>>>>> 16d285de933d85594cbc18736b2b49adf2dbbf7f

  /// Login padrão
  Future<UserCredential> login({
    required String email,
    required String senha,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: senha,
    );
  }

  /// Registrar novo usuário
  Future<UserCredential> register({
    required String email,
    required String senha,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: senha,
    );
  }

  /// Verificar se o usuário tem 2FA ativado (via Firestore)
  Future<bool> isMultiFactorEnabled(User user) async {
    try {
      final settings = await _twoFactorService.getTwoFactorSettings(user.uid);
      return settings?.isEnabled ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Obter número de telefone para 2FA
  Future<String?> getPhoneForMFA(User user) async {
    try {
      final settings = await _twoFactorService.getTwoFactorSettings(user.uid);
      return settings?.phoneNumber;
    } catch (e) {
      return null;
    }
  }

  /// Enviar código de verificação por SMS para 2FA
  Future<String> sendMFACode({
    required String phoneNumber,
  }) async {
    final completer = Completer<String>();

    try {
      debugPrint('[AuthService] Iniciando verifyPhoneNumber para: $phoneNumber');
      _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (_) {
          debugPrint('[AuthService] verificationCompleted - auto-verification');
          if (!completer.isCompleted) {
            completer.completeError(FirebaseAuthException(
              code: 'auto-verification',
              message: 'Verificação automática concluída. Aguarde o código.',
            ));
          }
        },
        verificationFailed: (FirebaseAuthException error) {
          debugPrint('[AuthService] verificationFailed: ${error.code} - ${error.message}');
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('[AuthService] codeSent com verificationId: $verificationId');
          if (!completer.isCompleted) {
            completer.complete(verificationId);
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('[AuthService] codeAutoRetrievalTimeout');
          if (!completer.isCompleted) {
            completer.complete(verificationId);
          }
        },
      );

      return completer.future;
    } on FirebaseAuthException {
      debugPrint('[AuthService] FirebaseAuthException em sendMFACode');
      rethrow;
    } catch (e) {
      debugPrint('[AuthService] Erro genérico em sendMFACode: ${e.toString()}');
      if (!completer.isCompleted) {
        completer.completeError(FirebaseAuthException(
          code: 'sms-error',
          message: 'Erro ao enviar SMS: ${e.toString()}',
        ));
      }
      return completer.future;
    }
  }

  /// Verificar código OTP durante 2FA
  Future<UserCredential> verifyMFACode({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-signed-in',
        message: 'Usuário precisa estar autenticado para verificar o código.',
      );
    }

    return await user.reauthenticateWithCredential(credential);
  }

  /// Iniciar inscrição de 2FA - enviar código por SMS
  Future<String> enrollPhoneForMFA({
    required String phoneNumber,
  }) {
    return sendMFACode(phoneNumber: phoneNumber);
  }

  /// Completar inscrição de 2FA com código OTP
  Future<void> completePhoneMfaEnrollment({
    required String verificationId,
    required String smsCode,
    required String phoneNumber,
  }) async {
    final user = _auth.currentUser;
    debugPrint('[AuthService] completePhoneMfaEnrollment - user: ${user?.uid}');
    
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-signed-in',
        message: 'Usuário precisa estar autenticado para concluir a inscrição.',
      );
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    try {
      debugPrint('[AuthService] Linkando credencial de telefone...');
      await user.linkWithCredential(credential);
      debugPrint('[AuthService] Credencial linkada com sucesso');
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] FirebaseAuthException ao linkar: ${e.code} - ${e.message}');
      if (e.code != 'provider-already-linked') {
        rethrow;
      }
    }

    try {
      debugPrint('[AuthService] Salvando configurações de 2FA...');
      final settings = TwoFactorAuthSettings(
        userId: user.uid,
        isEnabled: true,
        phoneNumber: phoneNumber,
      );
      await _twoFactorService.saveTwoFactorSettings(settings);
      debugPrint('[AuthService] Configurações de 2FA salvas com sucesso');
    } catch (e) {
      debugPrint('[AuthService] Erro ao salvar configurações de 2FA: ${e.toString()}');
      rethrow;
    }
  }

  /// Remover 2FA desativando a flag de 2FA
  Future<void> removeMultiFactorAuth() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final settings = TwoFactorAuthSettings(
          userId: user.uid,
          isEnabled: false,
          phoneNumber: null,
        );
        await _twoFactorService.saveTwoFactorSettings(settings);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Verificar telefone durante login com 2FA
  /// Retorna true se o código for válido
  Future<bool> verifyPhoneForLogin({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      await verifyMFACode(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return true;
    } on FirebaseAuthException {
      return false;
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() {
    return _auth.signOut();
  }

  Future<String?> getUserFullName(String uid) async {
    final snapshot = await _firestore.collection('usuarios').doc(uid).get();
    final data = snapshot.data();
    final value = data?['fullName'] as String?;

    if (value == null) return null;

    final fullName = value.trim();
    return fullName.isEmpty ? null : fullName;
  }

  String? formatDisplayName(String? fullName) {
    if (fullName == null) return null;

    final partes = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((parte) => parte.isNotEmpty)
        .toList();

    if (partes.isEmpty) return null;
    if (partes.length == 1) return partes.first;
    if (partes.length == 2) return '${partes[0]} ${partes[1]}';

    final primeiroNome = partes.first;
    final segundoNome = partes[1];
    final ultimoNome = partes.last;

    if (segundoNome.length > 2) {
      return '$primeiroNome $segundoNome';
    }

    if (ultimoNome.length > 2) {
      return '$primeiroNome $ultimoNome';
    }

    final restantesAbreviados = partes
        .skip(1)
        .map((parte) => '${parte[0].toUpperCase()}.')
        .join(' ');

    return '$primeiroNome $restantesAbreviados';
  }

  Future<String?> getUserDisplayName(String uid) async {
    final fullName = await getUserFullName(uid);
    return formatDisplayName(fullName);
  }

  User? get currentUser => _auth.currentUser;
}
