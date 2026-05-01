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
                  SizedBox(height: 20),
                  
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
                                  fontSize: 13, color: Colors.black45),
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
                                    fontSize: 12, color: Colors.black45)),
                            Text('R\$ 180K / 250K',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.black45)),
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
                                  color:  Color.fromARGB(143, 26, 34, 126),
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
                              side: const BorderSide(color:  Color(0xFF1A237E)),
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
                                color:  Color(0xFF1A237E),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor:  Color(0xFF1A237E),
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
                    labelColor:  Color(0xFF1A237E),
                    unselectedLabelColor: Colors.black45,
                    indicatorColor: Color.fromARGB(143, 26, 34, 126),
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
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
}

