//Giovana Uchelli - 25008818
import 'dart:async'; // Timer — usado para o polling periódico
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // autenticação e verificação de e-mail

import '../home/home_screen.dart'; // tela para onde o usuário vai após verificar


class Verificacao2FAScreen extends StatefulWidget {
  const Verificacao2FAScreen({
    super.key,
    this.canal = 'e-mail',           // canal de envio exibido na tela ("e-mail", "SMS"...)
    this.destinoMascarado = '',       // ex: "p***@gmail.com" — exibido na tela
    this.onVerificado,                // se fornecido, é fluxo de ATIVAÇÃO; se nulo, é fluxo de LOGIN
  });

  final String canal;
  final String destinoMascarado;
  final VoidCallback? onVerificado;

  @override
  State<Verificacao2FAScreen> createState() => _Verificacao2FAScreenState();
}

class _Verificacao2FAScreenState extends State<Verificacao2FAScreen> {

  // Polling a cada 4s; timeout de 5 minutos
  static const Duration _intervalo       = Duration(seconds: 4);
  static const int      _timeoutSegundos = 300;

  Timer? _pollingTimer;       // timer que verifica periodicamente se o e-mail foi confirmado
  int    _segundosPassados = 0;
  bool   _verificado  = false; // true quando emailVerified == true
  bool   _expirado    = false; // true quando passou os 5 minutos sem verificar
  bool   _reenviando  = false; // true enquanto o reenvio do link está em andamento

  @override
  void initState() {
    super.initState();
    _iniciarPolling(); // começa a checar o Firebase assim que a tela abre
  }

  // ─── Polling ──────────────────────────────────────────────────────────────

  // Cria um Timer que dispara a cada 4s e checa se o usuário já clicou no link
  void _iniciarPolling() {
    _pollingTimer?.cancel(); // cancela qualquer timer anterior antes de criar um novo
    setState(() {
      _verificado       = false;
      _expirado         = false;
      _segundosPassados = 0;
    });

    _pollingTimer = Timer.periodic(_intervalo, (_) async {
      if (!mounted) return; // widget foi destruído, não faz nada

      _segundosPassados += _intervalo.inSeconds;

      // Timeout atingido: para o polling e marca como expirado
      if (_segundosPassados >= _timeoutSegundos) {
        _pollingTimer?.cancel();
        if (mounted) setState(() => _expirado = true);
        return;
      }

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        // reload() força o Firebase a buscar o estado atual do usuário no servidor
        // sem isso, emailVerified ficaria com o valor em cache (sempre false)
        await user.reload();

        final emailVerificado =
            FirebaseAuth.instance.currentUser?.emailVerified ?? false;

        if (emailVerificado && mounted) {
          _pollingTimer?.cancel();
          setState(() => _verificado = true);
          await _concluir(); // navega para a próxima tela
        }
      } catch (_) {
        // Erro pontual de rede — ignora e tenta no próximo tick
      }
    });
  }

  // ─── Após confirmação ─────────────────────────────────────────────────────

  // Decide para onde ir após a verificação:
  // fluxo de ativação → pop(true) de volta para quem chamou
  // fluxo de login    → vai para a HomeScreen removendo toda a pilha de navegação
  Future<void> _concluir() async {
    if (!mounted) return;

    if (widget.onVerificado != null) {
      widget.onVerificado!();
      Navigator.of(context).pop(true);
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false, // remove todas as rotas anteriores
      );
    }
  }

  // ─── Reenviar link ────────────────────────────────────────────────────────

  // Chama o Firebase para enviar um novo e-mail de verificação
  // e reinicia o polling (zera o timeout)
  Future<void> _reenviar() async {
    if (_reenviando) return;
    setState(() => _reenviando = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Novo link enviado! Verifique seu e-mail.'),
            backgroundColor: Colors.green[400],
          ),
        );
        _iniciarPolling(); // reinicia o contador de 5 minutos
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao reenviar: $e'),
            backgroundColor: Colors.red[400],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _reenviando = false);
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel(); // SEMPRE cancela o timer para não vazar memória
    super.dispose();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => true, // permite voltar com o botão físico
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.of(context).pop(false), // false = não verificou
          ),
          // Linha decorativa de gradiente abaixo do AppBar
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
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildInfoBanner(),
                const SizedBox(height: 48),
                _buildStatusArea(),
                const SizedBox(height: 36),

                // Botão grande de reenvio — aparece só quando expirado
                if (_expirado) _buildBotaoReenviar(),

                // Link discreto de reenvio — aparece enquanto ainda está aguardando
                if (!_expirado && !_verificado) _buildAguardandoInfo(),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
          // Subtítulo muda conforme o fluxo: ativação ou login
          Text(
            widget.onVerificado != null ? 'Ativando proteção extra' : 'Passo 2 de 2',
            style: const TextStyle(fontSize: 14, color: Colors.black45),
          ),
          const SizedBox(height: 4),
          const Divider(color: Color(0xFFEEEEEE)),
        ],
      );

  // Banner roxo claro com instrução sobre o que o usuário deve fazer
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
            // RichText permite misturar estilos diferentes na mesma linha
            RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 13, color: Colors.black87, height: 1.5),
                children: widget.onVerificado != null
                    ? const [
                        TextSpan(text: 'Confirmando para '),
                        TextSpan(
                          text: 'ativar o 2FA.',
                          style: TextStyle(
                            color: Color(0xFF6C63FF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ]
                    : const [
                        TextSpan(text: 'Usuário com '),
                        TextSpan(
                          text: '2FA ativo.',
                          style: TextStyle(
                            color: Color(0xFF6C63FF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Clique no link enviado para o seu e-mail. Esta tela confirma automaticamente assim que o link for aberto.',
              style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
            ),
          ],
        ),
      );

  // Ícone central + texto de status — muda conforme o estado atual
  Widget _buildStatusArea() => Center(
        child: Column(
          children: [
            // AnimatedSwitcher troca o ícone com uma animação suave de fade
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _verificado
                  ? const Icon(Icons.check_circle_outline,
                      key: ValueKey('ok'),
                      size: 72,
                      color: Color(0xFF6C63FF))    // ✓ verde roxo — verificado
                  : _expirado
                      ? const Icon(Icons.timer_off_outlined,
                          key: ValueKey('exp'),
                          size: 72,
                          color: Colors.red)        // ✗ vermelho — expirado
                      : const _PulsingIcon(key: ValueKey('pulse')), // pulsando — aguardando
            ),
            const SizedBox(height: 20),
            Text(
              _verificado
                  ? 'E-mail verificado!'
                  : _expirado
                      ? 'Tempo esgotado'
                      : 'Aguardando verificação…',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _expirado ? Colors.red : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),

            // Exibe o destino mascarado enquanto aguarda (ex: "p***@gmail.com")
            if (!_verificado && !_expirado && widget.destinoMascarado.isNotEmpty)
              Text(
                'Link enviado por ${widget.canal} para ${widget.destinoMascarado}',
                style: const TextStyle(fontSize: 13, color: Colors.black45),
                textAlign: TextAlign.center,
              ),

            if (_expirado)
              const Text(
                'O link expirou. Reenvie para tentar novamente.',
                style: TextStyle(fontSize: 13, color: Colors.black45),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      );

  // Link discreto de reenvio — visível enquanto ainda está no prazo
  Widget _buildAguardandoInfo() => Center(
        child: Column(
          children: [
            const Text(
              'Não recebeu o e-mail?',
              style: TextStyle(fontSize: 14, color: Colors.black45),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _reenviando ? null : _reenviar,
              child: Text(
                _reenviando ? 'Reenviando…' : 'Reenviar link',
                style: TextStyle(
                  fontSize: 14,
                  color: _reenviando ? Colors.black26 : const Color(0xFF6C63FF),
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      );

  // Botão grande de reenvio — visível apenas quando o tempo expirou
  Widget _buildBotaoReenviar() => SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton(
          onPressed: _reenviando ? null : _reenviar,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.black87, width: 1.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: _reenviando
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  'Reenviar link de verificação',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
        ),
      );
}

// ─── Ícone pulsante enquanto aguarda ──────────────────────────────────────────

// Widget separado porque precisa do próprio AnimationController (StatefulWidget)
class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon({super.key});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin { // necessário para usar AnimationController

  late final AnimationController _ctrl;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true); // vai de 0.92 → 1.08 → 0.92 → ... infinitamente

    // Escala oscila entre 92% e 108% com easing suave
    _scale = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose(); // libera o controller para não vazar memória
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale, // aplica a animação de escala no ícone
      child: const Icon(
        Icons.mark_email_unread_outlined,
        size: 72,
        color: Color(0xFF6C63FF),
      ),
    );
  }
}