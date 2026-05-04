import 'package:flutter/material.dart';
import '../home/home_screen.dart';

// ─────────────────────────────────────────────
// TELA: Saldo Confirmado
// ─────────────────────────────────────────────
class SaldoConfirmadoScreen extends StatefulWidget {
  final double valorCreditado;
  final double saldoAnterior;
  final double novoSaldo;

  const SaldoConfirmadoScreen({
    super.key,
    required this.valorCreditado,
    required this.saldoAnterior,
    required this.novoSaldo,
  });

  @override
  State<SaldoConfirmadoScreen> createState() => _SaldoConfirmadoScreenState();
}

class _SaldoConfirmadoScreenState extends State<SaldoConfirmadoScreen>
    with TickerProviderStateMixin {

  // Animação do círculo
  AnimationController? _circleController;
  Animation<double> _circleAnimation = const AlwaysStoppedAnimation(0.0);

  // Animação do check
  AnimationController? _checkController;
  Animation<double> _checkAnimation = const AlwaysStoppedAnimation(0.0);

  // (mantido, mas não usado no texto)
  AnimationController? _fadeController;
  Animation<double> _fadeAnimation = const AlwaysStoppedAnimation(0.0);

  @override
  void initState() {
    super.initState();

    _circleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _circleAnimation = CurvedAnimation(
      parent: _circleController!,
      curve: Curves.easeOut,
    );

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _checkAnimation = CurvedAnimation(
      parent: _checkController!,
      curve: Curves.easeOut,
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController!,
      curve: Curves.easeIn,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _circleController?.forward();
      await _checkController?.forward();
      _fadeController?.forward();
    });
  }

  @override
  void dispose() {
    _circleController?.dispose();
    _checkController?.dispose();
    _fadeController?.dispose();
    super.dispose();
  }

  String _formatReal(double valor) =>
      'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

  String _dataAtual() {
    final now = DateTime.now();
    final meses = [
      '',
      'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
      'jul', 'ago', 'set', 'out', 'nov', 'dez',
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
          const SizedBox(height: 20),
          Container(
            color: const Color.fromARGB(255, 255, 255, 255),
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

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),

                  // Ícone animado
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _circleAnimation,
                        _checkAnimation,
                      ]),
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _CheckPainter(
                            circleProgress: _circleAnimation.value,
                            checkProgress: _checkAnimation.value,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // TEXTO SEM ANIMAÇÃO (alteração solicitada)
                  const Text(
                    'Saldo adicionado!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 36),

                  Column(
                    children: [
                      _LinhaResumo(
                        label: 'Valor Creditado',
                        valor: _formatReal(widget.valorCreditado),
                        valorColor: Colors.black87,
                        bold: false,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Divider(height: 1, color: Color(0xFFEEEEEE)),
                      ),
                      _LinhaResumo(
                        label: 'Data',
                        valor: _dataAtual(),
                        valorColor: Colors.black87,
                        bold: false,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Divider(height: 1, color: Color(0xFFEEEEEE)),
                      ),
                      _LinhaResumo(
                        label: 'Saldo anterior',
                        valor: _formatReal(widget.saldoAnterior),
                        valorColor: Colors.black87,
                        bold: false,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Divider(height: 1, color: Color(0xFFEEEEEE)),
                      ),
                      _LinhaResumo(
                        label: 'Novo saldo',
                        valor: _formatReal(widget.novoSaldo),
                        valorColor: const Color(0xFF6C63FF),
                        bold: true,
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.popUntil(context, (route) => route.isFirst);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.black87, width: 1.5),
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

// ── Painter
class _CheckPainter extends CustomPainter {
  final double circleProgress;
  final double checkProgress;

  _CheckPainter({
    required this.circleProgress,
    required this.checkProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    final circlePaint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      2 * 3.14159 * circleProgress,
      false,
      circlePaint,
    );

    if (checkProgress > 0) {
      final checkPaint = Paint()
        ..color = const Color(0xFF4CAF50)
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final p1 = Offset(size.width * 0.25, size.height * 0.50);
      final p2 = Offset(size.width * 0.43, size.height * 0.65);
      final p3 = Offset(size.width * 0.73, size.height * 0.35);

      final totalLength =
          (p2 - p1).distance + (p3 - p2).distance;
      final drawn = totalLength * checkProgress;

      final path = Path();
      path.moveTo(p1.dx, p1.dy);

      final seg1 = (p2 - p1).distance;

      if (drawn <= seg1) {
        final t = drawn / seg1;
        path.lineTo(
          p1.dx + (p2.dx - p1.dx) * t,
          p1.dy + (p2.dy - p1.dy) * t,
        );
      } else {
        path.lineTo(p2.dx, p2.dy);
        final remaining = drawn - seg1;
        final seg2 = (p3 - p2).distance;
        final t = (remaining / seg2).clamp(0.0, 1.0);
        path.lineTo(
          p2.dx + (p3.dx - p2.dx) * t,
          p2.dy + (p3.dy - p2.dy) * t,
        );
      }

      canvas.drawPath(path, checkPaint);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.circleProgress != circleProgress ||
      old.checkProgress != checkProgress;
}

// ── Linha resumo
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