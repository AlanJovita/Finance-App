import 'package:finance_app/utils/currency_formatter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../models/relatorio_mensal.dart';
import '../../utils/app_colors_extension.dart';
import '../../utils/app_tokens.dart';

class MonthlyChartsWidget extends StatefulWidget {
  final List<RelatorioMensal> relatorios;

  const MonthlyChartsWidget({super.key, required this.relatorios});

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

  @override
  Widget build(BuildContext context) {
    if (widget.relatorios.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Nenhum dado disponível para exibir gráficos'),
        ),
      );
    }

    return Column(
      children: [
        _buildSaldoChart(context),
        const SizedBox(height: 16),
        _buildPedidosChart(context),
      ],
    );
  }

  Widget _buildSaldoChart(BuildContext context) {
    final theme = Theme.of(context);
    final cores = context.appColors;

    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Faturamento Mensal',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Soma dos faturamentos e média mensal',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 24),
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
                              final relatorio =
                                  widget.relatorios[spot.x.toInt()];
                              final isMedia = spot.barIndex == 1;
                              return LineTooltipItem(
                                '${relatorio.nomeMesAbreviado}\n',
                                TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                                children: [
                                  TextSpan(
                                    text:
                                        isMedia
                                            ? 'Média: ${CurrencyFormatter.format(spot.y)}'
                                            : 'Soma: ${CurrencyFormatter.format(spot.y)}',
                                    style: TextStyle(
                                      color: spot.bar.color,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              );
                            }).toList();
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 &&
                                  index < widget.relatorios.length &&
                                  value == value.toInt()) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    widget.relatorios[index].nomeMesAbreviado,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 50,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                'R\$ ${CurrencyFormatter.formatSimple(value / 1000, decimals: 0)}k',
                                style: theme.textTheme.bodySmall,
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
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
                      lineBarsData: _buildSaldoLineData(context),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Soma', cores.series1),
                const SizedBox(width: AppSpacing.xl),
                _buildLegendItem('Média (linha tracejada)', cores.series2),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPedidosChart(BuildContext context) {
    final theme = Theme.of(context);
    final cores = context.appColors;

    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pedidos Mensais',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total de pedidos, média e estornados',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return LineChart(
                    LineChartData(
                      maxY: _getMaxPedidos() * 1.2,
                      minY: 0,
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor:
                              (touchedSpot) =>
                                  theme.colorScheme.surfaceContainerHighest,
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final relatorio =
                                  widget.relatorios[spot.x.toInt()];
                              String label;
                              if (spot.barIndex == 0) {
                                label = 'Total';
                              } else if (spot.barIndex == 1) {
                                label = 'Média';
                              } else {
                                label = 'Estornados';
                              }
                              return LineTooltipItem(
                                '${relatorio.nomeMesAbreviado}\n',
                                TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                                children: [
                                  TextSpan(
                                    text:
                                        '$label: ${CurrencyFormatter.formatSimple(spot.y, decimals: 0)}',
                                    style: TextStyle(
                                      color: spot.bar.color,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              );
                            }).toList();
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 &&
                                  index < widget.relatorios.length &&
                                  value == value.toInt()) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    widget.relatorios[index].nomeMesAbreviado,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: theme.textTheme.bodySmall,
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: _getMaxPedidos() / 5,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: theme.dividerColor,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: _buildPedidosLineData(context),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Total', cores.series1),
                const SizedBox(width: AppSpacing.lg),
                _buildLegendItem('Média', cores.series2),
                const SizedBox(width: AppSpacing.lg),
                _buildLegendItem('Estornados', cores.series3),
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

  /// A série principal: traço grosso, ponto com anel da cor da superfície e um
  /// véu da própria cor por baixo.
  LineChartBarData _buildLinhaPrincipal(
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
          colors: [cor.withValues(alpha: 0.3), cor.withValues(alpha: 0.0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  /// Uma série secundária: traço fino, sem véu. O tracejado marca a linha de
  /// referência (a média), que é um limiar e não uma medição.
  LineChartBarData _buildLinhaSecundaria(
    ThemeData theme,
    List<FlSpot> spots,
    Color cor, {
    bool tracejada = false,
  }) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: cor,
      barWidth: 2,
      isStrokeCapRound: true,
      dashArray: tracejada ? [5, 5] : null,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 3,
            color: cor,
            strokeWidth: tracejada ? 1 : 2,
            strokeColor: theme.colorScheme.surfaceContainerHighest,
          );
        },
      ),
    );
  }

  List<LineChartBarData> _buildSaldoLineData(BuildContext context) {
    final theme = Theme.of(context);
    final cores = context.appColors;
    final animationValue = _animation.value;

    // Calcular a média dos saldos
    double totalSaldo = 0;
    for (var relatorio in widget.relatorios) {
      totalSaldo += (relatorio.somaSaldo ?? 0);
    }
    final mediaSaldo =
        widget.relatorios.isNotEmpty
            ? totalSaldo / widget.relatorios.length
            : 0;

    // Linha principal com área preenchida (Soma)
    final somaSpots = List.generate(
      widget.relatorios.length,
      (index) => FlSpot(
        index.toDouble(),
        (widget.relatorios[index].somaSaldo ?? 0) * animationValue,
      ),
    );

    // Linha da média (valor fixo calculado)
    final mediaSpots = List.generate(
      widget.relatorios.length,
      (index) => FlSpot(index.toDouble(), mediaSaldo * animationValue),
    );

    return [
      _buildLinhaPrincipal(theme, somaSpots, cores.series1),
      _buildLinhaSecundaria(theme, mediaSpots, cores.series2, tracejada: true),
    ];
  }

  List<LineChartBarData> _buildPedidosLineData(BuildContext context) {
    final theme = Theme.of(context);
    final cores = context.appColors;
    final animationValue = _animation.value;

    // Calcular a média dos pedidos confirmados
    double totalPedidos = 0;
    for (var relatorio in widget.relatorios) {
      totalPedidos += (relatorio.somaPedidosConfirmados ?? 0);
    }
    final mediaPedidos =
        widget.relatorios.isNotEmpty
            ? totalPedidos / widget.relatorios.length
            : 0;

    // Linha principal (Total de pedidos confirmados)
    final totalSpots = List.generate(
      widget.relatorios.length,
      (index) => FlSpot(
        index.toDouble(),
        (widget.relatorios[index].somaPedidosConfirmados ?? 0) * animationValue,
      ),
    );

    // Linha da média (valor fixo calculado)
    final mediaSpots = List.generate(
      widget.relatorios.length,
      (index) => FlSpot(index.toDouble(), mediaPedidos * animationValue),
    );

    // Linha dos estornados
    final estornadosSpots = List.generate(
      widget.relatorios.length,
      (index) => FlSpot(
        index.toDouble(),
        (widget.relatorios[index].somaPedidosEstornados ?? 0) * animationValue,
      ),
    );

    return [
      _buildLinhaPrincipal(theme, totalSpots, cores.series1),
      _buildLinhaSecundaria(theme, mediaSpots, cores.series2, tracejada: true),
      // Estornados pediam vermelho, mas o vermelho de erro fica em ΔE 8.7 da
      // série magenta no tema escuro — indistinguíveis. Fica na terceira série,
      // que é validada contra as outras duas; quem nomeia é a legenda.
      _buildLinhaSecundaria(theme, estornadosSpots, cores.series3),
    ];
  }

  double _getMaxSaldo() {
    double max = 0;
    for (var relatorio in widget.relatorios) {
      if ((relatorio.somaSaldo ?? 0) > max) {
        max = relatorio.somaSaldo!;
      }
    }
    return max > 0 ? max : 1000;
  }

  double _getMaxPedidos() {
    double max = 0;
    for (var relatorio in widget.relatorios) {
      if ((relatorio.somaPedidosConfirmados ?? 0) > max) {
        max = relatorio.somaPedidosConfirmados!;
      }
    }
    return max > 0 ? max : 100;
  }
}
