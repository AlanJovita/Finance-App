import 'package:flutter/material.dart';

import '../models/fluxo_caixa.dart';
import '../services/api_service.dart';
import '../services/global_state.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';
import '../utils/currency_formatter.dart';
import '../utils/currency_input_formatter.dart';

/// Margem que o diálogo guarda contra a borda da tela.
const double _inset = AppSpacing.lg;

/// Baixa de um lançamento: confirma a conta e, de quebra, acerta o valor com
/// encargos e descontos.
///
/// O banco não tem onde guardar encargo e desconto separados, então eles não
/// são persistidos: entram no cálculo e o que vai para `valor` é o líquido
/// efetivamente pago ou recebido. É também por isso que o estorno não devolve
/// o valor original — ele não existe mais em lugar nenhum.
class PagamentoDialog extends StatefulWidget {
  final FluxoCaixa fluxo;

  /// Muda o verbo da tela inteira: receita se recebe, despesa se paga.
  final bool ehReceita;

  const PagamentoDialog({
    super.key,
    required this.fluxo,
    required this.ehReceita,
  });

  @override
  State<PagamentoDialog> createState() => _PagamentoDialogState();
}

class _PagamentoDialogState extends State<PagamentoDialog> {
  final _encargosController = TextEditingController();
  final _descontosController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _salvando = false;
  String? _erro;

  double get _valorOriginal => widget.fluxo.valor ?? 0;
  double get _encargos => CurrencyFormatter.parse(_encargosController.text) ?? 0;
  double get _descontos =>
      CurrencyFormatter.parse(_descontosController.text) ?? 0;
  double get _total => _valorOriginal + _encargos - _descontos;

  String get _verbo => widget.ehReceita ? 'Receber' : 'Pagar';
  String get _substantivo =>
      widget.ehReceita ? 'recebimento' : 'pagamento';

  @override
  void dispose() {
    _encargosController.dispose();
    _descontosController.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (_total <= 0) {
      setState(() => _erro = 'O total precisa ser maior que zero.');
      return;
    }

    setState(() {
      _salvando = true;
      _erro = null;
    });

    try {
      // O `UPDATE` da API reescreve todas as colunas: o registro vai inteiro,
      // com apenas o valor e a confirmação trocados.
      final atualizado = widget.fluxo.copyWith(
        idLoja: widget.fluxo.idLoja ?? GlobalState().firstIdLoja,
        valor: _total,
        confirmado: true,
        // `tipo_fluxo` também é sobrescrito no update; sem ele uma despesa
        // viraria receita.
        tipoFluxo: widget.fluxo.tipoFluxo ?? (widget.ehReceita ? '1' : '2'),
      );

      await _apiService.updateFluxo(atualizado);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _salvando = false;
        _erro = 'Não foi possível confirmar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cores = context.appColors;
    final cor = widget.ehReceita ? cores.success : cores.error;

    // Mesma conta do modal de detalhes: a largura útil é a da tela menos a
    // margem contra a borda e o `contentPadding`, não uma fração dela.
    final largura = (MediaQuery.sizeOf(context).width -
            _inset * 2 -
            AppSpacing.xl * 2)
        .clamp(0.0, 400.0);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: _inset,
        vertical: AppSpacing.xl,
      ),
      title: Text('$_verbo conta'),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        0,
      ),
      content: SizedBox(
        width: largura,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.fluxo.descricao ?? 'Sem descrição',
                style: theme.textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Valor da conta: ${CurrencyFormatter.format(_valorOriginal)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Row(
                children: [
                  Expanded(
                    child: _campo(
                      controller: _encargosController,
                      rotulo: 'Encargos',
                      icone: Icons.trending_up,
                      cor: cores.error,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _campo(
                      controller: _descontosController,
                      rotulo: 'Descontos',
                      icone: Icons.trending_down,
                      cor: cores.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              _buildTotal(theme, cor),

              if (_erro != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _erro!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cores.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _salvando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        _salvando
            ? const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
            : FilledButton.icon(
              onPressed: _confirmar,
              style: FilledButton.styleFrom(backgroundColor: cor),
              icon: const Icon(Icons.check, size: 18),
              label: Text('Confirmar $_substantivo'),
            ),
      ],
    );
  }

  Widget _campo({
    required TextEditingController controller,
    required String rotulo,
    required IconData icone,
    required Color cor,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        isDense: true,
        labelText: rotulo,
        prefixText: 'R\$ ',
        prefixIcon: Icon(icone, size: 18, color: cor),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 32,
          minHeight: 32,
        ),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: const [CurrencyInputFormatter()],
      // Só o total depende do que foi digitado; o resto do diálogo é estático.
      onChanged: (_) => setState(() => _erro = null),
    );
  }

  Widget _buildTotal(ThemeData theme, Color cor) {
    final ajuste = _encargos - _descontos;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total a ${_verbo.toLowerCase()}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (ajuste != 0)
                  Text(
                    '${ajuste > 0 ? '+' : '−'} '
                    '${CurrencyFormatter.format(ajuste.abs())} '
                    'sobre o valor original',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          // Interpola entre o total anterior e o novo a cada tecla: o número
          // "corre" em vez de saltar, sem nenhuma animação em curso parada.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: _total, end: _total),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder:
                (context, valor, _) => Text(
                  CurrencyFormatter.format(valor),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: cor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}
