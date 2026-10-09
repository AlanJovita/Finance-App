import 'package:flutter/material.dart';

import '../models/cartao.dart';
import '../models/categoria.dart';
import '../models/subcategoria.dart';
import '../services/api_service.dart';
import '../services/cartoes_cache.dart';
import '../services/logger_service.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';
import '../utils/bandeiras.dart';
import '../utils/currency_formatter.dart';
import '../utils/meses.dart';
import '../utils/responsive_utils.dart';
import '../widgets/card_movimento_cartao.dart';
import '../widgets/logo_bandeira.dart';
import '../widgets/movimento_cartao_form_dialog.dart';
import '../widgets/pagamento_fatura_dialog.dart';
import '../widgets/shimmer_widgets.dart';

/// A fatura de um cartão, mês a mês — gêmea da [FluxosPage].
///
/// Três coisas a distinguem dela, e todas vêm do domínio do cartão:
///
/// 1. **O mês é a fatura, não o vencimento.** Lá o navegador recorta por
///    `data_vencimento`; aqui ele troca de *competência*, e a competência de uma
///    compra é decidida pelo dia de fechamento do cartão — não pela data em que
///    ela foi feita. Daí uma compra de 29/10 aparecer na fatura de novembro.
/// 2. **Uma requisição por mês, não três.** `GET /cartao/fatura` devolve a
///    fatura, os totais e os movimentos juntos, porque a tela precisa dos três
///    em toda troca de mês.
/// 3. **A tela tem um ciclo de vida, não só uma lista.** Aberta aceita
///    lançamento; fechar congela o valor e gera a despesa no caixa; pagar dá
///    baixa nessa despesa. O cabeçalho é onde esse ciclo aparece, e é o que o
///    [CardMovimentoCartao] propositalmente não tenta mostrar por lançamento.
///
/// Competência sem lançamento nenhum **não é erro**: a API devolve a fatura
/// vazia (`id == 0`) com as datas calculadas do ciclo, e a tela a desenha como
/// um mês em branco. Um GET não cria linha no banco.
class CartaoMovimentosPage extends StatefulWidget {
  final Cartao cartao;

  const CartaoMovimentosPage({super.key, required this.cartao});

  @override
  State<CartaoMovimentosPage> createState() => _CartaoMovimentosPageState();
}

class _CartaoMovimentosPageState extends State<CartaoMovimentosPage> {
  final ApiService _apiService = ApiService();
  final LoggerService _logger = LoggerService();

  late final Cartao _cartao = widget.cartao;

  /// Competência em foco, sempre no dia 1. Nula até a primeira resposta: quem
  /// decide qual fatura está aberta é o servidor, a partir do ciclo do cartão —
  /// e não é necessariamente o mês corrente (cartão que fecha dia 1 já está
  /// recebendo compras na fatura do mês seguinte).
  DateTime? _competencia;

  /// A competência aberta, como a API a resolveu na primeira carga.
  ///
  /// Guardada em vez de recalculada: a regra do fechamento mora na API
  /// (`Cartao.competenciaDe`), e uma segunda implementação dela aqui divergiria
  /// na primeira borda de mês curto. É o que decide se o modal de lançamento
  /// nasce com a data de hoje ou com uma data da fatura em foco.
  DateTime? _competenciaAberta;

  FaturaDetalhe? _detalhe;
  bool _carregando = true;
  Object? _erro;

  /// Cada carga leva um número e só a mais recente pode escrever no estado — o
  /// mesmo cuidado da [FluxosPage] e da [CartoesPage]. Trocar de mês duas vezes
  /// rápido fazia a resposta antiga repor a fatura anterior na tela.
  int _geracao = 0;

  /// As competências que têm fatura — alimenta o atalho de meses, sem baixar os
  /// movimentos de nenhuma delas.
  List<ResumoFatura> _faturas = const [];

  Map<int, Categoria> _categorias = const {};
  Map<int, Subcategoria> _subcategorias = const {};

  /// Os cartões do seletor do modal de lançamento, do [CartoesCache].
  List<Cartao> _cartoes = const [];

  /// Fechar, reabrir e pagar mexem na mesma fatura. Um por vez: dois toques no
  /// botão de fechar gerariam duas despesas no caixa, e o segundo só falharia
  /// depois de o primeiro ter gravado.
  bool _emAcao = false;

  @override
  void initState() {
    super.initState();
    _carregar();
    _carregarFaturas();
    _carregarCategorias();
    _carregarCartoes();
  }

  Fatura? get _fatura => _detalhe?.fatura;

  TotaisFatura get _totais => _detalhe?.totais ?? TotaisFatura.vazio;

  List<MovimentoCartao> get _movimentos => _detalhe?.movimentos ?? const [];

  /// Competência sem linha no banco: o mês em branco, que o primeiro lançamento
  /// materializa.
  bool get _faturaVazia => (_fatura?.id ?? 0) == 0;

  // ---------------------------------------------------------------- dados

  Future<void> _carregar() async {
    final geracao = ++_geracao;

    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final detalhe = await _apiService.getFatura(
        _cartao.id,
        competencia: _competencia,
      );

      if (!mounted || geracao != _geracao) return;

      setState(() {
        _detalhe = detalhe;
        _carregando = false;

        // A primeira carga vai sem competência e volta com a aberta — é daí que
        // a tela aprende em qual mês ela está.
        final competencia = detalhe.fatura.competencia;
        if (competencia != null) {
          _competencia = DateTime(competencia.year, competencia.month);
          _competenciaAberta ??= _competencia;
        }
      });
    } catch (e, s) {
      await _logger.logError(
        'CartaoMovimentosPage._carregar',
        e,
        stackTrace: s,
        additionalInfo: {
          'idCartao': _cartao.id,
          if (_competencia != null) 'competencia': chaveCompetencia(_competencia!),
        },
      );

      if (!mounted || geracao != _geracao) return;

      setState(() {
        _erro = e;
        _carregando = false;
      });
    }
  }

  /// O atalho de meses é acessório: sem ele a tela perde o menu, não a fatura.
  /// Por isso a falha não derruba o que está em foco — mas vai para o log, senão
  /// o sintoma chega como "sumiram os meses".
  Future<void> _carregarFaturas() async {
    try {
      final faturas = await _apiService.listFaturas(_cartao.id);
      if (!mounted) return;
      setState(() => _faturas = faturas);
    } catch (e, s) {
      await _logger.logError(
        'CartaoMovimentosPage._carregarFaturas',
        e,
        stackTrace: s,
        additionalInfo: {'idCartao': _cartao.id},
      );
    }
  }

  /// Categoria e subcategoria chegam ao card já resolvidas: quem tem os mapas é
  /// a página, e refazer a busca por item seria um `firstWhere` por card a cada
  /// rebuild da lista.
  Future<void> _carregarCategorias() async {
    try {
      final categorias = await _apiService.listCategorias();
      final subcategorias = await _apiService.listSubcategorias();
      if (!mounted) return;

      setState(() {
        _categorias = {
          for (final c in categorias)
            if (c.id != null) c.id!: c,
        };
        _subcategorias = {
          for (final s in subcategorias)
            if (s.id != null) s.id!: s,
        };
      });
    } catch (e, s) {
      // Sem as categorias os cards perdem nome, ícone e cor. A tela continua de
      // pé, então sem log o sintoma chega como "sumiram os ícones".
      await _logger.logError(
        'CartaoMovimentosPage._carregarCategorias',
        e,
        stackTrace: s,
      );
    }
  }

  Future<void> _carregarCartoes() async {
    await CartoesCache().obter();
    if (!mounted) return;
    setState(() => _cartoes = CartoesCache().ativos);
  }

  /// Recarrega depois de lançar, editar, excluir, fechar, reabrir ou pagar.
  ///
  /// A lista de faturas vem junto: um lançamento numa competência que ainda não
  /// existia cria a linha, e sem recarregar o atalho o mês novo não apareceria
  /// no menu. Fechar e pagar mudam o status que o menu mostra.
  void _recarregar() {
    _carregar();
    _carregarFaturas();
  }

  void _irPara(DateTime mes) {
    setState(() => _competencia = DateTime(mes.year, mes.month));
    _carregar();
  }

  // ---------------------------------------------------------------- ações

  /// Os cartões que o seletor do modal oferece: os ativos, mais este.
  ///
  /// Este entra mesmo arquivado — a tela dele está aberta, e um seletor que não
  /// mostra o cartão em foco pareceria defeito.
  List<Cartao> get _cartoesDoSeletor {
    if (_cartoes.any((c) => c.id == _cartao.id)) return _cartoes;
    return [_cartao, ..._cartoes];
  }

  /// A data que o lançamento novo já traz pronta.
  ///
  /// `null` (hoje) quando a fatura em foco é a aberta, que é o caso normal. Numa
  /// fatura passada ou futura, hoje cairia **noutra** competência: o lançamento
  /// sairia da tela no instante em que fosse salvo, sem aviso. A âncora é o dia
  /// anterior ao fechamento da fatura em foco, que é uma data garantidamente
  /// dentro do ciclo dela — inclusive quando o fechamento foi travado no último
  /// dia de um mês curto, porque é a própria data materializada pela API.
  DateTime? get _dataInicialDoLancamento {
    final competencia = _competencia;
    final aberta = _competenciaAberta;

    if (competencia == null ||
        (aberta != null &&
            competencia.year == aberta.year &&
            competencia.month == aberta.month)) {
      return null;
    }

    final fechamento = _fatura?.dataFechamento;
    if (fechamento == null) return null;

    return fechamento.subtract(const Duration(days: 1));
  }

  void _abrirFormulario({MovimentoCartao? movimento}) {
    showDialog(
      context: context,
      builder:
          (_) => MovimentoCartaoFormDialog(
            cartao: _cartao,
            cartoes: _cartoesDoSeletor,
            movimento: movimento,
            dataInicial: movimento == null ? _dataInicialDoLancamento : null,
            // Quem fecha o modal é ele mesmo — aqui só se recarrega. Vale para o
            // "salvar e continuar" também: a fatura atrás muda a cada gravação, e
            // atualizá-la é a única confirmação visível de que a anterior entrou.
            onSalvou: (_) => _recarregar(),
          ),
    );
  }

  Future<void> _fechar() async {
    final fatura = _fatura;
    if (fatura == null || _emAcao) return;

    final valor = _totais.valor;

    final confirmado = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Fechar a fatura?'),
            content: Text(
              valor <= 0
                  ? 'Esta fatura não tem valor a pagar, então nenhuma despesa '
                      'será gerada. Ela deixa de aceitar lançamentos — uma '
                      'compra retroativa passa a cair na fatura seguinte.'
                  : 'O valor de ${CurrencyFormatter.format(valor)} é congelado '
                      'e vira uma despesa única nas suas Despesas, vencendo em '
                      '${_dataCurta(fatura.dataVencimento)}.\n\n'
                      'É aqui que o cartão vira dinheiro: até agora as compras '
                      'eram dívida do cartão e não apareciam no caixa. Depois '
                      'de fechada, a fatura não aceita mais lançamentos.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Fechar fatura'),
              ),
            ],
          ),
    );

    if (confirmado != true) return;

    setState(() => _emAcao = true);

    try {
      final congelado = await _apiService.fecharFatura(fatura.id);

      if (!mounted) return;

      _avisar(
        congelado <= 0
            ? 'Fatura fechada sem valor a pagar.'
            : 'Fatura fechada. Despesa de '
                '${CurrencyFormatter.format(congelado)} gerada nas Despesas.',
        sucesso: true,
      );
      _recarregar();
    } catch (e, s) {
      await _logger.logError(
        'CartaoMovimentosPage._fechar',
        e,
        stackTrace: s,
        additionalInfo: {'idFatura': fatura.id},
      );
      if (mounted) _avisar('Não foi possível fechar a fatura: $e');
    } finally {
      if (mounted) setState(() => _emAcao = false);
    }
  }

  /// Desfaz o fechamento.
  ///
  /// A API recusa com pagamento registrado — apagar a despesa faria o dinheiro
  /// que saiu da conta desaparecer do caixa —, e a mensagem dela é a que a tela
  /// mostra: é ela que diz para apagar o pagamento primeiro.
  Future<void> _reabrir() async {
    final fatura = _fatura;
    if (fatura == null || _emAcao) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Reabrir a fatura?'),
            content: const Text(
              'A despesa que o fechamento gerou nas Despesas é apagada, e a '
              'fatura volta a aceitar lançamentos.\n\n'
              'É o caminho para corrigir uma fatura fechada cedo ou com um '
              'lançamento errado dentro.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Reabrir'),
              ),
            ],
          ),
    );

    if (confirmado != true) return;

    setState(() => _emAcao = true);

    try {
      await _apiService.reabrirFatura(fatura.id);

      if (!mounted) return;

      _avisar('Fatura reaberta. A despesa dela foi removida.', sucesso: true);
      _recarregar();
    } catch (e, s) {
      await _logger.logError(
        'CartaoMovimentosPage._reabrir',
        e,
        stackTrace: s,
        additionalInfo: {'idFatura': fatura.id},
      );
      if (mounted) _avisar('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _emAcao = false);
    }
  }

  Future<void> _pagar() async {
    final fatura = _fatura;
    if (fatura == null) return;

    final registrou = await showDialog<bool>(
      context: context,
      builder:
          (_) => PagamentoFaturaDialog(
            cartao: _cartao,
            fatura: fatura,
            totais: _totais,
          ),
    );

    // O próprio modal já confirmou o pagamento na snackbar dele.
    if (registrou == true) _recarregar();
  }

  /// Exclui um lançamento, ou a compra parcelada inteira.
  ///
  /// O checkbox é o que decide o escopo: `id_ref` positivo apaga o lote, 0 apaga
  /// a linha. Mandar `movimento.idRef` por reflexo transformaria "excluir esta
  /// parcela" em "excluir a compra" — o mesmo cuidado do modal de exclusão da
  /// [FluxosPage].
  Future<void> _excluir(MovimentoCartao movimento) async {
    final cores = context.appColors;
    final ehParcelamento = movimento.idRef > 0 && movimento.ehParcelado;

    // Fora do `builder` para sobreviver aos rebuilds do StatefulBuilder e
    // continuar legível depois que o diálogo fecha.
    var excluirGrupo = false;

    final confirmado = await showDialog<bool>(
      context: context,
      builder:
          (_) => StatefulBuilder(
            builder:
                (context, setStateDialog) => AlertDialog(
                  title: const Text('Confirmar exclusão'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Excluir "${movimento.descricao}" '
                        'desta fatura?',
                      ),
                      if (movimento.ehPagamento) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'A baixa que este pagamento deu na despesa da fatura '
                          'também é desfeita, e a fatura volta para "fechada".',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (ehParcelamento) ...[
                        const SizedBox(height: AppSpacing.sm),
                        CheckboxListTile(
                          value: excluirGrupo,
                          onChanged:
                              (marcado) => setStateDialog(
                                () => excluirGrupo = marcado ?? false,
                              ),
                          title: const Text('Excluir todas as parcelas'),
                          subtitle: Text(
                            'As ${movimento.totalParcelas} parcelas desta '
                            'compra, nas faturas seguintes.',
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ],
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: cores.error,
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Excluir'),
                    ),
                  ],
                ),
          ),
    );

    if (confirmado != true) return;

    try {
      await _apiService.deleteMovimentoCartao(
        movimento.id,
        excluirGrupo ? movimento.idRef : 0,
      );
      _recarregar();
    } catch (e, s) {
      await _logger.logError(
        'CartaoMovimentosPage._excluir',
        e,
        stackTrace: s,
        additionalInfo: {
          'id': movimento.id,
          'idRef': movimento.idRef,
          'excluirGrupo': excluirGrupo,
        },
      );
      if (mounted) _avisar('$e'.replaceFirst('Exception: ', ''));
    }
  }

  void _avisar(String mensagem, {bool sucesso = false}) {
    final cores = context.appColors;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: sucesso ? cores.success : cores.error,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: sucesso ? 3 : 4),
      ),
    );
  }

  static String _dataCurta(DateTime? data) {
    if (data == null) return '—';
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}';
  }

  // ----------------------------------------------------------------- tela

  @override
  Widget build(BuildContext context) {
    final fatura = _fatura;

    // Fatura fechada não aceita lançamento — a API recusa. O botão sai da tela
    // em vez de mostrar um formulário que terminaria em mensagem de erro.
    final podeLancar = fatura == null || fatura.aberta;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _cartao.descricao.isEmpty ? 'Cartão' : _cartao.descricao,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Fecha dia ${_cartao.diaFechamento} · '
              'vence dia ${_cartao.diaVencimento}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
      floatingActionButton:
          !podeLancar
              ? null
              : FloatingActionButton(
                onPressed: () => _abrirFormulario(),
                tooltip: 'Novo lançamento',
                child: const Icon(Icons.add),
              ),
      body: Column(
        children: [
          _navegador(),
          Expanded(child: _corpo()),
        ],
      ),
      bottomNavigationBar: _detalhe == null ? null : _rodape(),
    );
  }

  // ------------------------------------------------------- navegador de mês

  Widget _navegador() {
    final theme = Theme.of(context);
    final competencia = _competencia;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Fatura anterior',
              visualDensity: VisualDensity.compact,
              onPressed:
                  competencia == null
                      ? null
                      : () => _irPara(
                        DateTime(competencia.year, competencia.month - 1),
                      ),
            ),
            Expanded(child: _atalhoFaturas(theme)),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Próxima fatura',
              visualDensity: VisualDensity.compact,
              onPressed:
                  competencia == null
                      ? null
                      : () => _irPara(
                        DateTime(competencia.year, competencia.month + 1),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  /// O rótulo do mês é também um menu: lista as competências que têm fatura,
  /// para não obrigar a clicar na seta doze vezes até achar.
  Widget _atalhoFaturas(ThemeData theme) {
    final competencia = _competencia;
    final aberta = _competenciaAberta;

    final naAberta =
        competencia != null &&
        aberta != null &&
        competencia.year == aberta.year &&
        competencia.month == aberta.month;

    return PopupMenuButton<String>(
      tooltip: 'Escolher fatura',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      onSelected: (chave) {
        final partes = chave.split('-');
        _irPara(DateTime(int.parse(partes[0]), int.parse(partes[1])));
      },
      itemBuilder: (context) {
        final itens = <PopupMenuEntry<String>>[
          if (!naAberta && aberta != null)
            PopupMenuItem(
              value: chaveCompetencia(aberta),
              child: const Row(
                children: [
                  Icon(Icons.today, size: 16),
                  SizedBox(width: AppSpacing.sm),
                  Text('Fatura aberta'),
                ],
              ),
            ),
          if (!naAberta && aberta != null && _faturas.isNotEmpty)
            const PopupMenuDivider(),
          for (final f in _faturas)
            if (f.competencia != null)
              PopupMenuItem(
                value: f.chave,
                child: Row(
                  children: [
                    Expanded(child: Text(rotuloMes(f.competencia!))),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      CurrencyFormatter.format(f.valor),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color:
                            f.status == StatusFatura.paga
                                ? context.appColors.success
                                : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
        ];

        // Cartão sem fatura nenhuma, parado na competência aberta: as duas
        // listas acima ficam vazias e o `showMenu` do Material quebra num
        // assert se abrir sem item nenhum.
        if (itens.isEmpty) {
          itens.add(
            PopupMenuItem(
              enabled: false,
              child: Text('Nenhuma fatura ainda', style: theme.textTheme.bodySmall),
            ),
          );
        }

        return itens;
      },
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                competencia == null ? 'Fatura' : rotuloMes(competencia),
                style: theme.textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- corpo

  Widget _corpo() {
    if (_carregando && _detalhe == null) {
      return SingleChildScrollView(
        padding: context.responsivePadding(),
        child: Column(
          children: [
            ShimmerWidgets.dashboardCardShimmer(context),
            SizedBox(height: context.responsiveSpacing()),
            ShimmerWidgets.listFluxosShimmer(context),
          ],
        ),
      );
    }

    if (_erro != null && _detalhe == null) {
      final theme = Theme.of(context);

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off,
                size: 40,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Não foi possível carregar a fatura.\n$_erro',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _carregar,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
      );
    }

    final movimentos = _movimentos;

    return RefreshIndicator(
      onRefresh: () async => _recarregar(),
      child: ListView.builder(
        padding: context.responsivePadding(),
        // Cabeçalho + lista (ou o vazio) numa rolagem só: o cabeçalho tem a
        // altura de um card e fixá-lo comeria metade da tela no celular.
        itemCount: 1 + (movimentos.isEmpty ? 1 : movimentos.length),
        itemBuilder: (context, i) {
          if (i == 0) return _cabecalho();
          if (movimentos.isEmpty) return _vazio();
          return _card(movimentos[i - 1]);
        },
      ),
    );
  }

  Widget _vazio() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Nenhum lançamento nesta fatura.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (_faturaVazia) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'A primeira compra desta competência é o que cria a fatura.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _card(MovimentoCartao movimento) {
    final fatura = _fatura;

    return CardMovimentoCartao(
      movimento: movimento,
      categoria: _categorias[movimento.idCategoria],
      subcategoria: _subcategorias[movimento.idSubcategoria],
      faturaFechada: fatura != null && !fatura.aberta,
      onEditar: () => _abrirFormulario(movimento: movimento),
      onExcluir: () => _excluir(movimento),
    );
  }

  // ------------------------------------------------------------- cabeçalho

  /// O ciclo da fatura: situação, datas, valor e as ações que a movem adiante.
  ///
  /// É o que a lista de lançamentos não consegue dizer — "fechada e vencida" é
  /// um fato da fatura, não de nenhuma compra dentro dela.
  Widget _cabecalho() {
    final theme = Theme.of(context);
    final cores = context.appColors;
    final fatura = _fatura;
    if (fatura == null) return const SizedBox.shrink();

    final totais = _totais;
    final vencida = fatura.vencida && totais.saldo > 0.005;

    return Card(
      elevation: AppElevation.card,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                LogoBandeira(chave: _cartao.bandeira, largura: 40),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Bandeiras.nome(_cartao.bandeira).isEmpty
                            ? 'Fatura'
                            : Bandeiras.nome(_cartao.bandeira),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        // Fatura aberta mostra a soma ao vivo; fechada mostra o
                        // congelado. A API já resolve qual dos dois é `valor`.
                        CurrencyFormatter.format(totais.valor),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: vencida ? cores.error : null,
                        ),
                      ),
                    ],
                  ),
                ),
                _chipStatus(theme, cores, fatura, vencida),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.xs,
              children: [
                _dado(
                  theme,
                  Icons.event_available,
                  'Fecha',
                  _dataCurta(fatura.dataFechamento),
                ),
                _dado(
                  theme,
                  Icons.event,
                  'Vence',
                  _dataCurta(fatura.dataVencimento),
                  cor: vencida ? cores.error : null,
                ),
                if (totais.pago > 0.005)
                  _dado(
                    theme,
                    Icons.price_check,
                    'Pago',
                    CurrencyFormatter.format(totais.pago),
                    cor: cores.success,
                  ),
                if (totais.pagoParcialmente)
                  _dado(
                    theme,
                    Icons.pending_actions,
                    'Falta',
                    CurrencyFormatter.format(totais.saldo),
                    cor: cores.warning,
                  ),
              ],
            ),
            _acoes(fatura, totais),
          ],
        ),
      ),
    );
  }

  Widget _chipStatus(
    ThemeData theme,
    AppColors cores,
    Fatura fatura,
    bool vencida,
  ) {
    final (texto, cor) = switch (fatura.status) {
      StatusFatura.paga => ('Paga', cores.success),
      StatusFatura.fechada => (vencida ? 'Vencida' : 'Fechada', vencida ? cores.error : cores.warning),
      StatusFatura.aberta => ('Aberta', cores.info),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        texto,
        style: theme.textTheme.labelSmall?.copyWith(
          color: cor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _dado(
    ThemeData theme,
    IconData icone,
    String rotulo,
    String valor, {
    Color? cor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 13, color: cor ?? theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '$rotulo ',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          valor,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Uma ação por situação, e nenhuma quando não há o que fazer.
  ///
  /// Duas ausências são deliberadas:
  ///
  /// - **Aberta antes do dia do fechamento não mostra botão nenhum.** Fechar
  ///   adiantado é legítimo e a API não trava a data, mas oferecer o botão todo
  ///   dia faria o fechamento parecer parte do lançamento, e o lojista fecharia
  ///   um mês que ainda vai receber compras. Fatura vazia também não: não há o
  ///   que congelar.
  /// - **Reabrir só aparece sem pagamento registrado.** A API recusa o resto —
  ///   apagar a despesa faria o dinheiro que saiu da conta desaparecer do caixa
  ///   —, e um botão que sempre falha é pior que nenhum. O caminho é apagar o
  ///   pagamento pelo card dele, que é o que a linha de aviso diz.
  Widget _acoes(Fatura fatura, TotaisFatura totais) {
    final temPagamento = totais.pago > 0.005;

    final botoes = <Widget>[
      if (fatura.aberta && !_faturaVazia && fatura.podeFechar)
        FilledButton.icon(
          onPressed: _emAcao ? null : _fechar,
          icon: const Icon(Icons.lock_outline, size: 18),
          label: const Text('Fechar fatura'),
        ),
      if (fatura.status == StatusFatura.fechada && totais.saldo > 0.005)
        FilledButton.icon(
          onPressed: _pagar,
          icon: const Icon(Icons.payments_outlined, size: 18),
          label: const Text('Pagar'),
        ),
      if (!fatura.aberta && !temPagamento)
        TextButton.icon(
          onPressed: _emAcao ? null : _reabrir,
          icon: const Icon(Icons.lock_open, size: 18),
          label: const Text('Reabrir'),
        ),
    ];

    final aviso = !fatura.aberta && temPagamento;

    if (botoes.isEmpty && !aviso) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (botoes.isNotEmpty)
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: botoes,
            ),
          if (aviso) ...[
            if (botoes.isNotEmpty) const SizedBox(height: AppSpacing.sm),
            Text(
              'Para reabrir esta fatura, apague primeiro o pagamento dela na '
              'lista abaixo.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------------------- rodapé

  /// Compras, créditos e o valor que sai dos dois.
  ///
  /// Pagamento fica fora do valor de propósito: ele abate o saldo, não a fatura.
  /// Somá-lo junto a zeraria no instante do pagamento, e ninguém saberia mais de
  /// quanto ela era.
  Widget _rodape() {
    final theme = Theme.of(context);
    final cores = context.appColors;
    final totais = _totais;

    return Material(
      elevation: AppElevation.overlay,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              _bloco(theme, 'Compras', totais.compras, cores.error),
              _bloco(theme, 'Créditos', totais.creditos, cores.success),
              if (totais.pago > 0.005)
                _bloco(theme, 'Pago', totais.pago, cores.info),
              _bloco(
                theme,
                totais.pago > 0.005 ? 'Falta' : 'Fatura',
                totais.pago > 0.005 ? totais.saldo : totais.valor,
                theme.colorScheme.onSurface,
                destaque: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bloco(
    ThemeData theme,
    String rotulo,
    double valor,
    Color cor, {
    bool destaque = false,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rotulo,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          // Em telas estreitas quatro valores monetários não cabem lado a lado;
          // encolher a fonte preserva o número inteiro em vez de cortá-lo.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              CurrencyFormatter.format(valor),
              style: (destaque
                      ? theme.textTheme.titleSmall
                      : theme.textTheme.bodyMedium)
                  ?.copyWith(color: cor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
