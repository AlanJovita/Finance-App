# Logos das instituições (conta bancária)

Um arquivo por entrada de `lib/utils/bancos.dart`, **com o nome da chave**, que é
o código COMPE do banco:

```
104.png   Caixa Econômica Federal
001.png   Banco do Brasil
341.png   Itaú
260.png   Nubank
```

## Formato

- PNG com fundo transparente, quadrado, **96×96** (o `LogoBanco` desenha em 44 px
  lógicos e o `cacheWidth` cobre telas 3×; acima de 96 só pesa o bundle).
- Centralizado, com uma margem pequena: o widget recorta em círculo, então
  qualquer coisa no canto é cortada.
- Símbolo da marca, não o logotipo com o nome escrito — o nome já aparece ao lado,
  e texto dentro de um círculo de 44 px não se lê.

## Enquanto o arquivo não existe

Nada quebra e nada precisa ser alterado em código. `LogoBanco` cai na cor da marca
com as iniciais do nome da conta (`errorBuilder`), e passa a mostrar o logo no
próximo build depois de o PNG entrar aqui. A chave gravada no banco de dados é a
mesma nos dois casos.

Entradas que **não** têm arquivo por natureza: `carteira`, `cofre` e `outro`. Elas
declaram `temLogo: false` no catálogo e usam ícone do Material — `Bancos.asset`
devolve `null` e nem se tenta carregar imagem.

## Uso de marca

São logos de terceiros, usados para o lojista identificar a conta dele: sem
modificar o símbolo, sem sugerir parceria ou endosso, e sempre ao lado do nome que
o próprio lojista deu à conta. Novas entradas seguem a mesma regra.
