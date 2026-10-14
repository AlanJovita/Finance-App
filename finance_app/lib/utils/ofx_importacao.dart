import '../models/cartao.dart';
import 'ofx.dart';

/// Por que uma linha do arquivo está (ou não está) marcada para importar.
enum SituacaoOfx {
  /// Não existe na fatura: entra marcada.
  novo,

  /// A fatura já tem um movimento igual — o arquivo do mês seguinte traz as
  /// linhas antigas junto. Entra desmarcada.
  jaImportado,

  /// Crédito que parece pagamento de fatura. **Não é importável**: a API o
  /// recusa, porque pagamento é o que dá baixa na despesa da fatura no caixa.
  pagamento,

  /// Crédito que não é pagamento (estorno, cashback). Entra desmarcada: a
  /// natureza é escolha do usuário, e errar aqui abate o saldo do cartão sem
  /// contrapartida no caixa.
  credito,
}

/// Uma linha do arquivo na tela de revisão.
class ItemImportacaoOfx {
  final LancamentoOfx lancamento;
  final SituacaoOfx situacao;

  /// Vai ser importada? Mutável — é o checkbox da lista.
  bool marcado;

  /// Para os créditos: estorno ou cashback. Ignorado nas compras, que são
  /// sempre `NaturezaMovimento.compra`.
  NaturezaMovimento natureza;

  ItemImportacaoOfx({
    required this.lancamento,
    required this.situacao,
    required this.marcado,
    this.natureza = NaturezaMovimento.estorno,
  });

  /// O usuário pode marcar esta linha?
  ///
  /// Pagamento, não: a recusa vem da API e repassá-la como erro depois de o
  /// lojista marcar e esperar seria pior que não oferecer.
  bool get podeMarcar => situacao != SituacaoOfx.pagamento;

  /// O movimento a gravar, ou `null` quando a linha não vai.
  ///
  /// **`totalParcelas` é sempre 1, mesmo em "Parcela 5/12".** O que o extrato
  /// traz é *uma* parcela, já cobrada nesta fatura; mandar 12 faria a API criar
  /// doze linhas em doze faturas consecutivas (é o que `total_parcelas > 1`
  /// significa lá), e o arquivo do mês seguinte traria "Parcela 6/12" para
  /// duplicar tudo de novo. A posição da parcela fica no texto, que é onde o
  /// banco a pôs.
  ///
  /// `dataLancamento` é a data da compra, e é **ela** que decide a fatura — a
  /// API resolve pelo ciclo do cartão, e por isso `id_fatura` não vai no corpo.
  MovimentoCartao? paraMovimento({
    required int idCliente,
    required int idCartao,
    required int idCategoria,
  }) {
    if (!marcado || !podeMarcar) return null;

    final credito = lancamento.credito;

    return MovimentoCartao(
      id: 0,
      idCliente: idCliente,
      idCartao: idCartao,
      // Resolvida no servidor; o model já deixa a chave fora do `toJson`.
      idFatura: 0,
      idCategoria: idCategoria,
      idSubcategoria: 0,
      descricao: lancamento.descricao,
      valor: lancamento.valor,
      tipoFluxo: credito ? 1 : 2,
      natureza: credito ? natureza : NaturezaMovimento.compra,
      cancelado: false,
      dataCriacao: DateTime.now(),
      dataLancamento: lancamento.data,
      repeticao: 1,
      parcela: 1,
      totalParcelas: 1,
      idRef: 0,
    );
  }
}

/// Casa o arquivo com o que a fatura já tem, e decide o estado inicial de cada
/// linha.
///
/// **A deduplicação é por (data + valor + descrição), contando repetição.** Não
/// é por `FITID` porque a coluna não existe no banco — e, mesmo que existisse,
/// o `FITID` do Nubank se repete entre o IOF e a compra internacional que o
/// gerou. A contagem é o que salva o caso real deste extrato: `Pjbank *Saipos`
/// de R$ 99,00 aparece **três vezes** no mesmo dia, com ids diferentes, e as
/// três são legítimas. Comparando por conjunto, duas delas seriam dadas como
/// "já importadas"; contando, se a fatura tem duas, exatamente uma entra.
///
/// O limite conhecido: editar a descrição de um movimento importado faz a
/// próxima importação do mesmo arquivo não reconhecê-lo e oferecê-lo de novo —
/// desmarcar é com o usuário. Fechar isso exigiria guardar o `FITID` no banco.
List<ItemImportacaoOfx> conciliarOfx({
  required List<LancamentoOfx> lancamentos,
  required List<MovimentoCartao> existentes,
}) {
  final contagem = <String, int>{};
  for (final m in existentes) {
    // Cancelado não conta: a linha está na fatura mas não vale nada, e
    // reimportar o lançamento é justamente o que alguém faria depois de
    // cancelar por engano.
    if (m.cancelado) continue;
    final chave = _chave(m.dataLancamento, m.valor, m.descricao);
    if (chave != null) contagem[chave] = (contagem[chave] ?? 0) + 1;
  }

  return [
    for (final l in lancamentos)
      () {
        if (l.parecePagamentoDeFatura) {
          return ItemImportacaoOfx(
            lancamento: l,
            situacao: SituacaoOfx.pagamento,
            marcado: false,
          );
        }

        final chave = _chave(l.data, l.valor, l.descricao)!;
        final restantes = contagem[chave] ?? 0;
        if (restantes > 0) {
          contagem[chave] = restantes - 1;
          return ItemImportacaoOfx(
            lancamento: l,
            situacao: SituacaoOfx.jaImportado,
            marcado: false,
          );
        }

        if (l.credito) {
          return ItemImportacaoOfx(
            lancamento: l,
            situacao: SituacaoOfx.credito,
            marcado: false,
          );
        }

        return ItemImportacaoOfx(
          lancamento: l,
          situacao: SituacaoOfx.novo,
          marcado: true,
        );
      }(),
  ];
}

/// `2026-10-14|10899|pjbank *saipos`.
///
/// Valor em centavos porque `decimal(11,2)` volta como double e 99.00 do banco
/// não é bit a bit o 99.0 do arquivo. Descrição em minúsculas e com espaços
/// colapsados: é a mesma string que o importador gravou, mas o caminho de volta
/// passa por JSON e pelo banco.
String? _chave(DateTime? data, double valor, String descricao) {
  if (data == null) return null;

  final dia =
      '${data.year.toString().padLeft(4, '0')}-'
      '${data.month.toString().padLeft(2, '0')}-'
      '${data.day.toString().padLeft(2, '0')}';
  final centavos = (valor.abs() * 100).round();
  final texto = descricao.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  return '$dia|$centavos|$texto';
}
