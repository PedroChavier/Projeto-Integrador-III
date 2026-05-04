/// Modelo para gerenciar configurações de autenticação de dois fatores
class TwoFactorAuthSettings {
  final String userId;
  final bool isEnabled;
  final String? phoneNumber;
  final DateTime? enrolledAt;
  final List<String> backupCodes;
  final String? lastVerificationDate;

  TwoFactorAuthSettings({
    required this.userId,
    this.isEnabled = false,
    this.phoneNumber,
    this.enrolledAt,
    this.backupCodes = const [],
    this.lastVerificationDate,
  });

  /// Criar a partir de JSON (do Firestore)
  factory TwoFactorAuthSettings.fromJson(Map<String, dynamic> json) {
    return TwoFactorAuthSettings(
      userId: json['userId'] ?? '',
      isEnabled: json['isEnabled'] ?? false,
      phoneNumber: json['phoneNumber'],
      enrolledAt: json['enrolledAt'] != null
          ? DateTime.parse(json['enrolledAt'])
          : null,
      backupCodes: List<String>.from(json['backupCodes'] ?? []),
      lastVerificationDate: json['lastVerificationDate'],
    );
  }

  /// Converter para JSON (para Firestore)
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'isEnabled': isEnabled,
      'phoneNumber': phoneNumber,
      'enrolledAt': enrolledAt?.toIso8601String(),
      'backupCodes': backupCodes,
      'lastVerificationDate': lastVerificationDate,
    };
  }

  /// Copiar com novas propriedades
  TwoFactorAuthSettings copyWith({
    String? userId,
    bool? isEnabled,
    String? phoneNumber,
    DateTime? enrolledAt,
    List<String>? backupCodes,
    String? lastVerificationDate,
  }) {
    return TwoFactorAuthSettings(
      userId: userId ?? this.userId,
      isEnabled: isEnabled ?? this.isEnabled,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      enrolledAt: enrolledAt ?? this.enrolledAt,
      backupCodes: backupCodes ?? this.backupCodes,
      lastVerificationDate: lastVerificationDate ?? this.lastVerificationDate,
    );
  }

  /// Verificar se 2FA está ativo e válido
  bool get isActive => isEnabled && phoneNumber != null;

  /// Obter dias desde a inscrição
  int? get daysSinceEnrollment {
    if (enrolledAt == null) return null;
    return DateTime.now().difference(enrolledAt!).inDays;
  }

  @override
  String toString() =>
      'TwoFactorAuthSettings(userId: $userId, isEnabled: $isEnabled, '
      'phoneNumber: $phoneNumber, isActive: $isActive)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TwoFactorAuthSettings &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          isEnabled == other.isEnabled &&
          phoneNumber == other.phoneNumber;

  @override
  int get hashCode => userId.hashCode ^ isEnabled.hashCode ^ phoneNumber.hashCode;
}
