import 'package:flutter/material.dart';

import '../models/cartao.dart';
import '../models/categoria.dart';
import '../models/subcategoria.dart';
import '../services/api_service.dart';
import '../services/global_state.dart';
import '../services/logger_service.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';
import '../utils/categoria_visuais.dart';
import '../utils/currency_formatter.dart';
import '../utils/currency_input_formatter.dart';
import '../utils/meses.dart';
import '../utils/responsive_utils.dart';
import 'categoria_form_dialog.dart';
import 'logo_bandeira.dart';
import 'seletor_categoria.dart';
import 'subcategoria_form_dialog.dart';

/// Lançamento de compra, estorno ou cashback no cartão.
///
/// Mesma forma do [FluxoFormDialog] — cabeçalho com chips, seletor de categoria
/// em círculos, campos no corpo — com quatro diferenças que vêm do domínio:
///
/// 1. **A data é a data da compra**, não um vencimento. É ela que decide em qual
///    fatura o lançamento cai, e o cabeçalho diz qual é essa fatura enquanto o
///    lojista escolhe a data. Sem essa prévia, a regra do fechamento só se
///    manifestaria depois de salvar.
/// 2. **Não há "confirmado".** No cartão não existe baixa de lançamento: o que
///    liquida uma compra é o pagamento da fatura em que ela caiu.
/// 3. **Parcelamento é mensal e resolvido no servidor**, numa chamada. No caixa o
///    formulário faz N POST; aqui as N parcelas têm de cair em faturas
///    consecutivas, e N chamadas deixariam a sequência com buraco se a rede
///    caísse no meio.
/// 4. **Pagamento de fatura não é lançado aqui.** Ele paga uma fatura *escolhida*
///    e dá baixa na despesa dela no caixa — é o [PagamentoFaturaDialog], a partir
///    da fatura.
class MovimentoCartaoFormDialog extends StatefulWidget {
  /// O cartão em foco. O seletor de cartão só aparece quando há mais de um.
  final Cartao cartao;

  /// Os cartões que o seletor oferece — os ativos, mais o deste lançamento.
  final List<Cartao> cartoes;

  /// Nulo para lançamento novo.
  final MovimentoCartao? movimento;

  /// Data que o lançamento novo já traz pronta.
  ///
  /// A tela passa um dia da fatura em foco quando ela **não** é a aberta: abrir
  /// o modal numa fatura passada e vê-lo preenchido com hoje faria o lançamento
  /// cair noutra fatura sem aviso. Nulo cai em hoje.
  final DateTime? dataInicial;

  /// Chamado depois de cada gravação, com `continuar` indicando se o modal
  /// permaneceu aberto para o próximo lançamento. A tela recarrega nos dois
  /// casos — quem fecha o modal é ele mesmo.
  final void Function(bool continuar) onSalvou;

  const MovimentoCartaoFormDialog({
    super.key,
    required this.cartao,
    required this.cartoes,
    required this.onSalvou,
    this.movimento,
    this.dataInicial,
  });

  @override
  State<MovimentoCartaoFormDialog> createState() =>
      _MovimentoCartaoFormDialogState();
}

class _MovimentoCartaoFormDialogState extends State<MovimentoCartaoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  final _valorController = TextEditingController();
  final _parcelasController = TextEditingController(text: '2');
  final _descricaoFocus = FocusNode();

  final ApiService _apiService = ApiService();
  final LoggerService _logger = LoggerService();

  bool _isLoading = false;

  late Cartao _cartao;
  late DateTime _dataLancamento;

  /// 2 compra, 1 crédito — o mesmo código do caixa.
  int _tipoFluxo = 2;

  /// Só vale para crédito. Pagamento fica fora da lista por desenho — ver o
  /// docstring da classe.
  NaturezaMovimento _natureza = NaturezaMovimento.estorno;

  int _categoriaId = 0;
  int _subcategoriaId = 0;
  List<Categoria> _categorias = [];
  List<Subcategoria> _subcategorias = [];

  /// Só aparece quando a categoria escolhida ainda não tem nenhuma filha — é o
  /// atalho para criar a primeira.
  bool _habilitarSubcategorias = false;

  bool _parcelar = false;
  int _numeroParcelas = 2;

  /// true = o valor digitado é o da parcela; false = é o total a dividir.
  bool _valorEhParcela = false;

  /// Quantos lançamentos esta sessão do modal já gravou. Vira a confirmação do
  /// "salvar e continuar", que é a única pista de que o anterior entrou — o modal
  /// não fecha, e sem contagem a tela atrás fica escondida.
  int _gravados = 0;

  bool get _editando => widget.movimento != null;

  bool get _ehCredito => _tipoFluxo == 1;

  @override
  void initState() {
    super.initState();

    _cartao = widget.cartao;
    _dataLancamento = widget.dataInicial ?? DateTime.now();

    final m = widget.movimento;
    if (m != null) {
      _descricaoController.text = _semSufixoParcela(m.descricao);
      // Pré-formatado: o campo é mascarado, então "150.5" cru entraria como
      // R$ 1,50 na primeira tecla.
      _valorController.text = CurrencyFormatter.formatValue(m.valor);
      _categoriaId = m.idCategoria;
      _subcategoriaId = m.idSubcategoria;
      _tipoFluxo = m.tipoFluxo;
      _natureza =
          m.natureza == NaturezaMovimento.compra
              ? NaturezaMovimento.estorno
              : m.natureza;
      _dataLancamento = m.dataLancamento ?? DateTime.now();
    }

    _carregarCategorias();
    _carregarSubcategorias();
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _valorController.dispose();
    _parcelasController.dispose();
    _descricaoFocus.dispose();
    super.dispose();
  }

  /// A descrição sem o "[3/12]" que o servidor anexou.
  ///
  /// Editar uma parcela e mandar a descrição de volta com o sufixo produziria
  /// "Geladeira [3/12] [3/12]" — o mesmo cuidado do `_baseDescricao` da API, que
  /// é quem põe o sufixo.
  static String _semSufixoParcela(String descricao) =>
      descricao.replaceAll(RegExp(r'\s*\[\s*\d+\s*/\s*\d+\s*\]\s*$'), '').trim();

  /// 1 = receita, 2 = despesa — o mesmo código de `tipo_fluxo` do banco.
  ///
  /// A categoria de um estorno é a da compra que está voltando, que é uma
  /// despesa; a de um cashback é receita. Por isso o tipo da categoria segue o
  /// tipo do lançamento.
  int get _tipoCategoria => _tipoFluxo;

  Future<void> _carregarCategorias() async {
    try {
      final categorias = await _apiService.listCategorias();
      if (!mounted) return;

      setState(() {
        _categorias =
            categorias.where((c) => c.tipoFluxo == _tipoCategoria).toList();

        if (_categoriaId != 0 && !_categorias.any((c) => c.id == _categoriaId)) {
          _categoriaId = 0;
          _subcategoriaId = 0;
        }
      });
    } catch (e, s) {
      // Sem isto a falha é invisível: o seletor abre vazio e o lojista conclui
      // que não tem categoria cadastrada.
      await _logger.logError(
        'MovimentoCartaoFormDialog._carregarCategorias',
        e,
        stackTrace: s,
        additionalInfo: {'tipoFluxo': _tipoFluxo},
      );
    }
  }

  Future<void> _carregarSubcategorias() async {
    try {
      final subcategorias = await _apiService.listSubcategorias();
      if (!mounted) return;

      setState(() {
        _subcategorias = subcategorias;

        if (_subcategoriaId != 0 &&
            !_subcategorias.any((s) => s.id == _subcategoriaId)) {
          _subcategoriaId = 0;
        }

        // Editando um lançamento que já tem subcategoria, o card precisa nascer
        // aberto mesmo que a categoria tenha só essa uma filha.
        if (_subcategoriaId != 0) _habilitarSubcategorias = true;
      });
    } catch (e, s) {
      await _logger.logError(
        'MovimentoCartaoFormDialog._carregarSubcategorias',
        e,
        stackTrace: s,
      );
    }
  }

  List<Subcategoria> get _subcategoriasDaCategoria {
    if (_categoriaId == 0) return const [];
    return _subcategorias.where((s) => s.idCategoria == _categoriaId).toList();
  }

  /// 0 quando não há subcategoria escolhida — ou quando a escolhida não é filha
  /// da categoria atual, o que impede gravar um vínculo órfão.
  int get _idSubcategoriaParaSalvar {
    if (_subcategoriaId == 0) return 0;
    return _subcategoriasDaCategoria.any((s) => s.id == _subcategoriaId)
        ? _subcategoriaId
        : 0;
  }

  Categoria? get _categoriaSelecionada {
    if (_categoriaId == 0) return null;
    for (final c in _categorias) {
      if (c.id == _categoriaId) return c;
    }
    return null;
  }

  /// A competência (mês da fatura) em que a data escolhida cai.
  ///
  /// Repete a conta que a API faz no INSERT — e isso é deliberado, com um limite:
  /// aqui ela serve **só** para mostrar a prévia no cabeçalho. Quem decide de
  /// verdade é o servidor, e o POST não manda `id_fatura`. Se as duas divergirem,
  /// o que vale é o banco, e o único sintoma é uma prévia errada — não um
  /// lançamento na fatura errada.
  DateTime get _competenciaPrevista {
    final d = _dataLancamento;
    final ultimoDiaDoMes = DateTime(d.year, d.month + 1, 0).day;
    final diaFechamento =
        _cartao.diaFechamento > ultimoDiaDoMes
            ? ultimoDiaDoMes
            : _cartao.diaFechamento;

    // A regra: compra no dia do fechamento ou depois entra na fatura seguinte.
    return d.day >= diaFechamento
        ? DateTime(d.year, d.month + 1)
        : DateTime(d.year, d.month);
  }

  // --------------------------------------------------------------- gravar

  Future<void> _salvar({required bool continuar}) async {
    if (!_formKey.currentState!.validate()) return;

    final valorBase = CurrencyFormatter.parse(_valorController.text);

    if (valorBase == null || valorBase <= 0) {
      _showError('O valor deve ser maior que zero');
      return;
    }

    setState(() => _isLoading = true);

    // Crédito não se parcela: o dinheiro de um estorno volta de uma vez. A API
    // também força isso, mas deixar o formulário mandar N seria mandar um pedido
    // que se sabe que será reduzido.
    final parcelas = (!_editando && _parcelar && !_ehCredito) ? _numeroParcelas : 1;

    // O servidor grava `valor` como o valor de **cada parcela**: a divisão do
    // total é decisão daqui, que é quem sabe se o lojista digitou a parcela ou o
    // total.
    final valorParcela =
        parcelas > 1 && !_valorEhParcela ? valorBase / parcelas : valorBase;

    final movimento = MovimentoCartao(
      id: widget.movimento?.id ?? 0,
      idCliente: GlobalState().firstIdLoja,
      idCartao: _cartao.id,
      // Quem resolve a fatura é a API, a partir da data e do ciclo do cartão.
      idFatura: 0,
      idCategoria: _categoriaId,
      idSubcategoria: _idSubcategoriaParaSalvar,
      descricao: _descricaoController.text.trim(),
      valor: valorParcela,
      tipoFluxo: _tipoFluxo,
      natureza: _ehCredito ? _natureza : NaturezaMovimento.compra,
      cancelado: widget.movimento?.cancelado ?? false,
      dataCriacao: DateTime.now(),
      dataLancamento: _dataLancamento,
      // Parcelamento de cartão é mensal por definição — não existe compra
      // parcelada "semanalmente" numa fatura.
      repeticao: parcelas > 1 ? 4 : 1,
      parcela: 1,
      totalParcelas: parcelas,
      idRef: widget.movimento?.idRef ?? 0,
    );

    try {
      if (_editando) {
        await _apiService.updateMovimentoCartao(movimento);
      } else {
        await _apiService.createMovimentoCartao(movimento);
      }

      if (!mounted) return;

      _gravados++;
      widget.onSalvou(continuar);

      if (!continuar) {
        Navigator.of(context).pop();
        return;
      }

      _limparParaProximo();
    } catch (e, s) {
      await _logger.logError(
        'MovimentoCartaoFormDialog._salvar',
        e,
        stackTrace: s,
        additionalInfo: {
          'edicao': _editando,
          'idCartao': _cartao.id,
          'tipoFluxo': _tipoFluxo,
          'parcelas': parcelas,
        },
      );
      if (mounted) _showError('Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Limpa só o que é único de cada lançamento.
  ///
  /// Descrição e valor saem; cartão, data, categoria, subcategoria e tipo ficam.
  /// É o ponto do "salvar e continuar": quem lança a fatura do mês inteiro de uma
  /// vez digita dez descrições e dez valores na **mesma** categoria e no mesmo
  /// cartão, e repor esses campos a cada linha é o trabalho que o botão existe
  /// para eliminar.
  ///
  /// O parcelamento também é limpo: ele é da compra, não da sessão de
  /// lançamento, e herdá-lo criaria doze parcelas de um lançamento que não era
  /// parcelado.
  void _limparParaProximo() {
    _descricaoController.clear();
    _valorController.clear();

    setState(() {
      _parcelar = false;
      _numeroParcelas = 2;
      _parcelasController.text = '2';
    });

    _descricaoFocus.requestFocus();
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

  Future<void> _selecionarData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _dataLancamento,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('pt', 'BR'),
      helpText: 'Data da compra',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
      fieldLabelText: 'Data da compra',
      errorFormatText: 'Data inválida',
      errorInvalidText: 'Data fora do intervalo permitido',
    );

    if (escolhida != null) setState(() => _dataLancamento = escolhida);
  }

  Future<void> _abrirDialogNovaCategoria() async {
    final nova = await showDialog<int>(
      context: context,
      builder: (context) => CategoriaFormDialog(tipoFluxo: _tipoCategoria),
    );

    // `null` é cancelamento; 0 significa criada sem id conhecido — nos dois
    // casos diferente de selecionar, mas só o cancelamento dispensa recarregar.
    if (nova == null) return;

    await _carregarCategorias();
    if (!mounted) return;
    setState(() {
      if (nova != 0) _categoriaId = nova;
      _subcategoriaId = 0;
      _habilitarSubcategorias = false;
    });
  }

  Future<void> _abrirDialogNovaSubcategoria(
    Categoria categoria,
    Color corCategoria,
  ) async {
    final nova = await showDialog<int>(
      context: context,
      builder:
          (context) => SubcategoriaFormDialog(
            idCategoria: categoria.id!,
            nomeCategoria: categoria.descricao,
            corCategoria: corCategoria,
          ),
    );

    if (nova == null) return;

    await _carregarSubcategorias();
    if (!mounted) return;
    setState(() {
      _habilitarSubcategorias = true;
      if (nova != 0) _subcategoriaId = nova;
    });
  }

  // ------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final dialogWidth =
        ResponsiveUtils.isMobile(context)
            ? MediaQuery.of(context).size.width * 0.9
            : ResponsiveUtils.isTablet(context)
            ? 500.0
            : 600.0;

    return AlertDialog(
      title: _buildCabecalho(),
      contentPadding: context.responsivePadding(),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_editando) ...[
                  _buildTipo(),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (_ehCredito) ...[
                  _buildNatureza(),
                  const SizedBox(height: AppSpacing.md),
                ],

                TextFormField(
                  controller: _descricaoController,
                  focusNode: _descricaoFocus,
                  autofocus: !_editando,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Descrição',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Campo obrigatório';
                    }
                    if (value.trim().length < 3) return 'Mínimo 3 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                TextFormField(
                  controller: _valorController,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText:
                        _parcelar && !_valorEhParcela
                            ? 'Valor total'
                            : 'Valor',
                    prefixText: 'R\$ ',
                  ),
                  // Só dígitos: a vírgula e o ponto são postos pela máscara.
                  keyboardType: TextInputType.number,
                  inputFormatters: const [CurrencyInputFormatter()],
                  // Realimenta a prévia do valor por parcela.
                  onChanged: (_) {
                    if (_parcelar) setState(() {});
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Campo obrigatório';
                    }
                    final numero = CurrencyFormatter.parse(value);
                    if (numero == null) return 'Valor inválido';
                    if (numero <= 0) return 'Deve ser maior que zero';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                _buildCategoria(),
                ..._buildSubcategoria(),

                // Crédito não se parcela, e lançamento em edição não muda de
                // parcelamento: a posição de uma parcela na sequência é o que a
                // define.
                if (!_editando && !_ehCredito) ...[
                  const SizedBox(height: AppSpacing.md),
                  ..._buildParcelamento(),
                ],

                if (_gravados > 0) ...[
                  const SizedBox(height: AppSpacing.md),
                  _buildContagem(),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: _buildAcoes(),
    );
  }

  /// Título mais os dois controles compactos — cartão e data —, na forma do
  /// [FluxoFormDialog]: os dois já chegam decididos quando o modal abre, e como
  /// campo de formulário ocupariam duas linhas inteiras empurrando para baixo o
  /// que o lojista veio digitar.
  Widget _buildCabecalho() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: [
            Text(
              _editando ? 'Editar lançamento' : 'Novo lançamento',
              style: theme.textTheme.titleLarge,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Com um cartão só não há escolha a fazer, e um chip fixo seria
                // só ruído.
                if (widget.cartoes.length > 1) ...[
                  Flexible(child: _chipCartao()),
                  const SizedBox(width: AppSpacing.sm),
                ],
                _chipData(),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        // A prévia da fatura: é a regra central do cartão, e sem ela o lojista
        // só descobriria em qual fatura o lançamento caiu depois de salvar.
        Text(
          'Entra na fatura de ${rotuloMes(_competenciaPrevista).toLowerCase()}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _chipCartao() {
    return PopupMenuButton<int>(
      tooltip: 'Cartão',
      position: PopupMenuPosition.under,
      initialValue: _cartao.id,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      onSelected: (id) {
        for (final c in widget.cartoes) {
          if (c.id == id) setState(() => _cartao = c);
        }
      },
      itemBuilder:
          (context) => [
            for (final c in widget.cartoes)
              PopupMenuItem(
                value: c.id,
                child: Row(
                  children: [
                    LogoBandeira(chave: c.bandeira, largura: 26),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        c.ativado ? c.descricao : '${c.descricao} (arquivado)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
      child: _chip(
        icone: LogoBandeira(chave: _cartao.bandeira, largura: 22),
        texto: _cartao.descricao,
        dica: 'Cartão',
      ),
    );
  }

  Widget _chipData() {
    final d = _dataLancamento;

    return InkWell(
      onTap: _selecionarData,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: _chip(
        icone: const Icon(Icons.event, size: 16),
        texto:
            '${d.day.toString().padLeft(2, '0')}/'
            '${d.month.toString().padLeft(2, '0')}/${d.year}',
        dica: 'Data da compra',
      ),
    );
  }

  /// Forma comum dos chips do cabeçalho — a mesma do [FluxoFormDialog], inclusive
  /// o teto de largura e a ausência de chevron: no celular o diálogo sobra ~232
  /// lógicos para o cabeçalho, e os 18px da seta eram a diferença entre o nome
  /// inteiro e reticências.
  Widget _chip({required Widget icone, required String texto, String? dica}) {
    final theme = Theme.of(context);

    final conteudo = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: theme.inputDecorationTheme.fillColor,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icone,
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                texto,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );

    return dica == null ? conteudo : Tooltip(message: dica, child: conteudo);
  }

  /// Compra × crédito. Segmentado e não dropdown: são duas opções e a escolha
  /// muda o resto do formulário (natureza, parcelamento, tipo das categorias) —
  /// esconder isso atrás de um menu faria o formulário parecer trocar sozinho.
  Widget _buildTipo() {
    final cores = context.appColors;

    return SegmentedButton<int>(
      segments: [
        ButtonSegment(
          value: 2,
          icon: Icon(Icons.shopping_cart_outlined, size: 18, color: cores.error),
          label: const Text('Compra'),
        ),
        ButtonSegment(
          value: 1,
          icon: Icon(Icons.undo, size: 18, color: cores.success),
          label: const Text('Crédito'),
        ),
      ],
      selected: {_tipoFluxo},
      showSelectedIcon: false,
      onSelectionChanged: (selecao) {
        final novo = selecao.first;
        if (novo == _tipoFluxo) return;

        setState(() {
          _tipoFluxo = novo;
          // As categorias são de outra natureza agora: a escolhida pertencia à
          // anterior, e manter o id gravaria um vínculo que a tela não mostraria.
          _categoriaId = 0;
          _subcategoriaId = 0;
          _habilitarSubcategorias = false;
          _parcelar = false;
        });

        _carregarCategorias();
      },
    );
  }

  /// A natureza do crédito.
  ///
  /// "Pagamento de fatura" **não** está aqui, e é a decisão que mantém o caixa
  /// honesto: pagamento é o único crédito que move dinheiro, e ele dá baixa na
  /// despesa que o fechamento gerou em vez de criar outra. Oferecê-lo aqui faria
  /// a mesma fatura sair da conta duas vezes.
  Widget _buildNatureza() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<NaturezaMovimento>(
          value: _natureza,
          isDense: true,
          isExpanded: true,
          decoration: const InputDecoration(
            isDense: true,
            labelText: 'Tipo de crédito',
          ),
          items: [
            for (final n in NaturezaMovimento.creditosLancaveis)
              DropdownMenuItem(value: n, child: Text(n.rotulo)),
          ],
          onChanged: (v) => setState(() => _natureza = v ?? _natureza),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Abate a fatura e não movimenta o caixa. Para pagar a fatura, use '
          '"Pagar fatura" na própria fatura.',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoria() {
    return SeletorCategoria(
      titulo: 'Categorias',
      rotuloBotaoNovo: 'nova categoria',
      mensagemVazio: 'Nenhuma categoria cadastrada',
      itens: [
        for (final cat in _categorias)
          if (cat.id != null)
            ItemSelecionavel(
              id: cat.id!,
              descricao: cat.descricao,
              icone: cat.icone,
              cor: CategoriaVisuais.cor(cat.cor),
              destaque: cat.destaque == true,
            ),
      ],
      selecionadoId: _categoriaId == 0 ? null : _categoriaId,
      onSelecionar: (id) {
        setState(() {
          _categoriaId = id ?? 0;
          // Trocar de categoria invalida a filha escolhida: ela pertencia à
          // categoria anterior.
          _subcategoriaId = 0;
          _habilitarSubcategorias = false;
        });
      },
      onNovo: _abrirDialogNovaCategoria,
      rotuloNenhum: 'Sem categoria',
    );
  }

  /// Bloco de subcategoria: o checkbox de habilitar, o card, ou nada — igual ao
  /// do caixa, porque as categorias e subcategorias são as mesmas.
  List<Widget> _buildSubcategoria() {
    final categoria = _categoriaSelecionada;
    if (categoria == null) return const [];

    final filhas = _subcategoriasDaCategoria;
    final corPai = CategoriaVisuais.cor(categoria.cor);
    final corFilha = corPai.withValues(
      alpha: CategoriaVisuais.opacidadeSubcategoria,
    );

    // Já existindo subcategoria, o card vai direto — o checkbox só serve para
    // criar a primeira.
    final mostraCard = filhas.isNotEmpty || _habilitarSubcategorias;

    return [
      const SizedBox(height: AppSpacing.sm),
      if (filhas.isEmpty)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          visualDensity: VisualDensity.compact,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('habilitar subcategorias'),
          value: _habilitarSubcategorias,
          onChanged:
              (v) => setState(() {
                _habilitarSubcategorias = v ?? false;
                if (!_habilitarSubcategorias) _subcategoriaId = 0;
              }),
        ),
      if (mostraCard) ...[
        if (filhas.isEmpty) const SizedBox(height: AppSpacing.xs),
        SeletorCategoria(
          titulo: 'Subcategoria',
          rotuloBotaoNovo: 'subcategoria',
          mensagemVazio: 'Nenhuma subcategoria cadastrada',
          itens: [
            for (final sub in filhas)
              if (sub.id != null)
                ItemSelecionavel(
                  id: sub.id!,
                  descricao: sub.descricao,
                  icone: sub.icone,
                  cor: corFilha,
                  destaque: sub.destaque == true,
                ),
          ],
          selecionadoId: _subcategoriaId == 0 ? null : _subcategoriaId,
          onSelecionar: (id) => setState(() => _subcategoriaId = id ?? 0),
          onNovo: () => _abrirDialogNovaSubcategoria(categoria, corPai),
          rotuloNenhum: 'Sem subcategoria',
        ),
      ],
    ];
  }

  /// Parcelamento: um checkbox que abre o número de parcelas e a prévia.
  ///
  /// Não é o dropdown de repetição do caixa ("Diária/Semanal/Mensal/Anual"):
  /// parcelamento de cartão é mensal por definição, e oferecer "semanal" seria
  /// oferecer algo que a fatura não sabe representar.
  List<Widget> _buildParcelamento() {
    final theme = Theme.of(context);
    final valorDigitado = CurrencyFormatter.parse(_valorController.text) ?? 0;
    final n = _numeroParcelas > 0 ? _numeroParcelas : 1;

    final valorParcela = _valorEhParcela ? valorDigitado : valorDigitado / n;
    final total = _valorEhParcela ? valorDigitado * n : valorDigitado;

    final primeira = _competenciaPrevista;
    final ultima = DateTime(primeira.year, primeira.month + n - 1);

    return [
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        visualDensity: VisualDensity.compact,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text('Compra parcelada'),
        value: _parcelar,
        onChanged: (v) => setState(() => _parcelar = v ?? false),
      ),
      if (_parcelar) ...[
        Row(
          children: [
            SizedBox(
              width: 110,
              child: TextFormField(
                controller: _parcelasController,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Parcelas',
                ),
                keyboardType: TextInputType.number,
                onChanged:
                    (v) => setState(() => _numeroParcelas = int.tryParse(v) ?? 1),
                validator: (value) {
                  if (!_parcelar) return null;
                  final numero = int.tryParse(value ?? '');
                  if (numero == null || numero < 2) return 'Mínimo 2';
                  // O teto é o da API (`PARCELAS_CARTAO_MAX`): acima disso é
                  // quase certo que o número veio errado.
                  if (numero > 48) return 'Máximo 48';
                  return null;
                },
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RadioListTile<bool>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: const Text('Valor total a dividir'),
                    value: false,
                    groupValue: _valorEhParcela,
                    onChanged: (v) => setState(() => _valorEhParcela = v ?? false),
                  ),
                  RadioListTile<bool>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: const Text('Valor é da parcela'),
                    value: true,
                    groupValue: _valorEhParcela,
                    onChanged: (v) => setState(() => _valorEhParcela = v ?? true),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (valorDigitado > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          // As duas coisas que o lojista confere no comprovante: o valor da
          // parcela e em que fatura a última cai.
          Text(
            '$n × ${CurrencyFormatter.format(valorParcela)} = '
            '${CurrencyFormatter.format(total)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'Faturas de ${rotuloMes(primeira).toLowerCase()} a '
            '${rotuloMes(ultima).toLowerCase()}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    ];
  }

  Widget _buildContagem() {
    final theme = Theme.of(context);
    final cores = context.appColors;

    return Row(
      children: [
        Icon(Icons.check_circle, size: 14, color: cores.success),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '$_gravados ${_gravados == 1 ? 'lançamento gravado' : 'lançamentos gravados'}',
          style: theme.textTheme.labelSmall?.copyWith(color: cores.success),
        ),
      ],
    );
  }

  /// Cancelar, "Salvar e continuar" e Salvar.
  ///
  /// "Salvar e continuar" grava e mantém o modal aberto com cartão, data,
  /// categoria e tipo preenchidos, limpando só descrição e valor — é para quem
  /// lança a fatura do mês inteiro de uma vez. Fica à esquerda do Salvar e sem
  /// destaque: a ação padrão continua sendo gravar e fechar.
  ///
  /// Não aparece em edição: editar é por definição uma operação de um registro,
  /// e "continuar" não teria o que continuar.
  List<Widget> _buildAcoes() {
    if (_isLoading) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: ResponsiveUtils.isMobile(context) ? 3.0 : 4.0,
            ),
          ),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        // Depois de gravar com "continuar", não há o que cancelar — o que foi
        // gravado está gravado, e "Cancelar" ali sugeriria desfazer.
        child: Text(_gravados > 0 ? 'Fechar' : 'Cancelar'),
      ),
      if (!_editando)
        TextButton(
          onPressed: () => _salvar(continuar: true),
          child: const Text('Salvar e continuar'),
        ),
      ElevatedButton(
        onPressed: () => _salvar(continuar: false),
        child: const Text('Salvar'),
      ),
    ];
  }
}
