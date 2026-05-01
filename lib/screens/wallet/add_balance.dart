import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../home/home_screen.dart';

// ─────────────────────────────────────────────
// TELA: Adicionar Saldo
// ─────────────────────────────────────────────
class AdicionarSaldoScreen extends StatefulWidget {
  final double saldoAtual;
  const AdicionarSaldoScreen({super.key, this.saldoAtual = 2000.00});

  @override
  State<AdicionarSaldoScreen> createState() => _AdicionarSaldoScreenState();
}

class _AdicionarSaldoScreenState extends State<AdicionarSaldoScreen> {
  final _valorController = TextEditingController();
  double _valorDigitado = 0.0;

  @override
  void dispose() {
    _valorController.dispose();
    super.dispose();
  }

  double get _novoSaldo => widget.saldoAtual + _valorDigitado;

  String _formatReal(double valor) {
    return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  void _confirmar() {
    if (_valorDigitado <= 0) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SaldoConfirmadoScreen(
          valorCreditado: _valorDigitado,
          saldoAnterior: widget.saldoAtual,
          novoSaldo: _novoSaldo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: Column(
        children: [
          // Gradiente + seta
          Container(
            color: const Color.fromARGB(255, 255, 255, 255),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 20),
                   Container(
                    height: 2,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFFE040FB), Color(0xFFFF6B6B)],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.black87, size: 22),
                    onPressed: () => Navigator.maybePop(context),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),

          // Conteúdo
          Expanded(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  const Text(
                    'Adicionar Saldo',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Saldo Atual
                  const Text(
                    'Saldo Atual',
                    style: TextStyle(fontSize: 13, color: Colors.black45),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatReal(widget.saldoAtual),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Campo valor
                  const Text(
                    'Digite o valor',
                    style: TextStyle(fontSize: 13, color: Colors.black45),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _valorController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    style: const TextStyle(
                        fontSize: 16, color: Colors.black87),
                    onChanged: (v) {
                      setState(() {
                        _valorDigitado = double.tryParse(v) ?? 0.0;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'R\$ 0,00',
                      hintStyle: const TextStyle(
                          color: Colors.black38, fontSize: 16),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: Color(0xFFDDDDDD)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: Color(0xFFDDDDDD)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: Color(0xFF6C63FF), width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Resumo
                  _LinhaResumo(
                    label: 'Saldo Atual',
                    valor: 'R\$ ${widget.saldoAtual.toStringAsFixed(0).replaceAll('.', ',')}00',
                    valorColor: Colors.black87,
                    bold: false,
                  ),
                  const SizedBox(height: 14),
                  _LinhaResumo(
                    label: 'Valor a adicionar',
                    valor: _valorDigitado > 0
                        ? '+ R\$ ${_valorDigitado.toStringAsFixed(0).replaceAll('.', ',')}00'
                        : '+ R\$ 0,00',
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

                  // Botão confirmar
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _confirmar,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Colors.black87, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
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

// ─────────────────────────────────────────────
// TELA: Saldo Confirmado
// ─────────────────────────────────────────────
class SaldoConfirmadoScreen extends StatelessWidget {
  final double valorCreditado;
  final double saldoAnterior;
  final double novoSaldo;

  const SaldoConfirmadoScreen({
    super.key,
    required this.valorCreditado,
    required this.saldoAnterior,
    required this.novoSaldo,
  });

  String _formatReal(double valor) =>
      'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

  String _dataAtual() {
    final now = DateTime.now();
    final meses = [
      '', 'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
      'jul', 'ago', 'set', 'out', 'nov', 'dez'
    ];
    final hora = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    return '${now.day} ${meses[now.month]} ${now.year} - $hora:$min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: Column(
        children: [
          // Gradiente topo
          SizedBox(height: 20),
          Container(
            color:Color.fromARGB(255, 255, 255, 255),
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 2,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF6C63FF),
                      Color(0xFFE040FB),
                      Color(0xFFFF6B6B),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Conteúdo
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),

                  // Ícone de sucesso
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF4CAF50), width: 3),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Color(0xFF4CAF50),
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Título
                  const Text(
                    'Saldo adicionado!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Resumo
                  _LinhaResumo(
                    label: 'Valor Creditado',
                    valor: _formatReal(valorCreditado),
                    valorColor: Colors.black87,
                    bold: false,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child:
                        Divider(height: 1, color: Color(0xFFEEEEEE)),
                  ),
                  _LinhaResumo(
                    label: 'Data',
                    valor: _dataAtual(),
                    valorColor: Colors.black87,
                    bold: false,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child:
                        Divider(height: 1, color: Color(0xFFEEEEEE)),
                  ),
                  _LinhaResumo(
                    label: 'Saldo anterior',
                    valor: _formatReal(saldoAnterior),
                    valorColor: Colors.black87,
                    bold: false,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child:
                        Divider(height: 1, color: Color(0xFFEEEEEE)),
                  ),
                  _LinhaResumo(
                    label: 'Novo saldo',
                    valor: _formatReal(novoSaldo),
                    valorColor: const Color(0xFF6C63FF),
                    bold: true,
                  ),
                  const SizedBox(height: 40),

                  // Botão voltar
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.popUntil(
                            context, (route) => route.isFirst);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Colors.black87, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Voltar para a Carteira',
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

// ── Linha de resumo ───────────────────────────────────────────
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

