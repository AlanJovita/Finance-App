import 'package:flutter/material.dart';
import '../models/fluxo_caixa.dart';
import '../services/api_service.dart';
import '../services/global_state.dart';
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
      print('Erro ao carregar categorias: $e');
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
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
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

    return AlertDialog(
      title: Text(
        '${widget.fluxo == null ? 'Nova' : 'Editar'} ${widget.tipoFluxo == 'receita' ? 'Receita' : 'Despesa'}',
        style: TextStyle(
          fontSize: ResponsiveUtils.getFontSize(
            context,
            mobile: 18.0,
            tablet: 20.0,
            desktop: 22.0,
          ),
        ),
      ),
      contentPadding: context.responsivePadding(
        mobile: 16.0,
        tablet: 20.0,
        desktop: 24.0,
      ),
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
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFontSize(context),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Descrição',
                    labelStyle: TextStyle(
                      fontSize: ResponsiveUtils.getFontSize(context),
                    ),
                    border: const OutlineInputBorder(),
                    helperStyle: TextStyle(
                      fontSize: ResponsiveUtils.getFontSize(
                        context,
                        mobile: 12.0,
                        tablet: 13.0,
                        desktop: 14.0,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: context.responsiveSpacing(),
                      vertical: context.responsiveSpacing(
                        mobile: 12.0,
                        tablet: 14.0,
                        desktop: 16.0,
                      ),
                    ),
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
                SizedBox(height: context.responsiveSpacing()),
                TextFormField(
                  controller: _valorController,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFontSize(context),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Valor',
                    labelStyle: TextStyle(
                      fontSize: ResponsiveUtils.getFontSize(context),
                    ),
                    prefixText: 'R\$ ',
                    border: const OutlineInputBorder(),
                    helperStyle: TextStyle(
                      fontSize: ResponsiveUtils.getFontSize(
                        context,
                        mobile: 12.0,
                        tablet: 13.0,
                        desktop: 14.0,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: context.responsiveSpacing(),
                      vertical: context.responsiveSpacing(
                        mobile: 12.0,
                        tablet: 14.0,
                        desktop: 16.0,
                      ),
                    ),
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
                SizedBox(height: context.responsiveSpacing()),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value:
                            _categorias.isEmpty
                                ? null
                                : (_categorias.any(
                                      (cat) => cat.id == _categoriaId,
                                    ) ||
                                    _categoriaId == 0)
                                ? _categoriaId
                                : 0,
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getFontSize(context),
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Categoria',
                          labelStyle: TextStyle(
                            fontSize: ResponsiveUtils.getFontSize(context),
                          ),
                          border: const OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: context.responsiveSpacing(),
                            vertical: context.responsiveSpacing(
                              mobile: 12.0,
                              tablet: 14.0,
                              desktop: 16.0,
                            ),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 0,
                            child: Text('Sem categoria'),
                          ),
                          ..._categorias.map((cat) {
                            return DropdownMenuItem<int>(
                              value: cat.id,
                              child: Text(
                                cat.descricao ?? 'Sem nome',
                                style: TextStyle(
                                  fontSize: ResponsiveUtils.getFontSize(
                                    context,
                                  ),
                                ),
                              ),
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
                    SizedBox(width: context.responsiveSpacing(mobile: 8.0)),
                    Container(
                      margin: const EdgeInsets.only(top: 8.0),
                      child: IconButton(
                        onPressed: _abrirDialogNovaCategoria,
                        icon: Icon(
                          Icons.add_circle_outline,
                          size: ResponsiveUtils.getIconSize(context),
                        ),
                        tooltip: 'Nova categoria',
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.1),
                          padding: EdgeInsets.all(
                            context.responsiveSpacing(
                              mobile: 12.0,
                              tablet: 14.0,
                              desktop: 16.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.responsiveSpacing()),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Data de Vencimento',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFontSize(context),
                    ),
                  ),
                  subtitle: Text(
                    _dataVencimento != null
                        ? '${_dataVencimento!.day.toString().padLeft(2, '0')}/${_dataVencimento!.month.toString().padLeft(2, '0')}/${_dataVencimento!.year}'
                        : 'Selecione uma data',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFontSize(
                        context,
                        mobile: 13.0,
                        tablet: 14.0,
                        desktop: 15.0,
                      ),
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.calendar_today,
                      size: ResponsiveUtils.getIconSize(
                        context,
                        mobile: 20.0,
                        tablet: 22.0,
                        desktop: 24.0,
                      ),
                    ),
                    onPressed: _selecionarData,
                  ),
                ),
                SizedBox(height: context.responsiveSpacing(mobile: 8.0)),
                DropdownButtonFormField<String>(
                  value: _repeticao,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFontSize(context),
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Repetição',
                    labelStyle: TextStyle(
                      fontSize: ResponsiveUtils.getFontSize(context),
                    ),
                    border: const OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: context.responsiveSpacing(),
                      vertical: context.responsiveSpacing(
                        mobile: 12.0,
                        tablet: 14.0,
                        desktop: 16.0,
                      ),
                    ),
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
                ),
                SizedBox(height: context.responsiveSpacing()),
                if (_repeticao != '1' && widget.fluxo == null) ...[
                  TextFormField(
                    controller: _parcelasController,
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFontSize(context),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Número de Parcelas',
                      labelStyle: TextStyle(
                        fontSize: ResponsiveUtils.getFontSize(context),
                      ),
                      border: const OutlineInputBorder(),
                      helperText: 'Mínimo 2 parcelas',
                      helperStyle: TextStyle(
                        fontSize: ResponsiveUtils.getFontSize(
                          context,
                          mobile: 12.0,
                          tablet: 13.0,
                          desktop: 14.0,
                        ),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: context.responsiveSpacing(),
                        vertical: context.responsiveSpacing(
                          mobile: 12.0,
                          tablet: 14.0,
                          desktop: 16.0,
                        ),
                      ),
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
                  SizedBox(height: context.responsiveSpacing()),
                  RadioListTile<bool>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Valor é da parcela',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFontSize(context),
                      ),
                    ),
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
                    title: Text(
                      'Valor total a dividir',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFontSize(context),
                      ),
                    ),
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
                      padding: EdgeInsets.only(
                        bottom: context.responsiveSpacing(),
                      ),
                      child: Text(
                        'Valor por parcela: R\$ ${(double.tryParse(_valorController.text.replaceAll(',', '.')) ?? 0) / _numeroParcelas}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: ResponsiveUtils.getFontSize(context),
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Confirmado',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFontSize(context),
                    ),
                  ),
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
          child: Text(
            'Cancelar',
            style: TextStyle(fontSize: ResponsiveUtils.getFontSize(context)),
          ),
        ),
        _isLoading
            ? CircularProgressIndicator(
              strokeWidth: ResponsiveUtils.isMobile(context) ? 3.0 : 4.0,
            )
            : ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: context.responsiveSpacing(
                    mobile: 16.0,
                    tablet: 20.0,
                    desktop: 24.0,
                  ),
                  vertical: context.responsiveSpacing(
                    mobile: 12.0,
                    tablet: 14.0,
                    desktop: 16.0,
                  ),
                ),
              ),
              child: Text(
                'Salvar',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getFontSize(context),
                ),
              ),
            ),
      ],
    );
  }
}
