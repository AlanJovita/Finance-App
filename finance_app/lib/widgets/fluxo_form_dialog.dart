import 'package:flutter/material.dart';
import '../models/fluxo_caixa.dart';
import '../services/api_service.dart';
import '../services/global_state.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';
import '../utils/responsive_utils.dart';
import 'categoria_form_dialog.dart';

class FluxoFormDialog extends StatefulWidget {
  final String tipoFluxo;
  final FluxoCaixa? fluxo;
  final VoidCallback onSave;

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
  bool _isLoading = false;
  DateTime? _dataVencimento;
  bool _confirmado = false;
  String _repeticao = '1'; // 1 = única vez
  int? _categoriaId = 0;
  List<dynamic> _categorias = [];
  int _numeroParcelas = 1;
  bool _valorEhParcela = true; // true = valor da parcela, false = valor total

  @override
  void initState() {
    super.initState();
    _dataVencimento = DateTime.now();

    if (widget.fluxo != null) {
      _descricaoController.text = widget.fluxo!.descricao ?? '';
      _valorController.text = widget.fluxo!.valor?.toString() ?? '';
      _categoriaId = widget.fluxo!.idCategoria ?? 0;
      _dataVencimento = widget.fluxo!.dataVencimento ?? DateTime.now();
      _confirmado = widget.fluxo!.confirmado ?? false;
      _repeticao = widget.fluxo!.repeticao ?? '1';
    }

    // Carregar categorias após definir os valores iniciais
    _loadCategorias();
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _valorController.dispose();
    _parcelasController.dispose();
    super.dispose();
  }

  Future<void> _loadCategorias() async {
    try {
      final categorias = await _apiService.listCategorias();
      setState(() {
        _categorias = categorias;

        // Validar se a categoria selecionada existe na lista
        if (_categoriaId != null && _categoriaId != 0) {
          final categoriaExiste = _categorias.any(
            (cat) => cat.id == _categoriaId,
          );
          if (!categoriaExiste) {
            // Se a categoria não existe, definir como "Sem categoria"
            _categoriaId = 0;
          }
        }
      });
    } catch (e) {
      debugPrint('Erro ao carregar categorias: $e');
    }
  }

  int _gerarIdRef() {
    final now = DateTime.now();
    final idLoja = GlobalState().firstIdLoja;
    return int.parse(
      '$idLoja${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.year}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}',
    );
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
      final valorText = _valorController.text.replaceAll(',', '.');
      final valorBase = double.tryParse(valorText);

      if (valorBase == null) {
        _showError('Valor inválido. Use apenas números');
        return;
      }

      if (valorBase <= 0) {
        _showError('O valor deve ser maior que zero');
        return;
      }

      setState(() => _isLoading = true);

      final tipoFluxoValue = widget.tipoFluxo == 'receita' ? '1' : '2';

      try {
        // Se for edição simples
        if (widget.fluxo != null) {
          final fluxo = FluxoCaixa(
            id: widget.fluxo!.id,
            idLoja: GlobalState().firstIdLoja,
            idCategoria: _categoriaId ?? 0,
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
          );
          await _apiService.updateFluxo(fluxo);
        } else {
          // Nova entrada
          if (_repeticao == '1') {
            // Única vez
            final fluxo = FluxoCaixa(
              id: 0,
              idLoja: GlobalState().firstIdLoja,
              idCategoria: _categoriaId ?? 0,
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
            );
            await _apiService.createFluxo(fluxo);
          } else {
            // Parcelado
            final idRef = _gerarIdRef();
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
              );
              await _apiService.createFluxo(fluxo);
            }
          }
        }

        widget.onSave();
      } catch (e) {
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
          (context) => CategoriaFormDialog(
            tipoFluxo: widget.tipoFluxo == 'receita' ? 1 : 2,
          ),
    );

    if (novaCategoriaId != null) {
      // Recarregar categorias
      await _loadCategorias();
      // Selecionar a categoria recém-criada
      setState(() {
        _categoriaId = novaCategoriaId;
      });
    }
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
      title: Text(
        '${widget.fluxo == null ? 'Nova' : 'Editar'} ${widget.tipoFluxo == 'receita' ? 'Receita' : 'Despesa'}',
      ),
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
                  decoration: const InputDecoration(labelText: 'Descrição'),
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
                const SizedBox(height: AppSpacing.lg),

                TextFormField(
                  controller: _valorController,
                  decoration: const InputDecoration(
                    labelText: 'Valor',
                    prefixText: 'R\$ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Campo obrigatório';
                    }
                    final valorLimpo = value.replaceAll(',', '.');
                    final numero = double.tryParse(valorLimpo);
                    if (numero == null) {
                      return 'Valor inválido';
                    }
                    if (numero <= 0) {
                      return 'Deve ser maior que zero';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                _buildCategoria(),
                const SizedBox(height: AppSpacing.lg),

                _buildDataVencimento(),
                const SizedBox(height: AppSpacing.sm),

                _buildRepeticao(),
                const SizedBox(height: AppSpacing.lg),

                if (_repeticao != '1' && widget.fluxo == null)
                  ..._buildCamposParcelamento(),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
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
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            value:
                _categorias.isEmpty
                    ? null
                    : (_categorias.any((cat) => cat.id == _categoriaId) ||
                        _categoriaId == 0)
                    ? _categoriaId
                    : 0,
            decoration: const InputDecoration(labelText: 'Categoria'),
            items: [
              const DropdownMenuItem(value: 0, child: Text('Sem categoria')),
              ..._categorias.map((cat) {
                return DropdownMenuItem<int>(
                  value: cat.id,
                  child: Text(cat.descricao ?? 'Sem nome'),
                );
              }),
            ],
            onChanged: (value) {
              setState(() {
                _categoriaId = value ?? 0;
              });
            },
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          onPressed: _abrirDialogNovaCategoria,
          icon: const Icon(Icons.add_circle_outline),
          tooltip: 'Nova categoria',
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(AppSpacing.md),
          ),
        ),
      ],
    );
  }

  Widget _buildDataVencimento() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Data de Vencimento'),
      subtitle: Text(
        _dataVencimento != null
            ? '${_dataVencimento!.day.toString().padLeft(2, '0')}/${_dataVencimento!.month.toString().padLeft(2, '0')}/${_dataVencimento!.year}'
            : 'Selecione uma data',
      ),
      trailing: IconButton(
        icon: const Icon(Icons.calendar_today, size: 20),
        onPressed: _selecionarData,
      ),
    );
  }

  Widget _buildRepeticao() {
    return DropdownButtonFormField<String>(
      value: _repeticao,
      decoration: const InputDecoration(labelText: 'Repetição'),
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
        (double.tryParse(_valorController.text.replaceAll(',', '.')) ?? 0) /
        _numeroParcelas;

    return [
      TextFormField(
        controller: _parcelasController,
        decoration: const InputDecoration(
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
      const SizedBox(height: AppSpacing.lg),
      RadioListTile<bool>(
        contentPadding: EdgeInsets.zero,
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
            'Valor por parcela: R\$ $valorPorParcela',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
    ];
  }
}
