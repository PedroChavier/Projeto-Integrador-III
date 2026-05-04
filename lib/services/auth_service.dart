import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// Login padrão sem 2FA
  Future<UserCredential> login({
    required String email,
    required String senha,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: senha,
    );
  }

  /// Login com 2FA - primeira etapa (verificar email e senha)
  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String senha,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: senha,
    );
  }

  /// Verificar se o usuário tem 2FA ativado
  bool isMultiFactorEnabled(User user) {
    return user.multiFactor.enrolledFactors.isNotEmpty;
  }

  /// Obter lista de fatores inscritos do usuário
  List<MultiFactor> getEnrolledFactors(User user) {
    return user.multiFactor.enrolledFactors;
  }

  /// Iniciar verificação por telefone (2FA via SMS)
  Future<String> verifyPhoneNumberForMFA({
    required User user,
    required String phoneNumber,
    required Function(PhoneAuthCredential) onCodeSent,
    required Function(FirebaseAuthException) onError,
  }) async {
    String? verificationId;

    try {
      await user.multiFactor.getSession().then((session) async {
        await _auth.verifyPhoneNumber(
          phoneNumber: phoneNumber,
          timeout: const Duration(minutes: 2),
          verificationCompleted: (PhoneAuthCredential credential) async {
            // Auto-resolução (Android apenas, geralmente)
            await user.multiFactor.enrollPhoneMfa(
              multiFactorSession: session,
              phoneMultiFactorInfo: PhoneMultiFactorInfo.from(credential),
            );
          },
          verificationFailed: (FirebaseAuthException e) {
            onError(e);
          },
          codeSent: (String verificationId, int? resendToken) {
            onCodeSent(PhoneAuthCredential(
              verificationId: verificationId,
              smsCode: '',
              providerId: 'phone',
            ));
          },
          codeAutoRetrievalTimeout: (String verificationId) {},
        );
      });
    } catch (e) {
      rethrow;
    }

    return verificationId ?? '';
  }

  /// Completar inscrição de telefone para 2FA
  Future<void> completePhoneMfaEnrollment({
    required User user,
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final session = await user.multiFactor.getSession();

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final phoneMultiFactorInfo = PhoneMultiFactorInfo.from(credential);

      await user.multiFactor.enroll(
        multiFactorInfo: phoneMultiFactorInfo,
        multiFactorSession: session,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Verificar 2FA durante login
  Future<UserCredential> verifyAndSignInWithMFA({
    required String verificationId,
    required String smsCode,
    required MultiFactorResolver resolver,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      return await resolver.resolveSignIn(
        multiFactorAssertion: PhoneMultiFactorAssertion(credential),
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Enviar código de verificação para resolver MFA durante login
  Future<void> sendMFACode({
    required MultiFactorResolver resolver,
    required int factorIndex,
    required Function(String) onCodeSent,
  }) async {
    try {
      final session = resolver.session;
      final factor = resolver.hints[factorIndex] as PhoneMultiFactorInfo;

      await _auth.verifyPhoneNumber(
        phoneNumber: factor.phoneNumber ?? '',
        timeout: const Duration(minutes: 2),
        verificationCompleted: (PhoneAuthCredential credential) {},
        verificationFailed: (FirebaseAuthException e) {
          throw e;
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
        multiFactorSession: session,
        multiFactorInfo: factor,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Remover fator de autenticação (desativar 2FA)
  Future<void> removeMultiFactorAuth({
    required User user,
    required int factorIndex,
  }) async {
    try {
      final enrolledFactors = user.multiFactor.enrolledFactors;
      if (factorIndex < enrolledFactors.length) {
        await user.multiFactor.unenroll(
          factorIndex: factorIndex,
        );
      }
    } catch (e) {
      rethrow;
    }
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

  User? get currentUser => _auth.currentUser;
}
