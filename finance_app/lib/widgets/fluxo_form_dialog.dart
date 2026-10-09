import 'package:flutter/material.dart';
import '../models/categoria.dart';
import '../models/conta.dart';
import '../models/fluxo_caixa.dart';
import '../models/subcategoria.dart';
import '../services/api_service.dart';
import '../services/contas_cache.dart';
import '../services/logger_service.dart';
import '../services/global_state.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';
import '../utils/categoria_visuais.dart';
import '../utils/currency_formatter.dart';
import '../utils/currency_input_formatter.dart';
import '../utils/responsive_utils.dart';
import '../utils/situacao_fluxo.dart';
import 'categoria_form_dialog.dart';
import 'logo_banco.dart';
import 'seletor_categoria.dart';
import 'subcategoria_form_dialog.dart';

class FluxoFormDialog extends StatefulWidget {
  final String tipoFluxo;
  final FluxoCaixa? fluxo;

  /// Chamado depois de gravar, com a data de vencimento efetivamente salva.
  ///
  /// A lista precisa dela para seguir o lançamento: editar a data move a conta
  /// de mês, e sem isso a tela continuaria no mês anterior — de onde o card
  /// acabou de sair — parecendo que a alteração não foi aplicada.
  ///
  /// `parcelasReplicadas` é quantas outras parcelas receberam a alteração, e 0
  /// quando não houve replicação. Vai junto porque quem avisa o usuário é a
  /// tela: a replicação muda linhas que não estão em foco — pode estar em outro
  /// mês — e sem o número a única confirmação seria o card que já estava à
  /// vista.
  final void Function(DateTime? vencimento, int parcelasReplicadas) onSave;

  const FluxoFormDialog({
    super.key,
    required this.tipoFluxo,
    this.fluxo,
    required this.onSave,
  });

  @override
  State<FluxoFormDialog> createState() => _FluxoFormDialogState();
}

class _FluxoFormDialogState extends State<FluxoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  final _valorController = TextEditingController();
  final _parcelasController = TextEditingController();
  final ApiService _apiService = ApiService();
  final LoggerService _logger = LoggerService();
  bool _isLoading = false;
  DateTime? _dataVencimento;
  bool _confirmado = false;
  String _repeticao = '1'; // 1 = única vez
  int? _categoriaId = 0;
  int? _subcategoriaId = 0;
  List<Categoria> _categorias = [];
  List<Subcategoria> _subcategorias = [];

  /// Conta bancária do lançamento; 0 é "sem conta", o padrão.
  int _contaId = 0;

  /// O que o seletor oferece. Vazio significa "a loja não tem conta cadastrada"
  /// — e então o seletor inteiro não aparece, porque não há escolha a fazer.
  List<Conta> _contas = const [];

  /// Só aparece quando a categoria escolhida ainda não tem nenhuma filha — é o
  /// atalho para criar a primeira. Com subcategorias já cadastradas, o card
  /// aparece direto e o checkbox some.
  bool _habilitarSubcategorias = false;
  int _numeroParcelas = 1;
  bool _valorEhParcela = true; // true = valor da parcela, false = valor total

  @override
  void initState() {
    super.initState();
    _dataVencimento = DateTime.now();

    if (widget.fluxo != null) {
      _descricaoController.text = widget.fluxo!.descricao ?? '';
      // Pré-formatado: o campo é mascarado, então "150.5" cru entraria como
      // R$ 1,50 na primeira tecla.
      _valorController.text =
          widget.fluxo!.valor == null
              ? ''
              : CurrencyFormatter.formatValue(widget.fluxo!.valor);
      _categoriaId = widget.fluxo!.idCategoria ?? 0;
      _subcategoriaId = widget.fluxo!.idSubcategoria ?? 0;
      _dataVencimento = widget.fluxo!.dataVencimento ?? DateTime.now();
      _confirmado = widget.fluxo!.confirmado ?? false;
      _repeticao = widget.fluxo!.repeticao ?? '1';
      _contaId = widget.fluxo!.idConta ?? 0;
    }

    // Carregar categorias após definir os valores iniciais
    _loadCategorias();
    _loadSubcategorias();
    _loadContas();
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _valorController.dispose();
    _parcelasController.dispose();
    super.dispose();
  }

  /// 1 = receita, 2 = despesa — o mesmo código de `tipo_fluxo` do banco.
  int get _tipoFluxoCategoria => widget.tipoFluxo == 'receita' ? 1 : 2;

  Future<void> _loadCategorias() async {
    try {
      final categorias = await _apiService.listCategorias();

      // A API devolve as categorias das duas naturezas; um lançamento de despesa
      // não pode oferecer categoria de receita.
      final doTipo =
          categorias
              .where((cat) => cat.tipoFluxo == _tipoFluxoCategoria)
              .toList();

      if (!mounted) return;
      setState(() {
        _categorias = doTipo;

        // Validar se a categoria selecionada existe na lista
        if (_categoriaId != null && _categoriaId != 0) {
          final categoriaExiste = _categorias.any(
            (cat) => cat.id == _categoriaId,
          );
          if (!categoriaExiste) {
            // Se a categoria não existe, definir como "Sem categoria"
            _categoriaId = 0;
            _subcategoriaId = 0;
          }
        }
      });
    } catch (e, s) {
      debugPrint('Erro ao carregar categorias: $e');
      // Sem isto a falha é invisível: o seletor abre vazio e o lojista conclui
      // que não tem categoria cadastrada.
      await _logger.logError(
        'FluxoFormDialog._loadCategorias',
        e,
        stackTrace: s,
        additionalInfo: {'tipoFluxo': widget.tipoFluxo},
      );
    }
  }

  Future<void> _loadSubcategorias() async {
    try {
      final subcategorias = await _apiService.listSubcategorias();
      if (!mounted) return;
      setState(() {
        _subcategorias = subcategorias;

        if (_subcategoriaId != null && _subcategoriaId != 0) {
          final existe = _subcategorias.any((s) => s.id == _subcategoriaId);
          if (!existe) _subcategoriaId = 0;
        }

        // Editando um lançamento que já tem subcategoria, o card precisa nascer
        // aberto mesmo que a categoria tenha só essa uma filha.
        if (_subcategoriaId != null && _subcategoriaId != 0) {
          _habilitarSubcategorias = true;
        }
      });
    } catch (e, s) {
      debugPrint('Erro ao carregar subcategorias: $e');
      await _logger.logError(
        'FluxoFormDialog._loadSubcategorias',
        e,
        stackTrace: s,
      );
    }
  }

  /// Contas que o seletor oferece.
  ///
  /// Vem do [ContasCache], carregado uma vez por sessão: este modal já consulta
  /// categorias e subcategorias a cada abertura, e a lista de contas muda muito
  /// menos que isso — pedi-la de novo aqui seria uma terceira requisição por
  /// abertura, para um dado praticamente fixo.
  ///
  /// Arquivada não entra, **exceto** a que este lançamento já usa: ela é omitida
  /// de lançamentos novos, mas tirá-la da lista durante uma edição faria o
  /// `Dropdown` cair em "sem conta" e a gravação desvincular a conta em silêncio.
  Future<void> _loadContas() async {
    final contas = await ContasCache().obter();
    if (!mounted) return;

    setState(() {
      _contas = [
        for (final c in contas)
          if (c.ativado || c.id == _contaId) c,
      ];

      // A conta gravada pode ter sido apagada entre a listagem e esta abertura.
      if (_contaId != 0 && !_contas.any((c) => c.id == _contaId)) {
        _contaId = 0;
      }
    });
  }

  /// Filhas da categoria em foco. Sem categoria escolhida não há pai ao qual
  /// vincular, então a lista é vazia e o bloco inteiro some.
  List<Subcategoria> get _subcategoriasDaCategoria {
    if (_categoriaId == null || _categoriaId == 0) return const [];
    return _subcategorias
        .where((s) => s.idCategoria == _categoriaId)
        .toList();
  }

  /// 0 quando não há subcategoria escolhida — ou quando a escolhida não é filha
  /// da categoria atual, o que impede gravar um vínculo órfão.
  int get _idSubcategoriaParaSalvar {
    final id = _subcategoriaId ?? 0;
    if (id == 0) return 0;
    return _subcategoriasDaCategoria.any((s) => s.id == id) ? id : 0;
  }

  /// `null` é "sem conta" — tanto o padrão quanto o caso em que a conta gravada
  /// sumiu da lista. Quem desenha o chip usa isso para cair no ícone genérico.
  Conta? get _contaSelecionada {
    if (_contaId == 0) return null;
    for (final c in _contas) {
      if (c.id == _contaId) return c;
    }
    return null;
  }

  Categoria? get _categoriaSelecionada {
    if (_categoriaId == null || _categoriaId == 0) return null;
    for (final cat in _categorias) {
      if (cat.id == _categoriaId) return cat;
    }
    return null;
  }


  /// Calcula a data de vencimento periódica considerando meses com dias diferentes
  DateTime _calcularDataVencimento(DateTime dataBase, int numeroParcela) {
    switch (_repeticao) {
      case '2': // Diária
        return dataBase.add(Duration(days: numeroParcela));

      case '3': // Semanal
        return dataBase.add(Duration(days: numeroParcela * 7));

      case '4': // Mensal
        int novoMes = dataBase.month + numeroParcela;
        int novoAno = dataBase.year;

        // Ajustar ano se necessário
        while (novoMes > 12) {
          novoMes -= 12;
          novoAno++;
        }

        // Ajustar dia se o mês não tiver esse dia
        int novoDia = dataBase.day;
        int ultimoDiaDoMes = DateTime(novoAno, novoMes + 1, 0).day;
        if (novoDia > ultimoDiaDoMes) {
          novoDia = ultimoDiaDoMes;
        }

        return DateTime(novoAno, novoMes, novoDia);

      case '5': // Anual
        int novoAno = dataBase.year + numeroParcela;
        int novoDia = dataBase.day;

        // Verificar se é 29 de fevereiro em ano não bissexto
        if (dataBase.month == 2 && dataBase.day == 29) {
          // Verificar se o novo ano é bissexto
          bool ehBissexto =
              (novoAno % 4 == 0 && novoAno % 100 != 0) || (novoAno % 400 == 0);
          if (!ehBissexto) {
            novoDia = 28;
          }
        }

        return DateTime(novoAno, dataBase.month, novoDia);

      default:
        return dataBase;
    }
  }

  /// Nomes de coluna da API que esta edição mudou em relação ao lançamento
  /// original — a lista que a replicação em grupo recebe.
  ///
  /// Só o que mudou vai para as outras parcelas. Replicar o registro inteiro
  /// sobrescreveria o `valor` de cada parcela já baixada com o valor desta, e a
  /// baixa grava ali o líquido (encargos e descontos já aplicados), sem guardar
  /// o original em lugar nenhum — ver `PagamentoDialog`.
  ///
  /// Vencimento e confirmação não aparecem aqui nem quando mudam: são de cada
  /// parcela, não do lote. A API também os recusa (`CAMPOS_REPLICAVEIS`), mas
  /// não oferecer a replicação quando foi *só* a data que mudou é o que evita
  /// perguntar algo que não teria efeito nenhum.
  List<String> _camposAlterados(double valor) {
    final original = widget.fluxo;
    if (original == null) return const [];

    final campos = <String>[];

    if (_descricaoController.text.trim() != (original.descricao ?? '').trim()) {
      campos.add('descricao');
    }

    // Em centavos: comparar double a double faria 150.00 digitado diferir do
    // 150.0 que veio da API.
    if ((valor * 100).round() != ((original.valor ?? 0) * 100).round()) {
      campos.add('valor');
    }

    if ((_categoriaId ?? 0) != (original.idCategoria ?? 0)) {
      campos.add('id_categoria');
    }

    if (_idSubcategoriaParaSalvar != (original.idSubcategoria ?? 0)) {
      campos.add('id_subcategoria');
    }

    if (_contaId != (original.idConta ?? 0)) {
      campos.add('id_conta');
    }

    if (_repeticao != (original.repeticao ?? '1')) {
      campos.add('repeticao');
    }

    return campos;
  }

  /// Pergunta se a alteração vale para o parcelamento inteiro.
  ///
  /// Devolve `null` quando o usuário desiste de salvar — "não replicar" e
  /// "cancelar" são respostas diferentes, e tratar as duas como `false` gravaria
  /// a edição de quem clicou em Cancelar.
  ///
  /// A caixa nasce desmarcada: o padrão de uma edição continua sendo mexer só na
  /// conta aberta. Só aparece quando há parcelamento (`id_ref > 0`) **e** algo
  /// replicável mudou.
  Future<bool?> _perguntarReplicar() async {
    var replicar = false;

    final confirmou = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setStateDialog) => AlertDialog(
                  title: const Text('Salvar alteração'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Esta conta faz parte de um parcelamento.',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      CheckboxListTile(
                        value: replicar,
                        onChanged:
                            (marcado) => setStateDialog(
                              () => replicar = marcado ?? false,
                            ),
                        title: const Text(
                          'Aplicar a mesma alteração às outras parcelas',
                        ),
                        subtitle: const Text(
                          'O vencimento de cada parcela é mantido, e as '
                          'parcelas já baixadas não são alteradas.',
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Salvar'),
                    ),
                  ],
                ),
          ),
    );

    return confirmou == true ? replicar : null;
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

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      // Validação da descrição
      if (_descricaoController.text.trim().length < 3) {
        _showError('A descrição deve ter no mínimo 3 caracteres');
        return;
      }

      // Validação do valor
      final valorBase = CurrencyFormatter.parse(_valorController.text);

      if (valorBase == null) {
        _showError('Valor inválido. Use apenas números');
        return;
      }

      if (valorBase <= 0) {
        _showError('O valor deve ser maior que zero');
        return;
      }

      // A pergunta vem antes do spinner: ela é parte da decisão de salvar, e
      // cancelar aqui tem que deixar o formulário como estava.
      final camposParaReplicar =
          (widget.fluxo?.idRef ?? 0) > 0
              ? _camposAlterados(valorBase)
              : const <String>[];

      var replicar = false;
      if (camposParaReplicar.isNotEmpty) {
        final resposta = await _perguntarReplicar();
        if (resposta == null) return;
        replicar = resposta;
      }

      if (!mounted) return;
      setState(() => _isLoading = true);

      final tipoFluxoValue = widget.tipoFluxo == 'receita' ? '1' : '2';

      var parcelasReplicadas = 0;

      try {
        // Se for edição simples
        if (widget.fluxo != null) {
          final fluxo = FluxoCaixa(
            id: widget.fluxo!.id,
            idLoja: GlobalState().firstIdLoja,
            idCategoria: _categoriaId ?? 0,
            idSubcategoria: _idSubcategoriaParaSalvar,
            descricao: _descricaoController.text,
            valor: valorBase,
            tipoFluxo: tipoFluxoValue,
            cancelado: false,
            confirmado: _confirmado,
            dataCriacao: DateTime.now(),
            dataVencimento: _dataVencimento ?? DateTime.now(),
            diaVencimento: (_dataVencimento ?? DateTime.now()).day,
            repeticao: _repeticao,
            idRef: widget.fluxo!.idRef,
            idConta: _contaId,
          );
          await _apiService.updateFluxo(fluxo);

          // Nesta ordem, e não ao contrário: esta parcela é a única que recebe o
          // vencimento e a confirmação do formulário, e a API deixa a linha
          // editada fora do escopo da replicação justamente porque ela já foi
          // gravada aqui.
          if (replicar) {
            parcelasReplicadas = await _apiService.updateFluxoGrupo(
              fluxo,
              camposParaReplicar,
            );
          }
        } else {
          // Nova entrada
          if (_repeticao == '1') {
            // Única vez
            final fluxo = FluxoCaixa(
              id: 0,
              idLoja: GlobalState().firstIdLoja,
              idCategoria: _categoriaId ?? 0,
            idSubcategoria: _idSubcategoriaParaSalvar,
              descricao: _descricaoController.text,
              valor: valorBase,
              tipoFluxo: tipoFluxoValue,
              cancelado: false,
              confirmado: _confirmado,
              dataCriacao: DateTime.now(),
              dataVencimento: _dataVencimento ?? DateTime.now(),
              diaVencimento: (_dataVencimento ?? DateTime.now()).day,
              repeticao: _repeticao,
              idRef: 0,
              idConta: _contaId,
            );
            await _apiService.createFluxo(fluxo);
          } else {
            // Parcelado
            final idRef = gerarIdRefParcelamento();
            final valorParcela =
                _valorEhParcela ? valorBase : valorBase / _numeroParcelas;

            for (int i = 0; i < _numeroParcelas; i++) {
              // Calcular data de vencimento periódica
              final dataBase = _dataVencimento ?? DateTime.now();
              final dataVencimentoParcela = _calcularDataVencimento(
                dataBase,
                i,
              );

              final descricaoComParcela =
                  '${_descricaoController.text} [${i + 1}/$_numeroParcelas]';

              final fluxo = FluxoCaixa(
                id: 0,
                idLoja: GlobalState().firstIdLoja,
                idCategoria: _categoriaId ?? 0,
            idSubcategoria: _idSubcategoriaParaSalvar,
                descricao: descricaoComParcela,
                valor: valorParcela,
                tipoFluxo: tipoFluxoValue,
                cancelado: false,
                confirmado: _confirmado,
                dataCriacao: DateTime.now(),
                dataVencimento: dataVencimentoParcela,
                diaVencimento: dataVencimentoParcela.day,
                repeticao: _repeticao,
                idRef: idRef,
                idConta: _contaId,
              );
              await _apiService.createFluxo(fluxo);
            }
          }
        }

        // No parcelamento a primeira parcela vence nesta data, então é também
        // para este mês que a lista deve ir.
        widget.onSave(_dataVencimento ?? DateTime.now(), parcelasReplicadas);
      } catch (e, s) {
        // No parcelamento o POST é um por parcela: saber em qual repetição
        // parou é a diferença entre "nada foi salvo" e "metade foi".
        await _logger.logError(
          'FluxoFormDialog._salvar',
          e,
          stackTrace: s,
          additionalInfo: {
            'edicao': widget.fluxo != null,
            'tipoFluxo': widget.tipoFluxo,
            'repeticao': _repeticao,
            'numeroParcelas': _numeroParcelas,
          },
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _selecionarData() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataVencimento ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('pt', 'BR'),
      helpText: 'Selecione a data de vencimento',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
      fieldLabelText: 'Data de vencimento',
      errorFormatText: 'Data inválida',
      errorInvalidText: 'Data fora do intervalo permitido',
    );
    if (picked != null && picked != _dataVencimento) {
      setState(() {
        _dataVencimento = picked;
      });
    }
  }

  Future<void> _abrirDialogNovaCategoria() async {
    final int? novaCategoriaId = await showDialog<int>(
      context: context,
      builder:
          (context) => CategoriaFormDialog(tipoFluxo: _tipoFluxoCategoria),
    );

    // `null` é cancelamento; 0 significa criada sem id conhecido — nos dois
    // casos diferente de selecionar, mas só o cancelamento dispensa recarregar.
    if (novaCategoriaId == null) return;

    await _loadCategorias();
    if (!mounted) return;
    setState(() {
      if (novaCategoriaId != 0) _categoriaId = novaCategoriaId;
      _subcategoriaId = 0;
      _habilitarSubcategorias = false;
    });
  }

  Future<void> _abrirDialogNovaSubcategoria(
    Categoria categoria,
    Color corCategoria,
  ) async {
    final int? novaId = await showDialog<int>(
      context: context,
      builder:
          (context) => SubcategoriaFormDialog(
            idCategoria: categoria.id!,
            nomeCategoria: categoria.descricao,
            corCategoria: corCategoria,
          ),
    );

    // `null` é cancelamento; 0 significa criada sem id conhecido — nos dois
    // casos diferente de selecionar, mas só o cancelamento dispensa recarregar.
    if (novaId == null) return;

    await _loadSubcategorias();
    if (!mounted) return;
    setState(() {
      _habilitarSubcategorias = true;
      if (novaId != 0) _subcategoriaId = novaId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth =
        ResponsiveUtils.isMobile(context)
            ? MediaQuery.of(context).size.width * 0.9
            : ResponsiveUtils.isTablet(context)
            ? 500.0
            : 600.0;

    // Os campos não declaram estilo nem padding: o `inputDecorationTheme` do
    // tema já define borda, preenchimento e tipografia para o app inteiro.
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
              children: [
                TextFormField(
                  controller: _descricaoController,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Descrição',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Campo obrigatório';
                    }
                    if (value.trim().length < 3) {
                      return 'Mínimo 3 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                TextFormField(
                  controller: _valorController,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Valor',
                    prefixText: 'R\$ ',
                  ),
                  // Só dígitos: a vírgula e o ponto são postos pela máscara.
                  keyboardType: TextInputType.number,
                  inputFormatters: const [CurrencyInputFormatter()],
                  onChanged: (_) {
                    // Realimenta a prévia do valor por parcela.
                    if (_repeticao != '1') setState(() {});
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Campo obrigatório';
                    }
                    final numero = CurrencyFormatter.parse(value);
                    if (numero == null) {
                      return 'Valor inválido';
                    }
                    if (numero <= 0) {
                      return 'Deve ser maior que zero';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                _buildCategoria(),
                ..._buildSubcategoria(),
                const SizedBox(height: AppSpacing.md),

                // Conta e vencimento ficam no cabeçalho: são as duas decisões
                // que o lojista já traz pronta ao abrir o modal, e no corpo
                // empurravam para baixo o que ele de fato vem preencher.
                _buildRepeticao(),
                const SizedBox(height: AppSpacing.md),

                if (_repeticao != '1' && widget.fluxo == null)
                  ..._buildCamposParcelamento(),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: const Text('Confirmado'),
                  value: _confirmado,
                  onChanged: (value) {
                    setState(() {
                      _confirmado = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        _isLoading
            ? CircularProgressIndicator(
              strokeWidth: ResponsiveUtils.isMobile(context) ? 3.0 : 4.0,
            )
            : ElevatedButton(onPressed: _save, child: const Text('Salvar')),
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

  /// Bloco de subcategoria: o checkbox de habilitar, o card, ou nada.
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

  // ── Cabeçalho ──────────────────────────────────────────────────────────────
  // Conta e vencimento moram aqui, não no corpo. Os dois já chegam decididos
  // quando o modal abre — a conta tem padrão ("Sem conta") e a data é hoje —,
  // então, como campo de formulário, ocupavam duas linhas inteiras empurrando
  // para baixo justamente o que o lojista veio digitar. Em chip continuam a um
  // toque, e o olho passa direto por eles quando os valores já servem.

  /// Título mais os dois controles compactos.
  ///
  /// `Wrap` com `spaceBetween` resolve a responsividade sem medir a tela: cabendo
  /// na linha, o título fica à esquerda e os chips à direita; não cabendo (o
  /// diálogo no celular tem 90% da largura), os chips descem para a linha de
  /// baixo inteiros, em vez de espremer o título ou estourar na horizontal.
  Widget _buildCabecalho() {
    final theme = Theme.of(context);

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: [
        Text(
          '${widget.fluxo == null ? 'Nova' : 'Editar'} '
          '${widget.tipoFluxo == 'receita' ? 'Receita' : 'Despesa'}',
          style: theme.textTheme.titleLarge,
        ),
        // `Row` e não outro `Wrap`: empilhar os dois chips um sobre o outro
        // gastaria uma terceira linha de cabeçalho no celular. Aqui eles seguem
        // lado a lado e quem cede é o nome da conta, que encolhe com reticências
        // — por isso o `Flexible`.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sem conta cadastrada não há escolha a fazer, e um chip fixo em
            // "Sem conta" seria só ruído: quem nunca cadastrou conta vê o
            // cabeçalho como antes, e grava `id_conta = 0`.
            if (_contas.isNotEmpty) ...[
              Flexible(child: _chipConta()),
              const SizedBox(width: AppSpacing.sm),
            ],
            _chipData(),
          ],
        ),
      ],
    );
  }

  Widget _chipConta() {
    final conta = _contaSelecionada;

    return PopupMenuButton<int>(
      tooltip: 'Conta bancária',
      position: PopupMenuPosition.under,
      initialValue: _contaId,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      onSelected: (v) => setState(() => _contaId = v),
      itemBuilder:
          (context) => [
            // Primeiro e padrão: lançar sem conta continua sendo o caminho
            // normal, não uma exceção escondida no fim da lista.
            const PopupMenuItem(
              value: 0,
              child: Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 20),
                  SizedBox(width: AppSpacing.sm),
                  Text('Sem conta'),
                ],
              ),
            ),
            for (final c in _contas)
              PopupMenuItem(
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
      child: _chip(
        icone:
            conta == null
                ? const Icon(Icons.account_balance_wallet_outlined, size: 16)
                : LogoBanco(
                  chave: conta.imagem,
                  nomeConta: conta.descricao,
                  diametro: 16,
                ),
        texto: conta?.descricao ?? 'Sem conta',
        dica: 'Conta bancária',
      ),
    );
  }

  Widget _chipData() {
    final data = _dataVencimento;

    return InkWell(
      onTap: _selecionarData,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: _chip(
        icone: const Icon(Icons.event, size: 16),
        texto:
            data == null
                ? 'Sem data'
                : '${data.day.toString().padLeft(2, '0')}/'
                    '${data.month.toString().padLeft(2, '0')}/${data.year}',
        dica: 'Data de vencimento',
      ),
    );
  }

  /// Forma comum dos dois chips do cabeçalho.
  ///
  /// O texto tem teto de largura e corta com reticências: nome de conta é livre,
  /// e um "Conta corrente Banco do Brasil agência 1234" empurraria o título para
  /// fora do diálogo.
  ///
  /// Nenhum dos dois leva chevron. Não é só estética: no celular o diálogo tem
  /// 280 lógicos de largura (o `insetPadding` do `AlertDialog` come 40 de cada
  /// lado, independente da largura que o conteúdo pede), sobrando ~232 para o
  /// cabeçalho — e os 18px da seta eram a diferença entre "Sem conta" inteiro e
  /// "Sem con…". A pílula com borda já lê como controle.
  Widget _chip({
    required Widget icone,
    required String texto,
    String? dica,
  }) {
    final theme = Theme.of(context);

    final conteudo = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        // Preenchimento e borda dos campos de texto, não `surfaceContainerHighest`:
        // no tema escuro essa última é a cor do próprio card do diálogo
        // (`darkCardBg`), e o chip desaparecia no fundo. Usar o par do input faz
        // os dois controles lerem como os campos logo abaixo.
        color: theme.inputDecorationTheme.fillColor,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icone,
          const SizedBox(width: AppSpacing.xs),
          // `Flexible` para o chip caber onde o pai apertar (celular), e
          // `ConstrainedBox` para ele não esticar onde há espaço de sobra.
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                texto,
                // `labelMedium` e não `labelLarge`: com o corpo maior, os dois
                // chips somados não cabiam na largura de um celular (360 lógicos
                // dão ~276 úteis no cabeçalho) e "Sem conta" truncava em "Sem…".
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

  Widget _buildRepeticao() {
    return DropdownButtonFormField<String>(
      value: _repeticao,
      isDense: true,
      decoration: const InputDecoration(
        isDense: true,
        labelText: 'Repetição',
      ),
      items: const [
        DropdownMenuItem(value: '1', child: Text('Única vez')),
        DropdownMenuItem(value: '2', child: Text('Diária')),
        DropdownMenuItem(value: '3', child: Text('Semanal')),
        DropdownMenuItem(value: '4', child: Text('Mensal')),
        DropdownMenuItem(value: '5', child: Text('Anual')),
      ],
      onChanged:
          widget.fluxo != null
              ? null
              : (value) {
                if (value != null) {
                  setState(() {
                    _repeticao = value;
                    if (value != '1') {
                      _numeroParcelas = 2;
                      _parcelasController.text = '2';
                    } else {
                      _parcelasController.clear();
                    }
                  });
                }
              },
    );
  }

  List<Widget> _buildCamposParcelamento() {
    final theme = Theme.of(context);
    final valorPorParcela =
        (CurrencyFormatter.parse(_valorController.text) ?? 0) /
        (_numeroParcelas > 0 ? _numeroParcelas : 1);

    return [
      TextFormField(
        controller: _parcelasController,
        decoration: const InputDecoration(
          isDense: true,
          labelText: 'Número de Parcelas',
          helperText: 'Mínimo 2 parcelas',
        ),
        keyboardType: TextInputType.number,
        onChanged: (value) {
          setState(() {
            _numeroParcelas = int.tryParse(value) ?? 1;
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Campo obrigatório';
          }
          final num = int.tryParse(value);
          if (num == null || num < 2) {
            return 'Mínimo 2 parcelas';
          }
          return null;
        },
      ),
      const SizedBox(height: AppSpacing.md),
      RadioListTile<bool>(
        contentPadding: EdgeInsets.zero,
        dense: true,
        visualDensity: VisualDensity.compact,
        title: const Text('Valor é da parcela'),
        value: true,
        groupValue: _valorEhParcela,
        onChanged: (value) {
          setState(() {
            _valorEhParcela = value ?? true;
          });
        },
      ),
      RadioListTile<bool>(
        contentPadding: EdgeInsets.zero,
        dense: true,
        visualDensity: VisualDensity.compact,
        title: const Text('Valor total a dividir'),
        value: false,
        groupValue: _valorEhParcela,
        onChanged: (value) {
          setState(() {
            _valorEhParcela = value ?? true;
          });
        },
      ),
      if (!_valorEhParcela && _numeroParcelas > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Text(
            'Valor por parcela: ${CurrencyFormatter.format(valorPorParcela)}',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
    ];
  }
}
