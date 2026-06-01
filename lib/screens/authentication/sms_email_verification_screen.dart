//Giovana Uchelli - 25008818
import 'package:flutter/material.dart';

import '../../models/user_profile.dart';        // dados do usuário (email, nome)
import '../../services/auth_service.dart';       // envia o e-mail de verificação e faz logout
import 'two_fa_verification_screen.dart';        // tela de polling que aguarda o clique no link

// ─── Widget principal ─────────────────────────────────────────────────────────

class SmsEmailVerificationScreen extends StatefulWidget {
  const SmsEmailVerificationScreen({
    super.key,
    required this.profile,    // dados do usuário logado
    this.onMfaAtivado,        // se fornecido → fluxo de ATIVAÇÃO; se nulo → fluxo de LOGIN
  });

  final UserProfile profile;

  /// Callback assíncrono chamado após verificação bem-sucedida no fluxo de ativação.
  /// Quando nulo, esta tela faz parte do login obrigatório (usuário já tem 2FA ativo).
  final Future<void> Function()? onMfaAtivado;

  @override
  State<SmsEmailVerificationScreen> createState() =>
      _SmsEmailVerificationScreenState();
}

class _SmsEmailVerificationScreenState
    extends State<SmsEmailVerificationScreen> {

  final AuthService _authService = AuthService();
  bool _isLoading = false;

  // Atalho: retorna true se o perfil tem e-mail válido cadastrado
  bool get _temEmail => widget.profile.email.trim().isNotEmpty;

  // ─── Envio do e-mail OOB ──────────────────────────────────────────────────

  // OOB = Out-Of-Band: link enviado por fora do app (via e-mail)
  // Fluxo: envia o link → navega para a tela de polling → aguarda confirmação
  Future<void> _enviarCodigo() async {
    if (!_temEmail) {
      _snack('Nenhum e-mail cadastrado na conta.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Chama o Firebase para disparar o e-mail de verificação
      await _authService.enviarEmailVerificacao2FA();

      if (!mounted) return;

      // Navega para a tela de polling e aguarda o retorno (true = verificado, false/null = cancelou)
      final verificado = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => Verificacao2FAScreen(
            canal: 'e-mail',
            destinoMascarado: _mascararEmail(widget.profile.email), // ex: "p***o@gmail.com"

            // Se é fluxo de ativação, passa um callback vazio só para sinalizar o modo
            // Se é fluxo de login, passa null (a tela de polling trata diferente)
            onVerificado: widget.onMfaAtivado != null ? () {} : null,
          ),
        ),
      );

      // Só executa se voltou com verificado == true E é fluxo de ativação
      if (verificado == true && widget.onMfaAtivado != null && mounted) {
        try {
          await widget.onMfaAtivado!(); // salva a configuração do 2FA no perfil
          if (mounted) Navigator.of(context).pop();
        } catch (_) {
          if (mounted) _snack('Erro ao salvar configuração do 2FA.', isError: true);
        }
      }
    } catch (e) {
      // Remove o prefixo "Exception: " para exibir mensagem limpa ao usuário
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Voltar / logout ──────────────────────────────────────────────────────

  // Comportamento do botão voltar muda conforme o fluxo:
  // Ativação → só fecha a tela (pop)
  // Login    → faz logout antes de fechar (usuário não pode entrar sem verificar)
  Future<void> _voltarOuSair() async {
    if (_isLoading) return;

    if (widget.onMfaAtivado != null) {
      Navigator.of(context).maybePop(); // fluxo de ativação: só fecha
      return;
    }

    // Fluxo de login: encerra a sessão para não deixar o usuário logado sem 2FA
    setState(() => _isLoading = true);
    try {
      await _authService.signOut();
    } catch (_) {
      if (mounted) _snack('Não foi possível encerrar a sessão.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).maybePop();
      }
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  // Exibe um SnackBar verde (sucesso) ou vermelho (erro)
  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red[400] : Colors.green[400],
    ));
  }

  // Mascara o e-mail para exibição: "pedro@gmail.com" → "p***o@gmail.com"
  String _mascararEmail(String email) {
    final partes = email.trim().split('@');
    if (partes.length != 2) return email; // formato inválido, retorna como está
    final u = partes[0]; // parte antes do @
    final d = partes[1]; // domínio
    if (u.length <= 2) return '${u[0]}***@$d'; // e-mail muito curto
    return '${u[0]}${'*' * (u.length - 2)}${u[u.length - 1]}@$d';
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Intercepta o botão físico de voltar para executar _voltarOuSair
      // retorna false para não fazer o pop automático (o método cuida disso)
      onWillPop: () async {
        await _voltarOuSair();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 28),
                _buildInfoBanner(),   // explicação do que vai acontecer
                const SizedBox(height: 28),
                _buildEmailCard(),    // card com o e-mail mascarado
                const SizedBox(height: 40),
                _buildBotaoEnviar(),  // botão de ação principal
              ],
            ),
          ),
        ),
      ),
    );
  }

  // AppBar com botão de voltar e linha de gradiente decorativa
  AppBar _buildAppBar() => AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: _isLoading ? null : _voltarOuSair, // desabilitado durante loading
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(
            height: 2,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [
                Color(0xFF6C63FF),
                Color(0xFFE040FB),
                Color(0xFFFF6B6B),
              ]),
            ),
          ),
        ),
      );

  // Título + subtítulo + divisor
  Widget _buildHeader() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            'Confirme sua identidade por e-mail',
            style: TextStyle(fontSize: 14, color: Colors.black45),
          ),
          const SizedBox(height: 4),
          const Divider(color: Color(0xFFEEEEEE)),
        ],
      );

  // Banner roxo claro — texto muda conforme o fluxo (ativação ou login)
  Widget _buildInfoBanner() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEAE8FF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // RichText permite aplicar estilos diferentes na mesma linha de texto
            RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 13, color: Colors.black87, height: 1.5),
                children: widget.onMfaAtivado != null
                    ? const [
                        TextSpan(text: 'Confirme seu acesso para '),
                        TextSpan(
                          text: 'ativar o 2FA.',
                          style: TextStyle(
                            color: Color(0xFF6C63FF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ]
                    : [
                        // Fluxo de login: mostra o nome do usuário em destaque
                        TextSpan(
                          text: widget.profile.displayName,
                          style: const TextStyle(
                            color: Color(0xFF6C63FF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const TextSpan(
                            text: ' possui autenticação multifator ativa.'),
                      ],
              ),
            ),
            const SizedBox(height: 6),
            // Descrição da ação — também muda conforme o fluxo
            Text(
              widget.onMfaAtivado != null
                  ? 'Enviaremos um link para o e-mail cadastrado. Clique nele para confirmar e ativar a proteção extra.'
                  : 'Enviaremos um link de verificação para o e-mail cadastrado. Clique no link para concluir o login.',
              style: const TextStyle(
                  fontSize: 13, color: Colors.black54, height: 1.4),
            ),
          ],
        ),
      );

  // Card do e-mail — animado: roxo/ativo se tem e-mail, cinza/inativo se não tem
  Widget _buildEmailCard() {
    // Cores mudam dinamicamente conforme _temEmail
    final corBorda = _temEmail ? const Color(0xFF6C63FF) : const Color(0xFFE0E0E0);
    final corFundo = _temEmail ? const Color(0xFFF2F0FF) : const Color(0xFFF8F8F8);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180), // transição suave ao mudar estado
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: corBorda, width: 1.6),
      ),
      child: Row(
        children: [
          // Ícone de e-mail com fundo colorido
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _temEmail
                  ? const Color(0xFFEAE8FF)
                  : const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.email_outlined,
              color: _temEmail ? const Color(0xFF6C63FF) : Colors.black26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Receber por e-mail',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _temEmail ? Colors.black87 : Colors.black38,
                  ),
                ),
                const SizedBox(height: 4),
                // Exibe o e-mail mascarado ou aviso de ausência
                Text(
                  _temEmail
                      ? _mascararEmail(widget.profile.email)
                      : 'Nenhum e-mail disponível',
                  style: TextStyle(
                    fontSize: 13,
                    color: _temEmail ? Colors.black54 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
          // Indicador de seleção (radio button visual)
          Icon(
            Icons.radio_button_checked,
            color: _temEmail ? const Color(0xFF6C63FF) : Colors.black26,
          ),
        ],
      ),
    );
  }

  // Botão principal — desabilitado se não tem e-mail ou está carregando
  Widget _buildBotaoEnviar() => SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton(
          onPressed: _isLoading || !_temEmail ? null : _enviarCodigo,
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              // Borda fica cinza quando desabilitado
              color: (_isLoading || !_temEmail) ? Colors.grey : Colors.black87,
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          // Spinner durante loading, texto quando disponível
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                  ),
                )
              : const Text(
                  'Enviar link de verificação',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
        ),
      );
}