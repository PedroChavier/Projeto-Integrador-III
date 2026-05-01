import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import '../startups/startup_detail.dart';

class StartupsScreen extends StatefulWidget {
  const StartupsScreen({super.key});

  @override
  State<StartupsScreen> createState() => _StartupsScreenState();
}

class _StartupsScreenState extends State<StartupsScreen> {
  final _searchController = TextEditingController();
  String _filtroSelecionado = 'Todas';

  final List<String> _filtros = ['Todas', 'Nova', 'Em operação', 'Em expansão'];

  final List<Map<String, String>> _startups = [
    {
      'nome': 'AgroSense',
      'descricao': 'Monitoramento Agrícola em IOT e analise preditiva de pequenos produtores rurais',
      'status': 'Em expansão',
      'tokens': '50k',
      'capital': 'R\$ 180k',
      'preco': 'R\$ 25,00',
    },
    {
      'nome': 'AgroSense',
      'descricao': 'Monitoramento Agrícola em IOT e analise preditiva de pequenos produtores rurais',
      'status': 'Em operação',
      'tokens': '50k',
      'capital': 'R\$ 180k',
      'preco': 'R\$ 25,00',
    },
    {
      'nome': 'AgroSense',
      'descricao': 'Monitoramento Agrícola em IOT e analise preditiva de pequenos produtores rurais',
      'status': 'Nova',
      'tokens': '50k',
      'capital': 'R\$ 180k',
      'preco': 'R\$ 25,00',
    },
  ];

  List<Map<String, String>> get _startupsFiltradas {
    return _startups.where((s) {
      final matchFiltro = _filtroSelecionado == 'Todas' || s['status'] == _filtroSelecionado;
      final matchSearch = s['nome']!.toLowerCase().contains(_searchController.text.toLowerCase());
      return matchFiltro && matchSearch;
    }).toList();
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
        return const Color.fromARGB(137, 181, 144, 144);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 20),
            Container(
              height: 2,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFFE040FB), Color(0xFFFF6B6B)],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Startups',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEEEEE),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                        decoration: const InputDecoration(
                          hintText: 'Buscar Startup',
                          hintStyle: TextStyle(color: Colors.black38, fontSize: 14),
                          prefixIcon: Icon(Icons.search, color: Colors.black38, size: 20),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 13),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _filtros.map((filtro) {
                        final selected = _filtroSelecionado == filtro;
                        return GestureDetector(
                          onTap: () => setState(() => _filtroSelecionado = filtro),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected ? const Color(0xFFD7DEEC) : Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: selected ? const Color(0xFF234794) : const Color(0xFFDDDDDD),
                              ),
                            ),
                            child: Text(
                              filtro,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: selected ? const Color.fromARGB(255, 10, 10, 160) : Colors.black54,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    ..._startupsFiltradas.map((startup) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _StartupCard(
                            nome: startup['nome']!,
                            descricao: startup['descricao']!,
                            status: startup['status']!,
                            tokens: startup['tokens']!,
                            capital: startup['capital']!,
                            preco: startup['preco']!,
                            tagColor: _tagColor(startup['status']!),
                            tagTextColor: _tagTextColor(startup['status']!),
                          ),
                        )),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
}

class _StartupCard extends StatelessWidget {
  final String nome;
  final String descricao;
  final String status;
  final String tokens;
  final String capital;
  final String preco;
  final Color tagColor;
  final Color tagTextColor;

  const _StartupCard({
    required this.nome,
    required this.descricao,
    required this.status,
    required this.tokens,
    required this.capital,
    required this.preco,
    required this.tagColor,
    required this.tagTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const StartupDetalheScreen(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color.fromARGB(255, 248, 248, 253),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  nome,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: tagColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tagTextColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              descricao,
              style: const TextStyle(
                fontSize: 13,
                color: Color.fromARGB(137, 0, 0, 0),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _Metrica(label: 'Tokens', valor: tokens),
                const SizedBox(width: 24),
                _Metrica(label: 'Capital', valor: capital),
                const SizedBox(width: 24),
                _Metrica(label: 'Preço token', valor: preco),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metrica extends StatelessWidget {
  final String label;
  final String valor;

  const _Metrica({required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black38),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

