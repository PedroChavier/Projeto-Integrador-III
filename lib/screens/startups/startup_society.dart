import 'package:flutter/material.dart';
import '../../models/startup.dart';

class SociedadeTab extends StatelessWidget {
  final Startup? startup;
  const SociedadeTab({super.key, required this.startup});

  String _iniciais(String nome) {
    final partes = nome.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes[0][0].toUpperCase();
    return (partes[0][0] + partes[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final s = startup;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Estrutura Societária ──────────────────────────────
          const Text(
            'Estrutura Societária',
            style: TextStyle(
                fontSize: 13,
                color: Colors.black45,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          if (s == null || s.socios.isEmpty)
            const _EmptyState(mensagem: 'Nenhum sócio cadastrado.')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: s.socios.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
              itemBuilder: (_, i) => _SocioItem(
                nome: s.socios[i].nome,
                percentual: s.socios[i].percentual,
              ),
            ),

          const SizedBox(height: 24),

          // ── Membros ───────────────────────────────────────────
          const Text(
            'Membros',
            style: TextStyle(
                fontSize: 13,
                color: Colors.black45,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          if (s == null || s.membros.isEmpty)
            const _EmptyState(mensagem: 'Nenhum membro cadastrado.')
          else
            Column(
              children: s.membros
                  .map((m) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MembroItem(
                          iniciais: _iniciais(m.nome),
                          nome: m.nome,
                          cargo: m.cargo,
                        ),
                      ))
                  .toList(),
            ),

          const SizedBox(height: 24),

          // ── Mentores ──────────────────────────────────────────
          const Text(
            'Mentores',
            style: TextStyle(
                fontSize: 13,
                color: Colors.black45,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          if (s == null || s.mentores.isEmpty)
            const _EmptyState(mensagem: 'Nenhum mentor cadastrado.')
          else
            Column(
              children: s.mentores
                  .map((m) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MembroItem(
                          iniciais: _iniciais(m.nome),
                          nome: m.nome,
                          cargo: m.cargo,
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

// ── Widgets internos ──────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String mensagem;
  const _EmptyState({required this.mensagem});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(mensagem,
          style: const TextStyle(fontSize: 13, color: Colors.black38)),
    );
  }
}

class _SocioItem extends StatelessWidget {
  final String nome;
  final String percentual;
  const _SocioItem({required this.nome, required this.percentual});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(nome,
              style: const TextStyle(fontSize: 14, color: Colors.black87)),
          Text(percentual,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
        ],
      ),
    );
  }
}

class _MembroItem extends StatelessWidget {
  final String iniciais;
  final String nome;
  final String cargo;
  const _MembroItem(
      {required this.iniciais, required this.nome, required this.cargo});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: Color(0xFFD1CEFF),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(iniciais,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6C63FF))),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nome,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87)),
            Text(cargo,
                style: const TextStyle(fontSize: 12, color: Colors.black45)),
          ],
        ),
      ],
    );
  }
}