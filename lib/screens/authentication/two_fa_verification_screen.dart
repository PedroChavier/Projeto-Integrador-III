import 'dart:async'; //usado para o timer (contagem regressiva)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; //usado para limitar a entrada so a numeros

class Verificacao2FAScreen extends StatefulWidget {
  const Verificacao2FAScreen({super.key});

  @override
  State<Verificacao2FAScreen> createState() => _Verificacao2FAScreenState();
}

class _Verificacao2FAScreenState extends State<Verificacao2FAScreen> {
  static const int _totalDigitos = 5; //quantidade de campos
  static const int _tempoInicial = 50; //tempo inicial do contador

  //controla o texto digitado em cada caixinha
  final List<TextEditingController> _controllers =
      List.generate(_totalDigitos, (_) => TextEditingController());
  //controla o foco (qual caixinha está ativa)
  final List<FocusNode> _focusNodes =
      List.generate(_totalDigitos, (_) => FocusNode());

  int _segundosRestantes = _tempoInicial;
  Timer? _timer; //timer que vai diminuindo o tempo

  @override
  void initState() {
    super.initState();
    _iniciarTimer();
    //coloca o cursor automaticamente no primeiro campo
    WidgetsBinding.instance.addPostFrameCallback((_) { 
      _focusNodes[0].requestFocus();
    });
  }

  void _iniciarTimer() {
    _timer?.cancel(); //cancela o timer antigo
    setState(() => _segundosRestantes = _tempoInicial); //reseta o tempo

    // a cada um segundo, diminui o tempo
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_segundosRestantes <= 1) {
        t.cancel(); //para quando chega em 0
        setState(() => _segundosRestantes = 0);
      } else {
        setState(() => _segundosRestantes--); //diminui 1 segundo
      }
    });
  }

  //chamado quando o usuario digita algo
  void _onDigitChanged(int index, String value) {

    //se digitou 1 numero, vai para a proxima caixa
    if (value.length == 1 && index < _totalDigitos - 1) {
      _focusNodes[index + 1].requestFocus();
    
    //se apagou, volta para a anterior
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {}); //atualiza o botão
  }

  //verifica se todas as caixas foram preenchidas
  bool get _codigoCompleto =>
      _controllers.every((c) => c.text.isNotEmpty);

  void _confirmar() {
    if (!_codigoCompleto) return; 

    //junta todos os numeros digitados
    final codigo = _controllers.map((c) => c.text).join();
    debugPrint('Código 2FA: $codigo');
    // TODO: validar código e navegar
  }

  void _reenviar() {
    //limpa todas as caixas
    for (final c in _controllers) {
      c.clear();
    }

    //volta o foco para a primeira caixa
    _focusNodes[0].requestFocus();
    _iniciarTimer();
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel(); //cancela o time ao sair da tela

    //libera as memorias 
    for (final c in _controllers) c.dispose(); 
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      //barra superior com o botao voltar
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,

        //botao voltar
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.maybePop(context),
        ),

        //linha colorida
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(
            height: 2,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFFE040FB), Color(0xFFFF6B6B)],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título
              const Text(
                'Verificação 2FA',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Passo 2 de 2',
                style: TextStyle(fontSize: 14, color: Colors.black45),
              ),
              const SizedBox(height: 4),
              const Divider(color: Color(0xFFEEEEEE)),
              const SizedBox(height: 16),

              // Banner informativo
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAE8FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.5),
                        children: [
                          TextSpan(text: 'Este usuário possui '),
                          TextSpan(
                            text: '2FA ativado.',
                            style: TextStyle(
                              color: Color(0xFF6C63FF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'A autenticação multifator é opcional, desabilite em perfil se necessário',
                      style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // Instrução + timer
              Center(
                child: Column(
                  children: [
                    const Text(
                      'Digite o codigo enviado',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 13, color: Colors.black45),
                        children: [
                          const TextSpan(text: 'o codigo expira em '),
                          TextSpan(
                            text: '${_segundosRestantes}s',
                            style: const TextStyle(
                              color: Color(0xFF6C63FF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Campos de dígito
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_totalDigitos, (i) => _DigitBox(
                  controller: _controllers[i],
                  focusNode: _focusNodes[i],
                  onChanged: (v) => _onDigitChanged(i, v),
                )),
              ),
              const SizedBox(height: 36),

              // Botão confirmar
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: _codigoCompleto ? _confirmar : null,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _codigoCompleto ? Colors.black87 : Colors.black26,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Confirmar e entrar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _codigoCompleto ? Colors.black87 : Colors.black38,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Reenviar código
              Center(
                child: GestureDetector(
                  onTap: _reenviar,
                  child: const Text(
                    'Reenviar Código',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6C63FF),
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//  Caixa de dígito 
class _DigitBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _DigitBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 58,

      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,

        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,

        inputFormatters: [FilteringTextInputFormatter.digitsOnly], //só numeros
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),

        decoration: InputDecoration(
          counterText: '', //remove o contador de caracteres
          contentPadding: EdgeInsets.zero, // remove espaço interno padrao (deixa mais compacto)

          //bordas da caixinha
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
          ),

          //borda quando NÃO esta selecionado
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
          ),
          
          //borda quando o usuario clica na caixa
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}