/// Catálogo de bandeiras para o cadastro de cartão de crédito.
///
/// O banco de dados guarda **texto**: `finance_cartao.bandeira` recebe a chave
/// deste catálogo. Nome e cor da marca não vão para o banco — eles são
/// determinados pela chave, e duplicá-los lá só criaria duas verdades. É
/// exatamente a forma de `bancos.dart` e de `categoria_visuais.dart`.
///
/// ## Bandeira e banco são dois campos, não um
///
/// Um cartão tem os dois, e eles variam independentemente: existe Nubank Visa e
/// Nubank Mastercard, e o mesmo Itaú emite Visa, Master e Amex. Guardar só um
/// obrigaria o lojista a escolher qual dos dois identifica o cartão dele — e na
/// prateleira da carteira ele reconhece pelos dois juntos.
///
/// Por isso o catálogo de **banco** do cartão é o de `bancos.dart`, o mesmo da
/// conta bancária: o emissor de um cartão é um banco, e um segundo catálogo de
/// bancos divergiria do primeiro na primeira atualização.
///
/// ## Por que um catálogo local
///
/// Mesma razão de `bancos.dart`, e mais forte aqui: não há API pública de logos
/// de bandeira, e em Flutter Web uma imagem de outro domínio depende de CORS
/// liberado por terceiro. São cinco entradas — a lista praticamente não muda.
///
/// ## Enquanto o PNG não existe
///
/// [LogoBandeira] desenha o logo quando o asset está lá e cai na cor da marca
/// com o ícone genérico de cartão quando não está (`errorBuilder`). O cadastro
/// funciona por inteiro antes de qualquer imagem entrar no repositório, e passa
/// a mostrar o logo assim que o arquivo aparece — sem mudança de código e sem
/// migração.
library;

import 'package:flutter/material.dart';

import 'categoria_visuais.dart';

/// Uma bandeira do catálogo.
///
/// `temLogo` falso é para o "outra bandeira" genérico: nunca terá arquivo, então
/// nem se tenta carregar um.
typedef ItemBandeira = ({String nome, String cor, String busca, bool temLogo});

abstract final class Bandeiras {
  /// Pasta dos logos. O arquivo tem o nome da chave: `visa` → `visa.png`.
  static const String pasta = 'assets/images/bandeiras';

  /// Usado quando o cartão não escolheu bandeira, ou quando a chave gravada não
  /// existe mais no catálogo.
  static const IconData iconeGenerico = Icons.credit_card;

  /// Cor de quem não tem marca — a mesma `corPadrao` das categorias e dos
  /// bancos, para a tela de Cartões não introduzir um cinza diferente do resto
  /// do app.
  static const String corPadrao = CategoriaVisuais.corPadrao;

  /// Catálogo. As cores são aproximações das cores de marca, usadas **só** como
  /// fundo do fallback e como acento do cartão na lista. Quem decide se o texto
  /// sobre elas sai claro ou escuro é [corDoTexto], pela luminância.
  static const Map<String, ItemBandeira> catalogo = {
    'visa': (
      nome: 'Visa',
      cor: '#1A1F71',
      busca: 'visa electron',
      temLogo: true,
    ),
    'mastercard': (
      nome: 'Mastercard',
      cor: '#EB001B',
      busca: 'mastercard master maestro mc',
      temLogo: true,
    ),
    'elo': (
      nome: 'Elo',
      cor: '#00A4E0',
      busca: 'elo',
      temLogo: true,
    ),
    'amex': (
      nome: 'American Express',
      cor: '#006FCF',
      busca: 'american express amex',
      temLogo: true,
    ),
    'hipercard': (
      nome: 'Hipercard',
      cor: '#B3131B',
      busca: 'hipercard hiper',
      temLogo: true,
    ),
    'diners': (
      nome: 'Diners Club',
      cor: '#0079BE',
      busca: 'diners club',
      temLogo: true,
    ),
    'outra': (
      nome: 'Outra bandeira',
      cor: corPadrao,
      busca: 'outra bandeira generica diversos',
      temLogo: false,
    ),
  };

  /// A entrada do catálogo, ou `null` para chave vazia e desconhecida.
  static ItemBandeira? de(String? chave) {
    if (chave == null || chave.isEmpty) return null;
    return catalogo[chave];
  }

  /// Nome da bandeira. Vazio quando não há chave — quem exibe usa o nome que o
  /// lojista deu ao cartão, que é o que manda na tela.
  static String nome(String? chave) => de(chave)?.nome ?? '';

  /// Cor da marca, ou a neutra do app para chave ausente/desconhecida.
  static Color cor(String? chave) =>
      CategoriaVisuais.cor(de(chave)?.cor ?? corPadrao);

  /// Caminho do PNG, ou `null` quando a entrada não tem logo por natureza
  /// ("outra") ou a chave é desconhecida.
  ///
  /// O arquivo pode não existir ainda: [LogoBandeira] trata isso no
  /// `errorBuilder`.
  static String? asset(String? chave) {
    final item = de(chave);
    if (item == null || !item.temLogo) return null;
    return '$pasta/$chave.png';
  }

  /// Texto sobre [fundo] que ainda se lê — mesma regra de `Bancos.corDoTexto`.
  static Color corDoTexto(Color fundo) =>
      fundo.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

  /// Chaves que casam com [termo]; termo vazio devolve tudo na ordem declarada.
  ///
  /// Sem a lista de sugeridos de `bancos.dart`: são sete entradas, e as quatro
  /// primeiras já são as que cobrem o varejo brasileiro — ordenar por relevância
  /// uma lista que cabe inteira na tela não acrescenta nada.
  static List<String> buscar(String termo) {
    final alvo = CategoriaVisuais.semAcento(termo.trim().toLowerCase());

    if (alvo.isEmpty) return catalogo.keys.toList();

    return catalogo.keys.where((chave) {
      final e = catalogo[chave]!;
      return CategoriaVisuais.semAcento(
        '${e.nome} ${e.busca} $chave'.toLowerCase(),
      ).contains(alvo);
    }).toList();
  }
}
