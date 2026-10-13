import 'fluxo_caixa.dart';
import 'resumo_fluxo.dart';

double _double(dynamic v) =>
    v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0);

int _int(dynamic v) =>
    v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

List<Map<String, dynamic>> _lista(dynamic v) =>
    (v as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().toList();

/// O que está em aberto de uma natureza — o par receber/pagar de uma situação.
///
/// Receber e pagar moram juntos porque o card os mostra na mesma linha: "a
/// receber" sozinho não diz nada sobre o mês.
class TotaisSituacao {
  final double receber;
  final int qtdReceber;
  final double pagar;
  final int qtdPagar;

  const TotaisSituacao({
    required this.receber,
    required this.qtdReceber,
    required this.pagar,
    required this.qtdPagar,
  });

  const TotaisSituacao.vazio()
      : receber = 0,
        qtdReceber = 0,
        pagar = 0,
        qtdPagar = 0;

  factory TotaisSituacao.fromJson(Map<String, dynamic> json) => TotaisSituacao(
    receber: _double(json['receber']),
    qtdReceber: _int(json['qtd_receber']),
    pagar: _double(json['pagar']),
    qtdPagar: _int(json['qtd_pagar']),
  );

  bool get vazio => receber == 0 && pagar == 0;
}

/// Um dia do mês com movimento (`diario` da resposta).
///
/// A API só manda o dia que tem lançamento — quem completa o mês com zeros é o
/// gráfico, que precisa dos dias vazios para acumular a curva.
class MovimentoDia {
  final int dia;
  final double receitas;
  final double despesas;
  final double receitasRealizado;
  final double despesasRealizado;

  const MovimentoDia({
    required this.dia,
    required this.receitas,
    required this.despesas,
    required this.receitasRealizado,
    required this.despesasRealizado,
  });

  factory MovimentoDia.fromJson(Map<String, dynamic> json) => MovimentoDia(
    dia: _int(json['dia']),
    receitas: _double(json['receitas']),
    despesas: _double(json['despesas']),
    receitasRealizado: _double(json['receitas_realizado']),
    despesasRealizado: _double(json['despesas_realizado']),
  );
}

/// Total de uma categoria no mês — uma fatia da pizza.
///
/// Traz `idCategoria` e mais nada de identidade: descrição, cor e ícone vêm do
/// mapa de categorias que a tela já carrega, para a fatia e o card do mesmo
/// lançamento nunca aparecerem de cores diferentes.
class TotalCategoria {
  final int idCategoria;
  final double valor;
  final int quantidade;

  const TotalCategoria({
    required this.idCategoria,
    required this.valor,
    required this.quantidade,
  });

  factory TotalCategoria.fromJson(Map<String, dynamic> json) => TotalCategoria(
    idCategoria: _int(json['id_categoria']),
    valor: _double(json['valor']),
    quantidade: _int(json['quantidade']),
  );

  /// 0 é "sem categoria" e é um grupo legítimo: a soma das fatias fecha com o
  /// total do mês justamente porque ele não é descartado.
  bool get semCategoria => idCategoria == 0;
}

/// O painel de movimentações inteiro (`GET /fluxo/resumo/painel/<id>`).
///
/// Uma resposta e não cinco porque a tela desenha os blocos todos de uma vez —
/// ver `FinanceBLL.GetResumoPainel` na API, inclusive o porquê de [atraso] e
/// [pendente] **não** terem o recorte de mês que o resto tem.
class ResumoPainel {
  /// `YYYY-MM` do mês em foco, como o servidor o resolveu. A tela não recalcula
  /// o mês corrente: o relógio do aparelho pode estar noutro dia.
  final String mes;

  /// Primeiro e último dia do mês, já resolvidos pelo servidor.
  final DateTime inicio;
  final DateTime fim;

  /// Receitas, despesas e saldo do mês — previsto e realizado.
  final ResumoFluxo resumo;

  /// Vencido e não confirmado, de qualquer data.
  final TotaisSituacao atraso;

  /// Ainda não vencido (ou sem vencimento) e não confirmado.
  final TotaisSituacao pendente;

  /// Só os dias que têm lançamento, em ordem crescente.
  final List<MovimentoDia> diario;

  /// Maior primeiro — é a ordem das fatias.
  final List<TotalCategoria> categoriasReceita;
  final List<TotalCategoria> categoriasDespesa;

  final List<FluxoCaixa> ultimasReceitas;
  final List<FluxoCaixa> ultimasDespesas;

  const ResumoPainel({
    required this.mes,
    required this.inicio,
    required this.fim,
    required this.resumo,
    required this.atraso,
    required this.pendente,
    required this.diario,
    required this.categoriasReceita,
    required this.categoriasDespesa,
    required this.ultimasReceitas,
    required this.ultimasDespesas,
  });

  factory ResumoPainel.fromJson(Map<String, dynamic> json) {
    // `inicio`/`fim` vêm em ISO; o fallback existe para a resposta de uma API
    // antiga não derrubar a tela inteira numa data.
    final inicio = DateTime.tryParse('${json['inicio']}') ?? DateTime.now();

    return ResumoPainel(
      mes: '${json['mes'] ?? ''}',
      inicio: inicio,
      fim:
          DateTime.tryParse('${json['fim']}') ??
          DateTime(inicio.year, inicio.month + 1, 0),
      resumo: ResumoFluxo.fromJson(
        (json['resumo'] as Map<String, dynamic>?) ?? const {},
      ),
      atraso: TotaisSituacao.fromJson(
        (json['atraso'] as Map<String, dynamic>?) ?? const {},
      ),
      pendente: TotaisSituacao.fromJson(
        (json['pendente'] as Map<String, dynamic>?) ?? const {},
      ),
      diario: _lista(json['diario']).map(MovimentoDia.fromJson).toList(),
      categoriasReceita:
          _lista(json['categorias_receita']).map(TotalCategoria.fromJson).toList(),
      categoriasDespesa:
          _lista(json['categorias_despesa']).map(TotalCategoria.fromJson).toList(),
      ultimasReceitas:
          _lista(json['ultimas_receitas']).map(FluxoCaixa.fromJson).toList(),
      ultimasDespesas:
          _lista(json['ultimas_despesas']).map(FluxoCaixa.fromJson).toList(),
    );
  }

  /// A loja nunca lançou nada — é o que decide se o bloco de movimentações
  /// aparece no painel.
  ///
  /// Não basta olhar a quantidade do mês: uma loja que só tem contas atrasadas
  /// de agosto tem o mês corrente vazio e precisa justamente ver o atraso. E
  /// não basta olhar o atraso: um mês todo pago tem as duas situações zeradas e
  /// ainda assim é movimentação.
  bool get vazio =>
      resumo.quantidade == 0 &&
      atraso.vazio &&
      pendente.vazio &&
      ultimasReceitas.isEmpty &&
      ultimasDespesas.isEmpty;
}
