//Pedro Andre do Carmo Chavier -25018639

//Banco e functions do firebase
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart'; //autenticação dos usuarios via Firebase

import 'package:flutter/foundation.dart'; //utilitarios do flutter, como debugPrint
import '../models/wallet_transaction.dart';
import '../models/user_profile.dart';

//Serviço central de autenticaçãi e perfil do usuario
class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  //Aponta para a região de Sao Paulo
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'southamerica-east1',
  );

  //Monta um Map para um novo perfil
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

  Future<void> sendPasswordResetEmail({required String email}) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() {
    return _auth.signOut();
  }

  //Buscao o nome completo do usuario
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
      rethrow; //Relança a mesma exceção recebida 

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
        partes.skip(1).map((parte) => '${parte[0].toUpperCase()}.').join(' '); //skip(1) ignora o primeiro elemento

    return '$primeiroNome $restantesAbreviados';
  }

  Future<String?> getUserDisplayName(String uid) async {
    final fullName = await getUserFullName(uid);
    return formatDisplayName(fullName);
  }

  //Busca o perfil completo do usuario
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
      rethrow; //Relança a exceção
    }
  }

  //Atalho para buscar o perfil do usuario atualmente autenticado
  Future<UserProfile?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return getUserProfile(user.uid);
  }

  //Escuta as mudanças do usuario em tempo real
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

    try {
      final callable = _functions.httpsCallable('atualizarMfaStatus');
      await callable.call({'habilitado': enabled});
    } on FirebaseFunctionsException catch (error, stackTrace) {
      debugPrint(
        '[AuthService] updateCurrentUserMfaStatus error: '
        'code=${error.code}, message=${error.message}',
      );
      debugPrintStack(stackTrace: stackTrace);

      if (error.code == 'not-found' ||
          error.code == 'unimplemented' ||
          error.code == 'internal') {
        throw Exception(
          'A funcao "atualizarMfaStatus" nao esta disponivel no Firebase. '
          'Publique as Cloud Functions (firebase deploy --only functions) e tente novamente.',
        );
      }

      // Repassa a mensagem original (ex.: resource-exhausted = rate limit,
      // unauthenticated, invalid-argument) para facilitar o diagnostico.
      throw Exception(
        error.message ?? 'Nao foi possivel atualizar a autenticacao 2FA.',
      );
    }
  }

  //Adiciona saldo simulado via Cloud Function
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

  //Escuta as transaões do usuario em tempo real
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

      //Ordenando da mais nova para a mais antiga
      transacoes.sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });
      return transacoes;
    });
  }

  // Busca as transações do usuario e ordena das mais recentes para as mais antigas
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

    transacoes.sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });
    return transacoes;
  }

  //Garante que o usuario autenticado tenha um perfil no Firestore
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

  //Verifica se a conta do usuario atual esta ativa
  Future<bool> isCurrentUserActive() async {
    final profile = await getCurrentUserProfile();
    return profile?.userActive ?? false;
  }

  //Expõe o usuario atualmente atenticado
  User? get currentUser => _auth.currentUser;
}
