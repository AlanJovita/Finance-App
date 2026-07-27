import 'package:finance_app/utils/currency_formatter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/caixa.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';

/// Um meio de pagamento com o que é preciso para desenhá-lo: o gráfico, a
/// legenda e a lista de detalhes saem todos desta mesma lista, em vez de cada
/// um repetir a paleta por conta própria.
typedef _MetodoPagamento = ({
  String label,
  IconData icone,
  double valor,
  Color cor,
});

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

  /// A ordem desta lista é a ordem das fatias no anel, e as cores vizinhas aqui
  /// são as vizinhas lá. A separação entre vizinhas é o que sustenta a leitura
  /// sob daltonismo — a ordem foi validada junto com a paleta em [AppColors].
  List<_MetodoPagamento> _metodos(AppColors cores) {
    final cartao = caixa.saldoCartao ?? 0;

    return [
      (
        label: 'Dinheiro',
        icone: Icons.account_balance_wallet,
        valor: caixa.saldoDinheiro ?? 0,
        cor: cores.paymentDinheiro,
      ),
      // A API devolve o cartão somado; a divisão 60/40 entre crédito e débito é
      // uma estimativa fixa, não um dado real vindo do caixa.
      (
        label: 'Crédito',
        icone: Icons.credit_card,
        valor: cartao * 0.6,
        cor: cores.paymentCredito,
      ),
      (
        label: 'Débito',
        icone: Icons.credit_card,
        valor: cartao * 0.4,
        cor: cores.paymentDebito,
      ),
      (
        label: 'PIX',
        icone: Icons.pix,
        valor: caixa.saldoPix ?? 0,
        cor: cores.paymentPix,
      ),
      (
        label: 'Ticket',
        icone: Icons.confirmation_number,
        valor: caixa.saldoTicket ?? 0,
        cor: cores.paymentTicket,
      ),
      (
        label: 'Outros',
        icone: Icons.more_horiz,
        valor: caixa.saldoOutras ?? 0,
        cor: cores.paymentOutras,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cores = context.appColors;
    final metodos = _metodos(cores);
    final total = metodos.fold<double>(0, (soma, m) => soma + m.valor);

    return Scaffold(
      appBar: AppBar(title: Text('Caixa #${caixa.idCaixa}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            _buildAberturaFechamento(context),
            const SizedBox(height: AppSpacing.lg),
            _buildGrafico(context, metodos, total),
            const SizedBox(height: AppSpacing.lg),
            _buildDetalhes(context, metodos),
          ],
        ),
      ),
    );
  }

  Widget _buildAberturaFechamento(BuildContext context) {
    final cores = context.appColors;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                context,
                icon: Icons.login,
                label: 'Abertura',
                value: _formatDateTime(caixa.dataAbertura),
                color: cores.success,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildInfoCard(
                context,
                icon: Icons.logout,
                label: 'Fechamento',
                value: _formatDateTime(caixa.dataFechamento),
                color: cores.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrafico(
    BuildContext context,
    List<_MetodoPagamento> metodos,
    double total,
  ) {
    final theme = Theme.of(context);
    final comValor = metodos.where((m) => m.valor > 0).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Text(
              CurrencyFormatter.format(total),
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Total de Pagamentos',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            SizedBox(
              height: 220,
              child:
                  total > 0
                      ? PieChart(
                        PieChartData(
                          // 2px de superfície entre as fatias separa sem
                          // precisar de borda em volta de cada uma.
                          sectionsSpace: 2,
                          centerSpaceRadius: 60,
                          sections: [
                            for (final m in comValor)
                              PieChartSectionData(
                                color: m.cor,
                                value: m.valor,
                                showTitle: false,
                                radius: 50,
                              ),
                          ],
                        ),
                      )
                      : Center(
                        child: Text(
                          'Sem dados',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
            ),
            if (comValor.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              // A legenda carrega nome, valor e percentual. O percentual ficava
              // escrito em branco dentro da fatia, onde não alcançava contraste
              // legível e ainda sumia nas fatias finas.
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.md,
                alignment: WrapAlignment.center,
                children: [
                  for (final m in comValor)
                    _buildLegendItem(context, m, m.valor / total),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetalhes(BuildContext context, List<_MetodoPagamento> metodos) {
    final theme = Theme.of(context);
    final cores = context.appColors;

    return Card(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: _fillSutil(theme),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                topRight: Radius.circular(AppRadius.lg),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.receipt_long, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Text('Detalhes do Caixa', style: theme.textTheme.titleMedium),
              ],
            ),
          ),

          for (final m in metodos)
            _buildListItem(
              context,
              icon: m.icone,
              label: m.label,
              value: m.valor,
              color: m.cor,
            ),

          const Divider(height: 1),
          _buildListItem(
            context,
            icon: Icons.remove_circle_outline,
            label: 'Sangria',
            value: caixa.sangria ?? 0,
            color: cores.error,
            isNegative: true,
          ),
          _buildListItem(
            context,
            icon: Icons.attach_money,
            label: 'Troco',
            value: caixa.troco ?? 0,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const Divider(height: 1, thickness: 2),
          _buildListItem(
            context,
            icon: Icons.account_balance,
            label: 'Saldo Final',
            value: caixa.saldo ?? 0,
            color: cores.success,
            isBold: true,
          ),
        ],
      ),
    );
  }

  /// Um véu sobre a superfície do card, para destacar um bloco sem inventar uma
  /// cor por modo.
  Color _fillSutil(ThemeData theme) =>
      theme.colorScheme.onSurface.withValues(alpha: 0.05);

  Widget _buildLegendItem(
    BuildContext context,
    _MetodoPagamento metodo,
    double fracao,
  ) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: metodo.cor, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        // O texto usa tinta de texto; quem carrega a identidade da fatia é o
        // ponto colorido ao lado.
        Text(metodo.label, style: theme.textTheme.labelMedium),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '${CurrencyFormatter.format(metodo.valor)} · ${(fracao * 100).toStringAsFixed(0)}%',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
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
    final cores = context.appColors;

    final valueColor =
        isNegative
            ? cores.error
            : (isBold ? cores.success : theme.textTheme.bodyLarge?.color);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: isBold ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            CurrencyFormatter.format(value),
            style: (isBold
                    ? theme.textTheme.titleLarge
                    : theme.textTheme.titleSmall)
                ?.copyWith(color: valueColor),
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

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _fillSutil(theme),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(value, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}
