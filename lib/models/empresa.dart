//Pedro Andre do Carmo Chavier -25018639

class Empresa {
  String? _cnpj;
  String? _nome;
  DateTime? _dataCriacao;

  Empresa({String? cnpj, String? nome, DateTime? dataCriacao})
  //Lista de inicialização -> aqui os atributos recebidos no construtor sao colocados nos atributos privados
    : _cnpj = cnpj,
      _nome = nome,
      _dataCriacao = dataCriacao;

  // Getters -> usados para ler os atributos privados fora da classe
  String? get cnpj => _cnpj;
  String? get nome => _nome;
  DateTime? get dataCriacao => _dataCriacao;

  // Setters -> usadoa para alterar os atributos privados fora da classe 
  set cnpj(String? value) => _cnpj = value;
  set nome(String? value) => _nome = value;
  set dataCriacao(DateTime? value) => _dataCriacao = value;
}
