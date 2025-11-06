import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/caixa.dart';

class CaixaPage extends StatelessWidget {
  final Caixa caixa;

  const CaixaPage({super.key, required this.caixa});

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat('dd-MM HH:mm').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Detalhes do Caixa #${caixa.idCaixa}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Informações Gerais'),
                _buildDetailRow(
                  'ID do Caixa:',
                  caixa.idCaixa?.toString() ?? 'N/A',
                ),
                _buildDetailRow('ID do Usuário:', caixa.idUsuario.toString()),
                _buildDetailRow('Status:', caixa.statusCaixa.toString()),
                _buildDetailRow(
                  'Data de Abertura:',
                  _formatDateTime(caixa.dataAbertura),
                ),
                _buildDetailRow(
                  'Data de Fechamento:',
                  _formatDateTime(caixa.dataFechamento),
                ),
                const Divider(height: 32),
                _buildSectionTitle('Valores'),
                _buildDetailRow(
                  'Saldo Total:',
                  'R\$ ${caixa.saldo?.toStringAsFixed(2) ?? '0.00'}',
                ),
                _buildDetailRow(
                  'Troco Inicial:',
                  'R\$ ${caixa.troco?.toStringAsFixed(2) ?? '0.00'}',
                ),
                _buildDetailRow(
                  'Sangria:',
                  'R\$ ${caixa.sangria?.toStringAsFixed(2) ?? '0.00'}',
                ),
                const Divider(height: 32),
                _buildSectionTitle('Saldos por Forma de Pagamento'),
                _buildDetailRow(
                  'Dinheiro:',
                  'R\$ ${caixa.saldoDinheiro?.toStringAsFixed(2) ?? '0.00'}',
                ),
                _buildDetailRow(
                  'Cartão:',
                  'R\$ ${caixa.saldoCartao?.toStringAsFixed(2) ?? '0.00'}',
                ),
                _buildDetailRow(
                  'PIX:',
                  'R\$ ${caixa.saldoPix?.toStringAsFixed(2) ?? '0.00'}',
                ),
                _buildDetailRow(
                  'Ticket:',
                  'R\$ ${caixa.saldoTicket?.toStringAsFixed(2) ?? '0.00'}',
                ),
                _buildDetailRow(
                  'Outras:',
                  'R\$ ${caixa.saldoOutras?.toStringAsFixed(2) ?? '0.00'}',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }
}
