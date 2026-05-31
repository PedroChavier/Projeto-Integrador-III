//Giovana Uchelli - 25008818
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.telefone,
    required this.role,
    required this.isAdmin,
    required this.userActive,
    required this.mfaHabilitado,
  });

  final String uid;
  final String fullName;
  final String email;
  final String telefone;
  final String role;
  final bool isAdmin;
  final bool userActive;
  final bool mfaHabilitado;

  //converte um obejto firestore para dart (map)
  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      fullName: (map['fullName'] as String? ?? '').trim(),
      email: (map['email'] as String? ?? '').trim(),
      telefone: (map['telefone'] as String? ?? '').trim(),
      role: (map['role'] as String? ?? 'user').trim().toLowerCase(),
      isAdmin: map['isAdmin'] as bool? ?? false,
      userActive: map['userActive'] as bool? ?? true,
      mfaHabilitado: map['mfaHabilitado'] as bool? ?? false,
    );
  }

  String get displayName {
    if (fullName.isNotEmpty) return fullName;
    if (email.isNotEmpty) return email;
    return uid;
  }

  //Gera as iniciais para os avatares  
  String get initials {

    //Divide o nome completo por espaços e remove partes vazias
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

    //Pega a inicial do primeiro e do ultimo nome    
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
