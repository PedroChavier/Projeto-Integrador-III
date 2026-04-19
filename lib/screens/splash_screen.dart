import 'package:flutter/material.dart';
import 'inicio_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const InicioScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: MesclaInvestLogo(),
      ),
    );
  }
}

class MesclaInvestLogo extends StatelessWidget {
  const MesclaInvestLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(120, 80),
          painter: _ChartLinePainter(),
        ),
        const SizedBox(height: 16),
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'mescla',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              TextSpan(
                text: 'invest',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6C63FF),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChartLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final gradient = LinearGradient(
      colors: [const Color(0xFF6C63FF), const Color(0xFFE91E8C)],
    );

    final path = Path()
      ..moveTo(size.width * 0.05, size.height * 0.75)
      ..lineTo(size.width * 0.30, size.height * 0.55)
      ..lineTo(size.width * 0.55, size.height * 0.65)
      ..lineTo(size.width * 0.95, size.height * 0.10);

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    paint.shader = gradient.createShader(rect);
    canvas.drawPath(path, paint);

    final dotPaint = Paint()
      ..color = const Color(0xFFE91E8C)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.95, size.height * 0.10),
      6,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}