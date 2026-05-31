//Pedro Andre do Carmo Chavier -25018639

import 'package:cloud_firestore/cloud_firestore.dart';

import 'pessoa.dart';

//Representa um usuario autenticado da plaforma
class Usuario extends Pessoa {
  String? _uid;
  String? _email;
  String? _telefone;
  bool _mfaHabilitado;
  bool _userActive;

  Usuario({
    String? uid,
    String? cpf,
    String? fullName,
    DateTime? dataNascimento,
    String? email,
    String? telefone,
    bool mfaHabilitado = false,
    bool userActive = true,
  })  : _uid = uid,
        _email = email,
        _telefone = telefone,
        _mfaHabilitado = mfaHabilitado,
        _userActive = userActive,
        super(cpf: cpf, fullName: fullName, dataNascimento: dataNascimento);

  //Transforma um objeto firestore para dart
  factory Usuario.fromMap(Map<String, dynamic> map) {
    final rawDataNascimento = map['dataNascimento'];
    DateTime? dataNascimento;

    if (rawDataNascimento is Timestamp) {
      dataNascimento = rawDataNascimento.toDate();
    } else if (rawDataNascimento is DateTime) {
      dataNascimento = rawDataNascimento;
    } else if (rawDataNascimento is String && rawDataNascimento.isNotEmpty) {
      dataNascimento = DateTime.tryParse(rawDataNascimento);
    }

    return Usuario(
      uid: map['uid'] as String?,
      cpf: map['cpf'] as String?,
      fullName: map['fullName'] as String?,
      dataNascimento: dataNascimento,
      email: map['email'] as String?,
      telefone: map['telefone'] as String?,
      mfaHabilitado: map['mfaHabilitado'] as bool? ?? false,
      userActive: map['userActive'] as bool? ?? true,
    );
  }

  //Getters para ler os atributos privados
  String? get uid => _uid;
  String? get email => _email;
  String? get telefone => _telefone;
  bool get mfaHabilitado => _mfaHabilitado;
  bool get userActive => _userActive;

  //setters para alterar os atributos priavdos
  set uid(String? value) => _uid = value;
  set userActive(bool value) => _userActive = value;
  set email(String? value) => _email = value;
  set telefone(String? value) => _telefone = value;
  set mfaHabilitado(bool value) => _mfaHabilitado = value;

  //Tranforma em um map compativel com o firestore
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uid': _uid,
      'cpf': cpf,
      'fullName': fullName,
      'dataNascimento': dataNascimento == null
          ? null
          : Timestamp.fromDate(dataNascimento!.toUtc()), //Utc -> horario universal
      'email': _email,
      'telefone': _telefone,
      'mfaHabilitado': _mfaHabilitado,
      'userActive': _userActive,
    };
  }

  bool cadastrarUsuario() {
    if (!validarCpf()) return false;
    if (_email == null || _email!.trim().isEmpty) return false;
    return true;
  }

  void habilitarMFA() {
    _mfaHabilitado = true;
  }

  void desabilitarMFA() {
    _mfaHabilitado = false;
  }
}
