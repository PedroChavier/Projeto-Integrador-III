import 'wallet_holding.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.telefone,
    required this.saldo,
    required this.role,
    required this.isAdmin,
    required this.userActive,
    required this.mfaHabilitado,
    required this.holdings,
  });

  final String uid;
  final String fullName;
  final String email;
  final String telefone;
  final double saldo;
  final String role;
  final bool isAdmin;
  final bool userActive;
  final bool mfaHabilitado;
  final List<WalletHolding> holdings;

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    final portfolioMap = map['portfolio'];
    final holdings = portfolioMap is Map
        ? (() {
            final parsedHoldings = portfolioMap.entries
                .where((entry) => entry.key != null && entry.value is Map)
                .map(
                  (entry) => WalletHolding.fromMap(
                    entry.key.toString(),
                    Map<String, dynamic>.from(entry.value as Map),
                  ),
                )
                .where((holding) => holding.quantidade > 0)
                .toList();

            parsedHoldings.sort(
              (a, b) => b.valorInvestido.compareTo(a.valorInvestido),
            );

            return parsedHoldings;
          })()
        : const <WalletHolding>[];

    return UserProfile(
      uid: uid,
      fullName: (map['fullName'] as String? ?? '').trim(),
      email: (map['email'] as String? ?? '').trim(),
      telefone: (map['telefone'] as String? ?? '').trim(),
      saldo: (map['saldo'] as num?)?.toDouble() ?? 0,
      role: (map['role'] as String? ?? 'user').trim().toLowerCase(),
      isAdmin: map['isAdmin'] as bool? ?? false,
      userActive: map['userActive'] as bool? ?? true,
      mfaHabilitado: map['mfaHabilitado'] as bool? ?? false,
      holdings: holdings,
    );
  }

  String get displayName {
    if (fullName.isNotEmpty) return fullName;
    if (email.isNotEmpty) return email;
    return uid;
  }

  String get initials {
    final parts = fullName
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      if (email.isEmpty) return 'US';
      return email.substring(0, email.length >= 2 ? 2 : 1).toUpperCase();
    }

    if (parts.length == 1) {
      final name = parts.first;
      return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
