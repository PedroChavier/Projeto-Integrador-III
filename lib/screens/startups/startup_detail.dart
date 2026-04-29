import 'package:flutter/material.dart';
//importa as abas que serao exibidas dentro do detalhe da startup
import '../startups/startup_overview.dart';
import '../startups/startup_society.dart';
import '../startups/startup_documents.dart';
import '../startups/startup_questions.dart';
import '../home/home_screen.dart';

//Tela principal
class StartupDetalheScreen extends StatefulWidget {
  const StartupDetalheScreen({super.key});

  @override
  State<StartupDetalheScreen> createState() => _StartupDetalheScreenState();
}

class _StartupDetalheScreenState extends State<StartupDetalheScreen>
    with SingleTickerProviderStateMixin {
  
  //controlador das tabs
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    //inicializa o controller com 4 abas
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    //libera o controller ao sair da pagina
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Column(
        children: [
          // Header fixo, nao rola com o conteudo
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false, //eveita espaço em baixo
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gradiente
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
                    icon: const Icon(Icons.arrow_back,
                        color: Color.fromARGB(221, 0, 0, 0), size: 22),

                    //volta para a tela anterior
                    onPressed: () => Navigator.maybePop(context),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    constraints: const BoxConstraints(),
                  ),

                  // Nome da startup + categoria + status
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        //nome + segmento
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'AgroSense',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Agritech - IoT - Sensores',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.black45),
                            ),
                          ],
                        ),

                        //tag de status da startup
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Em expansão',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFE65100),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Barra de progresso de capitação
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text('Capital captado',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.black45)),
                            Text('R\$ 180K / 250K',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.black45)),
                          ],
                        ),
                        const SizedBox(height: 6),

                        //barra de progresso
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Stack(
                            children: [
                              Container(
                                height: 5,
                                color: const Color(0xFFEEEEEE),
                              ),
                              FractionallySizedBox(
                                widthFactor: 0.72, // 72% preenchida
                                child: Container(
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color.fromARGB(255, 49, 43, 163),
                                        Color(0xFFE040FB),
                                        Color(0xFFFF6B6B),
                                      ],
                                    ),
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
                  // Botões Comprar / Vender
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.black26),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'Comprar',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 5, 5, 79),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
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
                  const SizedBox(height: 4),
                  // TabBar
                  TabBar(
                    controller: _tabController,
                    labelStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    unselectedLabelStyle:
                        const TextStyle(fontSize: 13),
                    labelColor: const Color(0xFF6C63FF),
                    unselectedLabelColor: Colors.black45,
                    indicatorColor: const Color(0xFF6C63FF),
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

          // ── Conteúdo das abas ─────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                VisaoGeralTab(),
                SociedadeTab(),
                PerguntasTab(),
                DocumentosTab(),
              ],
            ),
          ),

          // ── Bottom Nav ────────────────────────────────────────
          const _BottomNav(),
        ],
      ),
    );
  }
}

// ── Bottom Navigation ─────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
             _NavItem(
                icon: Icons.home_outlined,
                label: 'Home',
                onTap: () {
                  navigateNoAnimation(context, const HomeScreen());
                },
              ),
              _NavItem(
                  icon: Icons.grid_view_outlined,
                  label: 'Startups',
                  selected: true),
              _NavItem(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Carteira'),
              _NavItem(icon: Icons.swap_horiz_outlined, label: 'Balcão'),
              _NavItem(
                  icon: Icons.trending_up_outlined, label: 'DashBoard'),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF6C63FF) : Colors.black45;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

void navigateNoAnimation(BuildContext context, Widget page) {
  Navigator.pushReplacement(
    context,
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
}