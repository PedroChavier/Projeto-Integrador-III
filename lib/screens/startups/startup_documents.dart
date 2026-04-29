import 'package:flutter/material.dart';

class DocumentosTab extends StatelessWidget {
  const DocumentosTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Documentos públicos',
            style: TextStyle(
                fontSize: 13, color: Colors.black45, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          _DocumentoItem(
            titulo: 'Sumário Executivo',
            descricao: 'Visão geral do negócio, mercado e proposta de valor',
            bloqueado: false,
          ),
          const SizedBox(height: 10),
          _DocumentoItem(
            titulo: 'Plano de Negócios',
            descricao: 'Projeções financeiras, estratégia e roadmap completo',
            bloqueado: false,
          ),
          const SizedBox(height: 10),
          _DocumentoItem(
            titulo: 'Pitch Deck',
            descricao: 'Apresentação para investidores versão pública',
            bloqueado: false,
          ),
          const SizedBox(height: 24),
          const Text(
            'Documentos exclusivos para investidores',
            style: TextStyle(
                fontSize: 13, color: Colors.black45, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          _DocumentoItem(
            titulo: 'Relatório financeiro detalhado',
            descricao: 'Disponível somente para investidores desta startup',
            linkText: 'Investir para desbloquear',
            bloqueado: true,
          ),
        ],
      ),
    );
  }
}

class _DocumentoItem extends StatelessWidget {
  final String titulo;
  final String descricao;
  final bool bloqueado;
  final String? linkText;

  const _DocumentoItem({
    required this.titulo,
    required this.descricao,
    required this.bloqueado,
    this.linkText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
                const SizedBox(height: 4),
                Text(descricao,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black45, height: 1.4)),
                if (linkText != null) ...[
                  const SizedBox(height: 6),
                  Text(linkText!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6C63FF),
                          fontWeight: FontWeight.w500)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            bloqueado ? Icons.lock_outline : Icons.download_outlined,
            size: 20,
            color: bloqueado ? Colors.black38 : Colors.black54,
          ),
        ],
      ),
    );
  }
}