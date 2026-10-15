import 'package:flutter/material.dart';

import '../models/categoria.dart';
import '../models/conta.dart';
import '../models/edicao_lote.dart';
import '../models/subcategoria.dart';
import '../utils/app_tokens.dart';
import '../utils/responsive_utils.dart';

/// Altera os mesmos campos em vários lançamentos de uma vez.
///
/// **Nada vem preenchido, e cada campo tem um estado a mais que o formulário
/// normal: "não alterar".** É esse estado que faz o lote gravar só o que foi
/// tocado — e ele é o padrão de todos os campos. Um modal que abrisse com os
/// valores atuais não teria como representar "estes 30 lançamentos têm
/// categorias diferentes", e escolher um deles para mostrar faria o lojista
/// gravar sem querer a categoria do primeiro em todos.
///
/// Por isso os campos são `DropdownButtonFormField` com um item sentinela, e não
/// os seletores ricos do formulário de lançamento: aqui a pergunta não é "qual
/// categoria", é "mexo na categoria?".
///
/// Devolve `null` se o lojista cancelar, e uma [AlteracaoLote] com só os campos
/// preenchidos se confirmar. A confirmação em si — quantos lançamentos, quais
/// propriedades — é da tela que chamou, não daqui.
class EdicaoLoteDialog extends StatefulWidget {
  const EdicaoLoteDialog({
    super.key,
    required this.quantidade,
    required this.campos,
    required this.categorias,
    this.subcategorias = const [],
    this.contas = const [],
  });

  /// Quantos lançamentos estão selecionados. Só aparece no cabeçalho — quem
  /// aplica é a tela.
  final int quantidade;

  /// Quais campos esta tela oferece. O cartão manda só categoria e
  /// subcategoria: `id_conta` e `confirmado` não existem na tabela dele.
  final List<CampoLote> campos;

  final List<Categoria> categorias;
  final List<Subcategoria> subcategorias;
  final List<Conta> contas;

  @override
  State<EdicaoLoteDialog> createState() => _EdicaoLoteDialogState();
}

/// "Não alterar". Fora da faixa dos ids reais (que são positivos) e distinto de
/// 0, que é um valor legítimo — "sem conta", "sem subcategoria".
const int _naoAlterar = -1;

class _EdicaoLoteDialogState extends State<EdicaoLoteDialog> {
  int _conta = _naoAlterar;
  int _categoria = _naoAlterar;
  int _subcategoria = _naoAlterar;
  int _confirmado = _naoAlterar;

  bool _oferece(CampoLote campo) => widget.campos.contains(campo);

  /// As subcategorias da categoria escolhida.
  ///
  /// **Escolher subcategoria exige escolher categoria antes**, e isso não é
  /// capricho de formulário: subcategoria pertence a uma categoria, e aplicar
  /// uma subcategoria a lançamentos de categorias diferentes deixaria a trilha
  /// `Categoria › Subcategoria` mentindo em parte deles.
  ///
  /// A exceção é **limpar**: "Sem subcategoria" é sempre seguro, com ou sem
  /// categoria escolhida, e por isso continua na lista.
  List<Subcategoria> get _subcategoriasDisponiveis {
    if (_categoria <= 0) return const [];
    return widget.subcategorias
        .where((s) => s.idCategoria == _categoria)
        .toList();
  }

  AlteracaoLote _montar() {
    final valores = <CampoLote, Object>{};

    if (_oferece(CampoLote.conta) && _conta != _naoAlterar) {
      valores[CampoLote.conta] = _conta;
    }
    if (_oferece(CampoLote.categoria) && _categoria != _naoAlterar) {
      valores[CampoLote.categoria] = _categoria;
    }
    if (_oferece(CampoLote.subcategoria) && _subcategoria != _naoAlterar) {
      valores[CampoLote.subcategoria] = _subcategoria;
    }
    if (_oferece(CampoLote.confirmado) && _confirmado != _naoAlterar) {
      valores[CampoLote.confirmado] = _confirmado == 1;
    }

    return AlteracaoLote(valores);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alteracao = _montar();

    final largura = ResponsiveUtils.isMobile(context)
        ? MediaQuery.of(context).size.width * 0.9
        : 480.0;

    return AlertDialog(
      title: Text(
        widget.quantidade == 1
            ? 'Alterar 1 lançamento'
            : 'Alterar ${widget.quantidade} lançamentos',
      ),
      contentPadding: context.responsivePadding(),
      content: SizedBox(
        width: largura,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Só os campos que você preencher serão alterados. '
                'O resto fica como está.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              if (_oferece(CampoLote.conta)) ...[
                _campo(
                  rotulo: CampoLote.conta.rotulo,
                  valor: _conta,
                  itens: [
                    const DropdownMenuItem(value: 0, child: Text('Sem conta')),
                    for (final conta in widget.contas)
                      DropdownMenuItem(
                        value: conta.id,
                        child: Text(
                          conta.descricao,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (valor) => setState(() => _conta = valor),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              if (_oferece(CampoLote.categoria)) ...[
                _campo(
                  rotulo: CampoLote.categoria.rotulo,
                  valor: _categoria,
                  itens: [
                    const DropdownMenuItem(
                      value: 0,
                      child: Text('Sem categoria'),
                    ),
                    for (final categoria in widget.categorias)
                      if (categoria.id != null)
                        DropdownMenuItem(
                          value: categoria.id,
                          child: Text(
                            categoria.descricao,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                  ],
                  onChanged: (valor) => setState(() {
                    _categoria = valor;
                    // Trocar a categoria invalida a subcategoria escolhida: ela
                    // era de outra categoria.
                    if (_subcategoria > 0) _subcategoria = _naoAlterar;
                  }),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              if (_oferece(CampoLote.subcategoria)) ...[
                _campo(
                  rotulo: CampoLote.subcategoria.rotulo,
                  valor: _subcategoria,
                  itens: [
                    const DropdownMenuItem(
                      value: 0,
                      child: Text('Sem subcategoria'),
                    ),
                    for (final sub in _subcategoriasDisponiveis)
                      if (sub.id != null)
                        DropdownMenuItem(
                          value: sub.id,
                          child: Text(
                            sub.descricao,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                  ],
                  ajuda: _categoria <= 0
                      ? 'Escolha uma categoria para listar as subcategorias '
                            'dela. Limpar funciona sem isso.'
                      : null,
                  onChanged: (valor) => setState(() => _subcategoria = valor),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              if (_oferece(CampoLote.confirmado))
                _campo(
                  rotulo: CampoLote.confirmado.rotulo,
                  valor: _confirmado,
                  itens: const [
                    DropdownMenuItem(
                      value: 1,
                      child: Text('Marcar como confirmado'),
                    ),
                    DropdownMenuItem(value: 0, child: Text('Desmarcar')),
                  ],
                  // Marcar em lote não é dar baixa: a baixa calcula o valor
                  // líquido a partir de encargos e desconto, e aqui o valor do
                  // lançamento não é tocado.
                  ajuda: _confirmado == 1
                      ? 'O valor de cada lançamento não muda. Para registrar '
                            'encargos ou desconto, use a baixa individual.'
                      : null,
                  onChanged: (valor) => setState(() => _confirmado = valor),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          // Sem nenhum campo preenchido não há o que gravar, e um lote que não
          // altera nada é só uma requisição à toa.
          onPressed: alteracao.vazia
              ? null
              : () => Navigator.of(context).pop(alteracao),
          child: const Text('Continuar'),
        ),
      ],
    );
  }

  Widget _campo({
    required String rotulo,
    required int valor,
    required List<DropdownMenuItem<int>> itens,
    required ValueChanged<int> onChanged,
    String? ajuda,
  }) {
    return DropdownButtonFormField<int>(
      initialValue: valor,
      isExpanded: true,
      decoration: InputDecoration(labelText: rotulo, helperText: ajuda),
      items: [
        const DropdownMenuItem(value: _naoAlterar, child: Text('Não alterar')),
        ...itens,
      ],
      onChanged: (v) => onChanged(v ?? _naoAlterar),
    );
  }
}


/// Abre o modal em lote e, se algo for preenchido, a confirmação.
///
/// Devolve o que aplicar, ou `null` se o lojista desistir em qualquer uma das
/// duas etapas. **São duas etapas de propósito**: o modal é onde se escolhe, e a
/// confirmação é onde se lê em uma frase o que vai acontecer — "Conta e
/// Categoria em 23 lançamentos". Sem ela, um lote de 200 linhas sai de um toque
/// em "Salvar", e não existe desfazer.
Future<AlteracaoLote?> pedirAlteracaoLote(
  BuildContext context, {
  required int quantidade,
  required List<CampoLote> campos,
  required List<Categoria> categorias,
  List<Subcategoria> subcategorias = const [],
  List<Conta> contas = const [],
}) async {
  final alteracao = await showDialog<AlteracaoLote>(
    context: context,
    builder: (_) => EdicaoLoteDialog(
      quantidade: quantidade,
      campos: campos,
      categorias: categorias,
      subcategorias: subcategorias,
      contas: contas,
    ),
  );

  if (alteracao == null || alteracao.vazia) return null;
  if (!context.mounted) return null;

  final confirmou = await showDialog<bool>(
    context: context,
    builder: (_) =>
        _ConfirmacaoLote(alteracao: alteracao, quantidade: quantidade),
  );

  return confirmou == true ? alteracao : null;
}

/// "Isto vai alterar X em N lançamentos. Confirma?"
class _ConfirmacaoLote extends StatelessWidget {
  const _ConfirmacaoLote({required this.alteracao, required this.quantidade});

  final AlteracaoLote alteracao;
  final int quantidade;

  /// "Conta", "Conta e Categoria", "Conta, Categoria e Confirmado".
  String get _propriedades {
    final rotulos = alteracao.rotulos;
    if (rotulos.length == 1) return rotulos.single;
    return '${rotulos.sublist(0, rotulos.length - 1).join(', ')} '
        'e ${rotulos.last}';
  }

  String get _alvo => quantidade == 1
      ? '1 lançamento'
      : '$quantidade lançamentos';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Confirmar alteração em lote'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              style: theme.textTheme.bodyMedium,
              children: [
                const TextSpan(text: 'Serão alterados '),
                TextSpan(
                  text: _propriedades,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: ' em '),
                TextSpan(
                  text: _alvo,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Esta operação não tem desfazer.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
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
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
