// Pedro Andre do Carmo Chavier - 25018639

import 'dart:ui' as ui; // usado para criar o gradiente dentro do gráfico

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection; // formatação de moeda (R$) e números

import '../../models/wallet_holding.dart';
import '../../services/dashboard_service.dart';
import '../home/home_screen.dart';
import '../startups/startup_detail.dart';
import '../startups/startups_catalog_screen.dart';

// ── Cores usadas na tela ──────────────────────────────────────────────────────
const Color _corPrimaria   = Color(0xFF000141); 
const Color _corVerde      = Color(0xFF2E7D32); 
const Color _corVermelho   = Color(0xFFC62828); 
const Color _corNeutra     = Colors.black45;    
const Color _corSkeleton   = Color(0xFFEEEEEE); 
const Color _corSkeletonSoft = Color(0xFFF5F5F5);

// Nomes dos meses em português, usados nos rótulos do eixo X do gráfico
const List<String> _mesesAbrev = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
  'jul', 'ago', 'set', 'out', 'nov', 'dez',
];

//Formadores de texto - Preços e tokens
final NumberFormat _fmtBRL    = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ', decimalDigits: 2); 
final NumberFormat _fmtTokens = NumberFormat('#,##0', 'pt_BR');

// Formata percentual com sinal: ex. +3,5% ou -1,2%
String _fmtPct(double v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}%';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

// [SingleTickerProviderStateMixin] é necessário para usar [AnimationController]
class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {

  int _selectedPeriodIndex = 0; 
  String? _selectedStartupId;   

  // Controla a animação de entrada da linha do gráfico
  AnimationController? _chartController;
  Animation<double> _chartAnimation = const AlwaysStoppedAnimation(0.0);

  final List<String> _periods = [
    'Hoje', 'Semana', 'Mês', 'Bimestre',
    'Trimestre', 'Semestre', '1 ano', '5 anos', 'Tudo',
  ];

  final DashboardService _service = DashboardService();

  List<OrderExecution>            _executions       = const [];
  Map<String, List<PricePoint>>   _tradesByStartup  = const {};
  Map<String, double>             _custoPorStartup  = const {};

  bool         _loadingAux    = true;
  Set<String>  _auxLoadedIds  = const {};
  bool         _auxLoading    = false;

  @override
  void initState() {
    super.initState();

    // Cria o controlador da animação do gráfico com duração de 1,5 segundos
    _chartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    // [easeInOut] faz a animação começar devagar, acelerar e terminar devagar
    _chartAnimation = CurvedAnimation(
      parent: _chartController!,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _chartController?.dispose();
    super.dispose();
  }

  /// Evita recarregar os dados se as startups da carteira não mudaram
  void _maybeLoadAux(List<WalletHolding> holdings) {
    final ids = holdings.map((h) => h.startupUid).toSet();
    if (_auxLoading) return;
    
    final mesmoConjunto =
        ids.length == _auxLoadedIds.length && ids.containsAll(_auxLoadedIds);
    if (mesmoConjunto && !_loadingAux) return;
    _auxLoadedIds = ids;
    _loadAux(holdings);
  }

  /// Busca as ordens executadas e o histórico de preços de cada startup em paralelo
  Future<void> _loadAux(List<WalletHolding> holdings) async {
    _auxLoading = true;
    if (mounted) setState(() => _loadingAux = true);

    try {
      final execs = await _service.fetchExecutions();
      final trades = <String, List<PricePoint>>{};

      // Busca os trades de todas as startups ao mesmo tempo (em paralelo)
      await Future.wait(holdings.map((h) async {
        trades[h.startupUid] = await _service.fetchTrades(h.startupUid);
      }));

      if (!mounted) return;

      setState(() {
        _executions      = execs;
        _tradesByStartup = trades;
        _custoPorStartup = _service.custoPorStartup(execs);
        _loadingAux      = false;
      });

      // Inicia a animação do gráfico assim que os dados chegam
      _chartController?.forward(from: 0);

    } catch (_) {
      if (!mounted) return;

      setState(() => _loadingAux = false);
      _chartController?.forward(from: 0);
      _showError();

    } finally {
      _auxLoading = false;
    }
  }

  void _showError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Não foi possível carregar seus dados. Tente novamente.'),
      ),
    );
  }

  // ── Cálculos da carteira ──────────────────────────────────────────────────

  /// Soma o valor atual de todos os holdings = patrimônio total
  double _patrimonio(List<WalletHolding> h) =>
      h.fold(0.0, (sum, e) => sum + e.valorAtualEstimado);

  /// Custo total pago pelo investidor ao longo do tempo
  double _custoTotal(List<WalletHolding> holdings) {
    if (_executions.isEmpty) {
      return holdings.fold(0.0, (sum, h) => sum + h.valorInvestido); //percorre a lista e acumula valores
    }
    return _service.custoTotal(_executions);
  }

  /// Custo pago especificamente em uma startup
  double _custoAquisicao(WalletHolding h) =>
      _custoPorStartup[h.startupUid] ?? h.valorInvestido;

  /// Texto do subtítulo do card de lucro conforme o período selecionado
  String _subtituloLucro() {
    switch (_selectedPeriodIndex) {
      case 0: return 'hoje';
      case 1: return 'esta semana';
      case 2: return 'este mês';
      case 3: return 'no bimestre';
      case 4: return 'no trimestre';
      case 5: return 'no semestre';
      case 6: return 'em 1 ano';
      case 7: return 'em 5 anos';
      default: return 'todo o período';
    }
  }

  // ── Dados do gráfico ──────────────────────────────────────────────────────

  /// Gera os instantes de tempo que serão usadas como pontos do grafico
  List<DateTime> _sampleTimes(WalletHolding h) {
    final now = DateTime.now();
    switch (_selectedPeriodIndex) {
      case 0: return List.generate(24, (i) => now.subtract(Duration(hours: 23 - i)));        // 24 horas
      case 1: return List.generate(7,  (i) => now.subtract(Duration(days: 6 - i)));          // 7 dias
      case 2: return List.generate(30, (i) => now.subtract(Duration(days: 29 - i)));         // 30 dias
      case 3: return List.generate(30, (i) => now.subtract(Duration(days: 2 * (29 - i))));   // bimestre
      case 4: return List.generate(30, (i) => now.subtract(Duration(days: 3 * (29 - i))));   // trimestre
      case 5: return List.generate(26, (i) => now.subtract(Duration(days: 7 * (25 - i))));   // semestre
      case 6: return List.generate(27, (i) => now.subtract(Duration(days: 14 * (26 - i)))); // 1 ano
      case 7: return List.generate(60, (i) => now.subtract(Duration(days: 30 * (59 - i)))); // 5 anos
      default: return _allTimeSamples(h, now);
    }
  }

  /// Para o período "Tudo": 40 pontos igualmente espaçados desde o primeiro trade
  List<DateTime> _allTimeSamples(WalletHolding h, DateTime now) {
    final trades = _tradesByStartup[h.startupUid] ?? const [];

    final start  = trades.isNotEmpty
        ? trades.first.at
        : now.subtract(const Duration(days: 365)); // a patir de agora

    final totalMs = now.millisecondsSinceEpoch - start.millisecondsSinceEpoch;

    if (totalMs <= 0) return [start, now]; 

    const n = 40;
    return List.generate(n, (i) {
      final ms = start.millisecondsSinceEpoch + totalMs * i ~/ (n - 1);
      return DateTime.fromMillisecondsSinceEpoch(ms);
    });
  }

  /// Retorna o preço do token no instante [t].
  /// Usa o último trade registrado antes de [t] (se não houver, usa o preço médio)
  double _priceAt(WalletHolding h, DateTime t) {
    final trades = _tradesByStartup[h.startupUid] ?? const [];
    if (trades.isEmpty) return h.precoMedio;
    double? p;
    for (final tr in trades) {
      if (tr.at.isAfter(t)) break;
      p = tr.price;
    }
    return p ?? trades.first.price;
  }

  /// Retorna o holding selecionado; se nenhum estiver selecionado, retorna o primeiro
  WalletHolding? _selectedHolding(List<WalletHolding> holdings) {
    if (holdings.isEmpty) return null;
    for (final h in holdings) {
      if (h.startupUid == _selectedStartupId) return h;
    }
    return holdings.first;
  }

  /// Retorna true quando a startup não tem histórico de trades —
  /// nesse caso o gráfico exibe uma linha plana com o badge "Estimado"
  bool _priceEstimated(WalletHolding h) =>
      (_tradesByStartup[h.startupUid] ?? const []).isEmpty;

  /// Monta todos os dados necessários para renderizar o gráfico:
  /// pontos da linha, variação percentual no período e rótulos do eixo X
  ({
    List<Offset> points,
    bool estimated,
    double precoAtual,
    double? variacao,
    List<({double dx, String label})> xLabels,
    
  }) _chartData(WalletHolding h) {
    final samples    = _sampleTimes(h);
    final series     = samples.map((t) => (at: t, value: _priceAt(h, t))).toList();
    final points     = _normalize(series);
    final estimated  = _priceEstimated(h);
    final precoAtual = h.precoMedio;
    final precoInicio = series.first.value;
    // Variação = quanto o preço subiu ou caiu desde o início do período
    final variacao   = estimated || precoInicio == 0
        ? null
        : (precoAtual - precoInicio) / precoInicio * 100;

    return (
      points: points,
      estimated: estimated,
      precoAtual: precoAtual,
      variacao: variacao,
      xLabels: _buildXLabels(series, points),
    );
  }

  /// Gera até 4 rótulos espaçados uniformemente no eixo X
  List<({double dx, String label})> _buildXLabels(
    List<({DateTime at, double value})> series,
    List<Offset> points,
  ) {
    if (series.length < 2) return const [];
    const ticks = 4;
    final out   = <({double dx, String label})>[];
    var ultimo  = '';
    for (var j = 0; j < ticks; j++) {
      final idx   = (j * (series.length - 1) / (ticks - 1)).round();
      final label = _axisLabel(series[idx].at);
      if (label == ultimo) continue; // evita rótulos duplicados
      ultimo = label;
      out.add((dx: points[idx].dx, label: label));
    }
    return out;
  }

  /// Formata o rótulo do eixo X conforme o período:
  /// horas para "Hoje", dia+mês para curto prazo, mês/ano para longo prazo
  String _axisLabel(DateTime t) {
    String d2(int n) => n.toString().padLeft(2, '0');
    final mes  = _mesesAbrev[t.month - 1];
    final ano2 = d2(t.year % 100);
    switch (_selectedPeriodIndex) {
      case 0:            return '${d2(t.hour)}h';
      case 1: case 2:
      case 3: case 4:    return '${t.day} $mes';
      case 5: case 6:    return mes;
      default:           return '$mes/$ano2';
    }
  }

  /// Converte os valores da série em coordenadas entre 0 e 1,
  /// com 5% de margem para a linha não colar nas bordas do gráfico
  List<Offset> _normalize(List<({DateTime at, double value})> series) {
    if (series.isEmpty) return const [];
    var minV = series.first.value, maxV = series.first.value;
    for (final p in series) {
      if (p.value < minV) minV = p.value;
      if (p.value > maxV) maxV = p.value;
    }
    final minT   = series.first.at.millisecondsSinceEpoch.toDouble();
    final maxT   = series.last.at.millisecondsSinceEpoch.toDouble();
    final rangeT = maxT - minT;
    final rangeV = maxV - minV;

    return series.map((p) {
      final dx = rangeT == 0
          ? 0.0
          : (p.at.millisecondsSinceEpoch - minT) / rangeT;
      final dy = rangeV == 0 ? 0.5 : 1.0 - (p.value - minV) / rangeV;
      // multiplica por 0.85 e soma 0.05 para manter 5% de margem em cima e em baixo
      return Offset(dx, dy * 0.85 + 0.05);
    }).toList();
  }

  // ── Navegação ─────────────────────────────────────────────────────────────

  void _abrirStartup(WalletHolding h) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StartupDetalheScreen(startupUid: h.startupUid),
      ),
    );
  }

  /// Vai para o catálogo substituindo a tela atual (sem deixar o dashboard na pilha)
  void _verCatalogo() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const StartupsScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  // ── Build principal ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Linha decorativa de gradiente no topo
            Container(
              height: 2,
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
            Expanded(
              // Escuta a carteira em tempo real; reconstrói quando os dados mudam
              child: StreamBuilder<List<WalletHolding>>(
                stream: _service.watchHoldings(),
                builder: (context, snapshot) {
                  final waiting =
                      snapshot.connectionState == ConnectionState.waiting;

                  if (snapshot.hasError) {
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _showError());
                  }

                  final holdings = snapshot.data ?? const <WalletHolding>[];

                  // Carrega dados auxiliares após os holdings chegarem
                  if (!waiting && holdings.isNotEmpty) {
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _maybeLoadAux(holdings));
                  }

                  if (waiting)          return _buildBody(loading: true);
                  if (holdings.isEmpty) return _buildEmptyState();
                  return _buildBody(loading: _loadingAux, holdings: holdings);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Layout principal ──────────────────────────────────────────────────────
  Widget _buildBody({required bool loading, List<WalletHolding>? holdings}) {
    final h = holdings ?? const <WalletHolding>[];

    final patrimonio = _patrimonio(h);
    final custo      = _custoTotal(h);
    final lucro      = patrimonio - custo;
    final temCusto   = custo != 0;
    final variacao   = temCusto ? (patrimonio - custo) / custo * 100 : 0.0;

    final selecionada = loading ? null : _selectedHolding(h);
    final chart       = selecionada == null ? null : _chartData(selecionada);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),

          // Chips de período (Hoje / Semana / Mês…)
          _buildPeriodFilter(),
          const SizedBox(height: 20),

          // Cards de patrimônio e lucro — mostra skeleton enquanto carrega
          if (loading)
            _buildMetricCardsSkeleton()
          else
            _buildMetricCards(
              patrimonio: patrimonio,
              variacao: temCusto ? variacao : null,
              lucro: lucro,
            ),
          const SizedBox(height: 20),

          // Chips de startup + legenda de preço + gráfico
          if (!loading && selecionada != null) ...[
            _buildStartupSelector(h, selecionada),
            const SizedBox(height: 12),
            _buildPriceCaption(selecionada, chart!.precoAtual, chart.variacao),
            const SizedBox(height: 8),
          ],
          if (loading)
            _buildChartLoading()
          else
            _buildChart(
              points: chart!.points,
              label: _fmtBRL.format(chart.precoAtual),
              estimated: chart.estimated,
              xLabels: chart.xLabels,
            ),
          const SizedBox(height: 24),

          // Lista de posições por startup
          const Text(
            'Por Startup',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          if (loading)
            _buildStartupSkeleton()
          else
            ...h.asMap().entries.map((entry) {
              final index   = entry.key;
              final holding = entry.value;
              return Column(
                children: [
                  _buildStartupItem(holding),
                  if (index < h.length - 1)
                    const Divider(height: 1, color: Color(0xFFEEEEEE)),
                ],
              );
            }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Chips de seleção de período — ao tocar reinicia a animação do gráfico
  Widget _buildPeriodFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_periods.length, (index) {
          final isSelected = _selectedPeriodIndex == index;
          return GestureDetector(
            onTap: () {
              if (_selectedPeriodIndex == index) return;
              setState(() => _selectedPeriodIndex = index);
              _chartController?.forward(from: 0);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFD7DEEC) : Colors.white,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF234794)
                      : const Color(0xFFDDDDDD),
                  width: 1,
                ),
              ),
              child: Text(
                _periods[index],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? _corPrimaria : Colors.black54,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Cards de métricas ─────────────────────────────────────────────────────
  Widget _buildMetricCards({
    required double patrimonio,
    required double? variacao,
    required double lucro,
  }) {
    final temVariacao = variacao != null;
    // Cor do percentual: verde se subiu, vermelho se caiu, cinza se não há dados
    final corVariacao = !temVariacao
        ? _corNeutra
        : variacao > 0 ? _corVerde : variacao < 0 ? _corVermelho : _corNeutra;
    final corLucro    = lucro > 0 ? _corVerde : lucro < 0 ? _corVermelho : Colors.black87;
    final prefixoLucro = lucro > 0 ? '+' : '';

    return Row(
      children: [
        Expanded(
          child: _buildCard(
            label: 'Patrimônio',
            value: _fmtBRL.format(patrimonio),
            valueColor: Colors.black87,
            subtitle: temVariacao ? _fmtPct(variacao) : '—',
            subtitleColor: corVariacao,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCard(
            label: 'Lucro / Prejuízo',
            value: '$prefixoLucro${_fmtBRL.format(lucro)}',
            valueColor: corLucro,
            subtitle: _subtituloLucro(),
            subtitleColor: Colors.black45,
          ),
        ),
      ],
    );
  }

  /// Card com rótulo, valor em destaque e subtítulo colorido
  Widget _buildCard({
    required String label,
    required String value,
    required Color valueColor,
    required String subtitle,
    required Color subtitleColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEAEAF0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.black45)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: valueColor)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: subtitleColor)),
        ],
      ),
    );
  }

  /// Chips horizontais para trocar a startup exibida no gráfico
  Widget _buildStartupSelector(
      List<WalletHolding> holdings, WalletHolding selecionada) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: holdings.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final h          = holdings[i];
          final isSelected = h.startupUid == selecionada.startupUid;
          final rotulo     = h.startupSigla.isNotEmpty ? h.startupSigla : h.startupNome;
          return GestureDetector(
            onTap: () {
              if (_selectedStartupId == h.startupUid) return;
              setState(() => _selectedStartupId = h.startupUid);
              _chartController?.forward(from: 0); // reinicia animação ao trocar startup
            },
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? _corPrimaria : Colors.white,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: isSelected ? _corPrimaria : const Color(0xFFDDDDDD),
                  width: 1,
                ),
              ),
              child: Text(
                rotulo,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.black54,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Legenda acima do gráfico: nome da startup, preço atual e variação no período
  Widget _buildPriceCaption(
      WalletHolding h, double precoAtual, double? variacao) {
    final corVar = variacao == null || variacao == 0
        ? _corNeutra
        : variacao > 0 ? _corVerde : _corVermelho;
    return Row(
      children: [
        Expanded(
          child: Text(
            h.startupNome,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black87),
          ),
        ),
        Text(_fmtBRL.format(precoAtual),
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black87)),
        const SizedBox(width: 8),
        Text(
          variacao == null ? '—' : _fmtPct(variacao),
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: corVar),
        ),
      ],
    );
  }

  /// Container do gráfico com borda, sombra e badge "Estimado" quando aplicável
  Widget _buildChart({
    required List<Offset> points,
    required String label,
    required bool estimated,
    required List<({double dx, String label})> xLabels,
  }) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 253, 253, 255),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Redesenha o gráfico a cada frame da animação
            AnimatedBuilder(
              animation: _chartAnimation,
              builder: (context, _) {
                return CustomPaint(
                  painter: _LineChartPainter(
                    progress: _chartAnimation.value,
                    points: points,
                    label: label,
                    xLabels: xLabels,
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
            // Exibe "Estimado" quando não há trades reais para esta startup
            if (estimated)
              Positioned(
                top: 8,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Text(
                    'Estimado',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Item da lista "Por Startup" com nome, quantidade, valor e variação
  Widget _buildStartupItem(WalletHolding h) {
    final custo     = _custoAquisicao(h);
    final valorAtual = h.valorAtualEstimado;
    final temCusto  = custo != 0;
    final variacao  = temCusto ? (valorAtual - custo) / custo * 100 : 0.0;
    final corVar    = !temCusto || variacao == 0
        ? _corNeutra
        : variacao > 0 ? _corVerde : _corVermelho;

    final detalhe =
        '${_fmtTokens.format(h.quantidadeTotal)} tokens × ${_fmtBRL.format(h.precoMedio)}';

    return InkWell(
      onTap: () => _abrirStartup(h),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.startupNome,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87)),
                  const SizedBox(height: 3),
                  Text(detalhe,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black45)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_fmtBRL.format(valorAtual),
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
                const SizedBox(height: 3),
                Text(
                  temCusto ? _fmtPct(variacao) : '—',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: corVar),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Skeletons (blocos cinzas exibidos durante o carregamento) ─────────────

  Widget _skeletonBox(double h, double w) => Container(
        height: h,
        width: w,
        decoration: BoxDecoration(
          color: _corSkeleton,
          borderRadius: BorderRadius.circular(4),
        ),
      );

  Widget _buildMetricCardsSkeleton() {
    Widget card() => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEAEAF0), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _skeletonBox(11, 70),
              const SizedBox(height: 10),
              _skeletonBox(18, 100),
              const SizedBox(height: 8),
              _skeletonBox(11, 50),
            ],
          ),
        );
    return Row(
      children: [
        Expanded(child: card()),
        const SizedBox(width: 12),
        Expanded(child: card()),
      ],
    );
  }

  /// Spinner centralizado enquanto o gráfico ainda não tem dados
  Widget _buildChartLoading() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 253, 253, 255),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation(Color(0xFFAD1457)),
          ),
        ),
      ),
    );
  }

  Widget _buildStartupSkeleton() {
    return Column(
      children: List.generate(2, (i) {
        return Column(
          children: [
            if (i > 0) const Divider(height: 1, color: Color(0xFFEEEEEE)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _skeletonBox(14, 120),
                        const SizedBox(height: 6),
                        Container(
                          height: 11,
                          width: 70,
                          decoration: BoxDecoration(
                            color: _corSkeletonSoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _skeletonBox(14, 80),
                      const SizedBox(height: 6),
                      Container(
                        height: 11,
                        width: 60,
                        decoration: BoxDecoration(
                          color: _corSkeletonSoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  /// Tela exibida quando o usuário ainda não tem nenhum investimento
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dashboard',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87)),
          const SizedBox(height: 80),
          Center(
            child: Column(
              children: [
                const Icon(Icons.show_chart_outlined,
                    size: 64, color: Color(0xFFBBBBBB)),
                const SizedBox(height: 16),
                const Text('Nenhum investimento ainda',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87)),
                const SizedBox(height: 8),
                const Text(
                  'Explore startups e adquira seus primeiros tokens',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _verCatalogo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _corPrimaria,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50)),
                  ),
                  child: const Text('Ver Startups'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Desenho do gráfico ────────────────────────────────────────────────────────
// [CustomPainter] permite desenhar diretamente no canvas do Flutter.
// Esta classe desenha: linhas de grid, área de gradiente, linha curva e rótulos do eixo X
class _LineChartPainter extends CustomPainter {
  final double progress;  // de 0.0 a 1.0 — controla até onde a linha já foi desenhada
  final List<Offset> points; // posições normalizadas entre 0 e 1
  final String label;        // preço exibido na ponta da linha
  final List<({double dx, String label})> xLabels;

  _LineChartPainter({
    required this.progress,
    required this.points,
    required this.label,
    this.xLabels = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Margens internas do gráfico: espaço à direita para o label, embaixo para o eixo X
    const double paddingLeft   = 12;
    const double paddingRight  = 70;
    const double paddingTop    = 24;
    const double paddingBottom = 28;

    final chartW = size.width  - paddingLeft - paddingRight;
    final chartH = size.height - paddingTop  - paddingBottom;

    // ── 1. Linhas horizontais de referência (grid) ────────────────────────
    final gridPaint = Paint()
      ..color       = const Color.fromARGB(255, 236, 236, 241)
      ..strokeWidth = 1.0
      ..style       = PaintingStyle.stroke;

    for (int i = 0; i <= 4; i++) {
      final y = paddingTop + chartH * i / 4;
      canvas.drawLine(
        Offset(paddingLeft, y),
        Offset(paddingLeft + chartW, y),
        gridPaint,
      );
    }

    if (points.length < 2) return;

    // Converte as coordenadas normalizadas (0–1) em pixels reais do canvas
    final mapped = points.map((p) => Offset(
          paddingLeft + p.dx * chartW,
          paddingTop  + p.dy * chartH,
        )).toList();

    // ── 2. Calcula até qual ponto a linha chegou na animação atual ────────
    final totalSegments  = mapped.length - 1;
    final clampedProgress = progress.clamp(0.0, 1.0);
    final currentSegment  = (clampedProgress * totalSegments)
        .floor().clamp(0, totalSegments - 1);
    final segmentProgress = (clampedProgress * totalSegments) - currentSegment;

    // ── 3. Constrói o caminho da linha usando curvas de Bézier (mais suave que linhas retas) ──
    final linePath = Path();
    linePath.moveTo(mapped[0].dx, mapped[0].dy);

    for (int i = 1; i <= totalSegments; i++) {
      final prev = mapped[i - 1];
      final curr = mapped[i];
      final cx   = (prev.dx + curr.dx) / 2; // ponto de controle central da curva

      if (i < currentSegment + 1) {
        // Segmento já revelado: desenha a curva completa
        linePath.cubicTo(cx, prev.dy, cx, curr.dy, curr.dx, curr.dy);
      } else if (i == currentSegment + 1) {
        // Segmento atual: desenha apenas até onde a animação chegou
        final t    = clampedProgress >= 1.0 ? 1.0 : segmentProgress;
        final endX = prev.dx + (curr.dx - prev.dx) * t;
        final endY = prev.dy + (curr.dy - prev.dy) * t;
        linePath.cubicTo(cx, prev.dy, cx, endY, endX, endY);
        break;
      }
    }

    // Posição atual da ponta animada da linha
    final Offset animatedEnd;
    if (clampedProgress >= 1.0) {
      animatedEnd = mapped.last;
    } else {
      final prev  = mapped[currentSegment];
      final curr  = mapped[currentSegment + 1];
      animatedEnd = Offset(
        prev.dx + (curr.dx - prev.dx) * segmentProgress,
        prev.dy + (curr.dy - prev.dy) * segmentProgress,
      );
    }

    // ── 4. Área de gradiente abaixo da linha ──────────────────────────────
    // Cria um caminho que fecha a área entre a linha e o eixo X
    final fillPath = Path()..addPath(linePath, Offset.zero);
    fillPath.lineTo(animatedEnd.dx, paddingTop + chartH); // desce até o eixo X
    fillPath.lineTo(mapped.first.dx, paddingTop + chartH); // volta até o início
    fillPath.close();

    // Gradiente rosa: mais opaco no topo, quase transparente em baixo
    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, paddingTop),
        Offset(0, paddingTop + chartH),
        [
          const Color(0xFFE91E8C).withOpacity(0.25),
          const Color(0xFFE91E8C).withOpacity(0.02),
        ],
      );
    canvas.drawPath(fillPath, fillPaint);

    // ── 5. Linha principal ────────────────────────────────────────────────
    final linePaint = Paint()
      ..color      = const Color(0xFFAD1457)
      ..strokeWidth = 2.0
      ..style      = PaintingStyle.stroke
      ..strokeCap  = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    // Ponto circular na ponta da linha (acompanha o movimento da animação)
    canvas.drawCircle(animatedEnd, 5, Paint()..color = const Color(0xFFAD1457));

    // ── 6. Label do preço — aparece apenas quando a animação termina ──────
    if (clampedProgress >= 1.0) {
      const labelStyle = TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87);
      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(animatedEnd.dx + 8, animatedEnd.dy - tp.height / 2));
    }

    // ── 7. Rótulos do eixo X com pequenos traços de marcação ─────────────
    const axisStyle = TextStyle(
        fontSize: 9, fontWeight: FontWeight.w500, color: Colors.black38);
    for (final tick in xLabels) {
      final cx = paddingLeft + tick.dx * chartW;
      // Traço vertical abaixo do gráfico
      canvas.drawLine(
        Offset(cx, paddingTop + chartH),
        Offset(cx, paddingTop + chartH + 4),
        gridPaint,
      );
      final lp = TextPainter(
        text: TextSpan(text: tick.label, style: axisStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      // Centraliza o rótulo e impede que saia fora da tela
      final x = (cx - lp.width / 2).clamp(0.0, size.width - lp.width);
      lp.paint(canvas, Offset(x, paddingTop + chartH + 6));
    }
  }

  // Redesenha apenas quando algo realmente mudou
  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.progress != progress ||
      old.points   != points   ||
      old.label    != label    ||
      old.xLabels  != xLabels;
}