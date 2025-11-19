import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/boleto.dart';

enum BoletoStatus {
  pendente, // Verde - vence em dias futuros
  venceHoje, // Laranja - vence hoje
  vencido, // Vermelho - já passou da data
}

class BoletosWidget extends StatefulWidget {
  final List<Boleto> boletos;

  const BoletosWidget({super.key, required this.boletos});

  @override
  State<BoletosWidget> createState() => _BoletosWidgetState();
}

class _BoletosWidgetState extends State<BoletosWidget> {
  bool _autoOpenExecuted = false;

  BoletoStatus _getBoletoStatus(Boleto boleto) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(
      boleto.dueDateParsed.year,
      boleto.dueDateParsed.month,
      boleto.dueDateParsed.day,
    );

    if (dueDay.isBefore(today)) {
      return BoletoStatus.vencido;
    } else if (dueDay.isAtSameMomentAs(today)) {
      return BoletoStatus.venceHoje;
    } else {
      return BoletoStatus.pendente;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.boletos.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final boletosVencidos = widget.boletos.where((b) => b.isOverdue).length;
    final boletosPendentes = widget.boletos.where((b) => b.isPending).length;

    // Auto-abrir apenas o primeiro boleto urgente (hoje ou vencido)
    if (!_autoOpenExecuted) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final boletoUrgente = widget.boletos.firstWhere((b) {
        final dueDay = DateTime(
          b.dueDateParsed.year,
          b.dueDateParsed.month,
          b.dueDateParsed.day,
        );
        return dueDay.isBefore(today) || dueDay.isAtSameMomentAs(today);
      }, orElse: () => widget.boletos.first);

      final shouldAutoOpen =
          boletoUrgente.isOverdue || boletoUrgente.dueDateParsed.day == now.day;

      if (shouldAutoOpen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final status = _getBoletoStatus(boletoUrgente);
            _openBoleto(context, boletoUrgente.invoiceUrl, status);
            setState(() => _autoOpenExecuted = true);
          }
        });
      }
    }

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
                        style: theme.textTheme.titleMedium?.copyWith(
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
                  widget.boletos
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
    final isDark = theme.brightness == Brightness.dark;
    final status = _getBoletoStatus(boleto);
    final dateFormat = DateFormat('dd/MM/yyyy');
    final dueDate = dateFormat.format(boleto.dueDateParsed);

    // Cores baseadas no status
    Color statusColor;
    String statusText;

    switch (status) {
      case BoletoStatus.vencido:
        statusColor = Colors.red;
        statusText = 'VENCIDO';
        break;
      case BoletoStatus.venceHoje:
        statusColor = Colors.orange;
        statusText = 'VENCE HOJE';
        break;
      case BoletoStatus.pendente:
        statusColor = Colors.yellow.shade700;
        statusText = 'PENDENTE';
        break;
    }

    return InkWell(
      onTap: () => _openBoleto(context, boleto.invoiceUrl, status),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 180,
        height: 100,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            // Sombra externa (neumorfismo)
            BoxShadow(
              color:
                  isDark ? Colors.black.withOpacity(0.5) : Colors.grey.shade400,
              offset: const Offset(6, 6),
              blurRadius: 12,
              spreadRadius: 0,
            ),
            // Luz (neumorfismo)
            BoxShadow(
              color:
                  isDark
                      ? Colors.grey.shade900.withOpacity(0.3)
                      : Colors.white.withOpacity(0.9),
              offset: const Offset(-6, -6),
              blurRadius: 12,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Efeito de linhas pontilhadas (serrilhado do boleto)
            Positioned(
              left: 0,
              right: 0,
              top: 30,
              child: CustomPaint(
                size: const Size(double.infinity, 1),
                painter: _DashedLinePainter(
                  color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabeçalho - Ícone de código de barras
                  Row(
                    children: [
                      Icon(
                        Icons.qr_code_2,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                        size: 18,
                      ),
                      const Spacer(),
                      // Badge de status
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Data de vencimento
                  Text(
                    'Vencimento',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dueDate,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Código de barras simulado
                  Row(
                    children: List.generate(
                      8,
                      (index) => Expanded(
                        child: Container(
                          height: 12,
                          margin: EdgeInsets.only(right: index < 7 ? 2 : 0),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[700] : Colors.grey[800],
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
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

  void _openBoleto(BuildContext context, String url, BoletoStatus status) {
    // Definir cor e mensagem baseado no status
    Color statusColor;
    String statusTitle;
    String statusMessage;
    IconData statusIcon;

    switch (status) {
      case BoletoStatus.vencido:
        statusColor = Colors.red;
        statusTitle = 'Boleto Vencido';
        statusMessage =
            'Efetue o pagamento o quanto antes para evitar bloqueio';
        statusIcon = Icons.error_outline;
        break;
      case BoletoStatus.venceHoje:
        statusColor = Colors.orange;
        statusTitle = 'Vence Hoje';
        statusMessage = 'Efetue o pagamento clicando no link abaixo';
        statusIcon = Icons.warning_amber_outlined;
        break;
      case BoletoStatus.pendente:
        statusColor = Colors.yellow.shade700;
        statusTitle = 'Boleto em aberto';
        statusMessage = 'Efetue o pagamento clicando no link abaixo';
        statusIcon = Icons.receipt_long_outlined;
        break;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            icon: Icon(statusIcon, color: statusColor, size: 48),
            title: Text(statusTitle, style: TextStyle(color: statusColor)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  statusMessage,
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Clique no botão abaixo para copiar o link do boleto:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
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
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Link copiado para a área de transferência!',
                              ),
                            ],
                          ),
                          backgroundColor: statusColor,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: statusColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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

/// Painter para criar linha pontilhada (serrilhado do boleto)
class _DashedLinePainter extends CustomPainter {
  final Color color;

  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashSpace = 3.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
