import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/startup.dart';

class VisaoGeralTab extends StatelessWidget {
  final Startup? startup;

  const VisaoGeralTab({super.key, this.startup});

  static const String _youtubeUrl = 'https://www.youtube.com/watch?v=SEU_VIDEO_ID';

  Future<void> _abrirYoutube() async {
    final uri = Uri.parse(_youtubeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatarValor(double valor) {
    if (valor >= 1000000) return 'R\$ ${(valor / 1000000).toStringAsFixed(1)}M';
    if (valor >= 1000) return 'R\$ ${(valor / 1000).toStringAsFixed(0)}K';
    return 'R\$ ${valor.toStringAsFixed(2)}';
  }

  String _formatarTokens(int valor) {
    if (valor >= 1000000) return '${(valor / 1000000).toStringAsFixed(1)}M';
    if (valor >= 1000) return '${(valor / 1000).toStringAsFixed(0)}K';
    return valor.toString();
  }

  @override
  Widget build(BuildContext context) {
    final s = startup;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s?.descricao ?? '',
            style: const TextStyle(
                fontSize: 13.5, color: Colors.black54, height: 1.6),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _MetricaBox(
                label: 'Tokens Emitidos',
                valor: s == null ? '-' : _formatarTokens(s.totalTokensEmitidos),
                icon: Icons.token_outlined,
              ),
              const SizedBox(width: 12),
              _MetricaBox(
                label: 'Preço Atual',
                valor: s == null
                    ? '-'
                    : 'R\$ ${s.precoToken.toStringAsFixed(2).replaceAll('.', ',')}',
                icon: Icons.trending_up,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MetricaBox(
                label: 'Investidores',
                valor: s == null ? '-' : s.nmrInvestidores.toString(),
                icon: Icons.people_outline,
              ),
              const SizedBox(width: 12),
              _MetricaBox(
                label: 'Captado',
                valor: s == null ? '-' : _formatarValor(s.cptAportado),
                icon: Icons.account_balance_outlined,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Video Demonstrativo',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _abrirYoutube,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      'https://images.unsplash.com/photo-1500382017468-9049fed747ef',
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: const Color(0xFFDDDDDD),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF6C63FF),
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) =>
                          Container(color: const Color(0xFFDDDDDD)),
                    ),
                    Container(color: Colors.black.withOpacity(0.30)),
                    Center(
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Color.fromARGB(255, 5, 5, 79),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow,
                            color: Colors.white, size: 28),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 12,
                      child: Text(
                        s?.nome != null ? '${s!.nome} - Demo' : 'Demo',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _MetricaBox extends StatelessWidget {
  final String label;
  final String valor;
  final String? subvalor;
  final Color? subColor;
  final IconData icon;

  const _MetricaBox({
    required this.label,
    required this.valor,
    required this.icon,
    this.subvalor,
    this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 90,
        child: Container(
          padding: const EdgeInsets.all(12),
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(46, 212, 214, 239),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF1A237E), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color.fromARGB(169, 0, 0, 0))),
                    const SizedBox(height: 2),
                    Text(valor,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87)),
                    if (subvalor != null)
                      Text(subvalor!,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: subColor)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}