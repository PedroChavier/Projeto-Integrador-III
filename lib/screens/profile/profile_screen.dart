//Giovana Uchelli - 25008818

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
  final AuthService _authService = AuthService(); // Serviço de autenticação
  UserProfile? _perfil;       // Dados do usuário logado
  bool _carregando = true;    // Controla o indicador de carregamento
  bool _salvandoMfa = false;  // Bloqueia o switch enquanto salva

  @override
  void initState() {
    super.initState();
    _carregarPerfil(); // Carrega os dados ao abrir a tela
  }

  // Busca o perfil do usuário no serviço e atualiza o estado
  Future<void> _carregarPerfil() async {
    try {
      final perfil = await _authService.getCurrentUserProfile();
      if (mounted) {
        setState(() {
          _perfil = perfil;
          _2faAtivado = perfil?.mfaHabilitado ?? false;
          _carregando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _carregando = false);
    }
  }

  // Decide se vai ativar ou desativar o 2FA conforme o valor do switch
  Future<void> _alterarMfa(bool value) async {
    if (_salvandoMfa) return; // Ignora se já está salvando

    if (value) {
      await _ativarMfa();
    } else {
      await _desativarMfa();
    }
  }

  // Exibe confirmação e ativa o 2FA, gravando a flag no Firestore.
  // OBS: o mecanismo de verificação por código (SMS/e-mail) foi removido;
  // este fluxo apenas alterna a flag mfaHabilitado.
  Future<void> _ativarMfa() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ativar autenticacao 2FA'),
        content: const Text(
          'Deseja ativar a autenticacao em dois fatores na sua conta?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ativar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    final estadoAnterior = _2faAtivado; // Guarda estado para reverter se falhar
    setState(() {
      _salvandoMfa = true;
      _2faAtivado = true;
    });

    try {
      await _authService.updateCurrentUserMfaStatus(true);
      await _carregarPerfil();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Autenticacao em dois fatores ativada.'),
          backgroundColor: Colors.green[400],
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('[PerfilScreen] Falha ao ativar 2FA: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _2faAtivado = estadoAnterior); // Reverte o switch em caso de erro
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_mensagemErroMfa(error)),
          backgroundColor: Colors.red[400],
        ),
      );
    } finally {
      if (mounted) setState(() => _salvandoMfa = false); // Libera o switch
    }
  }

  // Exibe confirmação e desativa o 2FA, revertendo em caso de erro
  Future<void> _desativarMfa() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desativar autenticacao 2FA'),
        content: const Text(
          'Ao desativar, seu login nao exigira mais verificacao por codigo. Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Desativar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    final estadoAnterior = _2faAtivado; // Guarda estado para reverter se falhar
    setState(() {
      _salvandoMfa = true;
      _2faAtivado = false;
    });

    try {
      await _authService.updateCurrentUserMfaStatus(false);
      await _carregarPerfil();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Autenticacao em dois fatores desativada.'),
          backgroundColor: Colors.green[400],
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('[PerfilScreen] Falha ao desativar 2FA: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _2faAtivado = estadoAnterior); // Reverte o switch em caso de erro
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_mensagemErroMfa(error)),
          backgroundColor: Colors.red[400],
        ),
      );
    } finally {
      if (mounted) setState(() => _salvandoMfa = false); // Libera o switch
    }
  }

  // Extrai uma mensagem legível do erro de 2FA para exibir no SnackBar.
  String _mensagemErroMfa(Object error) {
    var msg = error.toString();
    const prefixo = 'Exception: ';
    if (msg.startsWith(prefixo)) {
      msg = msg.substring(prefixo.length);
    }
    return msg.trim().isEmpty
        ? 'Nao foi possivel atualizar a autenticacao 2FA.'
        : msg;
  }

  // Gera as iniciais do nome: "Ana Souza" → "AS"
  String _iniciais(String? nome) {
    if (nome == null || nome.trim().isEmpty) return '';
    final partes = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.length == 1) return partes[0][0].toUpperCase();
    return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
  }

  // Formata o telefone: "11999781289" → "(11) 99978-1289"
  String _formatarTelefone(String? tel) {
    if (tel == null || tel.isEmpty) return '-';
    final d = tel.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length == 11) return '(${d.substring(0,2)}) ${d.substring(2,7)}-${d.substring(7)}';
    if (d.length == 10) return '(${d.substring(0,2)}) ${d.substring(2,6)}-${d.substring(6)}';
    return tel;
  }

  @override
  Widget build(BuildContext context) {
    // Prepara os dados para exibição
    final nome = _perfil?.fullName ?? '';
    final email = _perfil?.email ?? '';
    final telefone = _formatarTelefone(_perfil?.telefone);
    final iniciais = _iniciais(nome);

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: Column(
        children: [
          // Cabeçalho com gradiente, botão voltar e título
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // Barra decorativa com gradiente no topo
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
                // Exibe loading enquanto os dados não chegaram
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        // Seção do avatar com iniciais e nome do usuário
                        Container(
                          width: double.infinity,
                          color: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Column(
                            children: [
                              // Círculo com iniciais (ou ícone padrão se não houver nome)
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
                                style: const TextStyle(fontSize: 13, color: Colors.black45),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Seção: dados da conta (nome e telefone)
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

                        // Seção: segurança (2FA e alterar senha)
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

                              // Switch para ativar/desativar autenticação em dois fatores
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
                                        onChanged: _salvandoMfa ? null : _alterarMfa, // Desabilitado enquanto salva
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

                              // Botão para ir à tela de recuperação/alteração de senha
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
                                      Text('>', style: TextStyle(fontSize: 16, color: Colors.black45)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Botão de logout — faz o signOut e volta para o SplashScreen
                        GestureDetector(
                          onTap: () async {
                            await _authService.signOut();
                            if (!context.mounted) return;
                            // Remove todas as rotas anteriores da pilha
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
      bottomNavigationBar: const AppBottomNav(currentIndex: 0), // Barra de navegação inferior
    );
  }
}

// Widget reutilizável para exibir uma linha de informação (label + valor)
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