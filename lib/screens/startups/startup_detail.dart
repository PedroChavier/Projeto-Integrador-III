import 'package:flutter/material.dart';
import '../startups/startup_overview.dart';
import '../startups/startup_society.dart';
import '../startups/startup_documents.dart';
import '../startups/startup_questions.dart';
import '../home/home_screen.dart';
import '../balcao/balcao_screen.dart';
import '../../models/startup.dart';
import '../../services/startup_service.dart';

class StartupDetalheScreen extends StatefulWidget {
  final String startupUid;

  const StartupDetalheScreen({super.key, required this.startupUid});

  @override
  State<StartupDetalheScreen> createState() => _StartupDetalheScreenState();
}

class _StartupDetalheScreenState extends State<StartupDetalheScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final StartupService _service = StartupService();
  Startup? _startup;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _carregarStartup();
  }

  Future<void> _carregarStartup() async {
    try {
      final startup = await _service.getStartup(widget.startupUid);
      if (mounted) setState(() { _startup = startup; _carregando = false; });
    } catch (_) {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatarCapital(double valor) {
    if (valor >= 1000000) return 'R\$ ${(valor / 1000000).toStringAsFixed(1)}M';
    if (valor >= 1000) return 'R\$ ${(valor / 1000).toStringAsFixed(0)}K';
    return 'R\$ ${valor.toStringAsFixed(0)}';
  }

  Color _tagColor(String status) {
    switch (status) {
      case 'Em expansão':
        return const Color(0xFFFFF3E0);
      case 'Em operação':
        return const Color(0xFFE8F5E9);
      case 'Nova':
        return const Color(0xFFE8E6FF);
      default:
        return const Color(0xFFEEEEEE);
    }
  }

  Color _tagTextColor(String status) {
    switch (status) {
      case 'Em expansão':
        return const Color(0xFFE65100);
      case 'Em operação':
        return const Color(0xFF2E7D32);
      case 'Nova':
        return const Color(0xFF6C63FF);
      default:
        return Colors.black54;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _startup;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
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
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.black87, size: 22),
                    onPressed: () => Navigator.maybePop(context),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    constraints: const BoxConstraints(),
                  ),
                  if (_carregando)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s?.nome ?? '',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                s?.setor ?? '',
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.black45),
                              ),
                            ],
                          ),
                          if (s?.status != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: _tagColor(s!.status!),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                s.status!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _tagTextColor(s.status!),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Capital captado',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.black45)),
                              Text(
                                s == null
                                    ? ''
                                    : '${_formatarCapital(s.cptAportado)} / ${_formatarCapital(s.metaCapital)}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black45),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Stack(
                              children: [
                                Container(
                                    height: 5,
                                    color: const Color(0xFFEEEEEE)),
                                FractionallySizedBox(
                                  widthFactor: s?.progressoCapital ?? 0,
                                  child: Container(
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: Color.fromARGB(143, 26, 34, 126),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const BalcaoScreen(abaInicial: 0),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF1A237E)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text(
                                'Comprar',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A237E),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const BalcaoScreen(abaInicial: 1),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A237E),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Vender',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  TabBar(
                    controller: _tabController,
                    labelStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    unselectedLabelStyle: const TextStyle(fontSize: 13),
                    labelColor: const Color(0xFF1A237E),
                    unselectedLabelColor: Colors.black45,
                    indicatorColor: const Color.fromARGB(143, 26, 34, 126),
                    indicatorWeight: 2,
                    tabs: const [
                      Tab(text: 'Visão Geral'),
                      Tab(text: 'Sociedade'),
                      Tab(text: 'Perguntas'),
                      Tab(text: 'Documentos'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                VisaoGeralTab(startup: _startup),
                const SociedadeTab(),
                const PerguntasTab(),
                const DocumentosTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
}