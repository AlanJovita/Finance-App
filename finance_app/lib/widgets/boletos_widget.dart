import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/boleto.dart';

class BoletosWidget extends StatelessWidget {
  final List<Boleto> boletos;

  const BoletosWidget({super.key, required this.boletos});

  @override
  Widget build(BuildContext context) {
    if (boletos.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final boletosVencidos = boletos.where((b) => b.isOverdue).length;
    final boletosPendentes = boletos.where((b) => b.isPending).length;

    return Card(
      elevation: 8.0,
      shadowColor: Colors.black.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho
            Row(
              children: [
                Icon(
                  Icons.receipt_long,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Boletos em Aberto',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$boletosVencidos vencido(s) • $boletosPendentes pendente(s)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Lista de boletos em linha
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  boletos
                      .map((boleto) => _buildBoletoCard(context, boleto))
                      .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoletoCard(BuildContext context, Boleto boleto) {
    final theme = Theme.of(context);
    final isOverdue = boleto.isOverdue;
    final dateFormat = DateFormat('dd/MM');
    final dueDate = dateFormat.format(boleto.dueDateParsed);

    return InkWell(
      onTap: () => _openBoleto(context, boleto.invoiceUrl),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color:
              isOverdue
                  ? Colors.red.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isOverdue
                    ? Colors.red.withOpacity(0.5)
                    : Colors.orange.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícone de status
            Icon(
              isOverdue ? Icons.warning_rounded : Icons.schedule_rounded,
              color: isOverdue ? Colors.red : Colors.orange[700],
              size: 20,
            ),
            const SizedBox(width: 8),
            // Data
            Text(
              dueDate,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isOverdue ? Colors.red : Colors.orange[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openBoleto(BuildContext context, String url) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            icon: const Icon(Icons.receipt_long, color: Colors.blue, size: 48),
            title: const Text('Link do Boleto'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Clique no botão abaixo para copiar o link do boleto:',
                  style: TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // Container com URL
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link, color: Colors.grey, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          url,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Botão de Copiar
                ElevatedButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: url));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Link copiado para a área de transferência!',
                              ),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text('Copiar Link'),
                      SizedBox(width: 8),
                      Icon(Icons.content_copy, size: 20),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
            ],
          ),
    );
  }
}
