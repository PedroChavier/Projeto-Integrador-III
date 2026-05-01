import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import '../startups/startups_catalog_screen.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  bool _2faAtivado = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: Column(
        children: [
          // ── Status bar area + gradiente + header ──
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Linha gradiente
                  Container(
                    height: 3,
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
                  // Seta voltar
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 22),
                    onPressed: () {
                        Navigator.pop(context);
                      },
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    constraints: const BoxConstraints(),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Text(
                      'Perfil',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Conteúdo rolável ──
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Avatar + nome + email
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Column(
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: const BoxDecoration(
                            color: Color(0xFFDCDAFF),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'AN',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6C63FF),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Ana Souza',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'ana.souza@gmail.com',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Dados Da conta ──
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Text(
                            'Dados Da conta',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFEEEEEE)),
                        _LinhaInfo(label: 'Nome Completo', valor: 'Ana Souza'),
                        const Divider(height: 1, indent: 16, color: Color(0xFFEEEEEE)),
                        _LinhaInfo(label: 'Telefone', valor: '199978-1289'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Segurança ──
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Text(
                            'Segurança',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFEEEEEE)),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Autenticação 2FA',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              Transform.scale(
                                scale: 0.85,
                                child: Switch(
                                  value: _2faAtivado,
                                  onChanged: (v) =>
                                      setState(() => _2faAtivado = v),
                                  activeColor: Colors.white,
                                  activeTrackColor: const Color(0xFF9E9E9E),
                                  inactiveThumbColor: Colors.white,
                                  inactiveTrackColor: const Color(0xFFBDBDBD),
                                  trackOutlineColor:
                                      MaterialStateProperty.all(Colors.transparent),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, indent: 16, color: Color(0xFFEEEEEE)),
                        GestureDetector(
                          onTap: () {
                            // TODO: alterar senha
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 18),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Text(
                                  'Alterar Senha',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  '>',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Sair da conta ──
                  GestureDetector(
                    onTap: () {
                      // TODO: logout
                    },
                    child: const Text(
                      'Sair da conta',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE53935),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // ── Bottom Nav ──
        ],
      ),
    );
  }
}

// ── Linha label + valor ───────────────────────────────────────
class _LinhaInfo extends StatelessWidget {
  final String label;
  final String valor;
  const _LinhaInfo({required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
          Text(valor,
              style:
                  const TextStyle(fontSize: 14, color: Colors.black45)),
        ],
      ),
    );
  }
}

