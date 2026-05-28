import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/wallet_transaction.dart';
import '../models/user_profile.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'southamerica-east1',
  );

  Map<String, dynamic> _buildDefaultUserProfilePayload(User user) {
    final fallbackName = user.displayName?.trim() ?? '';
    final fallbackEmail = user.email?.trim().toLowerCase() ?? '';

    return <String, dynamic>{
      'uid': user.uid,
      'fullName': fallbackName,
      'email': fallbackEmail,
      'telefone': '',
      'cpf': '',
      'role': 'user',
      'isAdmin': false,
      'mfaHabilitado': false,
      'userActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

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

  /// Enviar código de verificação por SMS para 2FA
  Future<String> sendMFACode({
    required String phoneNumber,
  }) async {
    final completer = Completer<String>();

    try {
      debugPrint(
          '[AuthService] Iniciando verifyPhoneNumber para: $phoneNumber');
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
          debugPrint(
              '[AuthService] verificationFailed: ${error.code} - ${error.message}');
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint(
              '[AuthService] codeSent com verificationId: $verificationId');
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

  /// Verificar código OTP durante 2FA (Reautenticação)
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

  /// Retorna se o usuário já possui Multi-Factor habilitado.
  Future<bool> isMultiFactorEnabled(User user) async {
    final factors = await user.multiFactor.getEnrolledFactors();
    return factors.isNotEmpty;
  }

  Future<void> sendPasswordResetEmail({required String email}) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() {
    return _auth.signOut();
  }

  Future<String?> getUserFullName(String uid) async {
    try {
      final snapshot = await _firestore.collection('usuarios').doc(uid).get();
      final data = snapshot.data();
      final value = data?['fullName'] as String?;

      if (value == null) return null;

      final fullName = value.trim();
      return fullName.isEmpty ? null : fullName;
    } on FirebaseException catch (e) {
      debugPrint('[AuthService] getUserFullName permission error: '
          'code=${e.code}, message=${e.message}');
      rethrow;
    }
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

    final restantesAbreviados =
        partes.skip(1).map((parte) => '${parte[0].toUpperCase()}.').join(' ');

    return '$primeiroNome $restantesAbreviados';
  }

  Future<String?> getUserDisplayName(String uid) async {
    final fullName = await getUserFullName(uid);
    return formatDisplayName(fullName);
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final snapshot = await _firestore.collection('usuarios').doc(uid).get();
      final data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return null;
      }

      return UserProfile.fromMap(uid, data);
    } on FirebaseException catch (e) {
      debugPrint(
        '[AuthService] getUserProfile error: code=${e.code}, message=${e.message}',
      );
      rethrow;
    }
  }

  Future<UserProfile?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return getUserProfile(user.uid);
  }

  Stream<UserProfile?> streamCurrentUserProfile() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(null);
    }

    return _firestore
        .collection('usuarios')
        .doc(user.uid)
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return null;
      }

      return UserProfile.fromMap(user.uid, data);
    });
  }

  Future<void> updateCurrentUserMfaStatus(bool enabled) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Usuario nao autenticado.',
      );
    }

    final docRef = _firestore.collection('usuarios').doc(user.uid);

    try {
      final snapshot = await docRef.get();
      final payload = <String, dynamic>{
        'mfaHabilitado': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (snapshot.exists) {
        await docRef.update(payload);
      } else {
        await docRef.set(
          {
            ..._buildDefaultUserProfilePayload(user),
            ...payload,
          },
          SetOptions(merge: true),
        );
      }
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        '[AuthService] updateCurrentUserMfaStatus error: '
        'code=${error.code}, message=${error.message}',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> creditCurrentUserSaldo(double valor) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Usuario nao autenticado.',
      );
    }

    if (valor <= 0) {
      throw ArgumentError.value(
          valor, 'valor', 'O valor deve ser maior que zero.');
    }

    try {
      final callable = _functions.httpsCallable('creditarSaldoSimulado');
      await callable.call(<String, dynamic>{
        'valor': valor,
      });
    } on FirebaseFunctionsException catch (error) {
      debugPrint(
        '[AuthService] creditCurrentUserSaldo function error: '
        'code=${error.code}, message=${error.message}',
      );

      if (error.code == 'not-found' ||
          error.code == 'unimplemented' ||
          error.code == 'internal') {
        throw Exception(
          'A funcao de credito ainda nao esta disponivel no Firebase. '
          'Publique as Cloud Functions e tente novamente.',
        );
      }

      throw Exception(error.message ?? 'Nao foi possivel creditar o saldo.');
    }
  }

  Stream<List<WalletTransaction>> streamCurrentUserTransactions() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(const []);
    }

    return _firestore
        .collection('usuarios')
        .doc(user.uid)
        .collection('transacoes')
        .snapshots()
        .map((snapshot) {
      final transacoes = snapshot.docs
          .map((doc) => WalletTransaction.fromFirestore(doc.id, doc.data()))
          .toList();

      transacoes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return transacoes;
    });
  }

  Future<List<WalletTransaction>> getCurrentUserTransactions() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const [];
    }

    final snapshot = await _firestore
        .collection('usuarios')
        .doc(user.uid)
        .collection('transacoes')
        .get();

    final transacoes = snapshot.docs
        .map((doc) => WalletTransaction.fromFirestore(doc.id, doc.data()))
        .toList();

    transacoes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return transacoes;
  }

  Future<UserProfile> ensureCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Usuario nao autenticado.',
      );
    }

    final existingProfile = await getUserProfile(user.uid);
    if (existingProfile != null) {
      return existingProfile;
    }

    final payload = _buildDefaultUserProfilePayload(user);

    await _firestore.collection('usuarios').doc(user.uid).set(payload);

    return UserProfile.fromMap(user.uid, payload);
  }

  Future<bool> isCurrentUserActive() async {
    final profile = await getCurrentUserProfile();
    return profile?.userActive ?? false;
  }

  User? get currentUser => _auth.currentUser;
}
