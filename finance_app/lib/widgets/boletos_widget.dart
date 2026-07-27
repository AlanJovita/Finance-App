import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/boleto.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';

enum BoletoStatus {
  pendente, // vence em dias futuros
  venceHoje, // vence hoje
  vencido; // já passou da data

  String get rotulo => switch (this) {
    BoletoStatus.vencido => 'VENCIDO',
    BoletoStatus.venceHoje => 'VENCE HOJE',
    BoletoStatus.pendente => 'PENDENTE',
  };

  String get titulo => switch (this) {
    BoletoStatus.vencido => 'Boleto Vencido',
    BoletoStatus.venceHoje => 'Vence Hoje',
    BoletoStatus.pendente => 'Boleto em aberto',
  };

  String get mensagem => switch (this) {
    BoletoStatus.vencido =>
      'Efetue o pagamento o quanto antes para evitar bloqueio',
    _ => 'Efetue o pagamento clicando no link abaixo',
  };

  IconData get icone => switch (this) {
    BoletoStatus.vencido => Icons.error_outline,
    BoletoStatus.venceHoje => Icons.warning_amber_outlined,
    BoletoStatus.pendente => Icons.receipt_long_outlined,
  };

  /// Três degraus de urgência crescente na escala de status.
  Color cor(AppColors cores) => switch (this) {
    BoletoStatus.vencido => cores.error,
    BoletoStatus.venceHoje => cores.serious,
    BoletoStatus.pendente => cores.warning,
  };
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
      elevation: AppElevation.overlay,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Boletos em Aberto',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        '$boletosVencidos vencido(s) • $boletosPendentes pendente(s)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final boleto in widget.boletos)
                  _buildBoletoCard(context, boleto),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoletoCard(BuildContext context, Boleto boleto) {
    final theme = Theme.of(context);
    final cores = context.appColors;
    final isDark = theme.brightness == Brightness.dark;
    final status = _getBoletoStatus(boleto);
    final statusColor = status.cor(cores);
    final dueDate = DateFormat('dd/MM/yyyy').format(boleto.dueDateParsed);

    return InkWell(
      onTap: () => _openBoleto(context, boleto.invoiceUrl, status),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: 180,
        height: 100,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            // Sombra externa (neumorfismo)
            BoxShadow(
              color:
                  isDark
                      ? Colors.black.withValues(alpha: 0.5)
                      : Colors.grey.shade400,
              offset: const Offset(6, 6),
              blurRadius: 12,
            ),
            // Luz (neumorfismo)
            BoxShadow(
              color:
                  isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.white.withValues(alpha: 0.9),
              offset: const Offset(-6, -6),
              blurRadius: 12,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Serrilhado do boleto
            Positioned(
              left: 0,
              right: 0,
              top: 30,
              child: CustomPaint(
                size: const Size(double.infinity, 1),
                painter: _DashedLinePainter(color: theme.dividerColor),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.qr_code_2,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 18,
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          status.rotulo,
                          style: theme.textTheme.labelSmall?.copyWith(
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
                  Text(
                    'Vencimento',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dueDate,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Código de barras simulado
                  Row(
                    children: List.generate(
                      8,
                      (index) => Expanded(
                        child: Container(
                          height: 12,
                          margin: EdgeInsets.only(right: index < 7 ? 2 : 0),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
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
    final cores = context.appColors;
    final statusColor = status.cor(cores);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            icon: Icon(status.icone, color: statusColor, size: 48),
            title: Text(
              status.titulo,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: statusColor),
            ),
            content: _buildConteudoDialogo(context, url, status, statusColor),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
            ],
          ),
    );
  }

  Widget _buildConteudoDialogo(
    BuildContext context,
    String url,
    BoletoStatus status,
    Color statusColor,
  ) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          status.mensagem,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        const Divider(),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Clique no botão abaixo para copiar o link do boleto:',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Row(
            children: [
              Icon(
                Icons.link,
                color: theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  url,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        ElevatedButton(
          onPressed: () => _copiarLink(context, url, statusColor),
          style: ElevatedButton.styleFrom(
            backgroundColor: statusColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Copiar Link'),
              SizedBox(width: AppSpacing.sm),
              Icon(Icons.content_copy, size: 20),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _copiarLink(
    BuildContext context,
    String url,
    Color statusColor,
  ) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: AppSpacing.sm),
              Text('Link copiado para a área de transferência!'),
            ],
          ),
          backgroundColor: statusColor,
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    }
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
