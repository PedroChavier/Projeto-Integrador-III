//Giovana Uchelli - 25008818

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/orderbook_models.dart';
import '../../models/wallet_holding.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/balcao_service.dart';
import '../balcao/balcao_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../profile/profile_screen.dart';
import '../startups/startups_catalog_screen.dart';
import '../wallet/wallet_screen.dart';

// ── Modelo local de Evento ────────────────────────────────────
// Representa um card de notícia/atualização exibido na Home.
// Definido aqui (e não em /models) por ser usado apenas nesta tela.
class Evento {
  final String id;
  final String titulo;
  final String descricao;
  final String tipo; // 'evento' | 'atualizacao' — define a cor do badge
  final DateTime data;

  const Evento({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.tipo,
    required this.data,
  });

  // Converte um documento do Firestore em Evento.
  // Timestamp é o tipo nativo do Firestore para datas — precisa de .toDate()
  factory Evento.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime date = DateTime.now();
    final ts = data['data'];
    if (ts is Timestamp) date = ts.toDate();

    return Evento(
      id:       id,
      titulo:   data['titulo']    as String? ?? '',
      descricao:data['descricao'] as String? ?? '',
      tipo:     data['tipo']      as String? ?? 'atualizacao',
      data:     date,
    );
  }
}

// ── Serviço de Eventos ────────────────────────────────────────
class EventoService {
  final FirebaseFirestore _firestore;

  EventoService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Stream em tempo real dos últimos [limite] eventos, ordenados do mais recente
  Stream<List<Evento>> watchEventos({int limite = 5}) {
    return _firestore
        .collection('eventos')
        .orderBy('data', descending: true)
        .limit(limite)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Evento.fromFirestore(doc.id, doc.data()))
            .toList());
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: SafeArea(
        child: Column(
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
            const Expanded(child: _HomeBody()),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }
}


class _HomeBody extends StatefulWidget {
  const _HomeBody();

  @override
  State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody> {
  final BalcaoService _balcaoService = BalcaoService();
  final EventoService _eventoService = EventoService();

  // Streams declarados como late e inicializados no initState (não no build)
  // para garantir que cada stream seja criado uma única vez
  late final Stream<Wallet> _walletStream;
  late final Stream<List<WalletHolding>> _holdingsStream;
  late final Stream<List<Evento>> _eventosStream;

  @override
  void initState() {
    super.initState();
    _walletStream   = _balcaoService.watchWallet();
    _holdingsStream = _balcaoService.watchHoldings();
    _eventosStream  = _eventoService.watchEventos();
  }

  @override
  Widget build(BuildContext context) {
    // Três StreamBuilders aninhados para combinar dados de fontes independentes.
    // Cada um escuta seu próprio stream e reconstrói apenas o necessário.
    return StreamBuilder<Wallet>(
      stream: _walletStream,
      builder: (context, walletSnap) {
        return StreamBuilder<List<WalletHolding>>(
          stream: _holdingsStream,
          builder: (context, holdingsSnap) {
            return StreamBuilder<List<Evento>>(
              stream: _eventosStream,
              builder: (context, eventosSnap) {
                // Fallback seguro: usa valor padrão enquanto o stream não emitiu
                final saldo    = walletSnap.data?.brl ?? 0;
                final holdings = holdingsSnap.data ?? const <WalletHolding>[];
                final eventos  = eventosSnap.data  ?? const <Evento>[];

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(),
                      const SizedBox(height: 24),
                      _SaldoCard(saldo: saldo, totalStartups: holdings.length),
                      const SizedBox(height: 28),

                      // Mostra skeleton enquanto holdings carrega, seção real quando pronto
                      if (holdingsSnap.connectionState == ConnectionState.waiting) ...[
                        const _TokensPlaceholder(),
                        const SizedBox(height: 28),
                      ] else if (holdings.isNotEmpty) ...[
                        _TokensSection(holdings: holdings),
                        const SizedBox(height: 28),
                      ],

                      // Spinner durante carregamento de eventos; seção real quando disponível
                      if (eventosSnap.connectionState == ConnectionState.waiting)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (eventos.isNotEmpty) ...[
                        _EventosSection(eventos: eventos),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ── Header ────────────────────────────────────────────────────
class _Header extends StatefulWidget {
  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  final AuthService _authService = AuthService();

  // FutureBuilder com Future iniciado no initState evita recarregar
  // o perfil a cada rebuild do widget pai
  Future<UserProfile?>? _perfilFuture;

  @override
  void initState() {
    super.initState();
    _perfilFuture = _authService.getCurrentUserProfile();
  }

  // Retorna apenas o primeiro nome (ex.: "João Silva" → "João")
  String _primeiroNome(String? nome) {
    if (nome == null || nome.trim().isEmpty) return '';
    return nome.trim().split(RegExp(r'\s+')).first;
  }

  // Gera as iniciais para o avatar (ex.: "João Silva" → "JS")
  String _iniciais(String? nome) {
    if (nome == null || nome.trim().isEmpty) return '';
    final partes = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.length >= 2) return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    return partes[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: _perfilFuture,
      builder: (context, snapshot) {
        final nome     = snapshot.data?.fullName ?? '';
        final iniciais = _iniciais(nome);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              nome.isNotEmpty ? 'Olá, ${_primeiroNome(nome)}' : 'Olá!',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.black87),
            ),
            // Avatar circular com iniciais — toque abre o perfil do usuário
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PerfilScreen()),
              ),
              child: Container(
                width: 42, height: 42,
                decoration: const BoxDecoration(color: Color(0xFFD1CEFF), shape: BoxShape.circle),
                alignment: Alignment.center,
                // Exibe iniciais quando disponíveis; ícone genérico como fallback
                child: iniciais.isNotEmpty
                    ? Text(iniciais,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF6C63FF)))
                    : const Icon(Icons.person, size: 22, color: Color(0xFF6C63FF)),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Card Saldo ────────────────────────────────────────────────
class _SaldoCard extends StatelessWidget {
  final double saldo;
  final int totalStartups;

  const _SaldoCard({required this.saldo, required this.totalStartups});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ', decimalDigits: 2);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9A1C63), Color(0xFF1A237E)], // rosa escuro → azul marinho
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Saldo Disponível',
              style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(fmt.format(saldo),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5)),
          // Linha de startups só aparece quando o usuário tem pelo menos 1 investimento
          if (totalStartups > 0) ...[
            const SizedBox(height: 16),
            Text(
              // Plural automático: "1 Startup Investida" vs "3 Startups Investidas"
              '$totalStartups ${totalStartups == 1 ? 'Startup Investida' : 'Startups Investidas'}',
              style: const TextStyle(fontSize: 13, color: Colors.white60),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Skeleton de Tokens (loading) ──────────────────────────────
// Exibe blocos cinzas no formato dos dados reais enquanto o stream não chegou
class _TokensPlaceholder extends StatelessWidget {
  const _TokensPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Meus tokens',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
        const SizedBox(height: 12),
        ...List.generate(2, (i) => Column(
          children: [
            if (i > 0) const Divider(height: 1, color: Color(0xFFEEEEEE)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(height: 14, width: 120,
                          decoration: BoxDecoration(color: const Color(0xFFEEEEEE), borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 6),
                      Container(height: 11, width: 70,
                          decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(4))),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Container(height: 14, width: 80,
                        decoration: BoxDecoration(color: const Color(0xFFEEEEEE), borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 6),
                    Container(height: 11, width: 60,
                        decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(4))),
                  ]),
                ],
              ),
            ),
          ],
        )),
      ],
    );
  }
}

// ── Seção de Tokens ───────────────────────────────────────────
class _TokensSection extends StatelessWidget {
  final List<WalletHolding> holdings;
  const _TokensSection({required this.holdings});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Meus tokens',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
        const SizedBox(height: 12),
        // asMap().entries fornece o índice (i) necessário para controlar o Divider
        ...holdings.asMap().entries.map((entry) {
          final i       = entry.key;
          final holding = entry.value;
          return Column(
            children: [
              if (i > 0) const Divider(height: 1, color: Color(0xFFEEEEEE)),
              _TokenItem(holding: holding),
            ],
          );
        }),
      ],
    );
  }
}

class _TokenItem extends StatelessWidget {
  final WalletHolding holding;
  const _TokenItem({required this.holding});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ', decimalDigits: 2);

    // Fallback para o UID caso o nome ainda não tenha sido carregado
    final nome = holding.startupNome.isNotEmpty ? holding.startupNome : holding.startupUid;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nome,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(height: 3),
              Text('${holding.quantidadeTotal} tokens',
                  style: const TextStyle(fontSize: 13, color: Colors.black45)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(fmt.format(holding.valorInvestido),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
            // Setor só é exibido quando o campo está preenchido
            if (holding.startupSetor.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(holding.startupSetor,
                  style: const TextStyle(fontSize: 12, color: Colors.black45)),
            ],
          ]),
        ],
      ),
    );
  }
}

// ── Seção de Eventos ──────────────────────────────────────────
class _EventosSection extends StatelessWidget {
  final List<Evento> eventos;
  const _EventosSection({required this.eventos});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Atualizações',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
        const SizedBox(height: 12),
        ...eventos.map((evento) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _EventoCard(evento: evento),
            )),
      ],
    );
  }
}

class _EventoCard extends StatelessWidget {
  final Evento evento;
  const _EventoCard({required this.evento});

  // Define cor de fundo e texto do badge conforme o tipo do evento
  ({Color bg, Color text, String label}) _tipoStyle() {
    switch (evento.tipo.toLowerCase()) {
      case 'evento':
        return (bg: const Color(0xFFF3E8FF), text: const Color(0xFFAB47BC), label: 'Evento');
      case 'atualizacao':
      default:
        return (bg: const Color(0xFFE8E6FF), text: const Color(0xFF6C63FF), label: 'Atualização');
    }
  }

  // Converte a data em texto relativo legível (ex.: "há 3h", "ontem", "em 2 dias")
  String _tempoRelativo(DateTime data) {
    final diff = DateTime.now().difference(data);
    if (diff.isNegative) {
      // Evento futuro
      final pos = data.difference(DateTime.now());
      if (pos.inDays == 0) return 'hoje';
      if (pos.inDays == 1) return 'amanhã';
      return 'em ${pos.inDays} dias';
    }
    // Evento passado
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes}min';
    if (diff.inHours < 24)   return 'há ${diff.inHours}h';
    if (diff.inDays == 1)    return 'ontem';
    return 'há ${diff.inDays} dias';
  }

  @override
  Widget build(BuildContext context) {
    final style = _tipoStyle();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(248, 244, 240, 240),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Badge colorido indicando o tipo do evento
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(20)),
                child: Text(style.label,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: style.text)),
              ),
              Text(_tempoRelativo(evento.data),
                  style: const TextStyle(fontSize: 12, color: Colors.black45)),
            ],
          ),
          const SizedBox(height: 10),
          Text(evento.titulo,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87)),
          // Descrição opcional — só renderiza quando existe conteúdo
          if (evento.descricao.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(evento.descricao,
                style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

// ── Bottom Nav (compartilhado entre todas as telas) ───────────
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  const AppBottomNav({super.key, required this.currentIndex});

  // Navega para a aba selecionada usando pushReplacement sem animação,
  // simulando o comportamento de troca de aba (sem empilhar na pilha)
  void _navigate(BuildContext context, int index) {
    if (index == currentIndex) return; // já está na aba — não faz nada

    Widget screen;
    switch (index) {
      case 0: screen = const HomeScreen();      break;
      case 1: screen = const StartupsScreen();  break;
      case 2: screen = const WalletScreen();    break;
      case 3: screen = const BalcaoScreen();    break;
      case 4: screen = const DashboardScreen(); break;
      default: return;
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionDuration: Duration.zero,        // sem animação entre abas
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex:        currentIndex,
      onTap:               (index) => _navigate(context, index),
      selectedItemColor:   const Color.fromARGB(255, 5, 0, 91),
      unselectedItemColor: Colors.black45,
      type:                BottomNavigationBarType.fixed, // mantém todos os itens visíveis
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined),                      label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.grid_view_outlined),                 label: 'Startups'),
        BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined),    label: 'Carteira'),
        BottomNavigationBarItem(icon: Icon(Icons.swap_horiz_outlined),                label: 'Balcão'),
        BottomNavigationBarItem(icon: Icon(Icons.trending_up_outlined),               label: 'DashBoard'),
      ],
    );
  }
}