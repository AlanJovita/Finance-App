import 'package:flutter/material.dart';
import '../models/categoria.dart';
import '../services/api_service.dart';
import '../services/global_state.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';
import '../utils/responsive_utils.dart';

/// Dialog para criar nova categoria
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
  bool _isLoading = false;

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
    if (_formKey.currentState!.validate()) {
      if (_descricaoController.text.trim().length < 3) {
        _showError('A descrição deve ter no mínimo 3 caracteres');
        return;
      }

      setState(() => _isLoading = true);

      try {
        final novaCategoria = Categoria(
          idLoja: GlobalState().firstIdLoja,
          descricao: _descricaoController.text.trim(),
          ativado: true,
          tipoFluxo: widget.tipoFluxo,
        );

        final response = await _apiService.createCategoria(novaCategoria);

        if (mounted) {
          if (response) {
            // Mostrar mensagem de sucesso
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
            Navigator.of(context).pop();
          } else {
            _showError('Erro: ID da categoria não foi retornado pela API');
          }
        }
      } catch (e) {
        if (mounted) {
          String errorMessage = 'Erro ao criar categoria';

          if (e.toString().contains('FormatException') ||
              e.toString().contains('not valid JSON')) {
            errorMessage =
                'Erro no servidor: O endpoint de criação de categoria pode não estar implementado na API. '
                'Verifique com o desenvolvedor backend.';
          } else if (e.toString().contains('SocketException')) {
            errorMessage = 'Erro de conexão: Verifique sua internet';
          } else if (e.toString().contains('TimeoutException')) {
            errorMessage =
                'Tempo esgotado: O servidor demorou muito para responder';
          } else {
            errorMessage = 'Erro ao criar categoria: ${e.toString()}';
          }

          _showError(errorMessage);
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth =
        ResponsiveUtils.isMobile(context)
            ? MediaQuery.of(context).size.width * 0.9
            : ResponsiveUtils.isTablet(context)
            ? 400.0
            : 450.0;

    // Sem estilo nem padding por campo: o `inputDecorationTheme` do tema já
    // cuida disso para o app inteiro.
    return AlertDialog(
      title: const Text('Nova Categoria'),
      contentPadding: context.responsivePadding(),
      content: SizedBox(
        width: dialogWidth,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _descricaoController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nome da Categoria',
                  helperText: 'Mínimo 3 caracteres',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Campo obrigatório';
                  }
                  if (value.trim().length < 3) {
                    return 'Mínimo 3 caracteres';
                  }
                  return null;
                },
              ),
            ],
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
