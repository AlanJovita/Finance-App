import 'package:finance_app/utils/currency_formatter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/caixa.dart';

class CaixaPage extends StatelessWidget {
  final Caixa caixa;

  const CaixaPage({super.key, required this.caixa});

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Aberto';
    final formatted = DateFormat('dd/MM HH:mm').format(dateTime);
    final dayOfWeek = _getDayOfWeek(dateTime.weekday);
    return '$formatted [$dayOfWeek]';
  }

  String _getDayOfWeek(int weekday) {
    const days = [
      'Segunda',
      'Terça',
      'Quarta',
      'Quinta',
      'Sexta',
      'Sábado',
      'Domingo',
    ];
    return days[weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Calcula o total para o gráfico
    final total =
        (caixa.saldoDinheiro ?? 0) +
        (caixa.saldoCartao ?? 0) +
        (caixa.saldoPix ?? 0) +
        (caixa.saldoTicket ?? 0) +
        (caixa.saldoOutras ?? 0);

    return Scaffold(
      backgroundColor: isDark ? null : Colors.grey[100],
      appBar: AppBar(title: Text('Caixa #${caixa.idCaixa}'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Card de Informações de Abertura/Fechamento
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        context,
                        icon: Icons.login,
                        label: 'Abertura',
                        value: _formatDateTime(caixa.dataAbertura),
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoCard(
                        context,
                        icon: Icons.logout,
                        label: 'Fechamento',
                        value: _formatDateTime(caixa.dataFechamento),
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card com Gráfico Circular
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Total no centro
                    Text(
                      CurrencyFormatter.format(total),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total de Pagamentos',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Gráfico Donut
                    SizedBox(
                      height: 220,
                      child:
                          total > 0
                              ? PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 60,
                                  sections: _buildPieChartSections(isDark),
                                  pieTouchData: PieTouchData(
                                    touchCallback:
                                        (
                                          FlTouchEvent event,
                                          pieTouchResponse,
                                        ) {},
                                  ),
                                ),
                              )
                              : Center(
                                child: Text(
                                  'Sem dados',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                    ),
                    const SizedBox(height: 24),

                    // Legenda (somente valores > 0)
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        if ((caixa.saldoDinheiro ?? 0) > 0)
                          _buildLegendItem(
                            'Dinheiro',
                            const Color(0xFF4CAF50),
                            caixa.saldoDinheiro ?? 0,
                          ),
                        if ((caixa.saldoCartao ?? 0) * 0.6 > 0)
                          _buildLegendItem(
                            'Crédito',
                            const Color(0xFFFF6B9D),
                            (caixa.saldoCartao ?? 0) * 0.6,
                          ),
                        if ((caixa.saldoCartao ?? 0) * 0.4 > 0)
                          _buildLegendItem(
                            'Débito',
                            const Color(0xFF2196F3),
                            (caixa.saldoCartao ?? 0) * 0.4,
                          ),
                        if ((caixa.saldoPix ?? 0) > 0)
                          _buildLegendItem(
                            'PIX',
                            const Color(0xFF00BCD4),
                            caixa.saldoPix ?? 0,
                          ),
                        if ((caixa.saldoTicket ?? 0) > 0)
                          _buildLegendItem(
                            'Ticket',
                            const Color(0xFFFF9800),
                            caixa.saldoTicket ?? 0,
                          ),
                        if ((caixa.saldoOutras ?? 0) > 0)
                          _buildLegendItem(
                            'Outros',
                            const Color(0xFF9E9E9E),
                            caixa.saldoOutras ?? 0,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Lista de Informações
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Cabeçalho
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[100],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long, color: theme.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Detalhes do Caixa',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Lista de itens
                  _buildListItem(
                    context,
                    icon: Icons.account_balance_wallet,
                    label: 'Dinheiro',
                    value: caixa.saldoDinheiro ?? 0,
                    color: const Color(0xFF4CAF50),
                  ),
                  _buildListItem(
                    context,
                    icon: Icons.credit_card,
                    label: 'Crédito',
                    value: (caixa.saldoCartao ?? 0) * 0.6,
                    color: const Color(0xFFFF6B9D),
                  ),
                  _buildListItem(
                    context,
                    icon: Icons.credit_card,
                    label: 'Débito',
                    value: (caixa.saldoCartao ?? 0) * 0.4,
                    color: const Color(0xFF2196F3),
                  ),
                  _buildListItem(
                    context,
                    icon: Icons.pix,
                    label: 'PIX',
                    value: caixa.saldoPix ?? 0,
                    color: const Color(0xFF00BCD4),
                  ),
                  _buildListItem(
                    context,
                    icon: Icons.confirmation_number,
                    label: 'Ticket',
                    value: caixa.saldoTicket ?? 0,
                    color: const Color(0xFFFF9800),
                  ),
                  _buildListItem(
                    context,
                    icon: Icons.more_horiz,
                    label: 'Outros',
                    value: caixa.saldoOutras ?? 0,
                    color: const Color(0xFF9E9E9E),
                  ),
                  const Divider(height: 1),
                  _buildListItem(
                    context,
                    icon: Icons.remove_circle_outline,
                    label: 'Sangria',
                    value: caixa.sangria ?? 0,
                    color: Colors.red,
                    isNegative: true,
                  ),
                  _buildListItem(
                    context,
                    icon: Icons.attach_money,
                    label: 'Troco',
                    value: caixa.troco ?? 0,
                    color: Colors.grey,
                  ),
                  const Divider(height: 1, thickness: 2),
                  _buildListItem(
                    context,
                    icon: Icons.account_balance,
                    label: 'Saldo Final',
                    value: caixa.saldo ?? 0,
                    color: Colors.green,
                    isBold: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(bool isDark) {
    final dinheiro = caixa.saldoDinheiro ?? 0;
    final cartao = caixa.saldoCartao ?? 0;
    final pix = caixa.saldoPix ?? 0;
    final ticket = caixa.saldoTicket ?? 0;
    final outras = caixa.saldoOutras ?? 0;

    // Divide cartão em crédito (60%) e débito (40%)
    final credito = cartao * 0.6;
    final debito = cartao * 0.4;

    final total = dinheiro + cartao + pix + ticket + outras;

    if (total == 0) return [];

    final sections = <PieChartSectionData>[];

    if (dinheiro > 0) {
      sections.add(
        PieChartSectionData(
          color: const Color(0xFF4CAF50),
          value: dinheiro,
          title: '${((dinheiro / total) * 100).toStringAsFixed(0)}%',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    if (credito > 0) {
      sections.add(
        PieChartSectionData(
          color: const Color(0xFFFF6B9D),
          value: credito,
          title: '${((credito / total) * 100).toStringAsFixed(0)}%',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    if (debito > 0) {
      sections.add(
        PieChartSectionData(
          color: const Color(0xFF2196F3),
          value: debito,
          title: '${((debito / total) * 100).toStringAsFixed(0)}%',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    if (pix > 0) {
      sections.add(
        PieChartSectionData(
          color: const Color(0xFF00BCD4),
          value: pix,
          title: '${((pix / total) * 100).toStringAsFixed(0)}%',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    if (ticket > 0) {
      sections.add(
        PieChartSectionData(
          color: const Color(0xFFFF9800),
          value: ticket,
          title: '${((ticket / total) * 100).toStringAsFixed(0)}%',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    if (outras > 0) {
      sections.add(
        PieChartSectionData(
          color: const Color(0xFF9E9E9E),
          value: outras,
          title: '${((outras / total) * 100).toStringAsFixed(0)}%',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return sections;
  }

  Widget _buildLegendItem(String label, Color color, double value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 4),
        Text(
          CurrencyFormatter.format(value),
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildListItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required double value,
    required Color color,
    bool isNegative = false,
    bool isBold = false,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isBold ? 16 : 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          Text(
            CurrencyFormatter.format(value),
            style: TextStyle(
              fontSize: isBold ? 18 : 15,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color:
                  isNegative
                      ? Colors.red
                      : (isBold
                          ? Colors.green
                          : theme.textTheme.bodyLarge?.color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
