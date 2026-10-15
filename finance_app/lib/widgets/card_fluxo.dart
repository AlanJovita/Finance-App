import 'package:flutter/material.dart';

import '../models/categoria.dart';
import '../models/conta.dart';
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
/// Recebe a categoria, a subcategoria e a conta já resolvidas: quem tem os
/// mapas é a página, e refazer a busca por item seria um `firstWhere` por card
/// a cada rebuild da lista.
///
/// **O que o card diz, e onde.** A marca à esquerda é a categoria, com um selo
/// de situação mordendo o canto: confirmado, atrasado, vence hoje. A linha de
/// baixo é a trilha (`Categoria › Subcategoria · 05/10`) e, à direita, a conta
/// bancária do lançamento. Antes o selo era a subcategoria e o chip era a
/// situação — a situação é o que se lê de relance numa lista de contas a pagar,
/// e a subcategoria continua escrita na trilha.
class CardFluxo extends StatelessWidget {
  final FluxoCaixa fluxo;
  final Categoria? categoria;
  final Subcategoria? subcategoria;

  /// Conta bancária do lançamento, já resolvida. Nula quando o lançamento não
  /// tem conta (`id_conta = 0`, o padrão) ou quando a loja não cadastrou
  /// nenhuma — nos dois casos o chip não aparece, porque "Sem conta" na maioria
  /// das linhas seria só ruído.
  final Conta? conta;

  /// Cor do valor: sucesso para receita, erro para despesa.
  final Color corValor;

  /// "Pagar" ou "Receber", conforme a natureza da tela.
  final String rotuloAcao;

  final VoidCallback onEditar;

  /// Abre o formulário preenchido com este lançamento para gravar **outro**.
  /// Ver `FluxoCaixa.paraClone`, que decide o que o clone não herda.
  final VoidCallback onDuplicar;

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
    this.conta,
    required this.corValor,
    required this.rotuloAcao,
    required this.onEditar,
    required this.onDuplicar,
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
                badge: _seloSituacao(theme, cores, situacao),
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
                    _buildLinhaSecundaria(theme, cores),
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

  /// Trilha da categoria, data e conta — a linha que mais disputa espaço.
  ///
  /// Os dois textos são de comprimento imprevisível (nome de categoria e nome
  /// de conta), então os dois cedem: a trilha primeiro, porque a categoria já
  /// está dita pelo círculo colorido à esquerda. No apertado a trilha fica só
  /// com a data — que é a informação que nada mais no card repete.
  Widget _buildLinhaSecundaria(ThemeData theme, AppColors cores) {
    return LayoutBuilder(
      builder: (context, limites) {
        final compacto = limites.maxWidth < 210;
        final trilha = _trilha(apenasData: compacto);
        final chip = _buildChipConta(theme);

        final texto = Text(
          trilha,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );

        return Row(
          children: [
            if (trilha.isNotEmpty) Flexible(child: texto),
            if (trilha.isNotEmpty && chip != null)
              const SizedBox(width: AppSpacing.xs),
            // Teto de largura para o chip não empurrar a data para fora quando
            // a conta tem nome comprido: aí ele que sai em reticências.
            if (chip != null)
              Flexible(
                child: Align(alignment: Alignment.centerLeft, child: chip),
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

  /// O selo de situação, mordendo o canto da marca da categoria.
  ///
  /// Cor cheia com o glifo em branco, e não o tratamento tonal dos círculos de
  /// categoria: aqui ele precisa ler como **estado**, não como uma segunda
  /// categoria. O anel na cor da superfície do card é o que o descola do
  /// círculo de trás quando as duas cores são próximas.
  ///
  /// Sem rótulo: são seis estados com ícone e cor próprios, e o nome deles
  /// ocupava a linha de baixo inteira — que agora é da conta. Quem precisar do
  /// nome tem o tooltip.
  Widget _seloSituacao(
    ThemeData theme,
    AppColors cores,
    SituacaoFluxo situacao,
  ) {
    final cor = situacao.cor(cores);

    return Tooltip(
      message: situacao.rotulo,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: cor,
          shape: BoxShape.circle,
          border: Border.all(color: theme.cardColor, width: 2),
        ),
        child: Icon(situacao.icone, size: 9, color: Colors.white),
      ),
    );
  }

  /// A conta bancária do lançamento. `null` quando não há conta — e aí a linha
  /// de baixo fica só com a trilha, sem chip vazio ocupando espaço.
  Widget? _buildChipConta(ThemeData theme) {
    final nome = conta?.descricao.trim() ?? '';
    if (nome.isEmpty) return null;

    final cor = theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        // Neutro de propósito: a cor do card já está comprometida com o valor
        // (receita/despesa) e com o selo de situação. Um terceiro tom colorido
        // aqui tiraria a hierarquia dos outros dois.
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_balance, size: 11, color: cor),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              nome,
              style: theme.textTheme.labelSmall?.copyWith(color: cor),
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
                  // `FilledButton` não tem tema no app e cai no `StadiumBorder`
                  // do Material: sem isto ele sairia em cápsula no meio de
                  // cantos retos.
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
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
        } else if (value == 'clone') {
          onDuplicar();
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
            // Entre editar e excluir de propósito: é a vizinha de editar (abre
            // o mesmo formulário) e tem de ficar longe da ação destrutiva.
            PopupMenuItem(
              value: 'clone',
              child: Row(
                children: [
                  Icon(Icons.copy, size: 20, color: cores.info),
                  const SizedBox(width: AppSpacing.md),
                  const Text('Duplicar'),
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
