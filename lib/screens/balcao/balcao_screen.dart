import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../home/home_screen.dart';

class BalcaoScreen extends StatefulWidget {
  const BalcaoScreen({super.key});
 
  @override
  State<BalcaoScreen> createState() => _BalcaoScreenState();
}
 
class _BalcaoScreenState extends State<BalcaoScreen> {
  final List<Map<String, dynamic>> _startups = [
    {'nome': 'AgroSense', 'variacao': '+8,2%', 'positivo': true},
    {'nome': 'EduTech', 'variacao': '+3,2%', 'positivo': true},
    {'nome': 'MedConnect', 'variacao': '-1,2%', 'positivo': false},
  ];
 
  int _startupSelecionada = 0;
  bool _dropdownAberto = false;
  int _tabSelecionada = 0;
 
  final _quantidadeController = TextEditingController(text: '10');
  final _precoController = TextEditingController(text: '25,00');
 
  final List<Map<String, String>> _ofertas = [
    {'compra': 'R\$ 24,90', 'compraQtd': '50 Tokens', 'venda': 'R\$ 25,00', 'vendaQtd': '30 Tokens'},
    {'compra': 'R\$ 24,50', 'compraQtd': '120 Tokens', 'venda': 'R\$ 25,50', 'vendaQtd': '80 Tokens'},
    {'compra': 'R\$ 24,00', 'compraQtd': '200 Tokens', 'venda': 'R\$ 26,00', 'vendaQtd': '150 Tokens'},
  ];
 
  double get _total {
    final qtd = double.tryParse(_quantidadeController.text.replaceAll(',', '.')) ?? 0;
    final preco = double.tryParse(_precoController.text.replaceAll(',', '.')) ?? 0;
    return qtd * preco;
  }
 
  @override
  void dispose() {
    _quantidadeController.dispose();
    _precoController.dispose();
    super.dispose();
  }
 
  
 
  @override
  Widget build(BuildContext context) {
    final startup = _startups[_startupSelecionada];
 
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
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
                    'Balcão de Tokens',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  const SizedBox(height: 20),
                  const Text('Selecione a Startup', style: TextStyle(fontSize: 12, color: Colors.black45)),
                  const SizedBox(height: 6),
 
                  // ── Dropdown com borda gradiente ──
                  GestureDetector(
                    onTap: () => setState(() => _dropdownAberto = !_dropdownAberto),
                    child: Container(
                      padding: const EdgeInsets.all(1.2),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(69, 0, 0, 0),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(8),
                          topRight: const Radius.circular(8),
                          bottomLeft: Radius.circular(_dropdownAberto ? 0 : 8),
                          bottomRight: Radius.circular(_dropdownAberto ? 0 : 8),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(7),
                            topRight: const Radius.circular(7),
                            bottomLeft: Radius.circular(_dropdownAberto ? 0 : 7),
                            bottomRight: Radius.circular(_dropdownAberto ? 0 : 7),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(startup['nome'],
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
                                Text(startup['variacao'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: startup['positivo'] ? const Color(0xFF2E7D32) : const Color(0xFFE53935),
                                    )),
                              ],
                            ),
                           Icon(
                              _dropdownAberto ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              color: Colors.black45,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
 
                  // Lista dropdown
                  if (_dropdownAberto)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFDDDDDD)),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                        color: Colors.white,
                      ),
                      child: Column(
                        children: List.generate(_startups.length, (i) {
                          final s = _startups[i];
                          final selected = i == _startupSelecionada;
                          return GestureDetector(
                            onTap: () => setState(() {
                              _startupSelecionada = i;
                              _dropdownAberto = false;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: selected ? const Color(0xFFF5F5F7) : Colors.white,
                                border: const Border(top: BorderSide(color: Color(0xFFEEEEEE))),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s['nome'],
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                                            color: Colors.black87,
                                          )),
                                      Text(s['variacao'],
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: s['positivo'] ? const Color(0xFF2E7D32) : const Color(0xFFE53935),
                                          )),
                                    ],
                                  ),
                                  if (selected)
                                    const Icon(Icons.check, color: Colors.black45, size: 16),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  const SizedBox(height: 20),
 
                  // ── Seção Comprar/Vender  ──
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color.fromARGB(69, 0, 0, 0)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        // Tabs
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _tabSelecionada = 0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: _tabSelecionada == 0 ? const Color(0xFF2E7D32) : const Color(0xFFEEEEEE),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Comprar',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: _tabSelecionada == 0 ? const Color(0xFF2E7D32) : Colors.black45,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _tabSelecionada = 1),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: _tabSelecionada == 1 ? const Color(0xFFE53935) : const Color(0xFFEEEEEE),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Vender',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: _tabSelecionada == 1 ? const Color(0xFFE53935) : Colors.black45,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
 
                        // Conteúdo interno
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Quantidade', style: TextStyle(fontSize: 13, color: Colors.black45)),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: _quantidadeController,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                          onChanged: (_) => setState(() {}),
                                          style: const TextStyle(fontSize: 14, color: Colors.black87),
                                          decoration: _inputDec(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Preço por token (R\$)', style: TextStyle(fontSize: 13, color: Colors.black45)),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: _precoController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          onChanged: (_) => setState(() {}),
                                          style: const TextStyle(fontSize: 14, color: Colors.black87),
                                          decoration: _inputDec(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: const [
                                  Text('Taxa Simulada', style: TextStyle(fontSize: 13, color: Colors.black45)),
                                  Text('R\$ 0,00', style: TextStyle(fontSize: 13, color: Colors.black45)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Divider(height: 1, color:  Color.fromARGB(69, 0, 0, 0)),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
                                  Text(
                                    'R\$ ${_total.toStringAsFixed(2).replaceAll('.', ',')}',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text('Saldo disponível: R\$ 2.000,00',
                                  style: TextStyle(fontSize: 13, color: Colors.black45)),
                              const SizedBox(height: 16),
                             SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: OutlinedButton(
                                  onPressed: () {},
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color.fromARGB(112, 0, 0, 0), width: 1.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    backgroundColor: Colors.white,
                                  ),
                                  child: Text(
                                    _tabSelecionada == 0 ? 'Registrar oferta de compra' : 'Registrar oferta de venda',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color.fromARGB(197, 0, 0, 0)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
 
                  // ── Livro de ofertas com borda cinza ──
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                      borderRadius: BorderRadius.circular(10),  
                    ),
                    child: Column(
                      children: [
                        // Cabeçalho
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Color.fromARGB(69, 0, 0, 0))),
                          ),
                          child: Row(
                            children: const [
                              Expanded(
                                child: Text('Compra',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
                              ),
                              Expanded(
                                child: Text('Venda',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFE53935))),
                              ),
                            ],
                          ),
                        ),
                        // Linhas
                        ...List.generate(_ofertas.length, (i) {
                          final o = _ofertas[i];
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              border: i < _ofertas.length - 1
                                  ? const Border(bottom: BorderSide(color:  Color.fromARGB(69, 0, 0, 0)))
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: RichText(
                                    textAlign: TextAlign.center,
                                    text: TextSpan(children: [
                                      TextSpan(
                                          text: '${o['compra']} ',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
                                      TextSpan(
                                          text: '- ${o['compraQtd']}',
                                          style: const TextStyle(fontSize: 13,fontWeight: FontWeight.w500, color: Colors.black45)),
                                    ]),
                                  ),
                                ),
                                Expanded(
                                  child: RichText(
                                    textAlign: TextAlign.center,
                                    text: TextSpan(children: [
                                      TextSpan(
                                          text: '${o['venda']} ',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFE53935))),
                                      TextSpan(
                                          text: '- ${o['vendaQtd']}',
                                          style: const TextStyle(fontSize: 13,fontWeight: FontWeight.w500, color: Colors.black45)),
                                    ]),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }
 
  InputDecoration _inputDec() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color.fromARGB(125, 0, 0, 0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color.fromARGB(69, 0, 0, 0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color.fromARGB(255, 6, 1, 83), width: 1.5)),
      filled: true,
      fillColor: Colors.white,
    );
  }
}
