import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/two_factor_auth_settings.dart';

class TwoFactorAuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collectionName = '2fa_settings';

  /// Salvar configurações de 2FA no Firestore
  Future<void> saveTwoFactorSettings(
    TwoFactorAuthSettings settings,
  ) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(settings.userId)
          .set(settings.toJson());
    } catch (e) {
      throw Exception('Erro ao salvar configurações 2FA: $e');
    }
  }

  /// Obter configurações de 2FA do usuário
  Future<TwoFactorAuthSettings?> getTwoFactorSettings(
    String userId,
  ) async {
    try {
      final doc = await _firestore
          .collection(_collectionName)
          .doc(userId)
          .get();

      if (doc.exists && doc.data() != null) {
        return TwoFactorAuthSettings.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Erro ao obter configurações 2FA: $e');
    }
  }

  /// Verificar se o usuário tem 2FA ativado
  Future<bool> isUserTwoFactorEnabled(String userId) async {
    try {
      final settings = await getTwoFactorSettings(userId);
      return settings?.isActive ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Atualizar status de 2FA
  Future<void> updateTwoFactorStatus(
    String userId,
    bool isEnabled,
  ) async {
    try {
      final settings = await getTwoFactorSettings(userId);
      if (settings != null) {
        await saveTwoFactorSettings(
          settings.copyWith(isEnabled: isEnabled),
        );
      }
    } catch (e) {
      throw Exception('Erro ao atualizar status 2FA: $e');
    }
  }

  /// Atualizar número de telefone
  Future<void> updatePhoneNumber(
    String userId,
    String phoneNumber,
  ) async {
    try {
      var settings = await getTwoFactorSettings(userId);
      
      if (settings == null) {
        settings = TwoFactorAuthSettings(
          userId: userId,
          phoneNumber: phoneNumber,
          isEnabled: true,
          enrolledAt: DateTime.now(),
        );
      } else {
        settings = settings.copyWith(
          phoneNumber: phoneNumber,
          isEnabled: true,
          enrolledAt: DateTime.now(),
        );
      }

      await saveTwoFactorSettings(settings);
    } catch (e) {
      throw Exception('Erro ao atualizar telefone 2FA: $e');
    }
  }

  /// Remover 2FA (desativar)
  Future<void> removeTwoFactorAuth(String userId) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(userId)
          .delete();
    } catch (e) {
      throw Exception('Erro ao remover 2FA: $e');
    }
  }

  /// Gerar códigos de backup (para uso futuro)
  List<String> generateBackupCodes({int count = 10}) {
    final codes = <String>[];
    final random = DateTime.now().millisecondsSinceEpoch;
    
    for (int i = 0; i < count; i++) {
      final code = '${random + i}'.substring(0, 8);
      codes.add(code);
    }
    
    return codes;
  }

  /// Salvar códigos de backup
  Future<void> saveBackupCodes(
    String userId,
    List<String> backupCodes,
  ) async {
    try {
      var settings = await getTwoFactorSettings(userId);
      
      if (settings == null) {
        settings = TwoFactorAuthSettings(
          userId: userId,
          backupCodes: backupCodes,
        );
      } else {
        settings = settings.copyWith(backupCodes: backupCodes);
      }

      await saveTwoFactorSettings(settings);
    } catch (e) {
      throw Exception('Erro ao salvar códigos de backup: $e');
    }
  }

  /// Registrar última verificação bem-sucedida
  Future<void> recordLastVerification(String userId) async {
    try {
      var settings = await getTwoFactorSettings(userId);
      
      if (settings != null) {
        final updated = settings.copyWith(
          lastVerificationDate: DateTime.now().toIso8601String(),
        );
        await saveTwoFactorSettings(updated);
      }
    } catch (e) {
      throw Exception('Erro ao registrar verificação: $e');
    }
  }

  /// Stream para monitorar mudanças nas configurações 2FA
  Stream<TwoFactorAuthSettings?> getTwoFactorSettingsStream(String userId) {
    return _firestore
        .collection(_collectionName)
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return TwoFactorAuthSettings.fromJson(doc.data()!);
      }
      return null;
    });
  }

  /// Obter número de telefone para MFA
  Future<String?> getPhoneNumberForMFA(String userId) async {
    try {
      final settings = await getTwoFactorSettings(userId);
      return settings?.phoneNumber;
    } catch (e) {
      return null;
    }
  }
}
