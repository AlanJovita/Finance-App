import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../models/caixa.dart';

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
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
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
                                  isDark
                                      ? Colors.grey[800]!
                                      : Colors.grey[100]!,
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
                                    color: isDark ? Colors.white : Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  children: [
                                    TextSpan(
                                      text:
                                          isSaldo
                                              ? 'Saldo: R\$ ${(caixa.saldo ?? 0).toStringAsFixed(2)}'
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
                            color:
                                isDark ? Colors.grey[800]! : Colors.grey[300]!,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: _buildLineData(isDark),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(
                  'Faturamento',
                  isDark ? Colors.green[300]! : Colors.green[600]!,
                ),
                const SizedBox(width: 24),
                _buildLegendItem(
                  'Pedidos',
                  isDark ? Colors.blue[300]! : Colors.blue[600]!,
                ),
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
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  List<LineChartBarData> _buildLineData(bool isDark) {
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
      // Linha de saldo
      LineChartBarData(
        spots: saldoSpots,
        isCurved: true,
        color: isDark ? Colors.green[300] : Colors.green[600],
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            return FlDotCirclePainter(
              radius: 4,
              color: isDark ? Colors.green[300]! : Colors.green[600]!,
              strokeWidth: 2,
              strokeColor: isDark ? Colors.grey[900]! : Colors.white,
            );
          },
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            colors: [
              (isDark ? Colors.green[300]! : Colors.green[600]!).withOpacity(
                0.3,
              ),
              (isDark ? Colors.green[300]! : Colors.green[600]!).withOpacity(
                0.0,
              ),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
      // Linha de pedidos confirmados
      LineChartBarData(
        spots: pedidosSpots,
        isCurved: true,
        color: isDark ? Colors.blue[300] : Colors.blue[600],
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            return FlDotCirclePainter(
              radius: 4,
              color: isDark ? Colors.blue[300]! : Colors.blue[600]!,
              strokeWidth: 2,
              strokeColor: isDark ? Colors.grey[900]! : Colors.white,
            );
          },
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            colors: [
              (isDark ? Colors.blue[300]! : Colors.blue[600]!).withOpacity(0.3),
              (isDark ? Colors.blue[300]! : Colors.blue[600]!).withOpacity(0.0),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
    ];
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
