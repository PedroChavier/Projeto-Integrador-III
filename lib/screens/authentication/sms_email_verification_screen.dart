import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import 'two_fa_verification_screen.dart';

enum _MetodoMfa { email, sms }

class SmsEmailVerificationScreen extends StatefulWidget {
  const SmsEmailVerificationScreen({
    super.key,
    required this.profile,
    this.onMfaAtivado,
  });

  final UserProfile profile;
  /// Quando fornecido, indica fluxo de ativação de 2FA vindo do perfil.
  /// Chamado após código verificado com sucesso; a tela é fechada com pop().
  final Future<void> Function()? onMfaAtivado;

  @override
  State<SmsEmailVerificationScreen> createState() =>
      _SmsEmailVerificationScreenState();
}

class _SmsEmailVerificationScreenState
    extends State<SmsEmailVerificationScreen> {
  final AuthService _authService = AuthService();

  _MetodoMfa? _metodoSelecionado;
  bool _isLoading = false;

  bool get _temEmail => widget.profile.email.trim().isNotEmpty;
  bool get _temTelefone =>
      _somenteDigitos(widget.profile.telefone).length >= 10;

  Future<void> _enviarCodigo() async {
    final metodo = _metodoSelecionado;

    if (metodo == null) {
      _mostrarMensagem(
        'Selecione como deseja receber o codigo.',
        isError: true,
      );
      return;
    }

    final canal = metodo == _MetodoMfa.email ? 'email' : 'sms';
    final destino = metodo == _MetodoMfa.email
        ? _mascararEmail(widget.profile.email)
        : _mascararTelefone(widget.profile.telefone);

    setState(() => _isLoading = true);

    try {
      if (!mounted) return;

      final functions = FirebaseFunctions.instanceFor(
        region: 'southamerica-east1',
      );

      final callable = functions.httpsCallable('solicitarCodigoMfa');

      await callable.call(<String, dynamic>{
        'canal': canal,
      });

      if (!mounted) return;

      _mostrarMensagem('Codigo enviado por $canal para $destino.');

      final resultado = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => Verificacao2FAScreen(
            canal: canal,
            destinoMascarado: destino,
            onVerificado: widget.onMfaAtivado != null ? () {} : null,
          ),
        ),
      );

      if (resultado == true && widget.onMfaAtivado != null && mounted) {
        try {
          await widget.onMfaAtivado!();
          if (mounted) Navigator.of(context).pop();
        } catch (_) {
          if (mounted) {
            _mostrarMensagem('Erro ao salvar configuracao do 2FA.', isError: true);
          }
        }
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      _mostrarMensagem(
        'Falha ao enviar o codigo: ${e.code} - ${e.message ?? 'sem mensagem'}.',
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;
      _mostrarMensagem(
        'Erro ao enviar o codigo: ${e.toString()}',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _voltarParaLogin() async {
    // No fluxo de ativação (vindo do perfil), apenas volta sem encerrar sessão.
    if (widget.onMfaAtivado != null) {
      Navigator.of(context).maybePop();
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.signOut();
    } catch (_) {
      if (!mounted) return;
      _mostrarMensagem(
        'Nao foi possivel encerrar a sessao agora.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).maybePop();
      }
    }
  }

  void _mostrarMensagem(String mensagem, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: isError ? Colors.red[400] : Colors.green[400],
      ),
    );
  }

  String _somenteDigitos(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _mascararEmail(String email) {
    final partes = email.trim().split('@');
    if (partes.length != 2) return email;

    final usuario = partes[0];
    final dominio = partes[1];

    if (usuario.length <= 2) {
      return '${usuario[0]}***@$dominio';
    }

    return '${usuario[0]}${'*' * (usuario.length - 2)}${usuario[usuario.length - 1]}@$dominio';
  }

  String _mascararTelefone(String telefone) {
    final digits = _somenteDigitos(telefone);
    if (digits.length < 10) return telefone;

    final ddd = digits.substring(0, 2);
    final finalNumero = digits.substring(digits.length - 2);
    return '($ddd) *****-$finalNumero';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _voltarParaLogin();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: _isLoading ? null : _voltarParaLogin,
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
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
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Verificacao 2FA',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Escolha como receber seu codigo de 6 digitos',
                  style: TextStyle(fontSize: 14, color: Colors.black45),
                ),
                const SizedBox(height: 4),
                const Divider(color: Color(0xFFEEEEEE)),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAE8FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                            height: 1.5,
                          ),
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
                                  const TextSpan(text: 'A conta de '),
                                  TextSpan(
                                    text: widget.profile.displayName,
                                    style: const TextStyle(
                                      color: Color(0xFF6C63FF),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const TextSpan(
                                    text: ' possui autenticacao multifator ativa.',
                                  ),
                                ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.onMfaAtivado != null
                            ? 'Escolha como receber o codigo e confirme para ativar a protecao extra na sua conta.'
                            : 'Para concluir o login, envie um codigo temporario e depois confirme os 6 digitos recebidos.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _OpcaoCanalCard(
                  icon: Icons.email_outlined,
                  titulo: 'Receber por e-mail',
                  subtitulo: _temEmail
                      ? _mascararEmail(widget.profile.email)
                      : 'Nenhum e-mail disponivel',
                  selecionado: _metodoSelecionado == _MetodoMfa.email,
                  habilitado: _temEmail,
                  onTap: _isLoading || !_temEmail
                      ? null
                      : () => setState(
                            () => _metodoSelecionado = _MetodoMfa.email,
                          ),
                ),
                const SizedBox(height: 16),
                _OpcaoCanalCard(
                  icon: Icons.sms_outlined,
                  titulo: 'Receber por SMS',
                  subtitulo: _temTelefone
                      ? _mascararTelefone(widget.profile.telefone)
                      : 'Nenhum telefone disponivel',
                  selecionado: _metodoSelecionado == _MetodoMfa.sms,
                  habilitado: _temTelefone,
                  onTap: _isLoading || !_temTelefone
                      ? null
                      : () =>
                          setState(() => _metodoSelecionado = _MetodoMfa.sms),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _enviarCodigo,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _isLoading ? Colors.grey : Colors.black87,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.black87,
                              ),
                            ),
                          )
                        : const Text(
                            'Enviar codigo de 6 digitos',
                            style: TextStyle(
                              fontSize: 16,
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
      ),
    );
  }
}

class _OpcaoCanalCard extends StatelessWidget {
  const _OpcaoCanalCard({
    required this.icon,
    required this.titulo,
    required this.subtitulo,
    required this.selecionado,
    required this.habilitado,
    required this.onTap,
  });

  final IconData icon;
  final String titulo;
  final String subtitulo;
  final bool selecionado;
  final bool habilitado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final corBorda = !habilitado
        ? const Color(0xFFE0E0E0)
        : selecionado
            ? const Color(0xFF6C63FF)
            : const Color(0xFFDDDDDD);

    final corFundo = !habilitado
        ? const Color(0xFFF8F8F8)
        : selecionado
            ? const Color(0xFFF2F0FF)
            : Colors.white;

    final corTexto = habilitado ? Colors.black87 : Colors.black38;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: corFundo,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: corBorda, width: selecionado ? 1.6 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: habilitado
                    ? const Color(0xFFEAE8FF)
                    : const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: habilitado ? const Color(0xFF6C63FF) : Colors.black26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: corTexto,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitulo,
                    style: TextStyle(
                      fontSize: 13,
                      color: habilitado ? Colors.black54 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selecionado
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off_outlined,
              color: habilitado
                  ? (selecionado ? const Color(0xFF6C63FF) : Colors.black26)
                  : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}
