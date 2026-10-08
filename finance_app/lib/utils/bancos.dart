/// Catálogo de bancos para o cadastro de conta bancária.
///
/// O banco de dados guarda **texto**: `finance_conta.imagem` recebe a chave
/// deste catálogo, que é o **código COMPE** da instituição ('104' Caixa, '341'
/// Itaú, '260' Nubank). Nome e cor da marca não vão para o banco — eles são
/// determinados pela chave, e duplicá-los lá só criaria duas verdades.
///
/// ## Por que um catálogo local, e não uma API de logos
///
/// Não existe fonte pública confiável para isto. A BrasilAPI (`/api/banks/v1`)
/// devolve código, ISPB e nome, mas **não logo**; a Logo API da Clearbit, que
/// metade dos tutoriais ainda cita, foi descontinuada no fim de 2024; e as que
/// sobraram pedem chave e impõem limite por mês. Pior que o custo: em Flutter Web
/// uma imagem de outro domínio depende de CORS liberado por terceiro, acrescenta
/// latência no primeiro desenho da tela e falha quando o lojista está sem rede —
/// numa tela cujo único conteúdo é "qual é a sua conta".
///
/// Guardar a imagem em base64 na coluna resolveria o offline e criaria outro
/// problema: toda resposta de lista de contas passaria a carregar os bytes de
/// todos os logos.
///
/// Então o logo é asset local (`assets/images/bancos/<chave>.png`) e a coluna
/// guarda 3 caracteres. A BrasilAPI serve para **gerar** esta lista em
/// desenvolvimento, não em tempo de execução.
///
/// ## Enquanto o PNG não existe
///
/// [LogoBanco] desenha o logo quando o asset está lá e cai na marca de cor +
/// iniciais quando não está (`errorBuilder`). Então o cadastro funciona por
/// inteiro antes de qualquer imagem entrar no repositório, e passa a mostrar o
/// logo assim que o arquivo aparece — sem mudança de código e sem migração.
///
/// Para acrescentar uma instituição: uma entrada aqui, e o PNG com o nome da
/// chave. A chave gravada no banco é o que importa.
library;

import 'package:flutter/material.dart';

import 'categoria_visuais.dart';

/// Uma instituição do catálogo.
///
/// `temLogo` falso é para as contas que não são banco (carteira em espécie, cofre)
/// e para o "outro banco" genérico: elas nunca terão arquivo, então nem se tenta
/// carregar um.
typedef ItemBanco = ({String nome, String cor, String busca, bool temLogo, IconData icone});

abstract final class Bancos {
  /// Pasta dos logos. O arquivo tem o nome da chave: `104` → `104.png`.
  static const String pasta = 'assets/images/bancos';

  /// Usado quando a conta não escolheu instituição, ou quando a chave gravada não
  /// existe mais no catálogo (ele encolheu entre versões do app).
  static const IconData iconeGenerico = Icons.account_balance;

  /// Cor de quem não tem marca — a mesma `corPadrao` das categorias, para a tela
  /// de Contas não introduzir um cinza diferente do resto do app.
  static const String corPadrao = CategoriaVisuais.corPadrao;

  /// Os que aparecem antes de qualquer busca. São os que um lojista cadastra
  /// primeiro, pela presença no varejo brasileiro.
  static const List<String> sugeridos = [
    '104', // Caixa Econômica Federal
    '001', // Banco do Brasil
    '341', // Itaú
    '237', // Bradesco
    '033', // Santander
    '260', // Nubank
    '077', // Inter
    '336', // C6
    'carteira',
    'outro',
  ];

  /// Catálogo. A chave é o código COMPE; `busca` casa os termos digitados sem
  /// acento, incluindo o próprio número do banco.
  ///
  /// As cores são aproximações das cores de marca, usadas **só** como fundo da
  /// marca de fallback e como acento do cartão da conta. Quem decide se o texto
  /// sobre elas sai claro ou escuro é [corDoTexto], pela luminância — por isso
  /// amarelo do Banco do Brasil e preto do C6 convivem na mesma lista.
  static const Map<String, ItemBanco> catalogo = {
    // ── Bancos de varejo ─────────────────────────────────────────────────────
    '104': (
      nome: 'Caixa Econômica Federal',
      cor: '#005CA9',
      busca: 'caixa economica federal cef 104 poupanca',
      temLogo: true,
      icone: Icons.account_balance,
    ),
    '001': (
      nome: 'Banco do Brasil',
      cor: '#F8D200',
      busca: 'banco do brasil bb 001',
      temLogo: true,
      icone: Icons.account_balance,
    ),
    '341': (
      nome: 'Itaú Unibanco',
      cor: '#EC7000',
      busca: 'itau unibanco 341 iti',
      temLogo: true,
      icone: Icons.account_balance,
    ),
    '237': (
      nome: 'Bradesco',
      cor: '#CC092F',
      busca: 'bradesco 237 next',
      temLogo: true,
      icone: Icons.account_balance,
    ),
    '033': (
      nome: 'Santander',
      cor: '#EC0000',
      busca: 'santander 033',
      temLogo: true,
      icone: Icons.account_balance,
    ),
    '422': (
      nome: 'Banco Safra',
      cor: '#003366',
      busca: 'safra 422',
      temLogo: true,
      icone: Icons.account_balance,
    ),
    '208': (
      nome: 'BTG Pactual',
      cor: '#15202B',
      busca: 'btg pactual 208',
      temLogo: true,
      icone: Icons.account_balance,
    ),
    '041': (
      nome: 'Banrisul',
      cor: '#0071BC',
      busca: 'banrisul banco estado rio grande sul 041',
      temLogo: true,
      icone: Icons.account_balance,
    ),
    '070': (
      nome: 'BRB — Banco de Brasília',
      cor: '#003F7F',
      busca: 'brb banco brasilia 070',
      temLogo: true,
      icone: Icons.account_balance,
    ),

    // ── Bancos digitais e contas de pagamento ────────────────────────────────
    '260': (
      nome: 'Nubank',
      cor: '#820AD1',
      busca: 'nubank nu pagamentos roxinho 260',
      temLogo: true,
      icone: Icons.account_balance,
    ),
    '077': (
      nome: 'Banco Inter',
      cor: '#FF7A00',
      busca: 'inter 077 laranja',
      temLogo: true,
      icone: Icons.account_balance,
    ),
    '336': (
      nome: 'C6 Bank',
      cor: '#242424',
      busca: 'c6 bank carbon 336',
      temLogo: true,
      icone: Icons.account_balance,
    ),
    '735': (
      nome: 'Neon',
      cor: '#00C3C8',
      busca: 'neon 735',
      temLogo: true,
      icone: Icons.account_balance,
    ),
    '212': (
      nome: 'Banco Original',
      cor: '#00A86B',
      busca: 'original 212',
      temLogo: true,
      icone: Icons.account_balance,
    ),
    '121': (
      nome: 'Agibank',
      cor: '#00A868',
      busca: 'agibank agi 121',
      temLogo: true,
      icone: Icons.account_balance,
    ),
    '403': (
      nome: 'Cora',
      cor: '#FE3E6D',
      busca: 'cora 403 pj',
      temLogo: true,
      icone: Icons.account_balance,
    ),
    '290': (
      nome: 'PagBank',
      cor: '#0FA958',
      busca: 'pagbank pagseguro uol 290 maquininha',
      temLogo: true,
      icone: Icons.account_balance,
    ),
    '323': (
      nome: 'Mercado Pago',
      cor: '#00AEEF',
      busca: 'mercado pago livre 323',
      temLogo: true,
      icone: Icons.account_balance,
    ),
    '380': (
      nome: 'PicPay',
      cor: '#21C25E',
      busca: 'picpay 380',
      temLogo: true,
      icone: Icons.account_balance,
    ),
    '197': (
      nome: 'Stone',
      cor: '#00A868',
      busca: 'stone ton 197 maquininha',
      temLogo: true,
      icone: Icons.account_balance,
    ),
    '301': (
      nome: 'Banco Cloud (Sumup)',
      cor: '#1F3C88',
      busca: 'sumup cloud 301 maquininha',
      temLogo: true,
      icone: Icons.account_balance,
    ),

    // ── Cooperativas ─────────────────────────────────────────────────────────
    '748': (
      nome: 'Sicredi',
      cor: '#3FA110',
      busca: 'sicredi cooperativa 748',
      temLogo: true,
      icone: Icons.account_balance,
    ),
    '756': (
      nome: 'Sicoob',
      cor: '#00995D',
      busca: 'sicoob bancoob cooperativa 756',
      temLogo: true,
      icone: Icons.account_balance,
    ),
    '085': (
      nome: 'Ailos',
      cor: '#00A0DF',
      busca: 'ailos cecred viacredi cooperativa 085',
      temLogo: true,
      icone: Icons.account_balance,
    ),
    '136': (
      nome: 'Unicred',
      cor: '#0C4DA2',
      busca: 'unicred cooperativa 136',
      temLogo: true,
      icone: Icons.account_balance,
    ),
    '133': (
      nome: 'Cresol',
      cor: '#006B3F',
      busca: 'cresol cooperativa 133',
      temLogo: true,
      icone: Icons.account_balance,
    ),

    // ── Contas que não são banco ──────────────────────────────────────────────
    // Sem logo por natureza: são formas de guardar dinheiro, não instituições.
    // O caixa da loja já tem tela própria ("Caixas"); estas servem para o que
    // fica fora dele, como o cofre e a reserva em espécie.
    'carteira': (
      nome: 'Dinheiro em espécie',
      cor: '#43A047',
      busca: 'dinheiro especie carteira vivo papel',
      temLogo: false,
      icone: Icons.payments,
    ),
    'cofre': (
      nome: 'Cofre / reserva',
      cor: '#6D4C41',
      busca: 'cofre reserva guardado poupado',
      temLogo: false,
      icone: Icons.savings,
    ),
    'outro': (
      nome: 'Outro banco',
      cor: corPadrao,
      busca: 'outro banco diversos generico',
      temLogo: false,
      icone: Icons.account_balance,
    ),
  };

  /// A entrada do catálogo, ou `null` para chave vazia e desconhecida.
  static ItemBanco? de(String? chave) {
    if (chave == null || chave.isEmpty) return null;
    return catalogo[chave];
  }

  /// Nome da instituição. Vazio quando não há chave — quem exibe usa o nome que
  /// o lojista deu à conta, que é o que manda na tela.
  static String nome(String? chave) => de(chave)?.nome ?? '';

  /// Cor da marca, ou a neutra do app para chave ausente/desconhecida.
  static Color cor(String? chave) =>
      CategoriaVisuais.cor(de(chave)?.cor ?? corPadrao);

  /// Ícone de fallback da instituição.
  static IconData icone(String? chave) => de(chave)?.icone ?? iconeGenerico;

  /// Caminho do PNG, ou `null` quando a entrada não tem logo por natureza
  /// (carteira, cofre, "outro") ou a chave é desconhecida.
  ///
  /// O arquivo pode não existir ainda: [LogoBanco] trata isso no `errorBuilder`.
  static String? asset(String? chave) {
    final item = de(chave);
    if (item == null || !item.temLogo) return null;
    return '$pasta/$chave.png';
  }

  /// Texto sobre [fundo] que ainda se lê.
  ///
  /// Branco sobre o amarelo do Banco do Brasil é ilegível, e preto sobre o preto
  /// do C6 também. A luminância decide, então cada marca pode manter a cor real.
  static Color corDoTexto(Color fundo) =>
      fundo.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

  /// Até duas letras para a marca de fallback: as iniciais das duas primeiras
  /// palavras com mais de duas letras ("Caixa Econômica" → "CE"), ou as duas
  /// primeiras letras de uma palavra só ("Nubank" → "NU").
  ///
  /// Recebe o nome digitado pelo lojista, não o do catálogo: é o nome dele que
  /// aparece no cartão, e iniciais que não correspondem confundem mais que
  /// ajudam.
  static String iniciais(String nome) {
    final palavras =
        nome
            .trim()
            .split(RegExp(r'\s+'))
            .where((p) => p.length > 2)
            .toList();

    if (palavras.isEmpty) {
      final limpo = nome.trim();
      if (limpo.isEmpty) return '?';
      return limpo.substring(0, limpo.length > 1 ? 2 : 1).toUpperCase();
    }

    if (palavras.length == 1) {
      final p = palavras.first;
      return p.substring(0, p.length > 1 ? 2 : 1).toUpperCase();
    }

    return (palavras[0][0] + palavras[1][0]).toUpperCase();
  }

  /// Chaves que casam com [termo]; termo vazio devolve tudo com os [sugeridos] à
  /// frente, na ordem em que foram declarados.
  ///
  /// A busca é sem acento e casa também o número do banco, que é como muita gente
  /// procura ("104", "341").
  static List<String> buscar(String termo) {
    final alvo = CategoriaVisuais.semAcento(termo.trim().toLowerCase());

    final chaves =
        alvo.isEmpty
            ? catalogo.keys.toList()
            : catalogo.keys.where((chave) {
              final e = catalogo[chave]!;
              return CategoriaVisuais.semAcento(
                '${e.nome} ${e.busca} $chave'.toLowerCase(),
              ).contains(alvo);
            }).toList();

    chaves.sort((a, b) {
      final ia = sugeridos.indexOf(a);
      final ib = sugeridos.indexOf(b);
      if (ia != ib) {
        if (ia == -1) return 1;
        if (ib == -1) return -1;
        return ia.compareTo(ib);
      }
      return catalogo[a]!.nome.compareTo(catalogo[b]!.nome);
    });

    return chaves;
  }
}
