import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';

class Setup2FAScreen extends StatefulWidget {
  const Setup2FAScreen({super.key});

  @override
  State<Setup2FAScreen> createState() => _Setup2FAScreenState();
}

class _Setup2FAScreenState extends State<Setup2FAScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isSaving = false;
  bool _show2FAStatus = true;
  String? _verificationId;
  final _otpController = TextEditingController();
  bool _isVerifyingOTP = false;

  late final AuthService _authService;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _currentUser = _authService.currentUser;
    _phoneController.text = '';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _ativarDoisFatores() async {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      _mostrarErro('Por favor, digite um número de telefone');
      return;
    }

    if (!phone.startsWith('+')) {
      _mostrarErro('Número deve iniciar com código do país (+55 para Brasil)');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.sendMFACode(
        phoneNumber: phone,
        onCodeSent: (String verificationId) {
          setState(() {
            _verificationId = verificationId;
            _show2FAStatus = false;
          });
          _mostrarSucesso('Código enviado para $phone');
        },
        onError: (FirebaseAuthException e) {
          _mostrarErro('Erro: ${e.message}');
        },
      );
    } catch (e) {
      _mostrarErro('Erro ao enviar código: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verificarOTPECompletarInscricao() async {
    final otp = _otpController.text.trim();

    if (otp.isEmpty || otp.length != 6) {
      _mostrarErro('Digite um código OTP válido (6 dígitos)');
      return;
    }

    if (_verificationId == null) {
      _mostrarErro('ID de verificação não disponível');
      return;
    }

    setState(() => _isVerifyingOTP = true);

    try {
      if (_currentUser == null) {
        _mostrarErro('Usuário não autenticado');
        return;
      }

      await _authService.completePhoneMfaEnrollment(
        verificationId: _verificationId!,
        smsCode: otp,
        phoneNumber: _phoneController.text.trim(),
      );

      if (mounted) {
        _mostrarSucesso('Dois fatores ativado com sucesso!');
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          setState(() {
            _show2FAStatus = true;
            _phoneController.clear();
            _otpController.clear();
            _verificationId = null;
          });
        }
      }
    } catch (e) {
      _mostrarErro('Erro ao verificar código: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isVerifyingOTP = false);
      }
    }
  }

  Future<void> _desativarDoisFatores() async {
    if (_currentUser == null) return;

    // Mostrar diálogo de confirmação
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desativar Dois Fatores?'),
        content: const Text(
          'Tem certeza que deseja desativar a autenticação de dois fatores? Sua conta será menos segura.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Desativar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      setState(() => _isSaving = true);

      try {
        await _authService.removeMultiFactorAuth();

        if (mounted) {
          _mostrarSucesso('Dois fatores desativado com sucesso');
          // Atualizar usuário atual
          _currentUser = _authService.currentUser;
        }
      } catch (e) {
        _mostrarErro('Erro ao desativar: ${e.toString()}');
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.red[400],
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _mostrarSucesso(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.green[400],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  bool _tem2FAAtivado() {
    if (_currentUser == null) return false;
    return _authService.isMultiFactorEnabled(_currentUser!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Segurança',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card de status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _tem2FAAtivado()
                    ? Colors.green[50]
                    : Colors.orange[50],
                border: Border.all(
                  color: _tem2FAAtivado()
                      ? Colors.green[300]!
                      : Colors.orange[300]!,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _tem2FAAtivado() ? Icons.verified : Icons.warning,
                    color: _tem2FAAtivado()
                        ? Colors.green[700]
                        : Colors.orange[700],
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tem2FAAtivado()
                              ? 'Dois Fatores Ativado'
                              : 'Dois Fatores Desativado',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _tem2FAAtivado()
                                ? Colors.green[700]
                                : Colors.orange[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _tem2FAAtivado()
                              ? 'Sua conta está protegida com autenticação de dois fatores'
                              : 'Ative a autenticação de dois fatores para maior segurança',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Seção de Dois Fatores
            if (_show2FAStatus) ...[
              const Text(
                'Autenticação de Dois Fatores',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Adicione uma camada extra de segurança verificando seu número de telefone',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              if (!_tem2FAAtivado()) ...[
                const Text(
                  'Número de Telefone',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: '+55 (11) 99999-9999',
                    hintStyle: const TextStyle(
                      color: Colors.black38,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(Icons.phone_outlined),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFF6C63FF),
                        width: 1.5,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _ativarDoisFatores,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      disabledBackgroundColor: Colors.black12,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Ativar Dois Fatores',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                    ),
                  ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    border: Border.all(color: Colors.blue[200]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verificado',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Seu telefone está protegido com 2FA',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _desativarDoisFatores,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[400],
                      disabledBackgroundColor: Colors.black12,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Desativar Dois Fatores',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                    ),
                  ),
              ],
            ] else ...[
              // Seção de verificação OTP
              const Text(
                'Digite o código OTP',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Um código foi enviado para seu telefone',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _otpController,
                enabled: !_isVerifyingOTP,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  hintText: '000000',
                  hintStyle: const TextStyle(
                    color: Colors.black26,
                    fontSize: 28,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFF6C63FF),
                      width: 2,
                    ),
                  ),
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed:
                      _isVerifyingOTP ? null : _verificarOTPECompletarInscricao,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    disabledBackgroundColor: Colors.black12,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isVerifyingOTP
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Verificar Código',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                  ),
                ),
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: _isVerifyingOTP
                      ? null
                      : () {
                          setState(() {
                            _show2FAStatus = true;
                            _verificationId = null;
                            _otpController.clear();
                          });
                        },
                  child: const Text(
                    'Voltar',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6C63FF),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
