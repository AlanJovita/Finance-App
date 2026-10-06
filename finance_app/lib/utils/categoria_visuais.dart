/// Cores e ícones que uma categoria (ou subcategoria) pode assumir.
///
/// O banco guarda texto: `cor` como `#RRGGBB` e `icone` como o nome da chave
/// deste catálogo (ex.: `shopping_cart`). Resolver nome → [IconData] por um mapa
/// constante é o que permite o `--tree-shake-icons` do Flutter continuar
/// funcionando; montar `IconData(codePoint)` dinamicamente desligaria a poda e
/// o ícone sairia em branco no build de release.
library;

import 'package:flutter/material.dart';

abstract final class CategoriaVisuais {
  /// Usado quando a categoria não tem ícone escolhido.
  static const IconData iconeGenerico = Icons.label_outline;

  /// Opacidade da cor da categoria pai quando pintamos uma subcategoria — a
  /// filha lê como variação do pai, não como uma categoria solta.
  static const double opacidadeSubcategoria = 0.7;

  /// Paleta fixa. A ordem é a da grade no formulário.
  static const List<({String nome, String hex})> paleta = [
    (nome: 'Vermelho', hex: '#E53935'),
    (nome: 'Rosa', hex: '#D81B60'),
    (nome: 'Roxo', hex: '#8E24AA'),
    (nome: 'Índigo', hex: '#3949AB'),
    (nome: 'Azul', hex: '#1E88E5'),
    (nome: 'Ciano', hex: '#00ACC1'),
    (nome: 'Verde-água', hex: '#00897B'),
    (nome: 'Verde', hex: '#43A047'),
    (nome: 'Lima', hex: '#7CB342'),
    (nome: 'Âmbar', hex: '#FFB300'),
    (nome: 'Laranja', hex: '#FB8C00'),
    (nome: 'Marrom', hex: '#6D4C41'),
    (nome: 'Cinza', hex: '#546E7A'),
    (nome: 'Grafite', hex: '#37474F'),
  ];

  /// Cor aplicada quando a categoria não escolheu nenhuma.
  static const String corPadrao = '#546E7A';

  /// Os que aparecem na primeira faixa do seletor de ícone, antes da busca.
  /// São os casos que o lojista cadastra primeiro.
  static const List<String> iconesSugeridos = [
    'restaurant',
    'shopping_cart',
    'directions_car',
    'home',
    'payments',
    'trending_up',
    'local_shipping',
    'receipt_long',
    'bolt',
    'medical_services',
  ];

  /// Catálogo completo, com os termos em português que a busca casa.
  ///
  /// Não é a lista inteira do Material (≈2000 ícones): é uma curadoria do que
  /// faz sentido num controle de caixa de loja. Para incluir um ícone novo
  /// basta acrescentar a entrada aqui — o valor gravado no banco é a chave.
  static const Map<String, ({IconData icone, String rotulo, String busca})>
  catalogo = {
    // Alimentação
    'restaurant': (
      icone: Icons.restaurant,
      rotulo: 'Restaurante',
      busca: 'alimentacao comida refeicao almoco jantar restaurante',
    ),
    'local_cafe': (
      icone: Icons.local_cafe,
      rotulo: 'Café',
      busca: 'cafe lanche padaria bebida',
    ),
    'local_bar': (
      icone: Icons.local_bar,
      rotulo: 'Bar',
      busca: 'bar bebida drinque cerveja',
    ),
    'lunch_dining': (
      icone: Icons.lunch_dining,
      rotulo: 'Lanche',
      busca: 'lanche hamburguer fast food',
    ),
    'bakery_dining': (
      icone: Icons.bakery_dining,
      rotulo: 'Padaria',
      busca: 'padaria pao confeitaria',
    ),
    'shopping_cart': (
      icone: Icons.shopping_cart,
      rotulo: 'Mercado',
      busca: 'mercado supermercado compras carrinho',
    ),
    'shopping_bag': (
      icone: Icons.shopping_bag,
      rotulo: 'Compras',
      busca: 'compras sacola loja varejo',
    ),
    'storefront': (
      icone: Icons.storefront,
      rotulo: 'Loja',
      busca: 'loja comercio ponto venda',
    ),
    'eco': (
      icone: Icons.eco,
      rotulo: 'Hortifruti',
      busca: 'hortifruti verdura fruta natural organico',
    ),
    'icecream': (
      icone: Icons.icecream,
      rotulo: 'Sorvete',
      busca: 'sorvete sobremesa doce',
    ),

    // Transporte
    'directions_car': (
      icone: Icons.directions_car,
      rotulo: 'Carro',
      busca: 'carro veiculo automovel transporte',
    ),
    'local_gas_station': (
      icone: Icons.local_gas_station,
      rotulo: 'Combustível',
      busca: 'combustivel gasolina posto alcool diesel',
    ),
    'two_wheeler': (
      icone: Icons.two_wheeler,
      rotulo: 'Moto',
      busca: 'moto motoboy entrega duas rodas',
    ),
    'local_shipping': (
      icone: Icons.local_shipping,
      rotulo: 'Frete',
      busca: 'frete entrega transporte caminhao logistica',
    ),
    'directions_bus': (
      icone: Icons.directions_bus,
      rotulo: 'Ônibus',
      busca: 'onibus transporte publico passagem',
    ),
    'local_taxi': (
      icone: Icons.local_taxi,
      rotulo: 'Táxi',
      busca: 'taxi aplicativo corrida uber',
    ),
    'flight': (
      icone: Icons.flight,
      rotulo: 'Viagem',
      busca: 'viagem aviao passagem aerea turismo',
    ),
    'build': (
      icone: Icons.build,
      rotulo: 'Manutenção',
      busca: 'manutencao conserto oficina reparo ferramenta',
    ),

    // Casa e contas
    'home': (
      icone: Icons.home,
      rotulo: 'Casa',
      busca: 'casa moradia residencia lar',
    ),
    'house': (
      icone: Icons.house,
      rotulo: 'Aluguel',
      busca: 'aluguel imovel locacao condominio',
    ),
    'bolt': (
      icone: Icons.bolt,
      rotulo: 'Energia',
      busca: 'energia luz eletrica conta',
    ),
    'water_drop': (
      icone: Icons.water_drop,
      rotulo: 'Água',
      busca: 'agua saneamento conta',
    ),
    'local_fire_department': (
      icone: Icons.local_fire_department,
      rotulo: 'Gás',
      busca: 'gas botijao gnv',
    ),
    'wifi': (
      icone: Icons.wifi,
      rotulo: 'Internet',
      busca: 'internet wifi banda larga telecom',
    ),
    'phone_iphone': (
      icone: Icons.phone_iphone,
      rotulo: 'Telefone',
      busca: 'telefone celular telefonia conta',
    ),
    'cleaning_services': (
      icone: Icons.cleaning_services,
      rotulo: 'Limpeza',
      busca: 'limpeza faxina higiene produto',
    ),
    'chair': (
      icone: Icons.chair,
      rotulo: 'Móveis',
      busca: 'moveis mobilia decoracao',
    ),

    // Receitas e finanças
    'payments': (
      icone: Icons.payments,
      rotulo: 'Salário',
      busca: 'salario pagamento pro labore renda receita',
    ),
    'attach_money': (
      icone: Icons.attach_money,
      rotulo: 'Dinheiro',
      busca: 'dinheiro especie caixa venda',
    ),
    'trending_up': (
      icone: Icons.trending_up,
      rotulo: 'Investimentos',
      busca: 'investimento aplicacao rendimento juros lucro',
    ),
    'savings': (
      icone: Icons.savings,
      rotulo: 'Poupança',
      busca: 'poupanca reserva economia cofre',
    ),
    'credit_card': (
      icone: Icons.credit_card,
      rotulo: 'Cartão',
      busca: 'cartao credito debito maquininha',
    ),
    'account_balance': (
      icone: Icons.account_balance,
      rotulo: 'Banco',
      busca: 'banco tarifa conta bancaria',
    ),
    'pix': (
      icone: Icons.pix,
      rotulo: 'Pix',
      busca: 'pix transferencia instantanea',
    ),
    'receipt_long': (
      icone: Icons.receipt_long,
      rotulo: 'Impostos',
      busca: 'imposto tributo nota fiscal das simples',
    ),
    'request_quote': (
      icone: Icons.request_quote,
      rotulo: 'Boleto',
      busca: 'boleto fatura cobranca duplicata',
    ),
    'percent': (
      icone: Icons.percent,
      rotulo: 'Taxas',
      busca: 'taxa juros comissao desconto',
    ),
    'handshake': (
      icone: Icons.handshake,
      rotulo: 'Fornecedor',
      busca: 'fornecedor parceiro compra insumo',
    ),
    'inventory_2': (
      icone: Icons.inventory_2,
      rotulo: 'Estoque',
      busca: 'estoque mercadoria insumo produto',
    ),

    // Pessoas e serviços
    'groups': (
      icone: Icons.groups,
      rotulo: 'Funcionários',
      busca: 'funcionario equipe folha pessoal salario',
    ),
    'school': (
      icone: Icons.school,
      rotulo: 'Educação',
      busca: 'educacao escola curso faculdade treinamento',
    ),
    'medical_services': (
      icone: Icons.medical_services,
      rotulo: 'Saúde',
      busca: 'saude medico plano farmacia consulta',
    ),
    'fitness_center': (
      icone: Icons.fitness_center,
      rotulo: 'Academia',
      busca: 'academia esporte treino',
    ),
    'pets': (icone: Icons.pets, rotulo: 'Pets', busca: 'pet animal veterinario'),
    'child_care': (
      icone: Icons.child_care,
      rotulo: 'Filhos',
      busca: 'filho crianca creche bebe',
    ),
    'volunteer_activism': (
      icone: Icons.volunteer_activism,
      rotulo: 'Doação',
      busca: 'doacao caridade ajuda contribuicao',
    ),
    'gavel': (
      icone: Icons.gavel,
      rotulo: 'Jurídico',
      busca: 'juridico advogado contabilidade honorario',
    ),

    // Lazer e outros
    'sports_esports': (
      icone: Icons.sports_esports,
      rotulo: 'Lazer',
      busca: 'lazer jogo diversao entretenimento',
    ),
    'movie': (
      icone: Icons.movie,
      rotulo: 'Streaming',
      busca: 'streaming cinema filme assinatura',
    ),
    'card_giftcard': (
      icone: Icons.card_giftcard,
      rotulo: 'Presentes',
      busca: 'presente brinde gift',
    ),
    'celebration': (
      icone: Icons.celebration,
      rotulo: 'Eventos',
      busca: 'evento festa confraternizacao',
    ),
    'campaign': (
      icone: Icons.campaign,
      rotulo: 'Marketing',
      busca: 'marketing propaganda anuncio publicidade',
    ),
    'computer': (
      icone: Icons.computer,
      rotulo: 'Tecnologia',
      busca: 'tecnologia software sistema informatica',
    ),
    'checkroom': (
      icone: Icons.checkroom,
      rotulo: 'Vestuário',
      busca: 'roupa vestuario uniforme moda',
    ),
    'content_cut': (
      icone: Icons.content_cut,
      rotulo: 'Beleza',
      busca: 'beleza salao cabelo estetica',
    ),
    'shield': (
      icone: Icons.shield,
      rotulo: 'Seguro',
      busca: 'seguro protecao apolice',
    ),
    'more_horiz': (
      icone: Icons.more_horiz,
      rotulo: 'Outros',
      busca: 'outros diversos geral',
    ),
  };

  /// Resolve o nome gravado no banco para o ícone. Nome vazio, nulo ou
  /// desconhecido (catálogo encolheu entre versões) cai no genérico.
  static IconData icone(String? nome) {
    if (nome == null || nome.isEmpty) return iconeGenerico;
    return catalogo[nome]?.icone ?? iconeGenerico;
  }

  /// Converte `#RRGGBB` (ou `RRGGBB`) na cor. Entrada inválida cai em
  /// [corPadrao], para um registro torto não derrubar a tela.
  static Color cor(String? hex) {
    final limpo = (hex ?? '').trim().replaceFirst('#', '');
    final valor = int.tryParse(limpo, radix: 16);

    if (valor == null || (limpo.length != 6 && limpo.length != 8)) {
      return cor(corPadrao);
    }

    // 6 dígitos vêm sem alfa: completa opaco.
    return Color(limpo.length == 6 ? 0xFF000000 | valor : valor);
  }

  /// Nomes do catálogo que casam com [termo]. Termo vazio devolve tudo, com os
  /// [iconesSugeridos] à frente.
  static List<String> buscarIcones(String termo) {
    final alvo = semAcento(termo.trim().toLowerCase());

    final nomes =
        alvo.isEmpty
            ? catalogo.keys.toList()
            : catalogo.keys.where((nome) {
              final e = catalogo[nome]!;
              return semAcento('${e.rotulo} ${e.busca} $nome').contains(alvo);
            }).toList();

    nomes.sort((a, b) {
      final ia = iconesSugeridos.indexOf(a);
      final ib = iconesSugeridos.indexOf(b);
      if (ia != ib) {
        // Sugeridos primeiro, na ordem em que foram declarados.
        if (ia == -1) return 1;
        if (ib == -1) return -1;
        return ia.compareTo(ib);
      }
      return catalogo[a]!.rotulo.compareTo(catalogo[b]!.rotulo);
    });

    return nomes;
  }

  /// A busca é digitada sem acento ("alimentacao"), mas os rótulos têm acento.
  /// Também serve à busca por descrição na lista de lançamentos, pelo mesmo
  /// motivo: ninguém digita "água" com trema de pressa.
  static String semAcento(String texto) {
    const comAcento = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const equivalente = 'aaaaaeeeeiiiiooooouuuucn';

    final buffer = StringBuffer();
    for (final rune in texto.runes) {
      final char = String.fromCharCode(rune);
      final i = comAcento.indexOf(char);
      buffer.write(i == -1 ? char : equivalente[i]);
    }
    return buffer.toString();
  }
}
