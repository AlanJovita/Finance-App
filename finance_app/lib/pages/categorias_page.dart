import 'package:flutter/material.dart';

import '../models/categoria.dart';
import '../models/resumo_fluxo.dart';
import '../models/subcategoria.dart';
import '../models/totais_categoria.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';
import '../utils/categoria_visuais.dart';
import '../utils/navegacao.dart';
import '../utils/responsive_utils.dart';
import '../widgets/app_drawer.dart';
import '../widgets/categoria_form_dialog.dart';
import '../widgets/moldura_menu.dart';
import '../widgets/navegador_mes.dart';
import '../widgets/shimmer_widgets.dart';
import '../widgets/subcategoria_form_dialog.dart';
import '../widgets/tabela_categorias.dart';

/// Categorias e subcategorias da loja, com o total de cada uma no mês.
///
/// É a tela de **gestão** do cadastro — até ela existir, categoria só se criava
/// de dentro do modal de lançamento, e editar ou excluir não existia em lugar
/// nenhum. Seis coisas aqui não se leem no código.
///
/// **O total inclui as compras do cartão de crédito**, pela categoria de cada
/// compra e atribuídas ao vencimento da fatura. É de propósito: é o mesmo número
/// do gráfico "Despesas por categoria" do Resumo, e a mesma categoria no mesmo
/// mês não pode mostrar um valor numa tela e outro na outra. **A consequência
/// aceita** é que a lista de lançamentos que o "Ver lançamentos" abre soma
/// *menos* que o total da linha quando há cartão naquela categoria — a lista só
/// tem `finance_fluxo_caixa`, e o gasto do cartão vive em
/// `finance_cartao_movimento`.
///
/// **Duas colunas são decididas por largura, nunca por orientação**
/// ([AppLayout.duasTabelasCategorias]). O pedido original era "em formato
/// horizontal, duas colunas", mas no navegador "orientação" não diz nada sobre
/// quanto espaço existe — uma janela estreitada continua paisagem. É a mesma
/// escolha da grade do Resumo, e o limiar é o mesmo (720 da largura **útil**,
/// descontado o menu lateral fixo).
///
/// **O toque na linha faz coisas diferentes nas duas larguras, e isso é a
/// decisão central.** Em duas colunas ele **seleciona** a categoria e a coluna
/// da direita acompanha; numa coluna ele **navega** para Receitas/Despesas. Não
/// é inconsistência: numa coluna não existe painel à direita para receber a
/// seleção, então não há duas coisas que o toque possa significar. O caminho que
/// falta em cada largura entra no menu de três pontos — "Ver lançamentos" em
/// duas colunas, "Subcategorias" numa.
///
/// **Excluir é cascata, e o aviso diz isso.** A API zera `id_categoria` e
/// `id_subcategoria` em `finance_fluxo_caixa` **e** em
/// `finance_cartao_movimento`, e apaga as subcategorias filhas — ver
/// `FinanceBLL.RemoveCategoria`. Os lançamentos **não** são apagados: eles
/// passam a ser "sem categoria". O modal precisa dizer as duas coisas, porque as
/// duas surpreendem: quem lê "excluir categoria" teme perder lançamento, e quem
/// não lê não espera perder as subcategorias.
///
/// **Trocar de aba não recarrega nada.** Receita e despesa saem da mesma
/// resposta (`tipo_fluxo` separa as duas), então a aba é um filtro em memória. A
/// única carga por aba é o atalho de meses do navegador, que a API devolve por
/// natureza — e essa fica em cache por `tipo`.
///
/// **A seleção é por aba.** Trocar para Despesas com "Mercado" (receita)
/// selecionada mostraria as subcategorias de uma categoria que não está na lista
/// à vista; a troca de aba limpa a seleção e ela se refaz na primeira linha.
class CategoriasPage extends StatefulWidget {
  const CategoriasPage({super.key});

  @override
  State<CategoriasPage> createState() => _CategoriasPageState();
}

class _CategoriasPageState extends State<CategoriasPage>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final LoggerService _logger = LoggerService();

  late final TabController _abas;
  late DateTime _mes;

  List<Categoria> _categorias = const [];
  List<Subcategoria> _subcategorias = const [];
  TotaisCategorias _totais = const TotaisCategorias.vazio();

  /// Atalho de meses do navegador, por natureza. A API devolve por `tipo`, e
  /// guardar por aba evita refazer a consulta a cada ida e volta entre as duas.
  final Map<int, List<ResumoMes>> _mesesPorTipo = {};

  /// A categoria em foco, cujas subcategorias a coluna da direita mostra. Nula
  /// em uma coluna, onde não há painel para receber seleção.
  int? _selecionada;

  bool _carregando = true;
  Object? _erro;

  /// Cada carga leva um número e só a mais recente pode escrever no estado.
  /// Sem isso, trocar de mês rápido deixa a resposta antiga chegar depois e
  /// repor os totais do mês anterior — o mesmo cuidado da `ContasPage`.
  int _geracao = 0;

  /// 1 receita, 2 despesa — a aba em foco.
  int get _tipo => _abas.index == 0 ? 1 : 2;

  @override
  void initState() {
    super.initState();

    final agora = DateTime.now();
    _mes = DateTime(agora.year, agora.month);

    // Despesa primeiro seria o palpite mais provável do uso, mas a ordem
    // receita→despesa é a do menu lateral e a do resto do app; divergir aqui
    // faria a primeira aba não ser a mesma coisa que o primeiro item do menu.
    _abas = TabController(length: 2, vsync: this)
      ..addListener(_aoTrocarAba);

    _carregar();
  }

  @override
  void dispose() {
    _abas.removeListener(_aoTrocarAba);
    _abas.dispose();
    super.dispose();
  }

  void _aoTrocarAba() {
    // O listener dispara duas vezes por gesto (no início e no fim da animação);
    // `indexIsChanging` filtra a primeira.
    if (_abas.indexIsChanging) return;

    setState(() => _selecionada = null);
    _carregarMeses();
  }

  // ---------------------------------------------------------------- dados

  Future<void> _carregar() async {
    final geracao = ++_geracao;

    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      // Em paralelo: o cadastro não depende dos totais, e a tela só desenha com
      // os dois. Em série, a abertura seria a soma das três.
      final resultados = await Future.wait([
        _apiService.listCategorias(),
        _apiService.listSubcategorias(),
        _apiService.getTotaisCategorias(mes: _mes),
      ]);

      if (!mounted || geracao != _geracao) return;

      setState(() {
        _categorias = resultados[0] as List<Categoria>;
        _subcategorias = resultados[1] as List<Subcategoria>;
        _totais = resultados[2] as TotaisCategorias;
        _carregando = false;
      });

      _carregarMeses();
    } catch (e, s) {
      await _logger.logError('CategoriasPage._carregar', e, stackTrace: s);
      if (!mounted || geracao != _geracao) return;
      setState(() {
        _erro = e;
        _carregando = false;
      });
    }
  }

  /// Só os totais — é o que muda ao trocar de mês. O cadastro é o mesmo.
  Future<void> _carregarTotais() async {
    final geracao = ++_geracao;

    try {
      final totais = await _apiService.getTotaisCategorias(mes: _mes);

      if (!mounted || geracao != _geracao) return;
      setState(() => _totais = totais);
    } catch (e, s) {
      await _logger.logError('CategoriasPage._carregarTotais', e, stackTrace: s);
      if (!mounted || geracao != _geracao) return;
      setState(() => _erro = e);
    }
  }

  /// O atalho de meses é **acessório**: sem ele o navegador perde a lista de
  /// meses com movimento, não as setas. Falha só vai para o log, como na
  /// `FluxosPage`.
  Future<void> _carregarMeses() async {
    final tipo = _tipo;
    if (_mesesPorTipo.containsKey(tipo)) return;

    try {
      final meses = await _apiService.getResumoMensal(tipo: tipo);
      if (!mounted) return;
      setState(() => _mesesPorTipo[tipo] = meses);
    } catch (e, s) {
      await _logger.logError('CategoriasPage._carregarMeses', e, stackTrace: s);
    }
  }

  void _irParaMes(DateTime mes) {
    setState(() => _mes = DateTime(mes.year, mes.month));
    _carregarTotais();
  }

  // ---------------------------------------------------------------- derivados

  /// As categorias da aba em foco, na ordem do maior total para o menor.
  ///
  /// A ordem é o total e não o cadastro: a pergunta da tela é "em que o dinheiro
  /// foi", e ordem alfabética obrigaria a varrer a coluna inteira para achar a
  /// maior. Categoria sem movimento no mês vai para o fim, em ordem de cadastro
  /// — ela continua na lista porque é aqui que se edita e exclui, e esconder o
  /// que não teve movimento tiraria da tela justamente a categoria que o lojista
  /// quer apagar.
  List<Categoria> get _categoriasDaAba {
    final totais = _totais.porCategoria(_tipo);

    final lista = _categorias
        .where((c) => c.tipoFluxo == _tipo && c.id != null)
        .toList();

    lista.sort((a, b) {
      final valorA = totais[a.id!]?.valor ?? 0;
      final valorB = totais[b.id!]?.valor ?? 0;
      if (valorA != valorB) return valorB.compareTo(valorA);
      return (a.id ?? 0).compareTo(b.id ?? 0);
    });

    return lista;
  }

  /// A categoria em foco, ou a primeira da aba.
  ///
  /// Cair na primeira é o que mantém a coluna da direita com assunto na abertura
  /// — um painel vazio ao lado de uma lista cheia pareceria quebrado. Nula só
  /// quando a aba não tem categoria nenhuma.
  Categoria? get _categoriaEmFoco {
    final lista = _categoriasDaAba;
    if (lista.isEmpty) return null;

    for (final c in lista) {
      if (c.id == _selecionada) return c;
    }
    return lista.first;
  }

  List<Subcategoria> _subcategoriasDe(int idCategoria) {
    final totais = _totais.porSubcategoria;

    final lista = _subcategorias
        .where((s) => s.idCategoria == idCategoria && s.id != null)
        .toList();

    lista.sort((a, b) {
      final valorA = totais[a.id!]?.valor ?? 0;
      final valorB = totais[b.id!]?.valor ?? 0;
      if (valorA != valorB) return valorB.compareTo(valorA);
      return (a.id ?? 0).compareTo(b.id ?? 0);
    });

    return lista;
  }

  List<LinhaCategoria> get _linhasCategorias {
    final totais = _totais.porCategoria(_tipo);

    return [
      for (final c in _categoriasDaAba)
        LinhaCategoria(
          id: c.id!,
          descricao: c.descricao,
          icone: c.icone,
          cor: CategoriaVisuais.cor(c.cor),
          total: totais[c.id!]?.valor ?? 0,
          quantidade: totais[c.id!]?.quantidade ?? 0,
        ),
    ];
  }

  List<LinhaCategoria> _linhasSubcategorias(Categoria pai) {
    final totais = _totais.porSubcategoria;
    // A filha herda a cor do pai a 70% — a mesma regra do seletor e do
    // `IconeCategoria`, e é por isso que a subcategoria não tem cor própria.
    final cor = CategoriaVisuais.cor(pai.cor).withValues(
      alpha: CategoriaVisuais.opacidadeSubcategoria,
    );

    return [
      for (final s in _subcategoriasDe(pai.id!))
        LinhaCategoria(
          id: s.id!,
          descricao: s.descricao,
          icone: s.icone,
          cor: cor,
          total: totais[s.id!]?.valor ?? 0,
          quantidade: totais[s.id!]?.quantidade ?? 0,
        ),
    ];
  }

  // ---------------------------------------------------------------- ações

  Future<void> _novaCategoria() async {
    final criou = await showDialog(
      context: context,
      builder: (_) => CategoriaFormDialog(tipoFluxo: _tipo),
    );

    // O modal devolve o id criado (ou 0) — qualquer valor não nulo é criação.
    if (criou != null) _carregar();
  }

  Future<void> _editarCategoria(int id) async {
    final categoria = _categorias.firstWhere(
      (c) => c.id == id,
      orElse: () => throw StateError('Categoria $id saiu da lista'),
    );

    final salvou = await showDialog<bool>(
      context: context,
      builder: (_) => CategoriaFormDialog(
        tipoFluxo: categoria.tipoFluxo,
        categoria: categoria,
      ),
    );

    if (salvou == true) _carregar();
  }

  Future<void> _novaSubcategoria(Categoria pai) async {
    final criou = await showDialog(
      context: context,
      builder: (_) => SubcategoriaFormDialog(
        idCategoria: pai.id!,
        nomeCategoria: pai.descricao,
        corCategoria: CategoriaVisuais.cor(pai.cor),
      ),
    );

    if (criou != null) _carregar();
  }

  Future<void> _editarSubcategoria(int id, Categoria pai) async {
    final subcategoria = _subcategorias.firstWhere(
      (s) => s.id == id,
      orElse: () => throw StateError('Subcategoria $id saiu da lista'),
    );

    final salvou = await showDialog<bool>(
      context: context,
      builder: (_) => SubcategoriaFormDialog(
        idCategoria: pai.id!,
        nomeCategoria: pai.descricao,
        corCategoria: CategoriaVisuais.cor(pai.cor),
        subcategoria: subcategoria,
      ),
    );

    if (salvou == true) _carregar();
  }

  /// Confirma e exclui uma categoria.
  ///
  /// O modal diz **as duas** consequências, porque as duas surpreendem: que os
  /// lançamentos **não** são apagados (passam a "sem categoria") e que as
  /// subcategorias **são**. Sem a primeira frase, quem lê "excluir categoria"
  /// desiste com medo de perder histórico; sem a segunda, perde as filhas sem
  /// saber.
  Future<void> _excluirCategoria(Categoria categoria) async {
    final filhas = _subcategoriasDe(categoria.id!).length;
    final total = _totais.porCategoria(_tipo)[categoria.id!];
    final movimentos = total?.quantidade ?? 0;

    final confirmou = await _confirmar(
      titulo: 'Excluir "${categoria.descricao}"?',
      linhas: [
        if (movimentos > 0)
          movimentos == 1
              ? '1 movimentação deste mês fica sem categoria. '
                  'Nenhum lançamento é apagado.'
              : '$movimentos movimentações deste mês ficam sem categoria. '
                  'Nenhum lançamento é apagado.'
        else
          'Nenhum lançamento é apagado — os que usam esta categoria ficam '
              'sem categoria.',
        if (filhas > 0)
          filhas == 1
              ? '1 subcategoria é excluída junto.'
              : '$filhas subcategorias são excluídas junto.',
        'Não há como desfazer.',
      ],
    );

    if (confirmou != true) return;

    try {
      await _apiService.deleteCategoria(categoria.id!);
      if (!mounted) return;

      // A seleção pode ter sido justamente a apagada.
      setState(() => _selecionada = null);
      _aviso('Categoria excluída.', erro: false);
      _carregar();
    } catch (e, s) {
      await _logger.logError(
        'CategoriasPage._excluirCategoria',
        e,
        stackTrace: s,
        additionalInfo: {'id': categoria.id},
      );
      if (mounted) _aviso('Não foi possível excluir: $e');
    }
  }

  Future<void> _excluirSubcategoria(LinhaCategoria linha) async {
    final confirmou = await _confirmar(
      titulo: 'Excluir "${linha.descricao}"?',
      linhas: [
        linha.quantidade > 0
            ? '${linha.quantidade} '
                '${linha.quantidade == 1 ? 'movimentação' : 'movimentações'} '
                'deste mês fica${linha.quantidade == 1 ? '' : 'm'} sem '
                'subcategoria. A categoria é mantida.'
            : 'Nenhum lançamento é apagado — os que usam esta subcategoria '
                'ficam sem subcategoria.',
        'Não há como desfazer.',
      ],
    );

    if (confirmou != true) return;

    try {
      await _apiService.deleteSubcategoria(linha.id);
      if (!mounted) return;

      _aviso('Subcategoria excluída.', erro: false);
      _carregar();
    } catch (e, s) {
      await _logger.logError(
        'CategoriasPage._excluirSubcategoria',
        e,
        stackTrace: s,
        additionalInfo: {'id': linha.id},
      );
      if (mounted) _aviso('Não foi possível excluir: $e');
    }
  }

  Future<bool?> _confirmar({
    required String titulo,
    required List<String> linhas,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);

        return AlertDialog(
          title: Text(titulo),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final linha in linhas)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(linha, style: theme.textTheme.bodyMedium),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            // Destrutivo em vermelho e **não** é o botão padrão: o foco inicial
            // fica no Cancelar.
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: context.appColors.error,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );
  }

  void _aviso(String mensagem, {bool erro = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor:
            erro ? context.appColors.error : context.appColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Abre Receitas/Despesas já filtrada pelo mês e pela categoria.
  ///
  /// O destino é irmão de topo, então a pilha fica `[raiz, destino]` e não há
  /// seta de voltar para cá — é o mesmo comportamento dos atalhos do Resumo
  /// (ver `irParaDestino`). O filtro vai como argumento da rota.
  void _verLancamentos(int idCategoria) {
    irParaDestino(
      context,
      _tipo == 1 ? '/receitas' : '/despesas',
      argumentos: FiltroInicialFluxos(mes: _mes, idCategoria: idCategoria),
    );
  }

  /// As subcategorias numa folha, para quando não há coluna à direita.
  ///
  /// Folha e não rota empilhada: a lista é curta, o contexto é a categoria que
  /// ficou atrás dela, e uma tela própria exigiria uma rota nova só para isto.
  /// `isScrollControlled` deixa a folha crescer com o conteúdo em vez de cortar
  /// a lista em metade da tela.
  void _abrirSubcategorias(Categoria pai) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          // O respiro do teclado/gesto do sistema: sem ele a última linha fica
          // debaixo da barra de navegação do Android.
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: _tabelaSubcategorias(pai, emFolha: true),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return MolduraMenu(
      builder: (context, menu) => _buildScaffold(context, menu),
    );
  }

  Widget _buildScaffold(BuildContext context, MenuLateral menu) {
    final duasColunas = AppLayout.duasTabelasCategorias(
      AppLayout.larguraUtil(MediaQuery.sizeOf(context).width, menu),
    );

    return Scaffold(
      appBar: AppBar(
        // Sem seta de voltar: é destino de topo, como os outros seis — com a
        // barra lateral à vista a seta não teria para onde levar.
        automaticallyImplyLeading: menu.ehGaveta,
        title: const Text('Categorias'),
        bottom: TabBar(
          controller: _abas,
          tabs: const [
            Tab(icon: Icon(Icons.arrow_upward), text: 'Receitas'),
            Tab(icon: Icon(Icons.arrow_downward), text: 'Despesas'),
          ],
        ),
      ),
      drawer: menu.ehGaveta ? const AppDrawer() : null,
      body: _carregando
          // O mesmo esqueleto da lista de Receitas/Despesas: linhas com
          // círculo à esquerda e dois blocos de texto, que é a forma da tabela
          // daqui.
          ? ShimmerWidgets.listFluxosShimmer(context)
          : _erro != null && _categorias.isEmpty
          ? _buildErro()
          : RefreshIndicator(
              onRefresh: _carregar,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: context.responsivePadding(),
                child: _buildConteudo(duasColunas),
              ),
            ),
    );
  }

  Widget _buildConteudo(bool duasColunas) {
    final emFoco = _categoriaEmFoco;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: NavegadorMes(
            mes: _mes,
            meses: _mesesPorTipo[_tipo] ?? const [],
            onMudarMes: _irParaMes,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (duasColunas && emFoco != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _tabelaCategorias(duasColunas: true)),
              const SizedBox(width: AppSpacing.lg),
              Expanded(child: _tabelaSubcategorias(emFoco)),
            ],
          )
        else
          _tabelaCategorias(duasColunas: false),
      ],
    );
  }

  Widget _tabelaCategorias({required bool duasColunas}) {
    final emFoco = _categoriaEmFoco;

    return TabelaCategorias(
      titulo: _tipo == 1 ? 'Categorias de receita' : 'Categorias de despesa',
      linhas: _linhasCategorias,
      // Em duas colunas o toque já seleciona, então o menu oferece o caminho
      // que falta (os lançamentos); numa coluna é o contrário.
      acoes: [
        AcaoLinha.editar,
        if (duasColunas)
          AcaoLinha.verLancamentos
        else
          AcaoLinha.subcategorias,
        AcaoLinha.excluir,
      ],
      selecionada: duasColunas ? emFoco?.id : null,
      onToqueNaLinha: (linha) {
        if (duasColunas) {
          setState(() => _selecionada = linha.id);
        } else {
          _verLancamentos(linha.id);
        }
      },
      onAcao: (acao, linha) {
        final categoria = _categorias.firstWhere(
          (c) => c.id == linha.id,
          orElse: () => throw StateError('Categoria ${linha.id} saiu da lista'),
        );

        switch (acao) {
          case AcaoLinha.editar:
            _editarCategoria(linha.id);
          case AcaoLinha.excluir:
            _excluirCategoria(categoria);
          case AcaoLinha.verLancamentos:
            _verLancamentos(linha.id);
          case AcaoLinha.subcategorias:
            _abrirSubcategorias(categoria);
        }
      },
      rotuloNovo: 'Nova categoria',
      onNovo: _novaCategoria,
      vazio: _tipo == 1
          ? 'Nenhuma categoria de receita cadastrada'
          : 'Nenhuma categoria de despesa cadastrada',
    );
  }

  Widget _tabelaSubcategorias(Categoria pai, {bool emFolha = false}) {
    return TabelaCategorias(
      titulo: 'Subcategorias',
      subtitulo: 'Em ${pai.descricao}',
      linhas: _linhasSubcategorias(pai),
      // Subcategoria não tem lançamento próprio a listar nem filha a abrir: o
      // filtro da tela de Receitas/Despesas é por categoria.
      acoes: const [AcaoLinha.editar, AcaoLinha.excluir],
      onToqueNaLinha: (linha) => _editarSubcategoria(linha.id, pai),
      onAcao: (acao, linha) {
        switch (acao) {
          case AcaoLinha.editar:
            _editarSubcategoria(linha.id, pai);
          case AcaoLinha.excluir:
            _excluirSubcategoria(linha);
          case AcaoLinha.verLancamentos:
          case AcaoLinha.subcategorias:
            break;
        }
      },
      rotuloNovo: 'Nova subcategoria',
      onNovo: () {
        // Na folha, fecha antes de abrir o modal: dois overlays empilhados
        // deixam o de baixo visível por trás e o "Cancelar" volta para a folha
        // em vez de para a tela.
        if (emFolha) Navigator.of(context).pop();
        _novaSubcategoria(pai);
      },
      vazio: 'Nenhuma subcategoria em ${pai.descricao}',
    );
  }

  Widget _buildErro() {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Não foi possível carregar as categorias.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: _carregar,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}
