import 'package:flutter/material.dart';
import '../models/categoria.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../services/global_state.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';
import '../utils/categoria_visuais.dart';
import '../utils/responsive_utils.dart';
import 'seletor_cor_icone.dart';

/// Dialog para criar nova categoria.
///
/// Devolve o id da categoria criada no `pop`, para quem abriu já deixá-la
/// selecionada. `tipo_fluxo` e `id_cliente` não aparecem no formulário: saem do
/// tipo da movimentação e da loja logada.
class CategoriaFormDialog extends StatefulWidget {
  final int tipoFluxo;

  const CategoriaFormDialog({super.key, required this.tipoFluxo});

  @override
  State<CategoriaFormDialog> createState() => _CategoriaFormDialogState();
}

class _CategoriaFormDialogState extends State<CategoriaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  final ApiService _apiService = ApiService();
  final LoggerService _logger = LoggerService();
  bool _isLoading = false;

  String _cor = CategoriaVisuais.paleta.first.hex;
  String? _icone;
  bool _destaque = true;

  @override
  void dispose() {
    _descricaoController.dispose();
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

    try {
      final novaCategoria = Categoria(
        idLoja: GlobalState().firstIdLoja,
        descricao: _descricaoController.text.trim(),
        ativado: true,
        tipoFluxo: widget.tipoFluxo,
        destaque: _destaque,
        icone: _icone,
        cor: _cor,
      );

      // Falha agora vem como exceção, com a mensagem da API. O que chega aqui
      // foi criado: `null` só significa que o endpoint não devolveu o id.
      final novoId =
          await _apiService.createCategoria(novaCategoria) ??
          await _idPelaDescricao(novaCategoria);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('Categoria criada com sucesso!')),
            ],
          ),
          backgroundColor: context.appColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );

      // 0 avisa quem abriu que a categoria existe mas não dá para
      // pré-selecioná-la — diferente de fechar sem valor, que é cancelamento.
      Navigator.of(context).pop(novoId ?? 0);
    } catch (e, s) {
      await _logger.logError(
        'CategoriaFormDialog._salvar',
        e,
        stackTrace: s,
        additionalInfo: {'tipoFluxo': widget.tipoFluxo},
      );
      if (mounted) _showError(_mensagemDeErro(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// A API confirmou a criação sem devolver o id. Relê a lista e procura a
  /// recém-criada pelo nome e pela natureza, ficando com o maior id entre as
  /// que casam — a última inserida.
  Future<int?> _idPelaDescricao(Categoria criada) async {
    try {
      final todas = await _apiService.listCategorias();
      final alvo = criada.descricao.toLowerCase();

      int? achado;
      for (final c in todas) {
        if (c.id != null &&
            c.tipoFluxo == criada.tipoFluxo &&
            c.descricao.trim().toLowerCase() == alvo &&
            (achado == null || c.id! > achado)) {
          achado = c.id;
        }
      }
      return achado;
    } catch (e, s) {
      // Sem o id a categoria apenas não nasce selecionada; não é motivo para
      // transformar uma criação bem-sucedida em erro — mas vai para o log,
      // porque a causa é uma falha de leitura da lista.
      await _logger.logError(
        'CategoriaFormDialog._idPelaDescricao',
        e,
        stackTrace: s,
        additionalInfo: {'descricao': criada.descricao},
      );
      return null;
    }
  }

  String _mensagemDeErro(Object e) {
    final texto = e.toString();

    if (texto.contains('FormatException') || texto.contains('not valid JSON')) {
      return 'Erro no servidor: o endpoint de criação de categoria pode não estar '
          'implementado na API. Verifique com o desenvolvedor backend.';
    }
    if (texto.contains('SocketException')) {
      return 'Erro de conexão: verifique sua internet';
    }
    if (texto.contains('TimeoutException')) {
      return 'Tempo esgotado: o servidor demorou muito para responder';
    }
    return 'Erro ao criar categoria: $texto';
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth =
        ResponsiveUtils.isMobile(context)
            ? MediaQuery.of(context).size.width * 0.9
            : ResponsiveUtils.isTablet(context)
            ? 400.0
            : 450.0;

    final cor = CategoriaVisuais.cor(_cor);

    return AlertDialog(
      title: const Text('Nova Categoria'),
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
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Nome da Categoria',
                    helperText: 'Mínimo 3 caracteres',
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

                SeletorCor(
                  selecionada: _cor,
                  onSelecionar: (hex) => setState(() => _cor = hex),
                ),
                const SizedBox(height: AppSpacing.md),

                SeletorIcone(
                  selecionado: _icone,
                  cor: cor,
                  onSelecionar: (nome) => setState(() => _icone = nome),
                ),
                const SizedBox(height: AppSpacing.xs),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: const Text('Mostrar em destaque'),
                  subtitle: const Text('Aparece entre os 4 círculos'),
                  value: _destaque,
                  onChanged: (v) => setState(() => _destaque = v),
                ),
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
