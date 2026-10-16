/// A tabela da página de Categorias — e a de Subcategorias, que é a mesma.
///
/// **Um widget para as duas de propósito.** As colunas são iguais (ícone,
/// descrição, total, ações) e as ações são as mesmas; o que muda é de onde vêm
/// as linhas, a cor do ícone e quais itens o menu de três pontos oferece. Duas
/// implementações divergiriam no alinhamento das colunas na primeira mudança, e
/// as duas ficam lado a lado na tela — a divergência seria visível.
///
/// Não é um `DataTable`: ele impõe largura mínima por coluna e rola na
/// horizontal quando não cabe, e estas tabelas moram em colunas estreitas (a
/// partir de 360px cada, em celular deitado). A linha aqui é um `InkWell` com
/// um `Row`, que encolhe a descrição por `Expanded` e nunca estoura.
library;

import 'package:flutter/material.dart';

import '../utils/app_tokens.dart';
import '../utils/currency_formatter.dart';
import 'icone_categoria.dart';

/// Uma ação do menu de três pontos.
enum AcaoLinha {
  editar,
  excluir,

  /// Abre a lista de lançamentos da categoria, já filtrada pelo mês.
  ///
  /// Só aparece em **duas colunas**: numa coluna o toque na linha já faz isso,
  /// e repetir a ação no menu seria oferecer o mesmo caminho duas vezes.
  verLancamentos,

  /// Abre as subcategorias numa folha.
  ///
  /// O espelho do item acima: só aparece em **uma coluna**, onde não há painel
  /// à direita para recebê-las.
  subcategorias,
}

/// Uma linha já resolvida: o que a tabela desenha, sem saber de onde veio.
class LinhaCategoria {
  final int id;
  final String descricao;

  /// Nome do ícone Material, resolvido por `CategoriaVisuais.icone`.
  final String? icone;

  /// Já resolvida pelo chamador — na subcategoria é a cor do pai a 70%, e quem
  /// sabe disso é a página, não a tabela.
  final Color cor;

  /// Total do mês. **Inclui as compras do cartão** quando há — ver
  /// `TotalGrupo`.
  final double total;

  /// Quantos movimentos entraram no total. 0 esconde a linha de apoio: "0
  /// movimentações" em metade das linhas seria só ruído.
  final int quantidade;

  const LinhaCategoria({
    required this.id,
    required this.descricao,
    required this.icone,
    required this.cor,
    required this.total,
    required this.quantidade,
  });
}

/// Cabeçalho, linhas e o botão de criar.
class TabelaCategorias extends StatelessWidget {
  const TabelaCategorias({
    super.key,
    required this.titulo,
    required this.linhas,
    required this.acoes,
    required this.onAcao,
    required this.onToqueNaLinha,
    required this.rotuloNovo,
    required this.onNovo,
    this.selecionada,
    this.subtitulo,
    this.vazio,
  });

  final String titulo;

  /// Linha de apoio do cabeçalho — a tabela de subcategorias usa para dizer de
  /// qual categoria elas são.
  final String? subtitulo;

  final List<LinhaCategoria> linhas;

  /// Quais itens o menu de três pontos oferece, na ordem. Varia com a largura
  /// da tela e com a tabela — ver [AcaoLinha].
  final List<AcaoLinha> acoes;

  final void Function(AcaoLinha acao, LinhaCategoria linha) onAcao;

  /// O que o toque na linha faz. Em duas colunas é selecionar; numa coluna é
  /// navegar para os lançamentos. Quem decide é a página.
  final ValueChanged<LinhaCategoria> onToqueNaLinha;

  final String rotuloNovo;
  final VoidCallback onNovo;

  /// Id da linha em foco, pintada com a cor de seleção. Nulo quando não há
  /// seleção — o caso de uma coluna só.
  final int? selecionada;

  /// O que mostrar sem linha nenhuma. Nulo cai num texto genérico.
  final String? vazio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: AppElevation.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cabecalho(context, theme),
          const Divider(height: 1),
          if (linhas.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                vazio ?? 'Nada por aqui',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final linha in linhas) _linha(context, theme, linha),
        ],
      ),
    );
  }

  Widget _cabecalho(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitulo != null)
                  Text(
                    subtitulo!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Ícone e não botão com rótulo: o cabeçalho divide a linha com o
          // título, e "Nova subcategoria" por extenso comeria o nome da
          // categoria em coluna estreita. O tooltip carrega o texto.
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: rotuloNovo,
            visualDensity: VisualDensity.compact,
            onPressed: onNovo,
          ),
        ],
      ),
    );
  }

  Widget _linha(BuildContext context, ThemeData theme, LinhaCategoria linha) {
    final emFoco = selecionada != null && selecionada == linha.id;

    return InkWell(
      onTap: () => onToqueNaLinha(linha),
      child: Container(
        color: emFoco
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : null,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            IconeCategoria(
              iconeCategoria: linha.icone,
              corCategoria: linha.cor,
              diametro: 32,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    linha.descricao,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: emFoco ? FontWeight.w600 : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (linha.quantidade > 0)
                    Text(
                      linha.quantidade == 1
                          ? '1 movimentação'
                          : '${linha.quantidade} movimentações',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // `tabularFigures` alinha a vírgula na coluna inteira: sem isso os
            // valores dançam de uma linha para a outra.
            Text(
              CurrencyFormatter.format(linha.total),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            PopupMenuButton<AcaoLinha>(
              tooltip: 'Opções',
              position: PopupMenuPosition.under,
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (acao) => onAcao(acao, linha),
              itemBuilder: (context) => [
                for (final acao in acoes)
                  PopupMenuItem(
                    value: acao,
                    child: Row(
                      children: [
                        Icon(_icone(acao), size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        // `Expanded` e não `Text` solto: o `PopupMenuItem` dá
                        // ao filho a largura do menu (256 por padrão) com
                        // `mainAxisSize.max`, e "Ver lançamentos" estoura a
                        // linha em telas estreitas.
                        Expanded(
                          child: Text(
                            _rotulo(acao),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static IconData _icone(AcaoLinha acao) => switch (acao) {
    AcaoLinha.editar => Icons.edit_outlined,
    AcaoLinha.excluir => Icons.delete_outline,
    AcaoLinha.verLancamentos => Icons.list_alt,
    AcaoLinha.subcategorias => Icons.account_tree_outlined,
  };

  static String _rotulo(AcaoLinha acao) => switch (acao) {
    AcaoLinha.editar => 'Editar',
    AcaoLinha.excluir => 'Excluir',
    AcaoLinha.verLancamentos => 'Ver lançamentos',
    AcaoLinha.subcategorias => 'Subcategorias',
  };
}
