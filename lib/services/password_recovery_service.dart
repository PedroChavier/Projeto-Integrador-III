//Giovana Uchelli - 25008818
import 'package:firebase_auth/firebase_auth.dart'; //Autenticação de usuarios via Firebase

//Serviço responsavel pelo envio do email de recuperação de senha
class PasswordRecoveryService {

  PasswordRecoveryService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  //Envia o email de redefinição de senha
  Future<void> sendPasswordResetEmail({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
  }
}