import 'package:flutter/material.dart';

import '../models/cartao.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';
import '../utils/currency_formatter.dart';
import '../utils/currency_input_formatter.dart';
import '../utils/meses.dart';
import '../utils/responsive_utils.dart';

/// Registra o pagamento de uma fatura fechada.
///
/// É a "receita dentro do cartão" que move dinheiro, e a única: ela abate o saldo
/// devedor do cartão **e** corresponde a uma saída de caixa. Estorno e cashback
/// também são créditos no cartão e não movem nada — eles vão pelo lançamento
/// comum.
///
/// A saída de caixa **não é uma despesa nova**: é a baixa da despesa que o
/// fechamento já gerou. É o invariante de uma despesa por fatura, e é por isso
/// que esta tela só existe para fatura fechada — fatura aberta não tem despesa em
/// que dar baixa.
///
/// Devolve `true` no `pop` quando registrou.
class PagamentoFaturaDialog extends StatefulWidget {
  final Cartao cartao;
  final Fatura fatura;
  final TotaisFatura totais;

  const PagamentoFaturaDialog({
    super.key,
    required this.cartao,
    required this.fatura,
    required this.totais,
  });

  @override
  State<PagamentoFaturaDialog> createState() => _PagamentoFaturaDialogState();
}

class _PagamentoFaturaDialogState extends State<PagamentoFaturaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _valorController = TextEditingController();
  final _observacaoController = TextEditingController();
  final ApiService _apiService = ApiService();
  final LoggerService _logger = LoggerService();

  bool _isLoading = false;
  late DateTime _data;

  /// Padrão ligado: pagar a fatura inteira é o caminho normal, e é o único que
  /// dá baixa na despesa do caixa. Desligar revela o campo de valor.
  bool _integral = true;

  double get _saldo => widget.totais.saldo;

  @override
  void initState() {
    super.initState();

    // O vencimento, não hoje: o lojista costuma registrar o pagamento no dia em
    // que a fatura venceu (débito automático), e corrigir a data é mais fácil que
    // notar que ela estava errada.
    final hoje = DateTime.now();
    final vencimento = widget.fatura.dataVencimento;
    _data =
        vencimento != null && !vencimento.isAfter(hoje) ? vencimento : hoje;

    _valorController.text = CurrencyFormatter.formatValue(_saldo);
  }

  @override
  void dispose() {
    _valorController.dispose();
    _observacaoController.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('pt', 'BR'),
      helpText: 'Data do pagamento',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
      fieldLabelText: 'Data do pagamento',
      errorFormatText: 'Data inválida',
      errorInvalidText: 'Data fora do intervalo permitido',
    );

    if (escolhida != null) setState(() => _data = escolhida);
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // `null` é "pagar o saldo" para a API, e é diferente de mandar o número: ela
    // recalcula o saldo no servidor, então um lançamento que entrou na fatura
    // entre o carregamento da tela e este toque não deixa o pagamento parcial
    // por acidente.
    final valor =
        _integral ? null : CurrencyFormatter.parse(_valorController.text);

    try {
      final quitada = await _apiService.pagarFatura(
        widget.fatura.id,
        valor: valor,
        data: _data,
        observacao: _observacaoController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  quitada
                      ? 'Fatura paga. A despesa dela foi baixada no caixa.'
                      : 'Pagamento parcial registrado.',
                ),
              ),
            ],
          ),
          backgroundColor: context.appColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e, s) {
      await _logger.logError(
        'PagamentoFaturaDialog._salvar',
        e,
        stackTrace: s,
        additionalInfo: {'idFatura': widget.fatura.id, 'integral': _integral},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível registrar o pagamento: $e'),
            backgroundColor: context.appColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cores = context.appColors;
    final competencia = widget.fatura.competencia;

    final largura =
        ResponsiveUtils.isMobile(context)
            ? MediaQuery.of(context).size.width * 0.9
            : 420.0;

    return AlertDialog(
      title: const Text('Pagar fatura'),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      content: SizedBox(
        width: largura,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.cartao.descricao}'
                  '${competencia == null ? '' : ' · ${rotuloMes(competencia)}'}',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Saldo a pagar: ${CurrencyFormatter.format(_saldo)}'
                  '${widget.totais.pago > 0 ? ' (${CurrencyFormatter.format(widget.totais.pago)} já pago)' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Divider(height: AppSpacing.xl),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: const Text('Pagar o valor integral'),
                  value: _integral,
                  onChanged: (v) => setState(() => _integral = v),
                ),

                if (!_integral) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _valorController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Valor pago',
                      prefixText: 'R\$ ',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: const [CurrencyInputFormatter()],
                    validator: (value) {
                      final numero = CurrencyFormatter.parse(value);
                      if (numero == null || numero <= 0) {
                        return 'Informe um valor maior que zero';
                      }
                      // Meio centavo de folga, como no servidor: o saldo vem de
                      // um `decimal(11,2)` convertido para double, e comparar
                      // sem tolerância recusaria o pagamento integral por um
                      // resíduo de 1e-14.
                      if (numero > _saldo + 0.005) {
                        return 'Maior que o saldo da fatura';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // O limite do desenho, dito onde ele importa. Pagamento parcial
                  // de fatura é crédito rotativo (o resto rola para a fatura
                  // seguinte, com juros), e o app não modela encargo — então ele
                  // registra o crédito no cartão sem fingir que o caixa foi
                  // resolvido.
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: cores.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: cores.warning),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'O pagamento parcial abate o saldo devedor do '
                            'cartão, mas a despesa da fatura continua pendente '
                            'no caixa até a liquidação. Juros de rotativo não '
                            'são calculados.',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.md),
                InkWell(
                  onTap: _selecionarData,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Data do pagamento',
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event, size: 16),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '${_data.day.toString().padLeft(2, '0')}/'
                          '${_data.month.toString().padLeft(2, '0')}/${_data.year}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                TextFormField(
                  controller: _observacaoController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Observação (opcional)',
                  ),
                ),

                if (_integral) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    widget.fatura.idFluxo > 0
                        ? 'A despesa desta fatura será baixada no caixa — '
                            'nenhuma despesa nova é criada.'
                        : 'Esta fatura fechou sem valor a pagar, então não há '
                            'despesa no caixa a baixar.',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        _isLoading
            ? const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 3.0),
              ),
            )
            : ElevatedButton(
              onPressed: _salvar,
              child: const Text('Registrar'),
            ),
      ],
    );
  }
}
