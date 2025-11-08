import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/caixa.dart';

class CaixaPage extends StatelessWidget {
  final Caixa caixa;

  const CaixaPage({super.key, required this.caixa});

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Aberto';
    return DateFormat('dd-MM HH:mm').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('Detalhes do Caixa #${caixa.idCaixa}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Cabeçalho com datas
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildHeaderInfo(
                        context,
                        icon: Icons.login,
                        label: 'Abertura',
                        value: _formatDateTime(caixa.dataAbertura),
                        iconColor: colorScheme.primary,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.shade300,
                    ),
                    Expanded(
                      child: _buildHeaderInfo(
                        context,
                        icon: Icons.logout,
                        label: 'Fechamento',
                        value: _formatDateTime(caixa.dataFechamento),
                        iconColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Grid responsivo de saldos
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 1.8,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    _buildPaymentCard(
                      context,
                      icon: Icons.account_balance_wallet,
                      label: 'Dinheiro',
                      value: caixa.saldoDinheiro ?? 0.00,
                      color: Colors.green,
                    ),
                    _buildPaymentCard(
                      context,
                      icon: Icons.credit_card,
                      label: 'Cartão',
                      value: caixa.saldoCartao ?? 0.00,
                      color: colorScheme.primary,
                    ),
                    _buildPaymentCard(
                      context,
                      icon: Icons.pix,
                      label: 'PIX',
                      value: caixa.saldoPix ?? 0.00,
                      color: Colors.teal,
                    ),
                    _buildPaymentCard(
                      context,
                      icon: Icons.confirmation_number,
                      label: 'Ticket',
                      value: caixa.saldoTicket ?? 0.00,
                      color: colorScheme.primary,
                    ),
                    _buildPaymentCard(
                      context,
                      icon: Icons.more_horiz,
                      label: 'Outros',
                      value: caixa.saldoOutras ?? 0.00,
                      color: Colors.grey,
                    ),
                    _buildPaymentCard(
                      context,
                      icon: Icons.remove_circle,
                      label: 'Sangria',
                      value: caixa.sangria ?? 0.00,
                      color: Colors.red,
                      backgroundColor: Colors.red.shade50,
                    ),
                    _buildPaymentCard(
                      context,
                      icon: Icons.add_circle,
                      label: 'Suprimento',
                      value: 0.00, // Adicionar campo se existir no modelo
                      color: Colors.grey,
                      backgroundColor: Colors.grey.shade100,
                    ),
                    _buildPaymentCard(
                      context,
                      icon: Icons.laptop,
                      label: 'Troco',
                      value: caixa.troco ?? 0.00,
                      color: Colors.grey,
                      backgroundColor: Colors.grey.shade100,
                    ),
                    _buildPaymentCard(
                      context,
                      icon: Icons.add_circle_outline,
                      label: 'Próximo Caixa',
                      value: 0.00, // Adicionar campo se existir no modelo
                      color: Colors.grey,
                      backgroundColor: Colors.grey.shade100,
                    ),
                    _buildPaymentCard(
                      context,
                      icon: Icons.info_outline,
                      label: 'Não Faturado',
                      value: 0.00, // Adicionar campo se existir no modelo
                      color: Colors.grey,
                      backgroundColor: Colors.grey.shade100,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Total do Caixa
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total do Caixa',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'R\$ ${caixa.saldo?.toStringAsFixed(2) ?? '0,00'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfo(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildPaymentCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required double value,
    required Color color,
    Color? backgroundColor,
  }) {
    return Card(
      elevation: 2,
      color: backgroundColor ?? Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
