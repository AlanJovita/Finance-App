/// Como um lançamento é lido em relação ao vencimento e à recorrência.
///
/// Mora fora das telas porque a lista, o resumo do rodapé e o modal de detalhes
/// precisam concordar: se cada um classificasse por conta própria, a soma das
/// situações deixaria de bater com o total de registros.
library;

import 'package:flutter/material.dart';

import '../models/fluxo_caixa.dart';
import 'app_colors_extension.dart';

/// Janela, em dias, que antecipa o aviso de vencimento.
const int kDiasProximoVencimento = 5;

/// Situação de um lançamento, na nomenclatura que aparece no card.
enum SituacaoFluxo {
  confirmado('Confirmado'),
  atrasado('Atrasado'),
  venceHoje('Vence Hoje'),
  proximoVencimento('Próximo do vencimento'),
  pendente('Pendente'),
  semData('Sem data');

  const SituacaoFluxo(this.rotulo);

  final String rotulo;

  /// Versão curta para o chip do card, onde a linha inteira compete com a
  /// descrição, a categoria e a data.
  String get rotuloCurto => switch (this) {
    SituacaoFluxo.proximoVencimento => 'Próx. vencimento',
    _ => rotulo,
  };

  Color cor(AppColors cores) => switch (this) {
    SituacaoFluxo.confirmado => cores.success,
    SituacaoFluxo.atrasado => cores.error,
    // `serious` existe exatamente para o "vence hoje": passou de aviso, ainda
    // não virou falha.
    SituacaoFluxo.venceHoje => cores.serious,
    SituacaoFluxo.proximoVencimento => cores.warning,
    SituacaoFluxo.pendente || SituacaoFluxo.semData => cores.info,
  };

  IconData get icone => switch (this) {
    SituacaoFluxo.confirmado => Icons.check_circle,
    SituacaoFluxo.atrasado => Icons.error_outline,
    SituacaoFluxo.venceHoje => Icons.today,
    SituacaoFluxo.proximoVencimento => Icons.schedule,
    SituacaoFluxo.pendente => Icons.radio_button_unchecked,
    SituacaoFluxo.semData => Icons.event_busy,
  };

  /// Um lançamento confirmado não é mais cobrado pelo vencimento — por isso a
  /// confirmação é testada antes de qualquer conta de dias.
  static SituacaoFluxo de(FluxoCaixa fluxo, {DateTime? hoje}) {
    if (fluxo.confirmado == true) return SituacaoFluxo.confirmado;

    final dias = diasAteVencimento(fluxo, hoje: hoje);
    if (dias == null) return SituacaoFluxo.semData;
    if (dias < 0) return SituacaoFluxo.atrasado;
    if (dias == 0) return SituacaoFluxo.venceHoje;
    if (dias <= kDiasProximoVencimento) return SituacaoFluxo.proximoVencimento;
    return SituacaoFluxo.pendente;
  }

  /// Dias inteiros entre hoje e o vencimento — negativo quando já passou, nulo
  /// quando o lançamento não tem data.
  ///
  /// As duas pontas viram `DateTime.utc` antes da subtração: em fuso local um
  /// salto de horário de verão faz a diferença dar 23h, e `inDays` truncaria um
  /// dia inteiro de atraso para zero.
  static int? diasAteVencimento(FluxoCaixa fluxo, {DateTime? hoje}) {
    final vencimento = fluxo.dataVencimento;
    if (vencimento == null) return null;

    final agora = hoje ?? DateTime.now();
    final inicio = DateTime.utc(agora.year, agora.month, agora.day);
    final fim = DateTime.utc(
      vencimento.year,
      vencimento.month,
      vencimento.day,
    );

    return fim.difference(inicio).inDays;
  }

  /// Agrupamento de quatro posições usado pelo modal de detalhes. Cobre todas
  /// as situações sem sobreposição, então as quatro somam o total de registros.
  GrupoSituacao get grupo => switch (this) {
    SituacaoFluxo.confirmado => GrupoSituacao.efetivadas,
    SituacaoFluxo.atrasado => GrupoSituacao.vencidas,
    SituacaoFluxo.venceHoje ||
    SituacaoFluxo.proximoVencimento => GrupoSituacao.proximas,
    SituacaoFluxo.pendente || SituacaoFluxo.semData => GrupoSituacao.pendentes,
  };

  /// O rodapé da lista trabalha com três faixas, não com as seis situações:
  /// confirmada, atrasada ou pendente (tudo o mais que ainda vai vencer).
  bool get emAtraso => this == SituacaoFluxo.atrasado;
}

/// As quatro linhas do bloco "situação" no modal de detalhes.
enum GrupoSituacao {
  efetivadas('Efetivadas'),
  proximas('Próximas do vencimento'),
  vencidas('Vencidas'),
  pendentes('Pendentes');

  const GrupoSituacao(this.rotulo);

  final String rotulo;

  Color cor(AppColors cores) => switch (this) {
    GrupoSituacao.efetivadas => cores.success,
    GrupoSituacao.proximas => cores.warning,
    GrupoSituacao.vencidas => cores.error,
    GrupoSituacao.pendentes => cores.info,
  };

  IconData get icone => switch (this) {
    GrupoSituacao.efetivadas => Icons.task_alt,
    GrupoSituacao.proximas => Icons.schedule,
    GrupoSituacao.vencidas => Icons.error_outline,
    GrupoSituacao.pendentes => Icons.radio_button_unchecked,
  };
}

/// As três linhas do bloco "recorrências" no modal de detalhes.
enum TipoRecorrencia {
  fixas('Fixas'),
  parceladas('Parceladas'),
  variaveis('Variáveis');

  const TipoRecorrencia(this.rotulo);

  final String rotulo;

  IconData get icone => switch (this) {
    TipoRecorrencia.fixas => Icons.repeat,
    TipoRecorrencia.parceladas => Icons.format_list_numbered,
    TipoRecorrencia.variaveis => Icons.bolt,
  };

  Color cor(AppColors cores) => switch (this) {
    TipoRecorrencia.fixas => cores.series1,
    TipoRecorrencia.parceladas => cores.series2,
    TipoRecorrencia.variaveis => cores.series3,
  };

  /// `id_ref` agrupa o lote criado de uma vez pelo formulário, então ele é o
  /// sinal mais forte e vem primeiro: hoje toda repetição diferente de "única
  /// vez" nasce parcelada, e testar a repetição antes esvaziaria este grupo.
  /// "Fixas" fica reservado para a recorrência sem lote — o que o formulário
  /// ainda não gera, mas o resumo já sabe contar quando passar a gerar.
  static TipoRecorrencia de(FluxoCaixa fluxo) {
    if ((fluxo.idRef ?? 0) > 0) return TipoRecorrencia.parceladas;

    final repeticao = int.tryParse(fluxo.repeticao ?? '1') ?? 1;
    if (repeticao != 1) return TipoRecorrencia.fixas;

    return TipoRecorrencia.variaveis;
  }
}
