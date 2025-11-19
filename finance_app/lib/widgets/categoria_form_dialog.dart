import 'package:flutter/material.dart';
import '../models/categoria.dart';
import '../services/api_service.dart';
import '../services/global_state.dart';
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
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Categoria criada com sucesso!'),
                    ),
                  ],
                ),
                backgroundColor: Colors.green.shade700,
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

    return AlertDialog(
      title: Text(
        'Nova Categoria',
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
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _descricaoController,
                autofocus: true,
                style: TextStyle(
                  fontSize: ResponsiveUtils.getFontSize(context),
                ),
                decoration: InputDecoration(
                  labelText: 'Nome da Categoria',
                  labelStyle: TextStyle(
                    fontSize: ResponsiveUtils.getFontSize(context),
                  ),
                  border: const OutlineInputBorder(),
                  helperText: 'Mínimo 3 caracteres',
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
          child: Text(
            'Cancelar',
            style: TextStyle(fontSize: ResponsiveUtils.getFontSize(context)),
          ),
        ),
        _isLoading
            ? Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.responsiveSpacing(
                  mobile: 16.0,
                  tablet: 20.0,
                  desktop: 24.0,
                ),
              ),
              child: SizedBox(
                width: ResponsiveUtils.getIconSize(
                  context,
                  mobile: 20.0,
                  tablet: 22.0,
                  desktop: 24.0,
                ),
                height: ResponsiveUtils.getIconSize(
                  context,
                  mobile: 20.0,
                  tablet: 22.0,
                  desktop: 24.0,
                ),
                child: CircularProgressIndicator(
                  strokeWidth: ResponsiveUtils.isMobile(context) ? 3.0 : 4.0,
                ),
              ),
            )
            : ElevatedButton(
              onPressed: _salvar,
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
