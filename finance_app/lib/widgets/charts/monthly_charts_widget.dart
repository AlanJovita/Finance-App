import 'package:finance_app/utils/currency_formatter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../models/relatorio_mensal.dart';
import '../../utils/app_tokens.dart';

/// Faturamento e pedidos dos últimos meses, em colunas.
///
/// **Forma:** o assunto é o mês corrente, e os anteriores são contexto — isso é
/// *ênfase*, não séries distintas. Por isso coluna em vez de linha: não dá para
/// destacar um trecho de uma linha de forma legível, e com 6 pontos discretos a
/// coluna compara magnitude melhor.
///
/// **Cores:** um matiz para o mês atual e um cinza recessivo para os demais,
/// validados com `dataviz/scripts/validate_palette.js` contra a superfície do
/// card em cada modo (claro ΔE 16,5 normal / 14,2 CVD; escuro 16,3 / 15,8; os
/// dois ≥3:1 de contraste). O passo escuro é próprio, não o claro clareado.
///
/// **A média é linha de referência, não série:** ela é base de comparação, e
/// desenhá-la como série competiria com o destaque.
class MonthlyChartsWidget extends StatefulWidget {
  final List<RelatorioMensal> relatorios;

  const MonthlyChartsWidget({super.key, required this.relatorios});

  /// Quantos meses a tela mostra.
  static const int mesesExibidos = 6;

  @override
  State<MonthlyChartsWidget> createState() => _MonthlyChartsWidgetState();
}

class _MonthlyChartsWidgetState extends State<MonthlyChartsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Os últimos meses recebidos, em ordem cronológica.
  ///
  /// O relatório é buscado por ano (`getRelatorioMensal(ano)`), então de janeiro
  /// a maio existem menos de 6 meses no ano corrente e a tela mostra o que há.
  /// Para a janela ser sempre de 6, o app teria de buscar o ano anterior também.
  List<RelatorioMensal> get _meses {
    final ordenados = [...widget.relatorios]..sort((a, b) {
      final porAno = (a.ano ?? 0).compareTo(b.ano ?? 0);
      return porAno != 0 ? porAno : (a.mes ?? 0).compareTo(b.mes ?? 0);
    });

    if (ordenados.length <= MonthlyChartsWidget.mesesExibidos) return ordenados;
    return ordenados.sublist(
      ordenados.length - MonthlyChartsWidget.mesesExibidos,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.relatorios.isEmpty) {
      return const Card(
        elevation: AppElevation.none,
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Nenhum dado disponível para exibir gráficos'),
        ),
      );
    }

    final meses = _meses;

    return Column(
      children: [
        _buildGrafico(
          context,
          titulo: 'Faturamento Mensal',
          subtitulo: 'Últimos ${meses.length} meses e média do período',
          meses: meses,
          valorDe: (r) => r.somaSaldo ?? 0,
          formatar: CurrencyFormatter.format,
          formatarEixo: (v) => 'R\$ ${_compacto(v)}',
        ),
        const SizedBox(height: 16),
        _buildGrafico(
          context,
          titulo: 'Pedidos Mensais',
          subtitulo: 'Últimos ${meses.length} meses e média do período',
          meses: meses,
          valorDe: (r) => r.somaPedidosConfirmados ?? 0,
          formatar: (v) => v.round().toString(),
          formatarEixo: (v) => v.round().toString(),
          // Estornados saíram do desenho: como série competiam com o destaque,
          // e o número bruto responde melhor "quantos foram".
          rodape: _estornados(meses),
        ),
      ],
    );
  }

  String? _estornados(List<RelatorioMensal> meses) {
    final total = meses.fold<double>(
      0,
      (s, r) => s + (r.somaPedidosEstornados ?? 0),
    );
    if (total <= 0) return null;
    return '${total.round()} pedidos estornados no período';
  }

  /// Os dois gráficos só diferem no que leem do relatório e em como formatam.
  Widget _buildGrafico(
    BuildContext context, {
    required String titulo,
    required String subtitulo,
    required List<RelatorioMensal> meses,
    required double Function(RelatorioMensal) valorDe,
    required String Function(double) formatar,
    required String Function(double) formatarEixo,
    String? rodape,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final destaque = isDark ? _destaqueDark : _destaqueLight;
    final contexto = isDark ? _contextoDark : _contextoLight;

    final valores = meses.map(valorDe).toList();
    final maximo =
        valores.isEmpty ? 1.0 : valores.reduce((a, b) => a > b ? a : b);
    final topo = maximo > 0 ? maximo * 1.25 : 1.0;
    final media =
        valores.isEmpty
            ? 0.0
            : valores.reduce((a, b) => a + b) / valores.length;

    return Card(
      elevation: AppElevation.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitulo,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 230,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return BarChart(
                    _dados(
                      context,
                      meses: meses,
                      valores: valores,
                      topo: topo,
                      media: media,
                      destaque: destaque,
                      contexto: contexto,
                      formatar: formatar,
                      formatarEixo: formatarEixo,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: [
                _legenda('Meses anteriores', contexto),
                _legenda('Mês atual', destaque),
                _legenda('Média', _tintaReferencia(theme), tracejada: true),
              ],
            ),
            if (rodape != null) ...[
              const SizedBox(height: AppSpacing.md),
              Center(child: Text(rodape, style: theme.textTheme.bodySmall)),
            ],
          ],
        ),
      ),
    );
  }

  BarChartData _dados(
    BuildContext context, {
    required List<RelatorioMensal> meses,
    required List<double> valores,
    required double topo,
    required double media,
    required Color destaque,
    required Color contexto,
    required String Function(double) formatar,
    required String Function(double) formatarEixo,
  }) {
    final theme = Theme.of(context);
    final ultimo = meses.length - 1;

    return BarChartData(
      maxY: topo,
      minY: 0,
      alignment: BarChartAlignment.spaceAround,
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => theme.colorScheme.surfaceContainerHighest,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final r = meses[groupIndex];
            return BarTooltipItem(
              '${_rotuloMes(r)}\n',
              TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
              children: [
                TextSpan(
                  text: formatar(valores[groupIndex]),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        // O valor do mês atual fica impresso acima da coluna, sempre visível.
        // Rótulo em todas as colunas viraria ruído; este é o ponto da tela.
        topTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            getTitlesWidget: (value, meta) {
              final i = value.toInt();
              if (i != ultimo) return const SizedBox.shrink();
              // FittedBox: um faturamento de sete dígitos não pode estourar o
              // slot da coluna e invadir o vizinho.
              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 4,
                // Sem isto, um valor largo sobre a última coluna é centrado no
                // slot dela e transborda a borda direita do card.
                fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatar(valores[i]),
                    maxLines: 1,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 38,
            getTitlesWidget: (value, meta) {
              final i = value.toInt();
              if (i < 0 || i >= meses.length) return const SizedBox.shrink();
              final atual = i == ultimo;
              final r = meses[i];

              // Mês e ano empilhados. Lado a lado ("Jun/26") o rótulo tem quase
              // 40px e o slot de uma coluna em tela de 380px tem ~48px — seis
              // deles se encostam e viram uma faixa contínua. Empilhado, cada
              // um ocupa ~24px e sobra respiro, sem perder o ano.
              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 6,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        r.nomeMesAbreviado,
                        maxLines: 1,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight:
                              atual ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      Text(
                        _ano(r),
                        maxLines: 1,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: _tintaReferencia(theme),
                          fontWeight:
                              atual ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Três marcas (0, meio, topo): com o valor do mês impresso na coluna, o
        // eixo serve só de escala — não precisa de precisão.
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 58,
            interval: topo / 2,
            getTitlesWidget: (value, meta) {
              // maxLines 1: sem isto "R$ 42k" quebra em duas linhas quando a
              // reserva aperta, e o eixo fica com altura irregular.
              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 6,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatarEixo(value),
                    maxLines: 1,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.right,
                  ),
                ),
              );
            },
          ),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: topo / 2,
        getDrawingHorizontalLine:
            (_) => FlLine(color: theme.dividerColor, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      // A média atravessa o gráfico: é base de comparação, não uma série.
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
            y: media * _animation.value,
            color: _tintaReferencia(theme),
            strokeWidth: 1,
            dashArray: const [4, 4],
          ),
        ],
      ),
      barGroups: List.generate(meses.length, (i) {
        final atual = i == ultimo;
        return BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: valores[i] * _animation.value,
              color: atual ? destaque : contexto,
              width: 26,
              // Ponta arredondada, base ancorada na linha de referência.
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ],
        );
      }),
    );
  }

  /// Tinta da linha de média: texto secundário, não cor de série. A média é
  /// referência, e pintá-la de série a colocaria em pé de igualdade com o mês
  /// em destaque.
  Color _tintaReferencia(ThemeData theme) =>
      theme.textTheme.bodySmall?.color ?? theme.hintColor;

  /// Ano com dois dígitos, para a segunda linha do rótulo do eixo.
  String _ano(RelatorioMensal r) =>
      ((r.ano ?? 0) % 100).toString().padLeft(2, '0');

  /// "Out/26" — usado no tooltip, onde cabe em uma linha.
  String _rotuloMes(RelatorioMensal r) {
    final ano = (r.ano ?? 0) % 100;
    return '${r.nomeMesAbreviado}/${ano.toString().padLeft(2, '0')}';
  }

  /// Abrevia o eixo: 1.2M, 45k, 980.
  String _compacto(double v) {
    if (v.abs() >= 1000000) {
      return '${(v / 1000000).toStringAsFixed(1).replaceAll('.', ',')}M';
    }
    if (v.abs() >= 1000) return '${(v / 1000).round()}k';
    return v.round().toString();
  }

  Widget _legenda(String label, Color color, {bool tracejada = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        tracejada
            ? SizedBox(
              width: 20,
              height: 3,
              child: CustomPaint(painter: _TracoTracejado(color)),
            )
            : Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        const SizedBox(width: AppSpacing.sm),
        // A tinta do rótulo é de texto; a identidade vem da marca ao lado.
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

/// Passos validados do par de ênfase. Ficam aqui, e não em `AppColors`, porque
/// são específicos destes gráficos — `series1..3` continuam sendo a paleta
/// categórica usada onde as séries de fato são o assunto.
const Color _destaqueLight = Color(0xFF2A78D6);
const Color _contextoLight = Color(0xFF8A919C);
const Color _destaqueDark = Color(0xFF4F97F2);
const Color _contextoDark = Color(0xFF6B7689);

class _TracoTracejado extends CustomPainter {
  final Color cor;

  const _TracoTracejado(this.cor);

  @override
  void paint(Canvas canvas, Size size) {
    final p =
        Paint()
          ..color = cor
          ..strokeWidth = 2;
    const traco = 4.0;
    const vao = 3.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + traco).clamp(0, size.width), size.height / 2),
        p,
      );
      x += traco + vao;
    }
  }

  @override
  bool shouldRepaint(_TracoTracejado old) => old.cor != cor;
}
