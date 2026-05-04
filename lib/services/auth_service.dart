import 'package:firebase_auth/firebase_auth.dart';
import 'two_factor_auth_service.dart';
import '../models/two_factor_auth_settings.dart';

class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  final TwoFactorAuthService _twoFactorService = TwoFactorAuthService();

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
  Future<void> sendMFACode({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(FirebaseAuthException) onError,
  }) async {
    try {
      final confirmationResult = await _auth.signInWithPhoneNumber(phoneNumber);
      // Armazenar o verificationId para uso posterior
      onCodeSent(confirmationResult.verificationId);
    } on FirebaseAuthException catch (e) {
      onError(e);
    } catch (e) {
      onError(FirebaseAuthException(
        code: 'sms-error',
        message: 'Erro ao enviar SMS: ${e.toString()}',
      ));
    }
  }

  /// Verificar código OTP durante 2FA
  Future<UserCredential> verifyMFACode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      rethrow;
    }
  }

  /// Iniciar inscrição de 2FA - enviar código por SMS
  Future<void> enrollPhoneForMFA({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(FirebaseAuthException) onError,
  }) async {
    try {
      await sendMFACode(
        phoneNumber: phoneNumber,
        onCodeSent: onCodeSent,
        onError: onError,
      );
    } catch (e) {
      if (e is FirebaseAuthException) {
        onError(e);
      }
    }
  }

  /// Completar inscrição de 2FA com código OTP
  Future<void> completePhoneMfaEnrollment({
    required String verificationId,
    required String smsCode,
    required String phoneNumber,
  }) async {
    try {
      // Verificar o código OTP
      await verifyMFACode(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      // Salvar configurações de 2FA no Firestore
      final user = _auth.currentUser;
      if (user != null) {
        final settings = TwoFactorAuthSettings(
          userId: user.uid,
          isEnabled: true,
          phoneNumber: phoneNumber,
        );
        await _twoFactorService.saveTwoFactorSettings(settings);
      }
    } catch (e) {
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
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      // Se chegar aqui, o código é válido
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() {
    return _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
}
