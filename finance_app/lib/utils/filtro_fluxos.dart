import '../models/fluxo_caixa.dart';
import 'categoria_visuais.dart';
import 'situacao_fluxo.dart';

/// Os quatro filtros da lista de receitas e despesas, num lugar só.
///
/// Todos são **locais**: a tela já tem o mês inteiro em memória, e filtrar no
/// cliente evita uma requisição por tecla digitada e por toque de menu. A
/// função mora fora da página para ser verificável sem subir a tela (que
/// instancia `ApiService` no `initState`) — as três convenções de "vazio" aqui
/// não são iguais e é exatamente aí que isto quebraria em silêncio:
///
/// - [termo] vazio não filtra;
/// - [categoria] **0** não filtra, porque 0 já é "sem categoria" em todo o app
///   e a tela não oferece esse recorte;
/// - [conta] **nula** não filtra, e `0` filtra de verdade: é o recorte "sem
///   conta", o estado de todo lançamento que nunca escolheu uma e de tudo que
///   vem do PDV;
/// - [situacao] nula não filtra.
///
/// [hoje] é injetável porque a situação é relativa ao dia: sem isso o teste
/// mudaria de resultado conforme o calendário da máquina.
bool fluxoPassaNoFiltro(
  FluxoCaixa fluxo, {
  String termo = '',
  int categoria = 0,
  int? conta,
  SituacaoFluxo? situacao,
  DateTime? hoje,
}) {
  if (categoria != 0 && (fluxo.idCategoria ?? 0) != categoria) return false;

  if (conta != null && (fluxo.idConta ?? 0) != conta) return false;

  if (situacao != null && SituacaoFluxo.de(fluxo, hoje: hoje) != situacao) {
    return false;
  }

  final busca = CategoriaVisuais.semAcento(termo.trim().toLowerCase());
  if (busca.isEmpty) return true;

  // Sem acento dos dois lados: quem digita "energia" tem de achar "Energia
  // Elétrica", e quem digita "eletrica" também.
  final descricao = CategoriaVisuais.semAcento(
    (fluxo.descricao ?? '').toLowerCase(),
  );

  return descricao.contains(busca);
}
