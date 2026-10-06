import 'package:flutter/material.dart';

import '../models/categoria.dart';
import '../models/fluxo_caixa.dart';
import '../models/subcategoria.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';
import '../utils/categoria_visuais.dart';
import '../utils/currency_formatter.dart';
import '../utils/situacao_fluxo.dart';
import 'icone_categoria.dart';

/// Uma conta na lista de receitas ou despesas.
///
/// Mora fora da página para caber num teste de widget sem subir a tela inteira
/// (que instancia `ApiService` no `initState`) — o aperto horizontal deste card
/// é o detalhe mais frágil da tela e precisa ser verificável.
///
/// Recebe a categoria e a subcategoria já resolvidas: quem tem os mapas é a
/// página, e refazer a busca por item seria um `firstWhere` por card a cada
/// rebuild da lista.
class CardFluxo extends StatelessWidget {
  final FluxoCaixa fluxo;
  final Categoria? categoria;
  final Subcategoria? subcategoria;

  /// Cor do valor: sucesso para receita, erro para despesa.
  final Color corValor;

  /// "Pagar" ou "Receber", conforme a natureza da tela.
  final String rotuloAcao;

  final VoidCallback onEditar;
  final VoidCallback onBaixar;
  final VoidCallback onEstornar;
  final VoidCallback onExcluir;

  /// Injetável para o teste fixar o "hoje" e a situação não mudar com o
  /// calendário da máquina.
  final DateTime? hoje;

  const CardFluxo({
    super.key,
    required this.fluxo,
    required this.categoria,
    required this.subcategoria,
    required this.corValor,
    required this.rotuloAcao,
    required this.onEditar,
    required this.onBaixar,
    required this.onEstornar,
    required this.onExcluir,
    this.hoje,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cores = context.appColors;

    final situacao = SituacaoFluxo.de(fluxo, hoje: hoje);
    final corCategoria = CategoriaVisuais.cor(categoria?.cor);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: InkWell(
        onTap: onEditar,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              IconeCategoria(
                iconeCategoria: categoria?.icone,
                corCategoria: corCategoria,
                iconeSubcategoria: subcategoria?.icone,
                temSubcategoria: subcategoria != null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fluxo.descricao ?? 'Sem descrição',
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    _buildLinhaSecundaria(theme, cores, situacao),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    CurrencyFormatter.format(fluxo.valor),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: corValor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _buildBotaoBaixa(theme),
                ],
              ),
              _buildMenu(theme, cores),
            ],
          ),
        ),
      ),
    );
  }

  /// Trilha da categoria, data e situação — a linha que mais disputa espaço.
  ///
  /// O chip não é flexível, para ficar inteiro enquanto houver espaço e empurrar
  /// o encolhimento para a trilha. O teto de largura cobre o caso em que nem ele
  /// caberia sozinho — "Próximo do vencimento" num celular estreito — que sem
  /// isso viraria overflow em vez de reticências.
  Widget _buildLinhaSecundaria(
    ThemeData theme,
    AppColors cores,
    SituacaoFluxo situacao,
  ) {
    return LayoutBuilder(
      builder: (context, limites) {
        // Apertado, o nome da categoria sai e fica só a data: a categoria já
        // está dita pelo círculo colorido à esquerda, enquanto a situação não
        // tem outra representação no card. Antes disto os dois disputavam a
        // linha e o status saía cortado em "Próx. …".
        final compacto = limites.maxWidth < 210;
        final trilha = _trilha(apenasData: compacto);

        final texto = Text(
          trilha,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
        final chip = _buildChipSituacao(theme, cores, situacao, compacto);

        // Quem encolhe é sempre o de comprimento imprevisível. No modo largo é
        // a trilha, que carrega nomes de categoria de qualquer tamanho; no
        // compacto ela já é só "06/10", então fixá-la e deixar o chip ceder
        // garante que a data saia inteira e ainda sobre espaço para o status.
        return Row(
          children: [
            if (trilha.isNotEmpty) ...[
              compacto ? texto : Flexible(child: texto),
              const SizedBox(width: AppSpacing.xs),
            ],
            compacto
                ? Flexible(child: chip)
                : ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: limites.maxWidth * 0.72,
                  ),
                  child: chip,
                ),
          ],
        );
      },
    );
  }

  /// "Categoria › Subcategoria · 05/10" — as partes ausentes somem em vez de
  /// deixar separadores soltos.
  String _trilha({bool apenasData = false}) {
    final partes = <String>[];

    if (categoria != null && !apenasData) {
      partes.add(
        subcategoria == null
            ? categoria!.descricao
            : '${categoria!.descricao} › ${subcategoria!.descricao}',
      );
    }

    final vencimento = fluxo.dataVencimento;
    if (vencimento != null) {
      partes.add(
        '${vencimento.day.toString().padLeft(2, '0')}/'
        '${vencimento.month.toString().padLeft(2, '0')}',
      );
    }

    return partes.join(' · ');
  }

  Widget _buildChipSituacao(
    ThemeData theme,
    AppColors cores,
    SituacaoFluxo situacao,
    bool compacto,
  ) {
    final cor = situacao.cor(cores);

    return Container(
      // No celular o chip se aperta até o limite do legível: cada pixel de
      // respiro aqui é um caractere a menos de reticências no rótulo.
      padding: EdgeInsets.symmetric(
        horizontal: compacto ? 5 : AppSpacing.sm,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(situacao.icone, size: 11, color: cor),
          SizedBox(width: compacto ? 3 : AppSpacing.xs),
          // Flexível para respeitar o teto imposto acima: sem isto o
          // `mainAxisSize.min` do Row ignoraria a restrição e estouraria.
          Flexible(
            child: Text(
              // Só o celular recebe a forma abreviada; onde há largura, o
              // rótulo aparece por extenso.
              compacto ? situacao.rotuloCurto : situacao.rotulo,
              style: theme.textTheme.labelSmall?.copyWith(
                color: cor,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotaoBaixa(ThemeData theme) {
    final confirmado = fluxo.confirmado == true;

    return SizedBox(
      height: 26,
      child:
          confirmado
              ? TextButton(
                onPressed: onEstornar,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: theme.textTheme.labelMedium,
                ),
                child: const Text('Estornar'),
              )
              : FilledButton(
                onPressed: onBaixar,
                style: FilledButton.styleFrom(
                  backgroundColor: corValor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: theme.textTheme.labelMedium,
                ),
                child: Text(rotuloAcao),
              ),
    );
  }

  Widget _buildMenu(ThemeData theme, AppColors cores) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurfaceVariant),
      iconSize: 18,
      padding: EdgeInsets.zero,
      // Sem isto o botão reserva a área de toque padrão de 48px e estica o
      // card de volta para a altura que o compactamos para tirar.
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      onSelected: (value) {
        if (value == 'edit') {
          onEditar();
        } else if (value == 'delete') {
          onExcluir();
        }
      },
      itemBuilder:
          (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20, color: cores.info),
                  const SizedBox(width: AppSpacing.md),
                  const Text('Editar'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: cores.error),
                  const SizedBox(width: AppSpacing.md),
                  const Text('Excluir'),
                ],
              ),
            ),
          ],
    );
  }
}
