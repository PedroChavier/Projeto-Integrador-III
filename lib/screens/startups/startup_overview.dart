import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/startup.dart';

class VisaoGeralTab extends StatelessWidget {
  final Startup? startup;

  const VisaoGeralTab({super.key, this.startup});

  static const String _youtubeUrl = 'https://www.youtube.com/watch?v=SEU_VIDEO_ID';

  static const _ink = Color(0xFF121212);
  static const _muted = Color(0xFF6E6E73);
  static const _accent = Color(0xFF173B7A);

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
                subvalor: s != null && s.precoEmissao > 0 &&
                        s.precoToken != s.precoEmissao
                    ? 'emissão R\$ ${s.precoEmissao.toStringAsFixed(2).replaceAll('.', ',')}'
                    : null,
                subColor: _muted,
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
          if (s != null && s.totalTokensEmitidos > 0) ...[
            const SizedBox(height: 20),
            _buildProgressoEmissao(s),
          ],
          if (s != null) ..._buildLockupSection(s),
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
                    Container(color: Colors.black),
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white54, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 32,
                        ),
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

  Widget _buildProgressoEmissao(Startup s) {
    final progress =
        (s.tokensVendidos / s.totalTokensEmitidos).clamp(0.0, 1.0);
    final pct = (progress * 100).toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Progresso da emissão',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: _muted),
            ),
            const Spacer(),
            Text(
              '${_formatarTokens(s.tokensVendidos)} / ${_formatarTokens(s.totalTokensEmitidos)} · $pct%',
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: _ink),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: const Color(0xFFEDEEDE),
            valueColor: const AlwaysStoppedAnimation<Color>(_accent),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildLockupSection(Startup s) {
    final hasQtd =
        s.lockupQuantidadeTipo != null && s.lockupQuantidadeValor > 0;
    final hasTempo = s.lockupDiasMinimo > 0;
    if (!hasQtd && !hasTempo) return [];

    final widgets = <Widget>[
      const SizedBox(height: 20),
      Row(
        children: const [
          Icon(Icons.lock_outline, size: 13, color: _muted),
          SizedBox(width: 4),
          Text(
            'Lock-up',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: _muted),
          ),
        ],
      ),
      const SizedBox(height: 8),
    ];

    if (hasQtd) {
      final vendidos = s.tokensVendidos;
      final int required;
      final String metaLabel;
      if (s.lockupQuantidadeTipo == 'percentual') {
        required = (s.lockupQuantidadeValor * s.totalTokensEmitidos).ceil();
        final pct = (s.lockupQuantidadeValor * 100).toStringAsFixed(0);
        metaLabel = 'meta: $pct% dos tokens emitidos';
      } else {
        required = s.lockupQuantidadeValor.toInt();
        metaLabel = 'meta: ${_formatarTokens(required)} ${s.sigla} vendidos';
      }
      final percorrido = vendidos.clamp(0, required);
      final falta = (required - percorrido).clamp(0, required);
      final progress =
          required > 0 ? (percorrido / required).clamp(0.0, 1.0) : 1.0;
      final unlocked = falta == 0;

      widgets.add(_LockupCard(
        icon: Icons.bar_chart_rounded,
        title: 'Por valor',
        subtitle: metaLabel,
        progress: progress,
        unlocked: unlocked,
        percorridoLabel:
            '${_formatarTokens(percorrido)} ${s.sigla} vendidos',
        faltaLabel: unlocked
            ? 'Desbloqueado'
            : 'Faltam ${_formatarTokens(falta)} ${s.sigla}',
      ));
    }

    if (hasTempo) {
      final lancamento = s.dataLancamento;
      final totalDias = s.lockupDiasMinimo;
      double? tempoProgress;
      bool tempoUnlocked = false;
      String percorridoLabel;
      String faltaLabel;

      if (lancamento != null) {
        final diasDecorridos =
            DateTime.now().difference(lancamento).inDays.clamp(0, totalDias);
        final diasFaltando = totalDias - diasDecorridos;
        tempoProgress = (diasDecorridos / totalDias).clamp(0.0, 1.0);
        tempoUnlocked = diasFaltando == 0;
        percorridoLabel = '$diasDecorridos de $totalDias dias decorridos';
        faltaLabel =
            tempoUnlocked ? 'Desbloqueado' : 'Faltam $diasFaltando dias';
      } else {
        percorridoLabel = 'carência de $totalDias dias por compra';
        faltaLabel = 'data de lançamento não definida';
      }

      widgets.add(_LockupCard(
        icon: Icons.schedule_rounded,
        title: 'Por tempo',
        subtitle: 'desde o lançamento da startup',
        progress: tempoProgress,
        unlocked: tempoUnlocked,
        percorridoLabel: percorridoLabel,
        faltaLabel: faltaLabel,
      ));
    }

    return widgets;
  }
}

class _LockupCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double? progress;
  final bool unlocked;
  final String percorridoLabel;
  final String faltaLabel;

  const _LockupCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.unlocked,
    required this.percorridoLabel,
    required this.faltaLabel,
  });

  @override
  Widget build(BuildContext context) {
    final accent =
        unlocked ? const Color(0xFF2E7D32) : const Color(0xFFB8860B);
    final bg = unlocked ? const Color(0xFFF0F7F3) : const Color(0xFFFFF8E1);
    final borderColor =
        unlocked ? const Color(0xFFA5D6A7) : const Color(0xFFFFE082);
    final barColor =
        unlocked ? const Color(0xFF2E7D32) : const Color(0xFFFFB300);
    final textStrong =
        unlocked ? const Color(0xFF1B5E20) : const Color(0xFF7B5800);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: accent),
              const SizedBox(width: 5),
              Text(
                title,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accent),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(
                      fontSize: 10,
                      color: accent.withValues(alpha: 0.75)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: borderColor,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  percorridoLabel,
                  style: TextStyle(
                      fontSize: 10, color: accent.withValues(alpha: 0.8)),
                ),
              ),
              Text(
                faltaLabel,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: textStrong),
              ),
            ],
          ),
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
                color: Colors.black.withValues(alpha: 0.04),
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
                              fontSize: 11,
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
