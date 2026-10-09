# Logos das bandeiras (cartão de crédito)

Um arquivo por entrada de `lib/utils/bandeiras.dart`, **com o nome da chave**:

```
visa.png
mastercard.png
elo.png
amex.png
hipercard.png
diners.png
```

## Formato

- PNG com fundo transparente, quadrado, **96×96** (o `LogoBandeira` desenha em
  28 px lógicos e o `cacheWidth` cobre telas 3×; acima de 96 só pesa o bundle).
- Centralizado, com margem pequena. Ao contrário do `LogoBanco`, o
  `LogoBandeira` **não** recorta em círculo — a maioria das bandeiras tem
  símbolo largo (o retângulo da Visa, os dois círculos do Mastercard) e um
  recorte circular cortaria as pontas. O widget usa `BoxFit.contain` dentro de
  um retângulo arredondado.
- Símbolo da marca. Aqui o logotipo com o nome escrito é aceitável — é como a
  bandeira aparece no plástico, e é assim que o lojista a reconhece.

## Enquanto o arquivo não existe

Nada quebra e nada precisa ser alterado em código. `LogoBandeira` cai na cor da
marca com o ícone de cartão (`errorBuilder`), e passa a mostrar o logo no próximo
build depois de o PNG entrar aqui. A chave gravada em `finance_cartao.bandeira` é
a mesma nos dois casos.

A entrada `outra` **não** tem arquivo por natureza: declara `temLogo: false` no
catálogo, então `Bandeiras.asset` devolve `null` e nem se tenta carregar imagem.

O **banco emissor** do cartão usa outro catálogo e outra pasta:
`lib/utils/bancos.dart` e `assets/images/bancos/`, os mesmos da conta bancária.
Bandeira e banco são dois campos porque variam independentemente — existe Nubank
Visa e Nubank Mastercard.

## Uso de marca

São logos de terceiros, usados para o lojista identificar o cartão dele: sem
modificar o símbolo, sem sugerir parceria ou endosso, e sempre ao lado do nome
que o próprio lojista deu ao cartão. Novas entradas seguem a mesma regra.
