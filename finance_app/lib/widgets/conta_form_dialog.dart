import 'package:flutter/material.dart';

import '../models/conta.dart';
import '../services/api_service.dart';
import '../services/contas_cache.dart';
import '../services/global_state.dart';
import '../services/logger_service.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';
import '../utils/currency_formatter.dart';
import '../utils/currency_input_formatter.dart';
import '../utils/responsive_utils.dart';
import 'seletor_banco.dart';

/// Cadastro e edição de conta bancária.
///
/// Devolve `true` no `pop` quando gravou — a página de Contas usa isso para
/// recarregar os saldos. `id_cliente` não aparece no formulário: sai da loja
/// logada, como no [CategoriaFormDialog].
class ContaFormDialog extends StatefulWidget {
  /// Nula para cadastro novo.
  final Conta? conta;

  const ContaFormDialog({super.key, this.conta});

  @override
  State<ContaFormDialog> createState() => _ContaFormDialogState();
}

class _ContaFormDialogState extends State<ContaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  final _saldoController = TextEditingController();
  final ApiService _apiService = ApiService();
  final LoggerService _logger = LoggerService();

  bool _isLoading = false;
  String? _banco;
  bool _ativado = true;

  /// Conta no vermelho (cheque especial, limite usado) é saldo inicial negativo,
  /// e a máscara de moeda só produz dígitos. Sem este botão não haveria como
  /// declarar a situação, e o saldo da conta nasceria errado.
  bool _negativo = false;

  bool get _editando => widget.conta != null;

  @override
  void initState() {
    super.initState();

    final conta = widget.conta;
    if (conta != null) {
      _descricaoController.text = conta.descricao;
      _banco = conta.imagem.isEmpty ? null : conta.imagem;
      _ativado = conta.ativado;
      _negativo = conta.saldoInicial < 0;
      // Pré-formatado: o campo é mascarado, então "1500.5" cru entraria como
      // R$ 15,00 na primeira tecla.
      _saldoController.text =
          conta.saldoInicial == 0
              ? ''
              : CurrencyFormatter.formatValue(conta.saldoInicial.abs());
    }
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _saldoController.dispose();
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

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final saldo = (CurrencyFormatter.parse(_saldoController.text) ?? 0) *
        (_negativo ? -1 : 1);

    final conta = Conta(
      id: widget.conta?.id ?? 0,
      idCliente: GlobalState().firstIdLoja,
      descricao: _descricaoController.text.trim(),
      ativado: _ativado,
      imagem: _banco ?? '',
      saldoInicial: saldo,
    );

    try {
      if (_editando) {
        await _apiService.updateConta(conta);
      } else {
        await _apiService.createConta(conta);
      }

      // O seletor do modal de lançamento lê do cache; sem isto a conta nova só
      // apareceria lá na sessão seguinte.
      ContasCache().invalidar();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(_editando ? 'Conta salva!' : 'Conta criada!'),
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
        'ContaFormDialog._salvar',
        e,
        stackTrace: s,
        additionalInfo: {'edicao': _editando, 'banco': _banco},
      );
      if (mounted) _showError('Não foi possível salvar a conta: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dialogWidth =
        ResponsiveUtils.isMobile(context)
            ? MediaQuery.of(context).size.width * 0.9
            : ResponsiveUtils.isTablet(context)
            ? 420.0
            : 460.0;

    return AlertDialog(
      title: Text(_editando ? 'Editar conta' : 'Nova conta'),
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
                TextFormField(
                  controller: _descricaoController,
                  autofocus: !_editando,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Nome da conta',
                    helperText: 'Como você chama esta conta no dia a dia',
                  ),
                  // Alimenta as iniciais do logo de fallback enquanto digita.
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Campo obrigatório';
                    }
                    if (value.trim().length < 3) return 'Mínimo 3 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                SeletorBanco(
                  selecionado: _banco,
                  nomeConta: _descricaoController.text,
                  onSelecionar: (chave) => setState(() => _banco = chave),
                ),
                const Divider(height: AppSpacing.xl),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _saldoController,
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'Saldo inicial',
                          prefixText: _negativo ? '- R\$ ' : 'R\$ ',
                          helperText: 'Saldo da conta antes dos lançamentos',
                          helperMaxLines: 2,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: const [CurrencyInputFormatter()],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Compacto de propósito: é o caso raro (conta no vermelho),
                    // e um seletor grande daria a ele mais peso do que tem.
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: IconButton(
                        tooltip:
                            _negativo
                                ? 'Saldo negativo — toque para positivo'
                                : 'Saldo positivo — toque para negativo',
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          backgroundColor:
                              _negativo
                                  ? context.appColors.error.withValues(
                                    alpha: 0.12,
                                  )
                                  : theme.colorScheme.surfaceContainerHighest,
                        ),
                        icon: Icon(
                          _negativo ? Icons.remove : Icons.add,
                          size: 18,
                          color: _negativo ? context.appColors.error : null,
                        ),
                        onPressed: () => setState(() => _negativo = !_negativo),
                      ),
                    ),
                  ],
                ),

                // Arquivar só faz sentido para conta que já existe: a nova nasce
                // ativa, e oferecer o contrário no cadastro só confundiria.
                if (_editando) ...[
                  const SizedBox(height: AppSpacing.xs),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: const Text('Conta ativa'),
                    subtitle: Text(
                      _ativado
                          ? 'Aparece no lançamento de receitas e despesas'
                          : 'Arquivada: sai do lançamento, mas o saldo e o '
                              'histórico continuam aqui',
                    ),
                    value: _ativado,
                    onChanged: (v) => setState(() => _ativado = v),
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
            : ElevatedButton(onPressed: _salvar, child: const Text('Salvar')),
      ],
    );
  }
}
