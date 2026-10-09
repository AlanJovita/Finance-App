import 'package:flutter/material.dart';

import '../models/cartao.dart';
import '../models/categoria.dart';
import '../models/subcategoria.dart';
import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';
import '../utils/categoria_visuais.dart';
import '../utils/currency_formatter.dart';
import 'icone_categoria.dart';

/// Um lançamento na lista de uma fatura.
///
/// Gêmeo do [CardFluxo], com as diferenças que vêm do domínio do cartão:
///
/// - **Não há botão de baixa.** No cartão não existe baixa de lançamento: o que
///   liquida uma compra é o pagamento da fatura em que ela caiu. O espaço que o
///   botão ocupava no card do caixa é o que deixa este card mais baixo.
/// - **O chip é a natureza**, não a situação. "Pendente/atrasado" é da fatura,
///   não da compra — uma compra não vence; a fatura vence.
/// - **O valor de um crédito aparece com sinal.** Compra e crédito dividem a
///   lista, e sem o `−` a única diferença entre os dois seria a cor.
///
/// Recebe a categoria e a subcategoria já resolvidas: quem tem os mapas é a
/// página, e refazer a busca por item seria um `firstWhere` por card a cada
/// rebuild da lista.
class CardMovimentoCartao extends StatelessWidget {
  final MovimentoCartao movimento;
  final Categoria? categoria;
  final Subcategoria? subcategoria;

  /// Ligado quando a fatura já fechou: a API recusa a edição, então oferecê-la
  /// levaria a uma mensagem de erro em vez de a um formulário.
  final bool faturaFechada;

  final VoidCallback onEditar;
  final VoidCallback onExcluir;

  const CardMovimentoCartao({
    super.key,
    required this.movimento,
    required this.categoria,
    required this.subcategoria,
    required this.faturaFechada,
    required this.onEditar,
    required this.onExcluir,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cores = context.appColors;

    final credito = movimento.ehCredito;
    final cancelado = movimento.cancelado;
    final corValor = credito ? cores.success : cores.error;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      // Cancelado fica atenuado em vez de sair da lista: ele continua no
      // histórico da fatura, e esconder um lançamento que existe é pior que
      // mostrá-lo riscado.
      color: cancelado ? theme.colorScheme.surfaceContainerHighest : null,
      elevation: cancelado ? AppElevation.none : AppElevation.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: InkWell(
        onTap: faturaFechada ? null : onEditar,
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
              Opacity(
                opacity: cancelado ? 0.5 : 1,
                child:
                    credito
                        ? _iconeCredito(theme, cores)
                        : IconeCategoria(
                          iconeCategoria: categoria?.icone,
                          corCategoria: CategoriaVisuais.cor(categoria?.cor),
                          iconeSubcategoria: subcategoria?.icone,
                          temSubcategoria: subcategoria != null,
                        ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      movimento.descricao.isEmpty
                          ? 'Sem descrição'
                          : movimento.descricao,
                      style: theme.textTheme.titleSmall?.copyWith(
                        decoration:
                            cancelado ? TextDecoration.lineThrough : null,
                        color: cancelado
                            ? theme.colorScheme.onSurfaceVariant
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    _buildLinhaSecundaria(theme, cores),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${credito ? '− ' : ''}'
                '${CurrencyFormatter.format(movimento.valor)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: cancelado ? theme.colorScheme.onSurfaceVariant : corValor,
                  fontWeight: FontWeight.w600,
                  decoration: cancelado ? TextDecoration.lineThrough : null,
                ),
              ),
              _buildMenu(theme, cores),
            ],
          ),
        ),
      ),
    );
  }

  /// Crédito não tem categoria obrigatória (pagamento de fatura nasce sem
  /// nenhuma), então o ícone vem da natureza — que é o que o distingue de uma
  /// compra na lista.
  Widget _iconeCredito(ThemeData theme, AppColors cores) {
    final icone = switch (movimento.natureza) {
      NaturezaMovimento.pagamento => Icons.price_check,
      NaturezaMovimento.estorno => Icons.undo,
      NaturezaMovimento.cashback => Icons.savings_outlined,
      NaturezaMovimento.compra => Icons.shopping_cart_outlined,
    };

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cores.success.withValues(alpha: 0.15),
      ),
      child: Icon(icone, size: 20, color: cores.success),
    );
  }

  /// Trilha da categoria, data da compra e o chip da natureza ou da parcela.
  ///
  /// A data é a da **compra**, não um vencimento: foi ela que decidiu em qual
  /// fatura o lançamento caiu, e é o que o lojista confere contra o comprovante.
  Widget _buildLinhaSecundaria(ThemeData theme, AppColors cores) {
    final partes = <String>[];

    if (categoria != null) {
      partes.add(
        subcategoria == null
            ? categoria!.descricao
            : '${categoria!.descricao} › ${subcategoria!.descricao}',
      );
    } else if (movimento.ehCredito) {
      partes.add(movimento.natureza.rotulo);
    }

    final data = movimento.dataLancamento;
    if (data != null) {
      partes.add(
        '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}',
      );
    }

    final texto = Text(
      partes.join(' · '),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    // O chip da parcela é o que diz que este valor se repete nas faturas
    // seguintes — a informação mais consequente de um lançamento de cartão, e a
    // que não se deduz do card.
    final chip =
        movimento.ehParcelado
            ? _chip(theme, movimento.rotuloParcela, cores.info, Icons.repeat)
            : null;

    return Row(
      children: [
        Flexible(child: texto),
        if (chip != null) ...[
          const SizedBox(width: AppSpacing.xs),
          chip,
        ],
      ],
    );
  }

  Widget _chip(ThemeData theme, String texto, Color cor, IconData icone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 11, color: cor),
          const SizedBox(width: 3),
          Text(
            texto,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenu(ThemeData theme, AppColors cores) {
    // Pagamento não se edita: ele deu baixa na despesa da fatura no caixa, e
    // mudar o valor dele deixaria as duas pontas discordando. Apagar desfaz as
    // duas coisas de uma vez, e é por isso que continua oferecido.
    final podeEditar = !faturaFechada && !movimento.ehPagamento;

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurfaceVariant),
      iconSize: 18,
      padding: EdgeInsets.zero,
      // Sem isto o botão reserva a área de toque padrão de 48px e estica o card
      // de volta para a altura que o compactamos para tirar.
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      onSelected: (value) {
        if (value == 'edit') onEditar();
        if (value == 'delete') onExcluir();
      },
      itemBuilder:
          (context) => [
            if (podeEditar)
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
                  Text(movimento.ehPagamento ? 'Apagar pagamento' : 'Excluir'),
                ],
              ),
            ),
          ],
    );
  }
}
