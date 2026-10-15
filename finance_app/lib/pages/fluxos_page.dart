import 'package:flutter/material.dart';

import '../models/categoria.dart';
import '../models/conta.dart';
import '../models/fluxo_caixa.dart';
import '../models/resumo_fluxo.dart';
import '../models/subcategoria.dart';
import '../services/api_service.dart';
import '../services/contas_cache.dart';
import '../services/logger_service.dart';
import '../services/global_state.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';
import '../utils/categoria_visuais.dart';
import '../utils/currency_formatter.dart';
import '../utils/filtro_fluxos.dart';
import '../utils/meses.dart';
import '../utils/responsive_utils.dart';
import '../utils/situacao_fluxo.dart';
import '../widgets/app_drawer.dart';
import '../widgets/moldura_menu.dart';
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
  final LoggerService _logger = LoggerService();
  final TextEditingController _buscaController = TextEditingController();

  /// Mês em foco, sempre no dia 1 — a tela mostra um mês por vez.
  late DateTime _mes;

  String _busca = '';

  /// Só vale na barra compacta: no celular o campo de busca ocupa a linha
  /// inteira e esconde o seletor de mês enquanto estiver aberto.
  bool _buscaAberta = false;

  /// 0 é "todas as categorias". Reaproveita a convenção do resto do app, onde
  /// 0 já significa ausência de categoria.
  int _categoriaFiltro = 0;

  /// Conta em foco. `null` é "todas" — e 0 **não** é vazio aqui: é o filtro
  /// "sem conta", que é o estado de todo lançamento que nunca escolheu uma (e
  /// de tudo que vem do PDV). Daí o nulo em vez do 0 das outras convenções.
  int? _contaFiltro;

  /// Situação em foco (`null` é "todas"). Calculada no cliente, como o resto
  /// dos filtros desta tela: a lista do mês já está em memória.
  SituacaoFluxo? _situacaoFiltro;

  /// Contas da loja, por id. Serve ao card (que mostra o nome da conta de cada
  /// lançamento) e ao filtro. Vem do [ContasCache] — carregado uma vez por
  /// sessão, então a tela não ganha requisição nenhuma por isso.
  Map<int, Conta> _contas = const {};

  /// Totais por mês (`/fluxo/resumo/mensal`): some uns bytes e diz em quais
  /// meses há lançamento, sem baixar nenhum deles. Alimenta o atalho de meses
  /// e revela se existe algo no grupo "sem data".
  List<ResumoMes> _meses = [];

  /// Lançamentos já carregados, por mês. Um mês só entra aqui quando é aberto —
  /// é o que evita baixar o histórico inteiro da loja para montar a tela.
  final Map<String, List<FluxoCaixa>> _itensPorMes = {};
  final Set<String> _carregando = {};
  final Map<String, Object> _erroPorMes = {};

  /// Número do pedido mais recente de cada mês, para descartar respostas que
  /// chegam fora de ordem. Ver [_carregarMes].
  final Map<String, int> _geracao = {};

  /// Lançamentos sem vencimento. Vêm de uma consulta sem recorte de data, que é
  /// cara, então só é disparada quando o resumo mensal confirma que existem —
  /// e o resultado vale para a sessão inteira da tela.
  List<FluxoCaixa>? _semData;

  Map<int, Categoria> _categorias = {};
  Map<int, Subcategoria> _subcategorias = {};

  TipoFluxo get _tipo => widget.tipo;

  /// Lado do botão quadrado e altura dos controles da barra. O atalho de
  /// detalhes, na AppBar, usa a mesma medida para cair na vertical do filtro de
  /// categoria, que fica uma linha abaixo dele.
  static const double _alturaControle = 40;

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _mes = DateTime(agora.year, agora.month);

    _carregarResumoMeses();
    _carregarCategorias();
    _carregarContas();
    _carregarMes(_chave(_mes));
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  static String _chave(DateTime mes) => '${mes.year}-${mes.month}';

  String _rotuloMes(DateTime mes) => rotuloMes(mes);

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
    } catch (e, s) {
      // O resumo é acessório: sem ele a tela perde o atalho de meses, não a
      // lista. Falhar aqui não pode derrubar o que já está em foco — mas tem
      // que aparecer no log, senão a tela só "nasce sem meses".
      debugPrint('Erro ao carregar o resumo mensal: $e');
      await _logger.logError(
        'FluxosPage._carregarResumoMeses',
        e,
        stackTrace: s,
        additionalInfo: {'tipo': _tipo.codigo},
      );
    }
  }

  /// Recarregar um mês descartava o pedido quando já havia um em voo, e a
  /// resposta antiga chegava depois repondo a lista anterior na tela — era isso
  /// que fazia uma edição salva não aparecer. Agora cada pedido leva um número
  /// e só o mais recente pode escrever no estado.
  Future<void> _carregarMes(String chave) async {
    final geracao = (_geracao[chave] ?? 0) + 1;
    _geracao[chave] = geracao;

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

      if (!mounted || _geracao[chave] != geracao) return;
      setState(() => _itensPorMes[chave] = pagina.itens);
    } catch (e, s) {
      await _logger.logError(
        'FluxosPage._carregarMes',
        e,
        stackTrace: s,
        additionalInfo: {'tipo': _tipo.codigo, 'mes': chave},
      );
      if (!mounted || _geracao[chave] != geracao) return;
      setState(() => _erroPorMes[chave] = e);
    } finally {
      if (mounted && _geracao[chave] == geracao) {
        setState(() => _carregando.remove(chave));
      }
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
        _semData = pagina.itens.where((f) => f.dataVencimento == null).toList();
      });
    } catch (e, s) {
      debugPrint('Erro ao carregar lançamentos sem data: $e');
      await _logger.logError(
        'FluxosPage._carregarSemData',
        e,
        stackTrace: s,
        additionalInfo: {'tipo': _tipo.codigo},
      );
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
    } catch (e, s) {
      debugPrint('Erro ao carregar categorias: $e');
      // Sem as categorias os cards perdem nome, ícone e cor. A tela continua
      // de pé, então sem log o sintoma chega como "sumiram os ícones".
      await _logger.logError(
        'FluxosPage._carregarCategorias',
        e,
        stackTrace: s,
      );
    }
  }

  /// As contas da loja, para o card resolver `id_conta` em nome e para o
  /// filtro ter o que listar.
  ///
  /// Falha não derruba a tela: o cache devolve lista vazia, o chip de conta não
  /// aparece em card nenhum e o filtro de conta fica sem opções — a lista
  /// continua de pé, que é o que importa aqui.
  Future<void> _carregarContas() async {
    final contas = await ContasCache().obter();
    if (!mounted) return;

    setState(() => _contas = {for (final c in contas) c.id: c});
  }

  /// Recarrega depois de gravar pelo formulário, acompanhando o lançamento.
  ///
  /// Mudar o vencimento muda o mês da conta. Sem seguir a data, a tela ficaria
  /// no mês anterior — de onde o card acabou de sair — e a alteração pareceria
  /// não ter sido aplicada.
  void _recarregarApos(DateTime? vencimento) {
    final origem = _chave(_mes);

    if (vencimento != null &&
        (vencimento.year != _mes.year || vencimento.month != _mes.month)) {
      setState(() => _mes = DateTime(vencimento.year, vencimento.month));
    }

    // O mês de origem também sai do cache: a conta pode ter saído dele.
    _itensPorMes.remove(origem);
    _recarregar();
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
    final lista = _categorias.values
        .where((c) => c.tipoFluxo == _tipo.codigo)
        .toList();
    lista.sort((a, b) => a.descricao.compareTo(b.descricao));
    return lista;
  }

  bool get _temFiltro =>
      _busca.trim().isNotEmpty ||
      _categoriaFiltro != 0 ||
      _contaFiltro != null ||
      _situacaoFiltro != null;

  /// Quantos dos três filtros de menu estão ativos. A busca fica fora: ela tem
  /// o próprio campo à vista, e não precisa ser contada num badge.
  int get _filtrosAtivos =>
      (_categoriaFiltro != 0 ? 1 : 0) +
      (_contaFiltro != null ? 1 : 0) +
      (_situacaoFiltro != null ? 1 : 0);

  void _limparFiltros() {
    setState(() {
      _categoriaFiltro = 0;
      _contaFiltro = null;
      _situacaoFiltro = null;
    });
  }

  /// Tudo que o mês em foco tem **antes** de qualquer filtro.
  ///
  /// É a base dos menus de filtro: contar as opções sobre a lista já filtrada
  /// esvaziaria as outras no instante em que uma fosse escolhida.
  List<FluxoCaixa> get _itensBrutos => [
    ...(_itensPorMes[_chave(_mes)] ?? const <FluxoCaixa>[]),
    ...(_semData ?? const <FluxoCaixa>[]),
  ];

  /// O predicado mora em `utils/filtro_fluxos.dart`: as convenções de "vazio"
  /// dos quatro filtros não são iguais (0 não filtra em categoria, mas filtra
  /// em conta), e isso precisa ser verificável sem subir a tela.
  List<FluxoCaixa> _filtrar(List<FluxoCaixa> itens) {
    return itens
        .where(
          (f) => fluxoPassaNoFiltro(
            f,
            termo: _busca,
            categoria: _categoriaFiltro,
            conta: _contaFiltro,
            situacao: _situacaoFiltro,
          ),
        )
        .toList();
  }

  List<FluxoCaixa> get _itensDoMes =>
      _filtrar(_itensPorMes[_chave(_mes)] ?? const []);

  List<FluxoCaixa> get _itensSemData => _filtrar(_semData ?? const []);

  /// O que o rodapé e o modal de detalhes somam: tudo que está listado, na
  /// ordem em que aparece.
  List<FluxoCaixa> get _itensVisiveis => [..._itensDoMes, ..._itensSemData];

  // --------------------------------------------------------------- ações

  /// Abre o formulário: sem [fluxo] para criar, com ele para editar, e com
  /// [clonar] para criar a partir de um molde já preenchido.
  void _showFormDialog({FluxoCaixa? fluxo, bool clonar = false}) {
    showDialog(
      context: context,
      builder: (context) {
        return FluxoFormDialog(
          tipoFluxo: _tipo.tipoDialogo,
          fluxo: fluxo,
          clonar: clonar,
          // Quem fecha o modal é ele mesmo: no "salvar e continuar" ele grava e
          // **fica aberto** para o próximo lançamento, e só ele sabe qual dos
          // dois botões foi tocado.
          onSave: (vencimento, parcelasReplicadas) => _aposSalvar(
            vencimento,
            parcelasReplicadas,
            ehEdicao: fluxo != null && !clonar,
            clonar: clonar,
          ),
        );
      },
    );
  }

  /// Atualiza a tela e confirma a gravação.
  ///
  /// A tela recarrega em toda gravação, inclusive nas que mantêm o formulário
  /// aberto: é a única confirmação visível de que a anterior entrou. A mensagem
  /// existe porque o formulário fechava calado, e aí "não atualizou" e "não
  /// gravou" ficavam indistinguíveis para quem está olhando.
  ///
  /// Quando houve replicação a contagem entra na mensagem: as outras parcelas
  /// podem estar em meses que não estão à vista, e aí o card recarregado não
  /// serve de comprovante.
  void _aposSalvar(
    DateTime? vencimento,
    int parcelasReplicadas, {
    required bool ehEdicao,
    required bool clonar,
  }) {
    _recarregarApos(vencimento);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !ehEdicao
              ? '${_tipo.singular[0].toUpperCase()}'
                    '${_tipo.singular.substring(1)} '
                    '${clonar ? 'duplicada' : 'criada'}.'
              : parcelasReplicadas > 0
              ? 'Alterações salvas e replicadas para '
                    '$parcelasReplicadas '
                    '${parcelasReplicadas == 1 ? 'parcela' : 'parcelas'}.'
              : 'Alterações salvas.',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _darBaixa(FluxoCaixa fluxo) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) =>
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
      builder: (context) => AlertDialog(
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
    } catch (e, s) {
      await _logger.logError(
        'FluxosPage._estornar',
        e,
        stackTrace: s,
        additionalInfo: {'idFluxo': fluxo.id, 'tipo': _tipo.codigo},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao estornar: $e')));
    }
  }

  Future<void> _confirmarExclusao(FluxoCaixa fluxo) async {
    final cores = context.appColors;

    // `id_ref` só agrupa quando é positivo — é a condição que a API testa em
    // `RemoveFluxoCaixa` para apagar o lote em vez da linha. Oferecer a opção
    // para 0 (ou para um valor negativo vindo de dado ruim) daria um checkbox
    // que não muda nada: o DELETE cairia no ramo da linha única de qualquer
    // forma.
    final idRef = fluxo.idRef ?? 0;
    final ehParcelamento = idRef > 0;

    // Fica fora do `builder` para sobreviver aos rebuilds do StatefulBuilder e
    // continuar legível depois que o diálogo fecha.
    var excluirGrupo = false;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Confirmar exclusão'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Deseja realmente excluir "${fluxo.descricao}"?'),
              if (ehParcelamento) ...[
                const SizedBox(height: AppSpacing.sm),
                CheckboxListTile(
                  value: excluirGrupo,
                  onChanged: (marcado) =>
                      setStateDialog(() => excluirGrupo = marcado ?? false),
                  // `titulo` é o plural da tela ("Receitas"/"Despesas").
                  title: Text(
                    'Excluir todas as ${_tipo.titulo.toLowerCase()} '
                    'deste parcelamento',
                  ),
                  subtitle: const Text('Inclui as parcelas de outros meses.'),
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
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: cores.error),
              child: const Text('Excluir'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    // `id_ref = 0` é o que pede a exclusão de uma linha só: a API só agrupa
    // quando recebe um valor positivo. Antes deste checkbox o app mandava
    // sempre o `id_ref` do lançamento, então apagar uma parcela derrubava o
    // parcelamento inteiro sem avisar.
    try {
      await _apiService.deleteFluxo(fluxo.id!, excluirGrupo ? idRef : 0);
      _recarregar();
    } catch (e, s) {
      await _logger.logError(
        'FluxosPage._confirmarExclusao',
        e,
        stackTrace: s,
        additionalInfo: {
          'idFluxo': fluxo.id,
          'idRef': idRef,
          'excluirGrupo': excluirGrupo,
          'tipo': _tipo.codigo,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
    }
  }

  void _abrirDetalhes() {
    showDialog(
      context: context,
      builder: (context) => DetalhesMesDialog(
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
    return MolduraMenu(
      builder: (context, menu) => _buildScaffold(context, menu),
    );
  }

  Widget _buildScaffold(BuildContext context, MenuLateral menu) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tipo.titulo),
        actions: [_buildBotaoDetalhes()],
      ),
      drawer: menu.ehGaveta ? const AppDrawer() : null,
      body: Column(
        children: [
          _buildBarraFiltros(),
          Expanded(child: _buildLista()),
        ],
      ),
      // O resumo é barra do `Scaffold`, e não o último item da coluna: é isso
      // que mantém o botão flutuante **acima** dele em vez de tapando os
      // totais.
      bottomNavigationBar: _buildResumoRodape(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(),
        tooltip: 'Nova ${_tipo.singular}',
        backgroundColor: _tipo.cor(context.appColors),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Atalho para o resumo do mês, em dourado.
  ///
  /// É a única ação dourada do app: a cor não entra na escala de status, então
  /// não compete com o verde de confirmado nem com o vermelho de atraso — ela
  /// só puxa o olho para onde o panorama do mês está.
  Widget _buildBotaoDetalhes() {
    final theme = Theme.of(context);
    final fundoBarra =
        theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface;

    // A barra é escura nos dois temas do app, então a variante que o olho vê
    // aqui é sempre a de superfície escura. Puxar o dourado pelo modo do app
    // misturaria o dourado escuro do tema claro com o azul da barra e o
    // resultado lê como oliva apagado, não como destaque.
    final paleta =
        ThemeData.estimateBrightnessForColor(fundoBarra) == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    final dourado = paleta.destaque;

    // O ícone contrasta com o dourado já misturado ao fundo da barra, não com o
    // dourado puro: é a cor composta que fica atrás dele.
    final preenchimento = Color.alphaBlend(
      dourado.withValues(alpha: 0.7),
      fundoBarra,
    );
    final tinta =
        ThemeData.estimateBrightnessForColor(preenchimento) == Brightness.dark
        ? Colors.white
        : Colors.black87;

    // Quadrado de 40 com a mesma margem direita da barra de filtros: assim ele
    // cai exatamente na vertical do botão de categoria, que fica uma linha
    // abaixo. Centralizado para não esticar na altura cheia da AppBar.
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        child: Tooltip(
          message: 'Detalhes do mês',
          child: Material(
            color: preenchimento,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: dourado),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: InkWell(
              onTap: _abrirDetalhes,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                width: _alturaControle,
                height: _alturaControle,
                child: Icon(Icons.insights, size: 18, color: tinta),
              ),
            ),
          ),
        ),
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
        child: estreito ? _buildBarraCompacta() : _buildBarraLarga(),
      ),
    );
  }

  /// `[mês] [busca] [categoria][conta][situação]`.
  ///
  /// Os três filtros são quadrados do mesmo tamanho, encostados: a fileira lê
  /// como um grupo de controles irmãos, e a busca fica com toda a largura que
  /// sobra. Antes o filtro de categoria era uma caixa de 200px com o nome
  /// dentro, o que comia a busca e não tinha irmão com que se alinhar.
  Widget _buildBarraLarga() {
    return Row(
      children: [
        _buildNavegadorMes(),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _buildBusca()),
        const SizedBox(width: AppSpacing.md),
        _buildFiltroCategoria(),
        const SizedBox(width: AppSpacing.xs),
        _buildFiltroConta(),
        const SizedBox(width: AppSpacing.xs),
        _buildFiltroSituacao(),
      ],
    );
  }

  /// No celular tudo cabe numa linha só: a lupa à esquerda do seletor de mês e
  /// o filtro de categoria à direita. Tocar na lupa troca a linha inteira pelo
  /// campo de busca — fechá-lo limpa o termo, para não restar filtro invisível.
  Widget _buildBarraCompacta() {
    if (_buscaAberta) {
      return _buildBusca(autofocus: true, aoFechar: _fecharBusca);
    }

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Buscar por descrição',
          visualDensity: VisualDensity.compact,
          onPressed: () => setState(() => _buscaAberta = true),
        ),
        Expanded(child: Center(child: _buildNavegadorMes(larguraRotulo: 132))),
        // Um quadrado só: três mais a lupa e o seletor de mês não cabem em
        // 360px sem espremer o nome do mês. Ele abre a folha com os três
        // filtros, que é onde o celular tem espaço de sobra.
        _buildBotaoFolhaFiltros(),
      ],
    );
  }

  void _fecharBusca() {
    _buscaController.clear();
    setState(() {
      _busca = '';
      _buscaAberta = false;
    });
  }

  Widget _buildNavegadorMes({double larguraRotulo = 150}) {
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
          width: larguraRotulo,
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
          if (!noMesAtual && comLancamento.isNotEmpty) const PopupMenuDivider(),
          for (final m in comLancamento)
            PopupMenuItem(
              value: m.chave,
              child: Row(
                children: [
                  Expanded(child: Text(_rotuloMes(DateTime(m.ano!, m.mes!)))),
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

  Widget _buildBusca({bool autofocus = false, VoidCallback? aoFechar}) {
    // Na barra compacta o X sempre aparece: ele é a única saída de volta para o
    // seletor de mês, mesmo com o campo ainda vazio.
    final mostraFechar = aoFechar != null || _busca.isNotEmpty;

    return TextField(
      controller: _buscaController,
      autofocus: autofocus,
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Buscar por descrição',
        prefixIcon: const Icon(Icons.search, size: 18),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
        suffixIcon: !mostraFechar
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 16),
                visualDensity: VisualDensity.compact,
                tooltip: aoFechar == null ? 'Limpar busca' : 'Fechar busca',
                onPressed: () {
                  if (aoFechar != null) {
                    aoFechar();
                    return;
                  }
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

  // ------------------------------------------------------------- filtros
  //
  // Três filtros, três quadrados do mesmo tamanho: categoria, conta e situação.
  // A caixa compartilhada ([_molduraFiltro]) é o que faz a fileira ler como um
  // grupo de controles irmãos — e é também o que a mantém alinhada com o botão
  // de detalhes da AppBar, que usa a mesma medida.
  //
  // Todos filtram **no cliente**, sobre a lista do mês que já está em memória:
  // nenhum deles dispara requisição.

  /// A moldura dos três: quadrado de [_alturaControle], borda e glifo acesos
  /// quando o filtro está ativo.
  Widget _molduraFiltro({
    required IconData icone,
    required bool ativo,
    required Color corAtiva,
  }) {
    final theme = Theme.of(context);

    return Container(
      height: _alturaControle,
      width: _alturaControle,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: ativo ? corAtiva : theme.dividerColor),
        // O preenchimento fraquinho é o que distingue "tem filtro" de "não
        // tem" num relance, sem precisar comparar as bordas uma com a outra.
        color: ativo ? corAtiva.withValues(alpha: 0.08) : null,
      ),
      child: Icon(
        icone,
        size: 18,
        color: ativo ? corAtiva : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  /// Item de menu dos filtros: glifo, rótulo e, quando há, a contagem à direita.
  PopupMenuItem<T> _itemFiltro<T>({
    required T valor,
    required IconData icone,
    required Color corIcone,
    required String rotulo,
    int? quantidade,
  }) {
    final theme = Theme.of(context);

    return PopupMenuItem<T>(
      value: valor,
      child: Row(
        children: [
          Icon(icone, size: 16, color: corIcone),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(rotulo, overflow: TextOverflow.ellipsis)),
          if (quantidade != null) ...[
            const SizedBox(width: AppSpacing.md),
            Text(
              '$quantidade',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFiltroCategoria() {
    final theme = Theme.of(context);
    final cores = context.appColors;
    final ativa = _categorias[_categoriaFiltro];

    return PopupMenuButton<int>(
      tooltip: 'Filtrar por categoria',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      onSelected: (id) => setState(() => _categoriaFiltro = id),
      itemBuilder: (context) => [
        _itemFiltro(
          valor: 0,
          icone: Icons.clear_all,
          corIcone: theme.colorScheme.onSurfaceVariant,
          rotulo: 'Todas as categorias',
        ),
        if (_categoriasDoTipo.isNotEmpty) const PopupMenuDivider(),
        for (final c in _categoriasDoTipo)
          _itemFiltro(
            valor: c.id!,
            icone: CategoriaVisuais.icone(c.icone),
            corIcone: CategoriaVisuais.cor(c.cor),
            rotulo: c.descricao,
          ),
      ],
      // Ativo, o quadrado mostra o ícone e a cor da própria categoria: é mais
      // direto que um ícone genérico de filtro aceso.
      child: _molduraFiltro(
        icone: ativa == null
            ? Icons.local_offer_outlined
            : CategoriaVisuais.icone(ativa.icone),
        ativo: ativa != null,
        corAtiva: ativa == null ? cores.info : CategoriaVisuais.cor(ativa.cor),
      ),
    );
  }

  /// Contagem por conta no mês em foco. A chave 0 é "sem conta".
  Map<int, int> get _quantidadePorConta {
    final mapa = <int, int>{};
    for (final f in _itensBrutos) {
      final id = f.idConta ?? 0;
      mapa[id] = (mapa[id] ?? 0) + 1;
    }
    return mapa;
  }

  /// O menu lista só as contas que **aparecem** no mês, com a contagem de cada
  /// uma. Oferecer as 8 contas cadastradas quando 7 não têm lançamento no mês
  /// seria oferecer 7 listas vazias.
  Widget _buildFiltroConta() {
    final theme = Theme.of(context);
    final cores = context.appColors;
    final quantidade = _quantidadePorConta;
    final ativa = _contaFiltro;

    final ids = quantidade.keys.where((id) => id != 0).toList()
      ..sort(
        (a, b) => (_contas[a]?.descricao ?? '').compareTo(
          _contas[b]?.descricao ?? '',
        ),
      );

    return PopupMenuButton<int?>(
      tooltip: 'Filtrar por conta',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      onSelected: (id) => setState(() => _contaFiltro = id),
      itemBuilder: (context) => [
        _itemFiltro<int?>(
          valor: null,
          icone: Icons.clear_all,
          corIcone: theme.colorScheme.onSurfaceVariant,
          rotulo: 'Todas as contas',
        ),
        if (quantidade.isNotEmpty) const PopupMenuDivider(),
        for (final id in ids)
          _itemFiltro<int?>(
            valor: id,
            icone: Icons.account_balance,
            corIcone: cores.info,
            rotulo: _contas[id]?.descricao ?? 'Conta $id',
            quantidade: quantidade[id],
          ),
        // "Sem conta" é um filtro de verdade, não ausência de filtro: é o
        // estado de todo lançamento que nunca escolheu conta e de tudo que
        // vem do PDV.
        if (quantidade.containsKey(0))
          _itemFiltro<int?>(
            valor: 0,
            icone: Icons.block,
            corIcone: theme.colorScheme.onSurfaceVariant,
            rotulo: 'Sem conta',
            quantidade: quantidade[0],
          ),
      ],
      child: _molduraFiltro(
        icone: Icons.account_balance_outlined,
        ativo: ativa != null,
        corAtiva: cores.info,
      ),
    );
  }

  /// Contagem por situação no mês em foco, na ordem do enum.
  Map<SituacaoFluxo, int> get _quantidadePorSituacao {
    final mapa = <SituacaoFluxo, int>{};
    for (final f in _itensBrutos) {
      final s = SituacaoFluxo.de(f);
      mapa[s] = (mapa[s] ?? 0) + 1;
    }
    return {
      for (final s in SituacaoFluxo.values)
        if (mapa.containsKey(s)) s: mapa[s]!,
    };
  }

  Widget _buildFiltroSituacao() {
    final theme = Theme.of(context);
    final cores = context.appColors;
    final quantidade = _quantidadePorSituacao;
    final ativa = _situacaoFiltro;

    return PopupMenuButton<SituacaoFluxo?>(
      tooltip: 'Filtrar por situação',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      onSelected: (s) => setState(() => _situacaoFiltro = s),
      itemBuilder: (context) => [
        _itemFiltro<SituacaoFluxo?>(
          valor: null,
          icone: Icons.clear_all,
          corIcone: theme.colorScheme.onSurfaceVariant,
          rotulo: 'Todas as situações',
        ),
        if (quantidade.isNotEmpty) const PopupMenuDivider(),
        for (final entrada in quantidade.entries)
          _itemFiltro<SituacaoFluxo?>(
            valor: entrada.key,
            icone: entrada.key.icone,
            corIcone: entrada.key.cor(cores),
            rotulo: entrada.key.rotulo,
            quantidade: entrada.value,
          ),
      ],
      // Com situação escolhida o quadrado veste a cor dela — o mesmo verde,
      // vermelho ou âmbar que o selo do card usa.
      child: _molduraFiltro(
        icone: ativa?.icone ?? Icons.flag_outlined,
        ativo: ativa != null,
        corAtiva: ativa?.cor(cores) ?? cores.info,
      ),
    );
  }

  /// No celular os três filtros moram numa folha, atrás de um quadrado só.
  ///
  /// Não é preferência de plataforma: a lupa, o seletor de mês e três quadrados
  /// não cabem em 360px sem espremer o nome do mês. A folha também é onde cabe
  /// o rótulo de cada filtro, que no quadrado só existe como tooltip.
  Widget _buildBotaoFolhaFiltros() {
    final cores = context.appColors;
    final ativos = _filtrosAtivos;

    return Tooltip(
      message: 'Filtros',
      child: InkWell(
        onTap: _abrirFolhaFiltros,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _molduraFiltro(
              icone: Icons.filter_alt_outlined,
              ativo: ativos > 0,
              corAtiva: cores.info,
            ),
            if (ativos > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cores.info,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).cardColor,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    '$ativos',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirFolhaFiltros() async {
    final theme = Theme.of(context);
    final cores = context.appColors;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (contextoFolha) => StatefulBuilder(
        // Dois `setState`: o da página, que refaz a lista atrás, e o da
        // folha, que redesenha os próprios seletores.
        builder: (contextoFolha, refazerFolha) {
          void aplicar(void Function() mudanca) {
            setState(mudanca);
            refazerFolha(() {});
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text('Filtros', style: theme.textTheme.titleMedium),
                      const Spacer(),
                      if (_filtrosAtivos > 0)
                        TextButton(
                          onPressed: () {
                            _limparFiltros();
                            refazerFolha(() {});
                          },
                          child: const Text('Limpar'),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<int>(
                    value: _categoriaFiltro,
                    isDense: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Categoria',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 0,
                        child: Text('Todas as categorias'),
                      ),
                      for (final c in _categoriasDoTipo)
                        DropdownMenuItem(
                          value: c.id!,
                          child: Text(
                            c.descricao,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => aplicar(() => _categoriaFiltro = v ?? 0),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<int?>(
                    value: _contaFiltro,
                    isDense: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Conta',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Todas as contas'),
                      ),
                      for (final entrada in _quantidadePorConta.entries.where(
                        (e) => e.key != 0,
                      ))
                        DropdownMenuItem(
                          value: entrada.key,
                          child: Text(
                            _contas[entrada.key]?.descricao ??
                                'Conta ${entrada.key}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (_quantidadePorConta.containsKey(0))
                        const DropdownMenuItem(
                          value: 0,
                          child: Text('Sem conta'),
                        ),
                    ],
                    onChanged: (v) => aplicar(() => _contaFiltro = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<SituacaoFluxo?>(
                    value: _situacaoFiltro,
                    isDense: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Situação',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Todas as situações'),
                      ),
                      for (final entrada in _quantidadePorSituacao.entries)
                        DropdownMenuItem(
                          value: entrada.key,
                          child: Row(
                            children: [
                              Icon(
                                entrada.key.icone,
                                size: 16,
                                color: entrada.key.cor(cores),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(entrada.key.rotulo),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (v) => aplicar(() => _situacaoFiltro = v),
                  ),
                ],
              ),
            ),
          );
        },
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
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
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
      // Resolvida aqui, como a categoria: quem tem o mapa é a página.
      conta: _contas[fluxo.idConta ?? 0],
      corValor: _tipo.cor(context.appColors),
      rotuloAcao: _tipo.rotuloAcao,
      onEditar: () => _showFormDialog(fluxo: fluxo),
      // O molde do clone é montado aqui, e não dentro do modal: é o model que
      // decide o que não se herda (`FluxoCaixa.paraClone`), e o formulário só
      // precisa saber que vai criar.
      onDuplicar: () => _showFormDialog(fluxo: fluxo.paraClone(), clonar: true),
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
              style:
                  (destaque
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
