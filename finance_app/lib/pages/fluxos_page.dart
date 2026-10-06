import 'package:flutter/material.dart';

import '../models/categoria.dart';
import '../models/fluxo_caixa.dart';
import '../models/resumo_fluxo.dart';
import '../models/subcategoria.dart';
import '../services/api_service.dart';
import '../services/global_state.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';
import '../utils/categoria_visuais.dart';
import '../utils/currency_formatter.dart';
import '../utils/responsive_utils.dart';
import '../utils/situacao_fluxo.dart';
import '../widgets/app_drawer.dart';
import '../widgets/card_fluxo.dart';
import '../widgets/detalhes_mes_dialog.dart';
import '../widgets/fluxo_form_dialog.dart';
import '../widgets/pagamento_dialog.dart';
import '../widgets/shimmer_widgets.dart';

/// Receitas e despesas são a mesma tela: mudam o filtro da API, o rótulo, o
/// ícone e a cor. Antes eram dois arquivos de ~530 linhas quase idênticos.
enum TipoFluxo {
  receita(
    titulo: 'Receitas',
    singular: 'receita',
    codigo: 1,
    tipoDialogo: 'receita',
    icone: Icons.attach_money,
    rotuloAcao: 'Receber',
  ),
  despesa(
    titulo: 'Despesas',
    singular: 'despesa',
    codigo: 2,
    tipoDialogo: 'despesa',
    icone: Icons.remove_circle_outline,
    rotuloAcao: 'Pagar',
  );

  const TipoFluxo({
    required this.titulo,
    required this.singular,
    required this.codigo,
    required this.tipoDialogo,
    required this.icone,
    required this.rotuloAcao,
  });

  /// Título da tela, no plural.
  final String titulo;

  /// Nome no singular, para textos como "Nova receita".
  final String singular;

  /// Valor de `tipo_fluxo` na API: 1 entrada, 2 saída.
  final int codigo;

  /// Valor esperado por [FluxoFormDialog].
  final String tipoDialogo;

  final IconData icone;

  /// Verbo do botão de baixa no card: receita se recebe, despesa se paga.
  final String rotuloAcao;

  bool get ehReceita => this == TipoFluxo.receita;

  /// Entrada de valor é sucesso; saída é erro.
  Color cor(AppColors cores) =>
      this == TipoFluxo.receita ? cores.success : cores.error;
}

class FluxosPage extends StatefulWidget {
  final TipoFluxo tipo;

  const FluxosPage({super.key, required this.tipo});

  @override
  State<FluxosPage> createState() => _FluxosPageState();
}

class _FluxosPageState extends State<FluxosPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _buscaController = TextEditingController();

  /// Mês em foco, sempre no dia 1 — a tela mostra um mês por vez.
  late DateTime _mes;

  String _busca = '';

  /// 0 é "todas as categorias". Reaproveita a convenção do resto do app, onde
  /// 0 já significa ausência de categoria.
  int _categoriaFiltro = 0;

  /// Totais por mês (`/fluxo/resumo/mensal`): some uns bytes e diz em quais
  /// meses há lançamento, sem baixar nenhum deles. Alimenta o atalho de meses
  /// e revela se existe algo no grupo "sem data".
  List<ResumoMes> _meses = [];

  /// Lançamentos já carregados, por mês. Um mês só entra aqui quando é aberto —
  /// é o que evita baixar o histórico inteiro da loja para montar a tela.
  final Map<String, List<FluxoCaixa>> _itensPorMes = {};
  final Set<String> _carregando = {};
  final Map<String, Object> _erroPorMes = {};

  /// Lançamentos sem vencimento. Vêm de uma consulta sem recorte de data, que é
  /// cara, então só é disparada quando o resumo mensal confirma que existem —
  /// e o resultado vale para a sessão inteira da tela.
  List<FluxoCaixa>? _semData;

  Map<int, Categoria> _categorias = {};
  Map<int, Subcategoria> _subcategorias = {};

  TipoFluxo get _tipo => widget.tipo;

  static const List<String> _nomesMeses = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _mes = DateTime(agora.year, agora.month);

    _carregarResumoMeses();
    _carregarCategorias();
    _carregarMes(_chave(_mes));
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  static String _chave(DateTime mes) => '${mes.year}-${mes.month}';

  String _rotuloMes(DateTime mes) =>
      '${_nomesMeses[mes.month - 1]} ${mes.year}';

  // ---------------------------------------------------------------- dados

  Future<void> _carregarResumoMeses() async {
    try {
      final meses = await _apiService.getResumoMensal(tipo: _tipo.codigo);
      if (!mounted) return;
      setState(() => _meses = meses);

      for (final m in meses) {
        if (m.semData && m.quantidade > 0 && _semData == null) {
          _carregarSemData();
          break;
        }
      }
    } catch (e) {
      // O resumo é acessório: sem ele a tela perde o atalho de meses, não a
      // lista. Falhar aqui não pode derrubar o que já está em foco.
      debugPrint('Erro ao carregar o resumo mensal: $e');
    }
  }

  Future<void> _carregarMes(String chave) async {
    if (_carregando.contains(chave)) return;

    setState(() {
      _carregando.add(chave);
      _erroPorMes.remove(chave);
    });

    try {
      final partes = chave.split('-');
      final ano = int.parse(partes[0]);
      final mes = int.parse(partes[1]);

      final pagina = await _apiService.listFluxosPagina(
        tipo: _tipo.codigo,
        de: DateTime(ano, mes, 1),
        // Dia 0 do mês seguinte é o último dia deste — evita a tabela de
        // 28/30/31.
        ate: DateTime(ano, mes + 1, 0),
        porPagina: 500,
      );

      if (!mounted) return;
      setState(() => _itensPorMes[chave] = pagina.itens);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erroPorMes[chave] = e);
    } finally {
      if (mounted) setState(() => _carregando.remove(chave));
    }
  }

  Future<void> _carregarSemData() async {
    try {
      // Sem `de`/`ate` o servidor devolve tudo, inclusive o que tem vencimento;
      // o recorte de quem não tem data é feito aqui.
      final pagina = await _apiService.listFluxosPagina(
        tipo: _tipo.codigo,
        porPagina: 500,
      );

      if (!mounted) return;
      setState(() {
        _semData =
            pagina.itens.where((f) => f.dataVencimento == null).toList();
      });
    } catch (e) {
      debugPrint('Erro ao carregar lançamentos sem data: $e');
    }
  }

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

        // A categoria filtrada pode ter sido excluída noutra aba: sem isso o
        // dropdown ficaria num valor que não existe mais na lista.
        if (_categoriaFiltro != 0 &&
            !_categorias.containsKey(_categoriaFiltro)) {
          _categoriaFiltro = 0;
        }
      });
    } catch (e) {
      debugPrint('Erro ao carregar categorias: $e');
    }
  }

  /// Recarrega o que está na tela depois de criar, editar, excluir ou dar baixa.
  void _recarregar() {
    final chave = _chave(_mes);
    setState(() {
      _itensPorMes.remove(chave);
      _erroPorMes.remove(chave);
      _semData = null;
    });
    _carregarResumoMeses();
    _carregarMes(chave);
  }

  // -------------------------------------------------------------- filtros

  void _irParaMes(DateTime mes) {
    final novo = DateTime(mes.year, mes.month);
    setState(() => _mes = novo);

    final chave = _chave(novo);
    if (!_itensPorMes.containsKey(chave)) _carregarMes(chave);
  }

  /// Categorias que o filtro oferece: só as da natureza desta tela, porque uma
  /// despesa nunca cairia numa categoria de receita.
  List<Categoria> get _categoriasDoTipo {
    final lista =
        _categorias.values
            .where((c) => c.tipoFluxo == _tipo.codigo)
            .toList();
    lista.sort((a, b) => a.descricao.compareTo(b.descricao));
    return lista;
  }

  bool get _temFiltro => _busca.trim().isNotEmpty || _categoriaFiltro != 0;

  List<FluxoCaixa> _filtrar(List<FluxoCaixa> itens) {
    final termo = CategoriaVisuais.semAcento(_busca.trim().toLowerCase());

    return itens.where((f) {
      if (_categoriaFiltro != 0 && (f.idCategoria ?? 0) != _categoriaFiltro) {
        return false;
      }
      if (termo.isEmpty) return true;

      final descricao = CategoriaVisuais.semAcento(
        (f.descricao ?? '').toLowerCase(),
      );
      return descricao.contains(termo);
    }).toList();
  }

  List<FluxoCaixa> get _itensDoMes =>
      _filtrar(_itensPorMes[_chave(_mes)] ?? const []);

  List<FluxoCaixa> get _itensSemData => _filtrar(_semData ?? const []);

  /// O que o rodapé e o modal de detalhes somam: tudo que está listado, na
  /// ordem em que aparece.
  List<FluxoCaixa> get _itensVisiveis => [..._itensDoMes, ..._itensSemData];

  // --------------------------------------------------------------- ações

  void _showFormDialog({FluxoCaixa? fluxo}) {
    showDialog(
      context: context,
      builder: (context) {
        return FluxoFormDialog(
          tipoFluxo: _tipo.tipoDialogo,
          fluxo: fluxo,
          onSave: () {
            _recarregar();
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  Future<void> _darBaixa(FluxoCaixa fluxo) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder:
          (context) =>
              PagamentoDialog(fluxo: fluxo, ehReceita: _tipo.ehReceita),
    );

    if (confirmou == true) {
      _recarregar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tipo.ehReceita
                  ? 'Recebimento confirmado.'
                  : 'Pagamento confirmado.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _estornar(FluxoCaixa fluxo) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Estornar baixa'),
            content: Text(
              'Desfazer a confirmação de "${fluxo.descricao}"?\n\n'
              'O valor atual é mantido: encargos e descontos aplicados na '
              'baixa não são revertidos.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Estornar'),
              ),
            ],
          ),
    );

    if (confirmou != true) return;

    try {
      await _apiService.updateFluxo(
        fluxo.copyWith(
          idLoja: fluxo.idLoja ?? GlobalState().firstIdLoja,
          confirmado: false,
          tipoFluxo: fluxo.tipoFluxo ?? '${_tipo.codigo}',
        ),
      );
      _recarregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao estornar: $e')));
    }
  }

  Future<void> _confirmarExclusao(FluxoCaixa fluxo) async {
    final cores = context.appColors;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmar exclusão'),
            content: Text('Deseja realmente excluir "${fluxo.descricao}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: cores.error),
                child: const Text('Excluir'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await _apiService.deleteFluxo(fluxo.id!, fluxo.idRef ?? 0);
      _recarregar();
    }
  }

  void _abrirDetalhes() {
    showDialog(
      context: context,
      builder:
          (context) => DetalhesMesDialog(
            mesReferencia: _rotuloMes(_mes),
            itens: _itensVisiveis,
            ehReceita: _tipo.ehReceita,
            filtroAtivo: _temFiltro,
          ),
    );
  }

  // ----------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tipo.titulo),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights),
            onPressed: _abrirDetalhes,
            tooltip: 'Detalhes do mês',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showFormDialog(),
            tooltip: 'Nova ${_tipo.singular}',
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          _buildBarraFiltros(),
          Expanded(child: _buildLista()),
          _buildResumoRodape(),
        ],
      ),
    );
  }

  // ------------------------------------------------------- barra de filtros

  Widget _buildBarraFiltros() {
    final theme = Theme.of(context);
    // Abaixo disso o seletor de mês, a busca e o filtro não cabem lado a lado
    // sem espremer a busca a ponto de não caber uma palavra.
    final estreito = MediaQuery.sizeOf(context).width < 720;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child:
            estreito
                ? Column(
                  children: [
                    _buildNavegadorMes(),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(child: _buildBusca()),
                        const SizedBox(width: AppSpacing.sm),
                        _buildFiltroCategoria(apenasIcone: true),
                      ],
                    ),
                  ],
                )
                : Row(
                  children: [
                    _buildNavegadorMes(),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: _buildBusca()),
                    const SizedBox(width: AppSpacing.md),
                    _buildFiltroCategoria(apenasIcone: false),
                  ],
                ),
      ),
    );
  }

  Widget _buildNavegadorMes() {
    final theme = Theme.of(context);
    final agora = DateTime.now();
    final noMesAtual = _mes.year == agora.year && _mes.month == agora.month;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Mês anterior',
          visualDensity: VisualDensity.compact,
          onPressed: () => _irParaMes(DateTime(_mes.year, _mes.month - 1)),
        ),
        // Largura fixa: sem ela o botão seguinte dança de lugar conforme o
        // nome do mês encolhe ou cresce.
        SizedBox(
          width: 150,
          child: _buildAtalhoMeses(theme, noMesAtual),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Próximo mês',
          visualDensity: VisualDensity.compact,
          onPressed: () => _irParaMes(DateTime(_mes.year, _mes.month + 1)),
        ),
      ],
    );
  }

  /// O rótulo do mês é também um menu: lista os meses em que a loja tem
  /// lançamento, para não obrigar a clicar na seta doze vezes até achar.
  Widget _buildAtalhoMeses(ThemeData theme, bool noMesAtual) {
    final comLancamento = _meses.where((m) => !m.semData).toList();

    return PopupMenuButton<String>(
      tooltip: 'Escolher mês',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      onSelected: (chave) {
        final partes = chave.split('-');
        _irParaMes(DateTime(int.parse(partes[0]), int.parse(partes[1])));
      },
      itemBuilder: (context) {
        final agora = DateTime.now();
        final itens = <PopupMenuEntry<String>>[
          if (!noMesAtual)
            PopupMenuItem(
              value: _chave(DateTime(agora.year, agora.month)),
              child: const Row(
                children: [
                  Icon(Icons.today, size: 16),
                  SizedBox(width: AppSpacing.sm),
                  Text('Mês atual'),
                ],
              ),
            ),
          if (!noMesAtual && comLancamento.isNotEmpty)
            const PopupMenuDivider(),
          for (final m in comLancamento)
            PopupMenuItem(
              value: m.chave,
              child: Row(
                children: [
                  Expanded(
                    child: Text(_rotuloMes(DateTime(m.ano!, m.mes!))),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    '${m.quantidade}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ];

        // Loja sem nenhum lançamento, parada no mês atual: as duas listas acima
        // ficam vazias e o `showMenu` do Material quebra num assert se abrir
        // sem item nenhum.
        if (itens.isEmpty) {
          itens.add(
            PopupMenuItem(
              enabled: false,
              child: Text(
                'Nenhum mês com lançamento',
                style: theme.textTheme.bodySmall,
              ),
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
                _rotuloMes(_mes),
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

  Widget _buildBusca() {
    return TextField(
      controller: _buscaController,
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Buscar por descrição',
        prefixIcon: const Icon(Icons.search, size: 18),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
        suffixIcon:
            _busca.isEmpty
                ? null
                : IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Limpar busca',
                  onPressed: () {
                    _buscaController.clear();
                    setState(() => _busca = '');
                  },
                ),
      ),
      // Filtro local sobre a lista já em memória: não há requisição por tecla,
      // então não precisa de debounce.
      onChanged: (v) => setState(() => _busca = v),
    );
  }

  Widget _buildFiltroCategoria({required bool apenasIcone}) {
    final theme = Theme.of(context);
    final cores = context.appColors;
    final ativa = _categorias[_categoriaFiltro];

    final itens = <PopupMenuEntry<int>>[
      PopupMenuItem(
        value: 0,
        child: Row(
          children: [
            Icon(
              Icons.clear_all,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            const Text('Todas as categorias'),
          ],
        ),
      ),
      if (_categoriasDoTipo.isNotEmpty) const PopupMenuDivider(),
      for (final c in _categoriasDoTipo)
        PopupMenuItem(
          value: c.id!,
          child: Row(
            children: [
              Icon(
                CategoriaVisuais.icone(c.icone),
                size: 16,
                color: CategoriaVisuais.cor(c.cor),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(c.descricao, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
    ];

    return PopupMenuButton<int>(
      tooltip: 'Filtrar por categoria',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      onSelected: (id) => setState(() => _categoriaFiltro = id),
      itemBuilder: (context) => itens,
      child: Container(
        height: 40,
        width: apenasIcone ? 40 : 200,
        padding: EdgeInsets.symmetric(
          horizontal: apenasIcone ? 0 : AppSpacing.md,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: ativa == null ? theme.dividerColor : cores.info,
          ),
        ),
        child:
            apenasIcone
                ? Icon(
                  Icons.filter_alt,
                  size: 18,
                  color:
                      ativa == null
                          ? theme.colorScheme.onSurfaceVariant
                          : cores.info,
                )
                : Row(
                  children: [
                    Icon(
                      ativa == null
                          ? Icons.filter_alt_outlined
                          : CategoriaVisuais.icone(ativa.icone),
                      size: 16,
                      color:
                          ativa == null
                              ? theme.colorScheme.onSurfaceVariant
                              : CategoriaVisuais.cor(ativa.cor),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        ativa?.descricao ?? 'Todas as categorias',
                        style: theme.textTheme.bodySmall,
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

  // ---------------------------------------------------------------- lista

  Widget _buildLista() {
    final theme = Theme.of(context);
    final chave = _chave(_mes);

    if (_carregando.contains(chave) && !_itensPorMes.containsKey(chave)) {
      return ShimmerWidgets.listFluxosShimmer(context);
    }

    final erro = _erroPorMes[chave];
    if (erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Erro ao carregar: $erro', textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => _carregarMes(chave),
                child: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
      );
    }

    final doMes = _itensDoMes;
    final semData = _itensSemData;

    if (doMes.isEmpty && semData.isEmpty) {
      final vazioPorFiltro = _temFiltro;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                vazioPorFiltro ? Icons.search_off : Icons.event_available,
                size: 36,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                vazioPorFiltro
                    ? 'Nenhuma conta corresponde aos filtros.'
                    : 'Nenhuma ${_tipo.singular} em ${_rotuloMes(_mes)}.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Um separador entre os dois blocos, quando há lançamentos sem vencimento.
    final totalLinhas =
        doMes.length + (semData.isEmpty ? 0 : semData.length + 1);

    return RefreshIndicator(
      onRefresh: () async => _recarregar(),
      child: ListView.builder(
        padding: context.responsivePadding(),
        itemCount: totalLinhas,
        itemBuilder: (context, i) {
          if (i < doMes.length) return _buildCard(doMes[i]);
          if (i == doMes.length) return _buildSeparadorSemData(semData.length);
          return _buildCard(semData[i - doMes.length - 1]);
        },
      ),
    );
  }

  Widget _buildSeparadorSemData(int quantidade) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        bottom: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            Icons.event_busy,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Sem data de vencimento ($quantidade)',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Divider(color: theme.dividerColor)),
        ],
      ),
    );
  }

  Widget _buildCard(FluxoCaixa fluxo) {
    return CardFluxo(
      fluxo: fluxo,
      categoria: _categorias[fluxo.idCategoria ?? 0],
      subcategoria: _subcategorias[fluxo.idSubcategoria ?? 0],
      corValor: _tipo.cor(context.appColors),
      rotuloAcao: _tipo.rotuloAcao,
      onEditar: () => _showFormDialog(fluxo: fluxo),
      onBaixar: () => _darBaixa(fluxo),
      onEstornar: () => _estornar(fluxo),
      onExcluir: () => _confirmarExclusao(fluxo),
    );
  }

  // --------------------------------------------------------------- rodapé

  /// Soma o que está listado, filtros inclusos — quem filtra por uma categoria
  /// quer o total daquela categoria, não o do mês inteiro.
  ///
  /// As três situações são exclusivas entre si e cobrem tudo, então elas somam
  /// exatamente o total.
  Widget _buildResumoRodape() {
    final theme = Theme.of(context);
    final cores = context.appColors;

    double confirmadas = 0;
    double pendentes = 0;
    double atrasadas = 0;
    double total = 0;

    final hoje = DateTime.now();
    for (final fluxo in _itensVisiveis) {
      final valor = fluxo.valor ?? 0;
      total += valor;

      final situacao = SituacaoFluxo.de(fluxo, hoje: hoje);
      if (situacao == SituacaoFluxo.confirmado) {
        confirmadas += valor;
      } else if (situacao.emAtraso) {
        atrasadas += valor;
      } else {
        pendentes += valor;
      }
    }

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
              _blocoResumo(theme, 'Confirmadas', confirmadas, cores.success),
              _blocoResumo(theme, 'Pendentes', pendentes, cores.warning),
              _blocoResumo(theme, 'Em atraso', atrasadas, cores.error),
              _blocoResumo(
                theme,
                'Total',
                total,
                _tipo.cor(cores),
                destaque: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blocoResumo(
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
