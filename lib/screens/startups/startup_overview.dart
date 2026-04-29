import 'package:flutter/material.dart';

class VisaoGeralTab extends StatelessWidget {
  const VisaoGeralTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A agro sense desenvolve sensores IoT de baixo custo para monitoramento de lavouras em tempo real, integrando dados via app mobile para produtores rurais.',
            style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.6),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _MetricaBox(label: 'Tokens Emitidos', valor: '50.000'),
              const SizedBox(width: 12),
              _MetricaBox(
                label: 'Preço Atual',
                valor: 'R\$ 25,00',
                subvalor: '+6%',
                subColor: const Color(0xFF2E7D32),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MetricaBox(label: 'Investidores', valor: '47'),
              const SizedBox(width: 12),
              _MetricaBox(label: 'Captado', valor: 'R\$ 180.000,00'),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Video Demonstrativo',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          const SizedBox(height: 10),
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color:   Color.fromARGB(255, 5, 5, 79),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                ),
                const Positioned(
                  bottom: 8,
                  left: 12,
                  child: Text(
                    'AgroSense - 3min',
                    style: TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricaBox extends StatelessWidget {
  final String label;
  final String valor;
  final String? subvalor;
  final Color? subColor;

  const _MetricaBox({
    required this.label,
    required this.valor,
    this.subvalor,
    this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 90, // controla a altura padrão dos cards
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start, // centraliza melhor
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 14, color: Color.fromARGB(169, 0, 0, 0))),
              const SizedBox(height: 4),
              Text(valor,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87)),
              if (subvalor != null)
                Text(subvalor!,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: subColor
                        )
                      ),
            ],
          ),
        ),
      ),
    );
  }
}