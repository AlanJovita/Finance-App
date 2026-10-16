import 'package:flutter/material.dart';
import '../models/subcategoria.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';
import '../utils/categoria_visuais.dart';
import '../utils/responsive_utils.dart';
import 'seletor_cor_icone.dart';

/// Dialog para criar ou editar uma subcategoria.
///
/// **Dois modos, e o que os distingue é [subcategoria].** Nulo cria e devolve o
/// id no `pop`; não nulo edita e devolve `true`.
///
/// **Não tem campo de cor, e a ausência é decisão**: a subcategoria herda a cor
/// da categoria pai a 70% de opacidade, e é isso que a faz ler como variação
/// dele no seletor, na trilha do card e nas fatias do gráfico. Daí
/// [corCategoria], que só serve para pintar a prévia dos ícones aqui dentro —
/// `finance_subcategoria` não tem coluna de cor.
class SubcategoriaFormDialog extends StatefulWidget {
  final int idCategoria;
  final String nomeCategoria;
  final Color corCategoria;

  /// A subcategoria a editar, ou nulo para criar.
  final Subcategoria? subcategoria;

  const SubcategoriaFormDialog({
    super.key,
    required this.idCategoria,
    required this.nomeCategoria,
    required this.corCategoria,
    this.subcategoria,
  });

  @override
  State<SubcategoriaFormDialog> createState() => _SubcategoriaFormDialogState();
}

class _SubcategoriaFormDialogState extends State<SubcategoriaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  final ApiService _apiService = ApiService();
  final LoggerService _logger = LoggerService();
  bool _isLoading = false;

  String? _icone;
  late bool _destaque;

  bool get _ehEdicao => widget.subcategoria != null;

  @override
  void initState() {
    super.initState();

    final atual = widget.subcategoria;

    _icone = atual?.icone;
    _destaque = atual?.destaque ?? true;

    if (atual != null) _descricaoController.text = atual.descricao;
  }

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
      final atual = widget.subcategoria;

      final subcategoria = Subcategoria(
        id: atual?.id,
        // Da subcategoria em edição: mover de categoria não é o que este modal
        // faz, e trocar o pai levaria a filha para outra natureza.
        idCategoria: atual?.idCategoria ?? widget.idCategoria,
        descricao: _descricaoController.text.trim(),
        // Preservado em edição, pelo mesmo motivo da categoria: o formulário
        // não oferece arquivar, e `true` por reflexo reativaria o que o lojista
        // tinha tirado do seletor.
        ativado: atual?.ativado ?? true,
        destaque: _destaque,
        icone: _icone,
      );

      if (_ehEdicao) {
        await _apiService.updateSubcategoria(subcategoria);

        if (!mounted) return;
        _showOk('Subcategoria atualizada!');
        Navigator.of(context).pop(true);
        return;
      }

      // Falha agora vem como exceção, com a mensagem da API. O que chega aqui
      // foi criado: `null` só significa que o endpoint não devolveu o id.
      final novoId =
          await _apiService.createSubcategoria(subcategoria) ??
          await _idPelaDescricao(subcategoria);

      if (!mounted) return;

      _showOk('Subcategoria criada com sucesso!');

      // 0 avisa quem abriu que a subcategoria existe mas não dá para
      // pré-selecioná-la — diferente de fechar sem valor, que é cancelamento.
      Navigator.of(context).pop(novoId ?? 0);
    } catch (e, s) {
      await _logger.logError(
        'SubcategoriaFormDialog._salvar',
        e,
        stackTrace: s,
        additionalInfo: {
          'idCategoria': widget.idCategoria,
          'edicao': _ehEdicao,
          'id': widget.subcategoria?.id,
        },
      );
      if (mounted) {
        _showError(
          _ehEdicao
              ? 'Erro ao editar subcategoria: $e'
              : 'Erro ao criar subcategoria: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showOk(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(mensagem)),
          ],
        ),
        backgroundColor: context.appColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// A API confirmou a criação sem devolver o id. Relê a lista e procura a
  /// recém-criada pela categoria e pelo nome, ficando com o maior id entre as
  /// que casam — a última inserida.
  Future<int?> _idPelaDescricao(Subcategoria criada) async {
    try {
      final todas = await _apiService.listSubcategorias();
      final alvo = criada.descricao.toLowerCase();

      int? achado;
      for (final s in todas) {
        if (s.id != null &&
            s.idCategoria == criada.idCategoria &&
            s.descricao.trim().toLowerCase() == alvo &&
            (achado == null || s.id! > achado)) {
          achado = s.id;
        }
      }
      return achado;
    } catch (e, s) {
      // Sem o id a subcategoria apenas não nasce selecionada; não é motivo
      // para transformar uma criação bem-sucedida em erro — mas vai para o log,
      // porque a causa é uma falha de leitura da lista.
      await _logger.logError(
        'SubcategoriaFormDialog._idPelaDescricao',
        e,
        stackTrace: s,
        additionalInfo: {'descricao': criada.descricao},
      );
      return null;
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

    final cor = widget.corCategoria.withValues(
      alpha: CategoriaVisuais.opacidadeSubcategoria,
    );

    return AlertDialog(
      title: Text(_ehEdicao ? 'Editar Subcategoria' : 'Nova Subcategoria'),
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
                Text(
                  'Em ${widget.nomeCategoria}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                TextFormField(
                  controller: _descricaoController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  // Largura de `finance_subcategoria.descricao`. Sem o limite,
                  // um nome mais longo só é recusado no servidor, e a mensagem
                  // que chega é a genérica "Falha ao executar o comando".
                  maxLength: 100,
                  // O contador "0/100" não cabe no layout do dialog, e o limite
                  // é alto o bastante para ninguém encostar nele por acidente.
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Nome da Subcategoria',
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
