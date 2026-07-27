import 'package:finance_app/utils/currency_formatter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../models/caixa.dart';
import '../../utils/app_colors_extension.dart';
import '../../utils/app_tokens.dart';

class CaixasChartWidget extends StatefulWidget {
  final List<Caixa> caixas;

  const CaixasChartWidget({super.key, required this.caixas});

  @override
  State<CaixasChartWidget> createState() => _CaixasChartWidgetState();
}

class _CaixasChartWidgetState extends State<CaixasChartWidget>
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

  @override
  Widget build(BuildContext context) {
    if (widget.caixas.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Nenhum dado disponível para exibir gráfico'),
        ),
      );
    }

    final theme = Theme.of(context);
    final cores = context.appColors;

    return Card(
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 250,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return LineChart(
                    LineChartData(
                      maxY: _getMaxSaldo() * 1.2,
                      minY: 0,
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor:
                              (touchedSpot) =>
                                  theme.colorScheme.surfaceContainerHighest,
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              // Usar caixasFechados ao invés de widget.caixas
                              final caixasFechados =
                                  widget.caixas
                                      .where(
                                        (c) =>
                                            c.statusCaixa == 1 &&
                                            c.dataFechamento != null,
                                      )
                                      .toList();

                              if (spot.x.toInt() >= 0 &&
                                  spot.x.toInt() < caixasFechados.length) {
                                final caixa = caixasFechados[spot.x.toInt()];
                                final isSaldo = spot.barIndex == 0;
                                return LineTooltipItem(
                                  '${_formatDate(caixa.dataFechamento)}\n',
                                  TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  children: [
                                    TextSpan(
                                      text:
                                          isSaldo
                                              ? 'Saldo: ${CurrencyFormatter.format(caixa.saldo)}'
                                              : 'Pedidos: ${(caixa.totalPedidoConfirmado ?? 0)}',
                                      style: TextStyle(
                                        color: spot.bar.color,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return null;
                            }).toList();
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: _getMaxSaldo() / 5,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: theme.dividerColor,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: _buildLineData(context),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Faturamento', cores.series2),
                const SizedBox(width: AppSpacing.xl),
                _buildLegendItem('Pedidos', cores.series1),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // A tinta do rótulo é de texto; a identidade da série é o traço ao lado.
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }

  List<LineChartBarData> _buildLineData(BuildContext context) {
    final theme = Theme.of(context);
    final cores = context.appColors;
    final animationValue = _animation.value;

    // Filtrar apenas caixas fechados (status_caixa == 1)
    final caixasFechados =
        widget.caixas
            .where((c) => c.statusCaixa == 1 && c.dataFechamento != null)
            .toList();

    if (caixasFechados.isEmpty) {
      return [];
    }

    // Linha de saldo
    final saldoSpots = List.generate(
      caixasFechados.length,
      (index) => FlSpot(
        index.toDouble(),
        (caixasFechados[index].saldo ?? 0) * animationValue,
      ),
    );

    // Calcular fator de escala para pedidos confirmados
    final maxSaldo = _getMaxSaldo();
    final maxPedidos = _getMaxPedidos();
    final scaleFactor = maxSaldo / (maxPedidos > 0 ? maxPedidos : 1);

    // Linha de pedidos confirmados (escalada para visualização)
    final pedidosSpots = List.generate(
      caixasFechados.length,
      (index) => FlSpot(
        index.toDouble(),
        (caixasFechados[index].totalPedidoConfirmado ?? 0).toDouble() *
            scaleFactor *
            animationValue,
      ),
    );

    return [
      _buildLinha(theme, saldoSpots, cores.series2),
      _buildLinha(theme, pedidosSpots, cores.series1),
    ];
  }

  /// Uma série do gráfico: traço fino, ponto com anel da cor da superfície e
  /// um véu da própria cor por baixo da linha.
  LineChartBarData _buildLinha(
    ThemeData theme,
    List<FlSpot> spots,
    Color cor,
  ) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: cor,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 4,
            color: cor,
            strokeWidth: 2,
            strokeColor: theme.colorScheme.surfaceContainerHighest,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [
            cor.withValues(alpha: 0.3),
            cor.withValues(alpha: 0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  double _getMaxSaldo() {
    double max = 0;
    for (var caixa in widget.caixas) {
      if (caixa.statusCaixa == 1 && (caixa.saldo ?? 0) > max) {
        max = caixa.saldo!;
      }
    }
    return max > 0 ? max : 1000;
  }

  double _getMaxPedidos() {
    double max = 0;
    for (var caixa in widget.caixas) {
      if (caixa.statusCaixa == 1 && (caixa.totalPedidoConfirmado ?? 0) > max) {
        max = caixa.totalPedidoConfirmado!.toDouble();
      }
    }
    return max > 0 ? max : 100;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }
}
