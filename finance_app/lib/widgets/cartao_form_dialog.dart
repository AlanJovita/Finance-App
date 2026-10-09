import 'package:flutter/material.dart';

import '../models/cartao.dart';
import '../models/conta.dart';
import '../services/api_service.dart';
import '../services/cartoes_cache.dart';
import '../services/contas_cache.dart';
import '../services/global_state.dart';
import '../services/logger_service.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';
import '../utils/currency_formatter.dart';
import '../utils/currency_input_formatter.dart';
import '../utils/responsive_utils.dart';
import 'logo_banco.dart';
import 'seletor_banco.dart';
import 'seletor_bandeira.dart';

/// Cadastro e edição de cartão de crédito.
///
/// Devolve `true` no `pop` quando gravou — a página de Cartões usa isso para
/// recarregar o resumo. `id_cliente` não aparece no formulário: sai da loja
/// logada, como no [ContaFormDialog].
class CartaoFormDialog extends StatefulWidget {
  /// Nulo para cadastro novo.
  final Cartao? cartao;

  const CartaoFormDialog({super.key, this.cartao});

  @override
  State<CartaoFormDialog> createState() => _CartaoFormDialogState();
}

class _CartaoFormDialogState extends State<CartaoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  final _limiteController = TextEditingController();
  final ApiService _apiService = ApiService();
  final LoggerService _logger = LoggerService();

  bool _isLoading = false;
  String? _bandeira;
  String? _banco;
  bool _ativado = true;

  int _diaFechamento = 1;
  int _diaVencimento = 10;

  /// Conta que paga a fatura; 0 é "sem conta".
  int _idConta = 0;

  List<Conta> _contas = const [];

  bool get _editando => widget.cartao != null;

  @override
  void initState() {
    super.initState();

    final cartao = widget.cartao;
    if (cartao != null) {
      _descricaoController.text = cartao.descricao;
      _bandeira = cartao.bandeira.isEmpty ? null : cartao.bandeira;
      _banco = cartao.banco.isEmpty ? null : cartao.banco;
      _ativado = cartao.ativado;
      _diaFechamento = cartao.diaFechamento;
      _diaVencimento = cartao.diaVencimento;
      _idConta = cartao.idConta;
      // Pré-formatado: o campo é mascarado, então "8000" cru entraria como
      // R$ 80,00 na primeira tecla.
      _limiteController.text =
          cartao.limite == 0 ? '' : CurrencyFormatter.formatValue(cartao.limite);
    }

    _carregarContas();
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _limiteController.dispose();
    super.dispose();
  }

  /// As contas vêm do [ContasCache], carregado uma vez por sessão — a mesma
  /// lista que o modal de lançamento do caixa usa.
  ///
  /// Arquivada não entra, **exceto** a que este cartão já usa: tirá-la da lista
  /// durante uma edição faria o seletor cair em "sem conta" e a gravação
  /// desvincular a conta de pagamento em silêncio.
  Future<void> _carregarContas() async {
    final contas = await ContasCache().obter();
    if (!mounted) return;

    setState(() {
      _contas = [
        for (final c in contas)
          if (c.ativado || c.id == _idConta) c,
      ];

      if (_idConta != 0 && !_contas.any((c) => c.id == _idConta)) {
        _idConta = 0;
      }
    });
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
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final cartao = Cartao(
      id: widget.cartao?.id ?? 0,
      idCliente: GlobalState().firstIdLoja,
      descricao: _descricaoController.text.trim(),
      ativado: _ativado,
      bandeira: _bandeira ?? '',
      banco: _banco ?? '',
      limite: CurrencyFormatter.parse(_limiteController.text) ?? 0,
      idConta: _idConta,
      diaFechamento: _diaFechamento,
      diaVencimento: _diaVencimento,
      // A categoria da fatura saiu do formulário: a despesa gerada no
      // fechamento nasce sem categoria, como todo lançamento do app. O valor
      // gravado ainda é devolvido porque o `UPDATE` da API escreve a coluna
      // sempre — mandar 0 por omissão apagaria, em silêncio, a categoria de um
      // cartão cadastrado antes desta mudança.
      idCategoria: widget.cartao?.idCategoria ?? 0,
    );

    try {
      if (_editando) {
        await _apiService.updateCartao(cartao);
      } else {
        await _apiService.createCartao(cartao);
      }

      // O seletor da tela de movimentos lê do cache; sem isto o cartão novo só
      // apareceria lá na sessão seguinte.
      CartoesCache().invalidar();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(_editando ? 'Cartão salvo!' : 'Cartão criado!'),
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
        'CartaoFormDialog._salvar',
        e,
        stackTrace: s,
        additionalInfo: {'edicao': _editando, 'bandeira': _bandeira},
      );
      // A mensagem da API é a que vale aqui ("Informe o nome do cartão",
      // "Conta de pagamento não encontrada"): ela diz o que corrigir. O prefixo
      // `Exception: ` que o Dart carimba no `toString` sai fora — não é
      // informação para o lojista.
      if (mounted) {
        _showError(
          'Não foi possível salvar o cartão: '
          '${'$e'.replaceFirst('Exception: ', '')}',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth =
        ResponsiveUtils.isMobile(context)
            ? MediaQuery.of(context).size.width * 0.9
            : ResponsiveUtils.isTablet(context)
            ? 440.0
            : 480.0;

    return AlertDialog(
      title: Text(_editando ? 'Editar cartão' : 'Novo cartão'),
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
                    labelText: 'Nome do cartão',
                    helperText: 'Como você chama este cartão no dia a dia',
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
                const SizedBox(height: AppSpacing.lg),

                SeletorBandeira(
                  selecionado: _bandeira,
                  onSelecionar: (chave) => setState(() => _bandeira = chave),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Bandeira e banco são dois campos porque variam
                // independentemente: existe Nubank Visa e Nubank Mastercard. O
                // catálogo de banco é o mesmo da conta bancária — o emissor de
                // um cartão é um banco.
                SeletorBanco(
                  selecionado: _banco,
                  nomeConta: _descricaoController.text,
                  onSelecionar: (chave) => setState(() => _banco = chave),
                ),
                const Divider(height: AppSpacing.xl),

                _buildCiclo(),
                const SizedBox(height: AppSpacing.md),

                TextFormField(
                  controller: _limiteController,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Limite',
                    prefixText: 'R\$ ',
                    helperText: 'Em branco: a tela não mostra o disponível',
                    helperMaxLines: 2,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: const [CurrencyInputFormatter()],
                ),
                const Divider(height: AppSpacing.xl),

                _buildConta(),

                // Arquivar só faz sentido para cartão que já existe: o novo
                // nasce ativo, e oferecer o contrário no cadastro só confundiria.
                if (_editando) ...[
                  const SizedBox(height: AppSpacing.xs),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: const Text('Cartão ativo'),
                    subtitle: Text(
                      _ativado
                          ? 'Aparece no lançamento de despesas do cartão'
                          : 'Arquivado: sai do lançamento, mas o saldo devedor '
                              'e o histórico continuam aqui',
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

  /// Os dois dias que definem o ciclo, lado a lado com a explicação do efeito.
  ///
  /// São **dias do mês**, não datas: o cartão repete o ciclo todo mês. Dropdown
  /// de 1 a 31 em vez de campo numérico porque não existe dia 0 nem dia 45, e
  /// validar depois é pior que não deixar digitar.
  Widget _buildCiclo() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _diaFechamento,
                isDense: true,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Dia do fechamento',
                ),
                items: [
                  for (var d = 1; d <= 31; d++)
                    DropdownMenuItem(value: d, child: Text('Dia $d')),
                ],
                onChanged: (v) => setState(() => _diaFechamento = v ?? 1),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _diaVencimento,
                isDense: true,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Dia do vencimento',
                ),
                items: [
                  for (var d = 1; d <= 31; d++)
                    DropdownMenuItem(value: d, child: Text('Dia $d')),
                ],
                onChanged: (v) => setState(() => _diaVencimento = v ?? 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          // O efeito do ciclo dito por extenso: é a regra que decide em qual
          // fatura cada compra cai, e ela não é óbvia a partir de dois números.
          'Compra feita a partir do dia $_diaFechamento entra na fatura do mês '
          'seguinte.'
          '${_diaVencimento <= _diaFechamento ? ' O vencimento cai no mês seguinte ao fechamento.' : ''}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (_editando) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'As faturas que já existem mantêm as datas com que foram criadas.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConta() {
    final theme = Theme.of(context);

    if (_contas.isEmpty) {
      // Sem conta cadastrada não há escolha a fazer, e um dropdown fixo em "Sem
      // conta" seria só ruído. A despesa da fatura nasce sem conta, que é o
      // padrão de todo lançamento do app.
      return Text(
        'Nenhuma conta bancária cadastrada: a fatura será lançada sem conta.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return DropdownButtonFormField<int>(
      value: _idConta,
      isDense: true,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        labelText: 'Conta que paga a fatura',
        helperText: 'A despesa da fatura debita esta conta',
        helperMaxLines: 2,
      ),
      items: [
        const DropdownMenuItem(value: 0, child: Text('Sem conta')),
        for (final c in _contas)
          DropdownMenuItem(
            value: c.id,
            child: Row(
              children: [
                LogoBanco(
                  chave: c.imagem,
                  nomeConta: c.descricao,
                  diametro: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    c.ativado ? c.descricao : '${c.descricao} (arquivada)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
      onChanged: (v) => setState(() => _idConta = v ?? 0),
    );
  }
}
