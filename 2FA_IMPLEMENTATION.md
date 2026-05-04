# Autenticação de Dois Fatores (2FA) com Firebase Auth

## Visão Geral

Esta implementação fornece autenticação de dois fatores (2FA) completa usando Firebase Authentication com verificação por SMS (OTP). O sistema permite que usuários ativem/desativem 2FA em suas contas e verifi em o código OTP durante o login.

## Arquivos Criados/Modificados

### 1. **AuthService** (`lib/services/auth_service.dart`)
Serviço principal de autenticação com métodos para:
- Login padrão
- Verificação de MFA durante login
- Inscrição em MFA (adicionar telefone)
- Verificação de código OTP
- Remoção de fatores de autenticação

**Métodos principais:**
```dart
// Verificar se usuário tem 2FA ativado
bool isMultiFactorEnabled(User user)

// Obter lista de fatores inscritos
List<MultiFactor> getEnrolledFactors(User user)

// Enviar código de verificação
Future<void> sendMFACode(...)

// Completar inscrição de 2FA
Future<void> completePhoneMfaEnrollment(...)

// Verificar 2FA durante login
Future<UserCredential> verifyAndSignInWithMFA(...)

// Remover 2FA
Future<void> removeMultiFactorAuth(...)
```

### 2. **VerifyOTPScreen** (`lib/screens/authentication/verify_otp_screen.dart`)
Tela para verificar o código OTP enviado durante login 2FA.

**Características:**
- Entrada de código OTP de 6 dígitos
- Temporizador com contagem regressiva
- Opção de reenviar código
- Validação automática

### 3. **Setup2FAScreen** (`lib/screens/authentication/setup_2fa_screen.dart`)
Tela para ativar/desativar 2FA nas configurações da conta.

**Características:**
- Status visual de 2FA (ativado/desativado)
- Formulário para inserir número de telefone
- Verificação de código OTP
- Opção de desativar 2FA com confirmação

### 4. **LoginScreen** (modificado)
Atualizado para lidar com o fluxo de 2FA:
- Detecta quando 2FA é necessário
- Navega para `VerifyOTPScreen` automaticamente
- Mantém compatibilidade com login padrão

### 5. **TwoFactorAuthSettings** (`lib/models/two_factor_auth_settings.dart`)
Modelo de dados para armazenar configurações de 2FA:
```dart
class TwoFactorAuthSettings {
  final String userId;
  final bool isEnabled;
  final String? phoneNumber;
  final DateTime? enrolledAt;
  final List<String> backupCodes;
  final String? lastVerificationDate;
}
```

### 6. **TwoFactorAuthService** (`lib/services/two_factor_auth_service.dart`)
Serviço para gerenciar dados de 2FA no Firestore:
- Salvar/obter configurações
- Verificar status de 2FA
- Gerar e armazenar códigos de backup
- Stream para monitorar mudanças

## Fluxo de Autenticação

### Login com 2FA Ativado

```
1. Usuário insere email e senha
   ↓
2. LoginScreen.login() é chamado
   ↓
3. Se 2FA está ativado → FirebaseAuthException('multi-factor-auth-required')
   ↓
4. Navega para VerifyOTPScreen
   ↓
5. Usuário recebe OTP por SMS
   ↓
6. Usuário digita OTP
   ↓
7. VerifyOTPScreen.verifyAndSignInWithMFA() é chamado
   ↓
8. Se código correto → Login bem-sucedido → Navega para HomeScreen
   Se código incorreto → Erro e tenta novamente
```

### Ativação de 2FA

```
1. Usuário navega para Setup2FAScreen
   ↓
2. Insere número de telefone (+55...)
   ↓
3. Clica em "Ativar Dois Fatores"
   ↓
4. Recebe OTP por SMS
   ↓
5. Digita OTP na tela
   ↓
6. Código verificado → 2FA ativado ✓
```

## Como Usar

### 1. Adicionar a Tela de Setup 2FA ao Menu

No seu `home_screen.dart` ou menu de configurações:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const Setup2FAScreen(),
  ),
);
```

### 2. Verificar se Usuário tem 2FA Ativado

```dart
final authService = AuthService();
final currentUser = authService.currentUser;

if (currentUser != null) {
  bool tem2FA = authService.isMultiFactorEnabled(currentUser);
  print('2FA ativado: $tem2FA');
}
```

### 3. Obter Configurações de 2FA do Firestore

```dart
final twoFactorService = TwoFactorAuthService();
final userId = FirebaseAuth.instance.currentUser?.uid;

if (userId != null) {
  final settings = await twoFactorService.getTwoFactorSettings(userId);
  print('Telefone: ${settings?.phoneNumber}');
  print('Ativado: ${settings?.isEnabled}');
}
```

### 4. Usar Stream para Monitorar Mudanças

```dart
final twoFactorService = TwoFactorAuthService();
final userId = FirebaseAuth.instance.currentUser?.uid;

if (userId != null) {
  twoFactorService.getTwoFactorSettingsStream(userId).listen((settings) {
    setState(() {
      _twoFactorEnabled = settings?.isEnabled ?? false;
    });
  });
}
```

## Configuração do Firebase

### 1. Habilitar SMS Provider no Firebase Console

1. Vá para Firebase Console → Authentication
2. Clique na aba "Sign-in method"
3. Habilite "Phone" se ainda não estiver habilitado
4. Configure o reCAPTCHA (necessário para SMS)

### 2. Configurar Firestore (Opcional)

Para armazenar configurações de 2FA:

1. Vá para Firestore Database
2. Crie uma coleção chamada `2fa_settings`
3. Defina regras de segurança:

```firestore
match /2fa_settings/{userId} {
  allow read, write: if request.auth.uid == userId;
}
```

### 3. Configurar Regras de Segurança do Storage

Para verificação de telefone:
```firestore
match /databases/{database}/documents {
  match /{document=**} {
    allow read, write: if request.auth != null;
  }
}
```

## Fluxo de Erro Tratado

A implementação trata os seguintes cenários:

- ✅ Código OTP inválido
- ✅ Sessão expirada
- ✅ Número de telefone inválido
- ✅ Código não recebido
- ✅ Muitas tentativas
- ✅ Usuário desativado

## Segurança

### Boas Práticas Implementadas

1. **Verificação de MFA Obrigatória**: Código validado por Firebase
2. **Timeout de Sessão**: Código expira em 2 minutos
3. **Rate Limiting**: Firebase limita tentativas automáticamente
4. **Validação**: Todos os inputs são validados
5. **Proteção de Dados**: Senhas e OTPs não são armazenados localmente

### Recomendações Adicionais

1. **HTTPS Obrigatório**: Sempre use HTTPS em produção
2. **Backup Codes**: Implemente códigos de backup para recuperação
3. **Email Notifications**: Notifique usuários de login com 2FA bem-sucedido
4. **Auditoria**: Registre eventos de 2FA no Firestore
5. **Rate Limiting Backend**: Implemente limites de taxa no backend

## Testes

### Testar Fluxo Completo

1. **Criar Conta de Teste**:
```
Email: teste@example.com
Senha: Senha123456
Telefone: +55 11 999999999 (será rejeitado sem verificação real)
```

2. **Ativar 2FA**:
- Abrir Setup2FAScreen
- Inserir número de telefone
- Receber OTP (simular)
- Verificar código

3. **Login com 2FA**:
- Sair da conta
- Fazer login novamente
- Inserir OTP quando solicitado
- Verificar acesso bem-sucedido

### Usar Firebase Emulator (Recomendado)

Para testes locais sem enviar SMS real:

```bash
firebase emulators:start
```

## Troubleshooting

### Problema: "Invalid phone number"
- **Solução**: Use formato internacional (+55 para Brasil)

### Problema: Código não é enviado
- **Solução**: Verificar configuração de SMS no Firebase Console
- **Solução**: Verificar limites de quota

### Problema: Sessão expirada
- **Solução**: Reenviar código antes que expire (2 min)

### Problema: "requiresRecentLogin"
- **Solução**: Usuário precisa fazer login novamente (implementar no login)

## Próximas Melhorias Sugeridas

1. ✨ Implementar códigos de backup
2. ✨ Suporte a autenticadores (TOTP)
3. ✨ Email como fator adicional
4. ✨ Biometria como opção
5. ✨ Histórico de logins
6. ✨ Alertas de atividade suspeita

## Documentação Firebase

- [Firebase Phone Authentication](https://firebase.google.com/docs/auth/web/phone-auth)
- [Firebase MFA](https://firebase.google.com/docs/auth/web/multi-factor-auth-start)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)

## Suporte

Para problemas ou dúvidas, consulte:
- Firebase Documentation: https://firebase.google.com/docs
- Flutter Firebase: https://firebase.flutter.dev
- GitHub Issues do projeto

---

**Última atualização**: Maio 2026
