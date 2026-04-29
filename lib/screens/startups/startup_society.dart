import 'package:flutter/material.dart';

class SociedadeTab extends StatelessWidget {
  const SociedadeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estrutura Societária',
            style: TextStyle(
                fontSize: 13, color: Colors.black45, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          _SocioItem(nome: 'Rafael Mendes (CEO)', percentual: '35%'),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          _SocioItem(nome: 'Laura Maria (CTO)', percentual: '30%'),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          _SocioItem(nome: 'Investidores (tokens)', percentual: '35%'),
          const SizedBox(height: 24),
          const Text(
            'Membros',
            style: TextStyle(
                fontSize: 13, color: Colors.black45, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          _MembroItem(iniciais: 'RA', nome: 'Rafael Mendes', cargo: 'CEO - Fundador'),
          const SizedBox(height: 12),
          _MembroItem(iniciais: 'RA', nome: 'Lara Costa', cargo: 'CTO - CoFundador'),
          const SizedBox(height: 24),
          const Text(
            'Mentores',
            style: TextStyle(
                fontSize: 13, color: Colors.black45, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          _MembroItem(
              iniciais: 'PM', nome: 'Professor Mateus', cargo: 'PUC - Campinas'),
        ],
      ),
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