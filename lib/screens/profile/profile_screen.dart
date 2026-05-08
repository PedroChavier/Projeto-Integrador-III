import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../models/user_profile.dart';
import '../home/home_screen.dart';
import '../initial/splash_screen.dart';
import '../authentication/password_recovery_screen.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  bool _2faAtivado = false;
  final AuthService _authService = AuthService();
  UserProfile? _perfil;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarPerfil();
  }

  Future<void> _carregarPerfil() async {
    try {
      final perfil = await _authService.getCurrentUserProfile();
      if (mounted) {
        setState(() {
          _perfil = perfil;
          _carregando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _carregando = false);
    }
  }

  // Gera as iniciais do nome (ex: "Ana Souza" → "AS")
  String _iniciais(String? nome) {
    if (nome == null || nome.trim().isEmpty) return '';
    final partes = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.length == 1) return partes[0][0].toUpperCase();
    return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
  }

  // Formata telefone: "11999781289" → "(11) 99978-1289"
  String _formatarTelefone(String? tel) {
    if (tel == null || tel.isEmpty) return '-';
    final d = tel.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length == 11) return '(${d.substring(0,2)}) ${d.substring(2,7)}-${d.substring(7)}';
    if (d.length == 10) return '(${d.substring(0,2)}) ${d.substring(2,6)}-${d.substring(6)}';
    return tel;
  }

  @override
  Widget build(BuildContext context) {
    final nome = _perfil?.fullName ?? '';
    final email = _perfil?.email ?? '';
    final telefone = _formatarTelefone(_perfil?.telefone);
    final iniciais = _iniciais(nome);

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: Column(
        children: [
          Container(
            color: Colors.white,
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
                        colors: [
                          Color(0xFF6C63FF),
                          Color(0xFFE040FB),
                          Color(0xFFFF6B6B),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 22),
                    onPressed: () => Navigator.pop(context),
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
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Column(
                      children: [
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
                                child: iniciais.isNotEmpty
                                    ? Text(
                                        iniciais,
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF6C63FF),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.person,
                                        size: 40,
                                        color: Color(0xFF6C63FF),
                                      ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                nome.isNotEmpty ? nome : 'Usuário',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
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
                              _LinhaInfo(label: 'Nome Completo', valor: nome.isNotEmpty ? nome : '-'),
                              const Divider(height: 1, indent: 16, color: Color(0xFFEEEEEE)),
                              _LinhaInfo(label: 'Telefone', valor: telefone),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
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
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                                        onChanged: (value) => setState(() => _2faAtivado = value),
                                        activeColor: Colors.white,
                                        activeTrackColor: const Color(0xFF9E9E9E),
                                        inactiveThumbColor: Colors.white,
                                        inactiveTrackColor: const Color(0xFFBDBDBD),
                                        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1, indent: 16, color: Color(0xFFEEEEEE)),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const RecuperarSenhaScreen(),
                                    ),
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
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
                                        style: TextStyle(fontSize: 16, color: Colors.black45),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        GestureDetector(
                          onTap: () async {
                            await _authService.signOut();
                            if (!context.mounted) return;
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const SplashScreen()),
                              (route) => false,
                            );
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
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }
}

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
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          Text(
            valor,
            style: const TextStyle(fontSize: 14, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}