import 'package:flutter/material.dart';
import '../home/home_screen.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  final List<Map<String, dynamic>> _transacoes = const [
    {
      'titulo': 'Compra - AGS',
      'subtitulo': '12 abr 2026 - 10 tokens',
      'valor': '- R\$ 250,00',
      'positivo': false,
    },
    {
      'titulo': 'Credito Simulado',
      'subtitulo': '11 abr 2026',
      'valor': '+R\$ 5.000,00',
      'positivo': true,
    },
    {
      'titulo': 'Compra - AGS',
      'subtitulo': '12 abr 2026 - 10 tokens',
      'valor': '- R\$ 250,00',
      'positivo': false,
    },
    {
      'titulo': 'Venda - AGS',
      'subtitulo': '12 abr 2026 - 10 tokens',
      'valor': '+ R\$ 250,00',
      'positivo': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Column(
        children: [
          // Status bar + gradiente
          SizedBox(height: 20),
            Container(
              height: 2,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFFE040FB), Color(0xFFFF6B6B)],
                ),
              ),
            ),

          // Conteúdo
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  const Text(
                    'Carteira',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Card Saldo
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF9A1C63),
                          Color(0xFF1A237E),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Saldo Disponível',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'R\$ 2.000,00',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botão Adicionar Saldo simulado
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color.fromARGB(79, 0, 0, 0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Adicionar Saldo simulado',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Banner Balcão
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(194, 240, 240, 240),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.swap_horiz_outlined,
                            color: Color.fromARGB(255, 112, 121, 133), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Comprar ou vender tokens?',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              GestureDetector(
                                onTap: () {},
                                child: const Text(
                                  'Ir para Balcão',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF6C63FF),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Text(
                          '>',
                          style:
                              TextStyle(fontSize: 16, color: Colors.black45),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Histórico de Transações
                  const Text(
                    'Historico de Transações',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Lista de transações
                  ..._transacoes.map((t) => Column(
                        children: [
                          const Divider(height: 1, color: Color(0xFFEEEEEE)),
                          _TransacaoItem(
                            titulo: t['titulo'],
                            subtitulo: t['subtitulo'],
                            valor: t['valor'],
                            positivo: t['positivo'],
                          ),
                        ],
                      )),
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  const SizedBox(height: 16),
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

// ── Item de transação ─────────────────────────────────────────
class _TransacaoItem extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final String valor;
  final bool positivo;

  const _TransacaoItem({
    required this.titulo,
    required this.subtitulo,
    required this.valor,
    required this.positivo,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitulo,
                style:
                    const TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ],
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: positivo
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFE53935),
            ),
          ),
        ],
      ),
    );
  }
}

