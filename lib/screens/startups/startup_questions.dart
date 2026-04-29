import 'package:flutter/material.dart';

class PerguntasTab extends StatefulWidget {
  const PerguntasTab({super.key});

  @override
  State<PerguntasTab> createState() => _PerguntasTabState();
}

class _PerguntasTabState extends State<PerguntasTab> {
  final TextEditingController _msgController = TextEditingController();

  // Controla qual pergunta está com resposta aberta (null = nenhuma)
  int? _respostaAberta;

  final List<Map<String, String>> _perguntas = [
    {
      'iniciais': 'PD',
      'nome': 'Paula Domingues',
      'pergunta': 'Qual é o modelo de receita principal?',
      'resposta':
          'Assinatura Mensal por sensor ativo na lavoura, com planos escalonáveis por tamanho da propriedade',
    },
    {
      'iniciais': 'PD',
      'nome': 'Paula Domingues',
      'pergunta': 'Qual é o modelo de receita principal?',
      'resposta':
          'Assinatura Mensal por sensor ativo na lavoura, com planos escalonáveis por tamanho da propriedade',
    },
    {
      'iniciais': 'PD',
      'nome': 'Paula Domingues',
      'pergunta': 'Qual é o modelo de receita principal?',
      'resposta':
          'Assinatura Mensal por sensor ativo na lavoura, com planos escalonáveis por tamanho da propriedade',
    },
    {
      'iniciais': 'PD',
      'nome': 'Paula Domingues',
      'pergunta': 'Qual é o modelo de receita principal?',
      'resposta':
          'Assinatura Mensal por sensor ativo na lavoura, com planos escalonáveis por tamanho da propriedade',
    },
  ];

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Lista de perguntas
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            children: List.generate(_perguntas.length, (i) {
              final p = _perguntas[i];
              final aberta = _respostaAberta == i;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pergunta
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Avatar(iniciais: p['iniciais']!),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p['nome']!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                p['pergunta']!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 6),
                              // Linha separadora + botão
                              Row(
                                children: [
                                  const Expanded(
                                    child: Divider(
                                      height: 1,
                                      color: Color(0xFFDDDDDD),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _respostaAberta = aberta ? null : i;
                                      });
                                    },
                                    child: Text(
                                      aberta
                                          ? 'Ocultar Resposta'
                                          : 'Ver resposta de AgroSense',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF9E9E9E),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Resposta expandível
                    if (aberta)
                      Padding(
                        padding: const EdgeInsets.only(left: 44, top: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AgroSense',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              p['resposta']!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() => _respostaAberta = null);
                                },
                                child: const Text(
                                  'Ocultar Reposta',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF9E9E9E),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ),

        // Campo de envio
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              _Avatar(iniciais: 'AN'),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _msgController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Enviar Mensagem',
                    hintStyle:
                        const TextStyle(fontSize: 13, color: Colors.black38),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: Color(0xFF6C63FF), width: 1.5),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9F9F9),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 5, 5, 79),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  elevation: 0,
                ),
                child: const Text(
                  'Enviar',
                  style: TextStyle(fontSize: 13, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String iniciais;
  const _Avatar({required this.iniciais});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        color: Color(0xFFD1CEFF),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        iniciais,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6C63FF),
        ),
      ),
    );
  }
}