import 'package:flutter/material.dart';

import '../models/conta.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';
import '../utils/currency_formatter.dart';
import '../utils/currency_input_formatter.dart';
import '../utils/responsive_utils.dart';
import 'logo_banco.dart';

/// Transferência entre duas contas da loja.
///
/// Devolve `true` no `pop` quando a transferência foi feita.
///
/// Uma única chamada à API cria as duas pernas — despesa na origem, receita no
/// destino — sob transação com rollback. Não existe caminho aqui que grave uma
/// perna só: isso deixaria as duas contas com saldo errado.
class TransferenciaDialog extends StatefulWidget {
  /// Contas ativas, na ordem em que a página as mostra. "Sem conta" não entra:
  /// não é conta, não tem saldo próprio e não participa de transferência.
  final List<SaldoConta> contas;

  const TransferenciaDialog({super.key, required this.contas});

  @override
  State<TransferenciaDialog> createState() => _TransferenciaDialogState();
}

class _TransferenciaDialogState extends State<TransferenciaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _valorController = TextEditingController();
  final _observacaoController = TextEditingController();
  final ApiService _apiService = ApiService();
  final LoggerService _logger = LoggerService();

  bool _isLoading = false;
  int? _origem;
  int? _destino;
  DateTime _data = DateTime.now();

  @override
  void initState() {
    super.initState();

    // Pré-seleção que economiza dois toques no caso comum de duas contas, e não
    // adivinha nada quando há mais: só a origem é sugerida.
    if (widget.contas.isNotEmpty) _origem = widget.contas.first.id;
    if (widget.contas.length == 2) _destino = widget.contas[1].id;
  }

  @override
  void dispose() {
    _valorController.dispose();
    _observacaoController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: context.appColors.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _transferir() async {
    if (!_formKey.currentState!.validate()) return;

    if (_origem == null || _destino == null) {
      _showError('Escolha a conta de origem e a de destino');
      return;
    }

    if (_origem == _destino) {
      _showError('A conta de origem e a de destino são a mesma');
      return;
    }

    final valor = CurrencyFormatter.parse(_valorController.text);
    if (valor == null || valor <= 0) {
      _showError('Informe um valor maior que zero');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _apiService.transferir(
        idOrigem: _origem!,
        idDestino: _destino!,
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
                  'Transferência de ${CurrencyFormatter.format(valor)} realizada',
                ),
              ),
            ],
          ),
          backgroundColor: context.appColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e, s) {
      await _logger.logError(
        'TransferenciaDialog._transferir',
        e,
        stackTrace: s,
        additionalInfo: {'origem': _origem, 'destino': _destino},
      );
      if (mounted) _showError('Não foi possível transferir: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selecionarData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('pt', 'BR'),
      helpText: 'Data da transferência',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );

    if (escolhida != null) setState(() => _data = escolhida);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dialogWidth =
        ResponsiveUtils.isMobile(context)
            ? MediaQuery.of(context).size.width * 0.9
            : ResponsiveUtils.isTablet(context)
            ? 430.0
            : 470.0;

    return AlertDialog(
      title: const Text('Transferir entre contas'),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _seletorConta(
                  rotulo: 'De (origem)',
                  valor: _origem,
                  // Sai uma despesa daqui.
                  cor: context.appColors.error,
                  onChanged: (v) => setState(() => _origem = v),
                ),
                const SizedBox(height: AppSpacing.md),

                Center(
                  child: Icon(
                    Icons.south,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                _seletorConta(
                  rotulo: 'Para (destino)',
                  valor: _destino,
                  // Entra uma receita aqui.
                  cor: context.appColors.success,
                  onChanged: (v) => setState(() => _destino = v),
                ),
                const SizedBox(height: AppSpacing.lg),

                TextFormField(
                  controller: _valorController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Valor',
                    prefixText: 'R\$ ',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: const [CurrencyInputFormatter()],
                  validator: (value) {
                    final numero = CurrencyFormatter.parse(value);
                    if (numero == null) return 'Campo obrigatório';
                    if (numero <= 0) return 'Deve ser maior que zero';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xs),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: const Text('Data'),
                  subtitle: Text(
                    '${_data.day.toString().padLeft(2, '0')}/'
                    '${_data.month.toString().padLeft(2, '0')}/${_data.year}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today, size: 20),
                    onPressed: _selecionarData,
                  ),
                ),

                TextFormField(
                  controller: _observacaoController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Observação (opcional)',
                    helperText: 'Entra na descrição das duas movimentações',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // O lojista precisa saber que isto cria dois lançamentos, senão
                // procura por eles nas telas de Receitas e Despesas — onde não
                // aparecem, justamente para não inflar os totais do mês.
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: context.appColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: context.appColors.info,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Gera uma saída na origem e uma entrada no destino. '
                          'Não conta como receita nem despesa do mês.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
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
              onPressed: _transferir,
              child: const Text('Transferir'),
            ),
      ],
    );
  }

  Widget _seletorConta({
    required String rotulo,
    required int? valor,
    required Color cor,
    required ValueChanged<int?> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      value: valor,
      isDense: true,
      isExpanded: true,
      decoration: InputDecoration(
        isDense: true,
        labelText: rotulo,
        // A barra colorida é o que diferencia origem de destino de relance, sem
        // precisar ler os dois rótulos.
        prefixIcon: Container(width: 4, color: cor),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 4,
          minHeight: 36,
        ),
      ),
      items: [
        for (final c in widget.contas)
          DropdownMenuItem(
            value: c.id,
            child: Row(
              children: [
                LogoBanco(
                  chave: c.imagem,
                  nomeConta: c.descricao,
                  diametro: 24,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    c.descricao,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  CurrencyFormatter.format(c.saldoAtual),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
      ],
      onChanged: _isLoading ? null : onChanged,
    );
  }
}
