//Giovana Uchelli

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../services/auth_service.dart';
import '../home/home_screen.dart';
import 'deposit_success_screen.dart';

// Tela para o usuário digitar e confirmar um depósito simulado
class AdicionarSaldoScreen extends StatefulWidget {
  final double saldoAtual;
  final Widget telaRetorno; // Tela para onde voltar após confirmar

  const AdicionarSaldoScreen({
    super.key,
    this.saldoAtual = 2000.00,
    required this.telaRetorno,
  });

  @override
  State<AdicionarSaldoScreen> createState() => _AdicionarSaldoScreenState();
}

class _AdicionarSaldoScreenState extends State<AdicionarSaldoScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _valorController = TextEditingController();
  double _valorDigitado = 0.0;
  bool _salvando = false;
  final _currencyFormat = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$ ',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    // Inicia o campo já formatado como "R$ 0,00"
    _valorController.value = TextEditingValue(
      text: _CurrencyInputFormatter.formatFromDigits(''),
      selection: TextSelection.collapsed(
        offset: _CurrencyInputFormatter.formatFromDigits('').length,
      ),
    );
  }

  @override
  void dispose() {
    _valorController.dispose();
    super.dispose();
  }

  // Calcula o novo saldo somando o valor digitado ao saldo atual
  double get _novoSaldo => widget.saldoAtual + _valorDigitado;

  String _formatReal(double valor) => _currencyFormat.format(valor);

  // Extrai o valor numérico do texto formatado removendo tudo que não é dígito
  double _parseValorFormatado(String valorFormatado) {
    final digits = valorFormatado.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0.0;
    return int.parse(digits) / 100; // Os dois últimos dígitos são centavos
  }

  // Salva o saldo no Firestore e navega para a tela de confirmação
  Future<void> _confirmar() async {
    if (_valorDigitado <= 0 || _salvando) return;

    setState(() => _salvando = true);

    try {
      await _authService.creditCurrentUserSaldo(_valorDigitado);
      if (!mounted) return;

      // Substitui a tela atual pela de confirmação (sem poder voltar)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SaldoConfirmadoScreen(
            valorCreditado: _valorDigitado,
            saldoAnterior: widget.saldoAtual,
            novoSaldo: _novoSaldo,
            telaRetorno: widget.telaRetorno,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar o saldo: $error')),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: Column(
        children: [
          // Cabeçalho com gradiente e botão voltar
          Container(
            color: const Color.fromARGB(255, 255, 255, 255),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Container(
                    height: 2,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFFE040FB), Color(0xFFFF6B6B)],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 22),
                    onPressed: () => Navigator.maybePop(context),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Adicionar Saldo',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  const SizedBox(height: 20),

                  // Exibe o saldo atual do usuário
                  const Text('Saldo Atual', style: TextStyle(fontSize: 13, color: Colors.black45)),
                  const SizedBox(height: 4),
                  Text(
                    _formatReal(widget.saldoAtual),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  const SizedBox(height: 24),

                  // Campo de entrada com formatação automática de moeda
                  const Text('Digite o valor', style: TextStyle(fontSize: 13, color: Colors.black45)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _valorController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_CurrencyInputFormatter()], // Formata enquanto digita
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                    onChanged: (value) {
                      setState(() => _valorDigitado = _parseValorFormatado(value));
                    },
                    decoration: InputDecoration(
                      hintText: 'R\$ 0,00',
                      hintStyle: const TextStyle(color: Colors.black38, fontSize: 16),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                      ),
                      // Borda roxa ao focar
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Resumo: saldo atual + valor a adicionar = novo saldo
                  _LinhaResumo(
                    label: 'Saldo Atual',
                    valor: _formatReal(widget.saldoAtual),
                    valorColor: Colors.black87,
                    bold: false,
                  ),
                  const SizedBox(height: 14),
                  _LinhaResumo(
                    label: 'Valor a adicionar',
                    valor: _valorDigitado > 0 ? '+ ${_formatReal(_valorDigitado)}' : '+ R\$ 0,00',
                    valorColor: const Color(0xFF6C63FF),
                    bold: false,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1, color: Color(0xFFEEEEEE)),
                  ),
                  _LinhaResumo(
                    label: 'Novo Saldo',
                    valor: _formatReal(_novoSaldo),
                    valorColor: Colors.black87,
                    bold: true,
                  ),
                  const SizedBox(height: 40),

                  // Botão confirmar — desabilitado enquanto salva
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _salvando ? null : _confirmar,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.black87, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _salvando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                              ),
                            )
                          : const Text(
                              'Confirmar crédito simulado',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }
}

// Linha de resumo reutilizável: label à esquerda, valor à direita
class _LinhaResumo extends StatelessWidget {
  final String label;
  final String valor;
  final Color valorColor;
  final bool bold;

  const _LinhaResumo({
    required this.label,
    required this.valor,
    required this.valorColor,
    required this.bold,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: Colors.black87,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            fontSize: 15,
            color: valorColor,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// Formata o campo de texto automaticamente no padrão "R$ 1.234,56" enquanto o usuário digita
class _CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final formatted = formatFromDigits(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  // Converte uma string de dígitos puros para o formato "R$ X.XXX,XX"
  static String formatFromDigits(String digits) {
    final onlyDigits = digits.replaceAll(RegExp(r'[^0-9]'), '');
    final padded = (onlyDigits.isEmpty ? '0' : onlyDigits).padLeft(3, '0');
    final cents = padded.substring(padded.length - 2);       // Últimos 2 dígitos = centavos
    final integerPart = padded.substring(0, padded.length - 2);
    final reais = _addThousandsSeparator(integerPart);
    return 'R\$ $reais,$cents';
  }

  // Adiciona separador de milhar com ponto: "1234" → "1.234"
  static String _addThousandsSeparator(String digits) {
    final trimmed = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final normalized = trimmed.isEmpty ? '0' : trimmed;
    final buffer = StringBuffer();

    for (var i = 0; i < normalized.length; i++) {
      final reverseIndex = normalized.length - i;
      buffer.write(normalized[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write('.');
      }
    }

    return buffer.toString();
  }
}