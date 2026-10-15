# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Layout

The Flutter app lives in `finance_app/` — run all Flutter/Dart commands from that directory, not the repo root. It is a cash-flow control app ("Controle de Caixa") for stores, in Brazilian Portuguese (the only supported locale is `pt_BR`; UI strings, code identifiers, and comments are in Portuguese).

## Commands

```powershell
cd finance_app
flutter pub get                # install dependencies
flutter run                    # run the app (android/ios/web/windows/linux/macos targets exist)
flutter analyze                # lint (flutter_lints; deprecated_member_use is ignored)
flutter test                   # run all tests (see note below — test/ is not in the repo)
flutter test test/widget_test.dart   # run a single test file

# Regenerate json_serializable models (*.g.dart) after editing files in lib/models/
dart run build_runner build --delete-conflicting-outputs

# Regenerate app icons after changing assets/images/logo.png
dart run flutter_launcher_icons
```

**`finance_app/test/` is not in the repository.** It is ignored by `finance_app/.gitignore`, by project decision: the suite lives on the developer's machine. That includes `test/goldens/` (the reference images, useless without the tests) and `test/failures/` (artifacts Flutter rewrites on every failing golden run — 40 PNGs that were committed by accident). `flutter test` works normally wherever the folder exists; a fresh clone has no `test/`, and the way back is the history (`git log --diff-filter=D -- finance_app/test/`). References to specific test files elsewhere in this document are still accurate — only their location changed. `ios/RunnerTests/` and `macos/RunnerTests/` stay tracked: they are Flutter platform scaffolding wired into the Xcode projects.

## Architecture

**State management** is Provider-based, wired in `lib/main.dart`:
- `AuthProvider` — login state; persiste user + `idLojas` (store IDs) pelo `SessaoStore`, que escolhe o destino conforme o "lembrar login" (ver a seção de sessão adiante). Expõe `sessaoCarregando` e `sessaoValida`, e é por eles que a UI decide — não por `isAuthenticated` sozinho.
- `ThemeProvider` — light/dark theme (themes defined in `lib/utils/app_theme.dart`).
- `GlobalState` (`lib/services/global_state.dart`) — a plain singleton (not a Provider) holding the logged-in `idLojas`; `ApiService` escopa as chamadas por `exigirIdCliente()`, que **lança** em vez de devolver 0. AuthProvider mantém o singleton em sincronia num ponto único (`_aplicarSessao`).

**API layer**: `lib/services/api_service.dart` is the single HTTP client, pointed at `http://api.premiosistemas.com.br`. There is no dependency injection — pages and dialogs instantiate `ApiService()` directly. All endpoints return an envelope `{ success, data, msg }`; `_handleRequest` centralizes decoding and error logging (including detecting HTML-instead-of-JSON responses from unimplemented endpoints).

**Remote error/event logging**: `LoggerService` (singleton) posts errors to `/v1/erro` and events to `/v1/evento` on the **api-master** (`apiBaseUrl`), not on the finance-api — see `lib/services/api_config.dart`. The prevailing pattern is: catch, `await _logger.logError(...)`, then rethrow or return false — follow it in new code. Logging failures are always swallowed so they never break the app.

Every log line carries `id_software = 10` (`idSoftwareFinance`) and `versao = versaoLog`, both in `api_config.dart`. Neither is cosmetic: `id_software` is what attributes the line to the Finance in the support panel, and the api-master accepts the payload without it, writing a NULL in silence. `versao` is the only *persisted* field that distinguishes an app error from a finance-api error — both send `id_software = 10`, and `origem` never reaches the database (`Erro.to_supabase()` in the api-master does not map it). `test/log_contrato_test.dart` locks both.

The finance-api sends to the same place, via `Util/log_api.py` there. Deserialization (`fromJson`) deliberately does **not** log remotely: it runs once per item, so a malformed list would emit one line per record — `ApiService` already logs the whole request once, with endpoint and body.

**Routing and token login** (`lib/main.dart`): named routes exist for `/login`, `/dashboard`, `/caixas`, `/contas`, `/cartoes`, `/receitas`, `/despesas`. Any *other* non-root path is treated as a login token: `onGenerateRoute` hands it to `TokenLoginWrapper`, which repassa o token a `AuthProvider.loginByToken` → `POST /finance/login/token`. O token é **opaco** (`secrets.token_urlsafe(32)`, ~43 chars): quem valida é a API, e o app não decodifica nada dele — ver `TokenService`, que só confere o formato para não gastar requisição com caminho que claramente não é token. Keep this in mind when adding routes — a new named route must be added to the known-routes check in `onGenerateRoute`, to the `routes` map, **and embrulhada na `GuardaSessao`** (seção seguinte), ou ela será interpretada como token — ou, pior, abrirá sem sessão.

**A rota vem do caminho da URL, e isso depende de duas peças.** `main()` chama
`usePathUrlStrategy()`: o padrão do Flutter Web é `HashUrlStrategy`, que lê a
rota de depois do `#`, e com ele o link de acesso direto do app-suporte
(`finance.premiosistemas.com.br/<token>`) nunca chegava ao `onGenerateRoute` —
o Flutter via um fragmento vazio, resolvia a rota inicial como `/` e caía na
tela de login, que era o sintoma. A outra peça é o `try_files ... /index.html`
do `nginx.conf`: sem ela, recarregar em `/receitas` daria 404 em vez de abrir o
app. **As duas são necessárias**; mexer em uma sem a outra quebra o acesso por
link ou o recarregamento.

Repare que o `initialRoute: '/'` do `MaterialApp` **não** atrapalha: o
`WidgetsApp` só o usa quando o `defaultRouteName` da plataforma é `/`, então a
rota do navegador sempre ganha.

**Sessão: `id_cliente` nunca pode ser 0** (`lib/widgets/guarda_sessao.dart`,
`lib/services/sessao_store.dart`, `lib/services/global_state.dart`).

O que aconteceu: em web a rota em foco vai para a URL do navegador. Quem saiu do
app pelo botão "voltar" e retornou pelo "avançar" **recarregou o Flutter direto
na rota interna** (`/receitas`), e o `AuthWrapper` — que é só a rota raiz —
nunca foi consultado. A tela montou com a sessão vazia, o então
`GlobalState.firstIdLoja` respondeu 0 porque `idLojas` estava vazia, e os ~35
chamadores usaram esse 0 sem conferir: as listas vieram do "cliente 0" (dados de
outra origem, contas da loja real ausentes) e o lançamento feito ali foi gravado
com `id_cliente = 0` — linha que nenhuma consulta da loja alcança mais, porque
todas são escopadas por cliente.

São **três** barreiras, e nenhuma substitui a outra:

1. **`GuardaSessao` embrulha toda rota interna** no `routes` do `main.dart`.
   Ela tem três respostas, não duas: *carregando* (espera), *sem sessão* (volta
   ao login com aviso), *válida* (monta a tela). A espera é o que impede a tela
   de montar no frame anterior à sessão chegar do disco — `AuthProvider`
   expõe `sessaoCarregando` justamente para isso, e o `AuthWrapper` também o
   respeita (de graça, parou de piscar o login em quem usa "lembrar login").
   O aviso só sai quando a guarda **nunca** viu sessão válida nesta tela: quem
   clicou em "Sair" pediu para sair e não precisa ser avisado de nada.
2. **`sessaoValida` = autenticado **e** com loja.** `isAuthenticated` sozinho já
   foi `true` com a lista de lojas vazia; o setter de `GlobalState.idLojas` e o
   `SessaoStore.lojasValidas` descartam 0, negativo e repetido, nas três
   entradas (formulário, link, sessão gravada). Login com credencial certa e
   nenhuma loja utilizável agora falha com mensagem própria (`erroLogin`), em
   vez de autenticar ninguém no cliente 0.
3. **`ApiService` recusa montar requisição sem sessão.** `_idCliente` lança
   `SessaoInvalidaException` em vez de devolver 0 (é o que os 27 pontos de
   leitura usam), e `_comCliente` **sobrescreve** `id_cliente`/`id_loja` do
   corpo de toda escrita com o id da sessão — um model montado antes da sessão
   carregar chegava lá com 0. `GlobalState.firstIdLoja` continua podendo
   responder 0 **só** para o `LoggerService`: erro ocorrido sem sessão ainda tem
   de ser registrado.

**A sessão tem dois destinos, e o "lembrar login" escolhe qual**
(`SessaoStore`): marcado grava no `SharedPreferences` (`localStorage` na web),
que é o que a opção promete; desmarcado grava no `ArmazenamentoVolatil` — o
`sessionStorage` na web, um mapa em memória no resto. Não é conforto gratuito:
sem o volátil, um F5 (ou o voltar/avançar) derrubava quem não marcou a opção
para dentro de uma tela interna sem `id_cliente`. A leitura tenta o volátil
primeiro, porque ele é sempre a sessão mais recente. Chave corrompida ou com id
0 é recusada **e apagada** — senão a mesma chave reabriria o app sem sessão
todas as vezes. Credencial nunca entra em nenhum dos dois (nem senha, nem o
token do link).

**O menu lateral preserva a raiz**: `AppDrawer` navega com
`pushNamedAndRemoveUntil(rota, (r) => r.isFirst)`. Com o `pushReplacementNamed`
que havia ali, a primeira navegação pelo menu substituía o próprio
`AuthWrapper`, e aí o `popUntil(isFirst)` de quem volta ao login
(`utils/auth_actions.dart` e a própria `GuardaSessao`) caía na tela interna em
vez da tela de login.

**O menu tem três formas** (`MenuLateral`, resolvida por `AppLayout.menuLateral`
e aplicada pela `widgets/moldura_menu.dart`): `gaveta` atrás do hambúrguer,
`recolhido` como barra fixa só de ícones, e `expandido` como barra fixa com os
rótulos. Seis coisas aí não se leem no código.

**A regra é uma só: a barra fica fixa sempre que couber sem derrubar a segunda
coluna do Resumo.** Expandida ela custa 305px e por isso só entra a partir de
1500; recolhida custa 73 e já entra a partir de 793 (`menuFixoColapsado` =
`duasColunas + 73`), o que inclui praticamente todo notebook. Entre 793 e 1499 a
barra é recolhida **por imposição**, e o botão de expandir não aparece —
`podeAlternarMenu` responde pela tela, nunca pela forma atual, senão quem
recolheu num monitor de 1920 ficaria sem o botão para desfazer.

**Altura também decide.** `alturaMinimaMenu` (500) é o que mantém **celular
deitado** na gaveta: 844px de largura dariam de sobra para a barra recolhida,
mas os seis destinos mais o tema e o "Sair" não cabem em 390px de altura, e a
barra viraria uma lista rolante de ícones — pior que o hambúrguer.

**Fixa, o `Navigator.pop` que fechava a gaveta acerta a rota.** É a armadilha da
feature: `AppDrawer` dá um `pop` antes de navegar — para fechar a gaveta — e sem
gaveta esse `pop` derruba a tela em foco. Daí o `_fecharGaveta` consultar
`forma.ehFixo`; vale para o item do menu **e** para o botão "Sair".
`test/menu_fixo_test.dart` trava os dois caminhos, nas duas formas fixas.

**A moldura embrulha a tela inteira, `AppBar` incluída.** Posta dentro do
`body`, ela deixaria o menu abaixo da barra de título e, nas Receitas/Despesas,
a barra de totais do rodapé (`bottomNavigationBar`) correria por baixo dele —
somando a lista debaixo do menu. E **fixa, a tela não declara `drawer:`**: por
isso o `builder` devolve a forma; declarar os dois deixaria o hambúrguer na
barra, abrindo uma segunda cópia do menu por cima da primeira.

**Recolher é preferência de quem usa, não estado de tela** (`MenuProvider`, no
molde do `ThemeProvider`). Precisa ser global: a `MolduraMenu` é montada por
cada página, então estado local faria a barra reexpandir a cada navegação.
Persiste no `SharedPreferences` pelo mesmo motivo do tema. Recolhida, **nada
some** do menu — os seis destinos, o tema e o "Sair" continuam lá como ícone, e
o que era rótulo vira `Tooltip`.

**A forma entra na conta de colunas do Resumo** (`AppLayout.larguraUtil`). A
barra expandida nasce em 1500px, exatamente o número que é o piso de três
colunas: sem descontar os 305px dela, uma tela de 1500 montaria três colunas de
~367px — mais estreitas que as **duas** de um celular deitado, que é o cenário
mais apertado que existe. É também o que faz recolher valer a pena: os 232px
devolvidos são o que cabe a terceira coluna entre 1573 e 1804px de tela.

Só as cinco telas de menu usam a moldura. As de detalhe empilhadas por cima
(`CaixaPage`, `CartaoMovimentosPage`) continuam sem menu: elas já não tinham
gaveta, e se sai delas pelo botão de voltar.

Duas armadilhas de **teste** que isso criou, as duas em
`lista_fluxos_golden_test.dart`: a página agora monta o `AppDrawer`, então o
arnês precisa do `MenuProvider` **e** do `ThemeProvider` (e do mock do
`SharedPreferences`); e o logo da barra é um `Image.asset`, que resolve de forma
assíncrona — sem o `_resolverImagens` antes do `expectLater`, o golden grava ora
o PNG, ora o ícone do `errorBuilder`, conforme um teste anterior do arquivo já
ter carregado o asset.

`test/sessao_test.dart` trava o conjunto: a rota interna aberta por
recarregamento não monta nem por um frame, a sessão lembrada monta a tela com a
loja (e nunca com 0), a sessão da aba sobrevive a um `AuthProvider` novo, o
`ApiService` recusa leitura e escrita sem sessão, e sair pelo menu não acusa
sessão encerrada. Do outro lado, a finance-api passou a recusar `id_cliente = 0`
na URL e nas escritas (ver o CLAUDE.md dela) — as rotas do financeiro não
autenticam nada, então as duas pontas precisam da guarda.

**Conta bancária** (`lib/pages/contas_page.dart`): three things there are not inferable from the code.

`id_conta = 0` is "sem conta" and is the default for every lançamento — including everything the PDV and the api-master write, since neither knows the column. The selector in `FluxoFormDialog` therefore only appears when the store has an account, and `toJson` always sends an explicit `id_conta`: on the API side an *absent* key means "don't touch the account" (that is what keeps the PDV sync from wiping it), so omitting 0 would make "Sem conta" fail to detach an account during an edit. **`id_subcategoria` now follows the same rule** — the app must keep sending it explicitly, including 0, or clearing a subcategoria stops working. Both are locked by `models_api_contract_test.dart`.

The account list is read from `ContasCache`, loaded once per session, **not** from `ApiService` directly. The lançamento modal already fires two requests per opening (categorias + subcategorias); the account list changes far less and a third request per opening buys nothing. `AuthProvider.logout` clears the cache — it is a per-store list. The cache deliberately does not store failures, and `ContaFormDialog`/`ContasPage` invalidate it after every write. One subtlety in `_loadContas`: an **archived** account stays in the dropdown when it is the one this lançamento already uses, otherwise editing an old entry would silently drop its account on save.

Bank logos are a local asset catalog (`lib/utils/bancos.dart`), keyed by COMPE code, and the database stores only that key (`finance_conta.imagem`) — the same shape as `categoria_visuais.dart`. There is no reliable public logo API (BrasilAPI returns names and codes, not logos; Clearbit's was discontinued in late 2024), and in Flutter Web a third-party image depends on someone else's CORS. `LogoBanco` falls back to the brand colour plus the account's initials through `errorBuilder`, so **the feature works with no PNG present at all** — dropping files into `assets/images/bancos/` is additive and needs no code change. Transferências do not appear in Receitas/Despesas on purpose (see the API's CLAUDE.md); the Contas page is where they are listed and deleted.

**Parcelamento** (`id_ref`): duas operações em `lib/pages/fluxos_page.dart` e
`lib/widgets/fluxo_form_dialog.dart` deixam de ser sobre um lançamento e passam a ser sobre
o lote, e nas duas quem decide o escopo é o app — a API obedece.

Em `deleteFluxo(id, idRef)` o `idRef` **é o seletor**: positivo apaga o parcelamento
inteiro, 0 apaga uma linha. Passar `fluxo.idRef` por reflexo era o que fazia excluir uma
parcela derrubar o lote em silêncio; hoje o valor vem do checkbox do modal de exclusão, que
só aparece para `id_ref > 0`.

Em `updateFluxoGrupo(fluxo, campos)` o `campos` é o **diff** calculado por
`_camposAlterados` — só o que o usuário mexeu no formulário. Não é economia de bytes:
replicar o registro inteiro sobrescreveria o `valor` de cada parcela já baixada, e a baixa
grava ali o líquido sem guardar o original (`PagamentoDialog`). `_camposAlterados` também
omite vencimento e confirmação de propósito, mesmo quando mudam — são de cada parcela, a
API os recusa, e não oferecer a replicação quando foi *só* a data que mudou evita perguntar
algo que não teria efeito. O modal pergunta no momento de salvar, antes do spinner, e
`null` do `_perguntarReplicar` é "cancelei a edição", diferente de `false`.

**A lista de lançamentos tem um arranjo só, em qualquer largura**: lista em
largura cheia, resumo do mês como `bottomNavigationBar` e lançamento pelo modal
do botão flutuante. Houve uma versão em que, acima de 1100px, ela virava "lista +
formulário fixo na lateral" (com o botão flutuante escondido, o resumo descido
para dentro da coluna e um `ApresentacaoFluxo.painel` no `FluxoFormDialog`);
**foi revertido por decisão de produto** — não tente reintroduzir sem pedido.
`test/salvar_continuar_test.dart` e `test/lista_fluxos_golden_test.dart` travam a
forma atual numa tela de 1300px, que é justamente onde a variante aparecia.

**O card da lista diz quatro coisas, e o lugar de cada uma é decisão**
(`CardFluxo`): a marca à esquerda é a categoria com um **selo de situação**
mordendo o canto (antes era a subcategoria), e a linha de baixo é a trilha
`Categoria › Subcategoria · 05/10` mais o chip da **conta bancária** (antes era
o status, por extenso). O que se lê de relance numa lista de contas a pagar é se
a conta está paga, vencida ou por vencer — isso virou cor e ícone no selo, que
não gasta linha nenhuma; a subcategoria continua escrita na trilha, e a conta,
que não tinha representação no card, ganhou o espaço que o rótulo de status
ocupava. Lançamento sem conta não mostra chip: `id_conta = 0` é o padrão de tudo
que vem do PDV, e "Sem conta" na maioria das linhas seria só ruído.

**Os filtros da lista são três quadrados iguais** (categoria, conta, situação),
todos locais sobre o mês que já está em memória. A caixa compartilhada é o que
os faz ler como um grupo, e o que sobra de largura fica com a busca — antes o
filtro de categoria era uma caixa de 200px com o nome dentro, que comia a busca
e não tinha irmão com que se alinhar. No celular os três moram numa folha atrás
de um quadrado só, porque lupa + mês + três quadrados não cabem em 360px.
O predicado vive em `utils/filtro_fluxos.dart`, fora da página, porque as
convenções de "vazio" dos quatro filtros **não são iguais**: 0 não filtra em
categoria (0 é "sem categoria" no app inteiro) mas filtra em conta (0 é o
recorte "sem conta"), e nulo não filtra em nenhum dos dois.
`test/filtros_lista_test.dart` trava exatamente isso.

**Duplicar lançamento** (`FluxoCaixa.paraClone` + o `clonar` do `FluxoFormDialog`): o
modal tem **três** modos, e o par `(fluxo, clonar)` é o que os distingue — `null/false`
cria, `!null/false` edita, `!null/true` abre preenchido e **cria**. Quem responde isso é
`_ehEdicao`, nunca `fluxo != null`: era essa pergunta que decidia o `UPDATE`, o `id_ref`
do lote, a oferta de replicação e a repetição travada, e o clone não pode entrar em
nenhuma delas — sob pena de o "Duplicar" sobrescrever o original em silêncio.

**O molde é montado no model, não no modal** (`paraClone`), e quatro campos não são
herdados: `id` e `id_ref` zerados (com eles não é cópia, é a mesma linha — e o `id_ref`
colaria o clone num parcelamento alheio, onde a replicação em grupo e a exclusão do lote o
alcançariam), `confirmado` em falso (duplicar uma conta paga não paga a nova) e `repeticao`
em "única vez", junto com o `[3/12]` fora da descrição — clonar *uma parcela* geraria doze
lançamentos e afirmaria uma posição que o clone não tem. O vencimento é **hoje**: o uso é
"isto outra vez", e copiar a data faria o clone de uma conta de agosto nascer atrasado.
`test/clone_fluxo_test.dart` trava os quatro campos, o sufixo (inclusive o colchete que faz
parte do nome e tem de sobreviver) e a separação entre os modos.

**"Salvar e continuar"** (`FluxoFormDialog._salvar(continuar:)`): três botões, na ordem
`Cancelar · Salvar e continuar · Salvar`. O do meio grava e **mantém o modal aberto**,
limpando só descrição e valor e devolvendo o cursor à descrição — é para quem lança as
contas do mês de uma vez, na mesma categoria e com o mesmo vencimento. Não aparece em
edição (editar é a operação de um registro); aparece em duplicar, que é criação. Depois da
primeira gravação o "Cancelar" vira **"Fechar"**: o que foi gravado está gravado, e
"Cancelar" ali sugeriria desfazer.

Duas consequências que não se leem no botão. **Quem fecha o modal agora é ele mesmo**, e
não mais o `onSave` da tela — o `Navigator.pop` saiu de `FluxosPage._showFormDialog`,
porque só o modal sabe qual dos dois botões foi tocado; repor aquele `pop` faz o
"continuar" fechar na primeira gravação. E a tela é avisada em **toda** gravação, inclusive
com `continuar`: ela recarrega a lista atrás do modal, que com o modal aberto é a única
confirmação visível de que o lançamento anterior entrou.

Difere do gêmeo do cartão (`MovimentoCartaoFormDialog`, que teve o botão primeiro) num
ponto: lá o parcelamento também é zerado a cada gravação, aqui a **repetição é mantida**.
O seletor continua visível no corpo do formulário e quem lança doze contas mensais em
sequência quer justamente mantê-lo — mas em "Mensal · 3 parcelas" cada gravação cria três
linhas. `test/salvar_continuar_test.dart` trava a ordem e a presença dos botões em cada
modo, e que uma gravação que falha **não** fecha o modal nem descarta o que foi digitado.

**Cartão de crédito** (`lib/pages/cartoes_page.dart` + `lib/pages/cartao_movimentos_page.dart`):
duas telas, e o que organiza as duas é uma frase — **compra no cartão não é saída de
caixa**. O dinheiro sai quando a fatura é paga, e o que entra em `finance_fluxo_caixa` é só
a despesa da fatura, gerada no fechamento. Daí o invariante que a API mantém e que explica
quase tudo aqui: **no máximo uma despesa no caixa por fatura**, apontada por
`Fatura.idFluxo`. Pagar dá baixa nessa despesa; não cria outra. Seis coisas não se leem no
código.

**A página de Cartões não tem navegador de mês, e isso é decisão.** A de Contas tem, porque
saldo de conta é um acumulado até uma data; dívida de cartão é um número de *agora*, e um
"saldo devedor de março" não significa nada para quem quer saber quanto deve. Quem navega
por fatura é a `CartaoMovimentosPage`. Por isso `getResumoCartoes()` não aceita período,
diferente de `getSaldosContas`.

**A competência em foco vem do servidor, não de `DateTime.now()`.** A primeira carga chama
`getFatura` **sem** competência e a API devolve a fatura aberta — que não é
necessariamente o mês corrente (cartão que fecha dia 1 já está recebendo compras na fatura
do mês seguinte). A tela guarda essa resposta em `_competenciaAberta` em vez de recalcular
a regra do fechamento: ela mora em `Cartao.competenciaDe` na API, e uma segunda
implementação divergiria na primeira borda de mês curto. É o que decide se o modal de
lançamento nasce com hoje ou com `dataInicial` — numa fatura passada, hoje cairia noutra
competência e o lançamento sairia da tela no instante em que fosse salvo. A âncora é
`fatura.dataFechamento - 1 dia`, uma data garantidamente dentro do ciclo **porque é a
própria data que a API materializou**, já travada no último dia do mês curto.

`MovimentoCartaoFormDialog` repete essa conta uma vez, em `_competenciaPrevista`, e só para
mostrar a prévia no cabeçalho enquanto o lojista escolhe a data. O POST **não** manda
`id_fatura`: quem resolve é o servidor, e se as duas divergirem o sintoma é uma prévia
errada — não um lançamento na fatura errada.

**O cadastro não pergunta a categoria da fatura, e a coluna não existe.** A despesa gerada
no fechamento nasce sem categoria, como todo lançamento do app, e quem quiser categorizá-la
o faz na própria despesa em Despesas — `finance_cartao` não tem `id_categoria` (ver o
comentário no lugar dela em `migration_cartao_credito.sql`) e `FecharFatura` grava 0.

`Cartao.idCategoria` **ainda existe no model Dart**, e é resíduo: o `toJson` manda a chave,
a API a ignora, e o `fromJson` lê 0 porque a resposta não a traz. Nada quebra — é só código
morto esperando limpeza, junto com a asserção do `paraCartao` em `test/cartao_test.dart`,
que hoje só prova que o model é consistente consigo mesmo.

**Parcelamento vai numa chamada, ao contrário do caixa.** `FluxoFormDialog` faz N POST;
aqui `total_parcelas > 1` vai num POST só, porque as N parcelas têm de cair em faturas
**consecutivas** e N chamadas deixariam a sequência com buraco se a rede caísse no meio. O
`valor` enviado é o de **cada parcela** — a divisão do total é decisão do formulário, que é
quem sabe se o lojista digitou a parcela ou o total.

**Pagamento de fatura não é um lançamento comum.** É o único crédito que move dinheiro, e
por isso tem modal próprio (`PagamentoFaturaDialog`) a partir da fatura, não do seletor de
natureza — `NaturezaMovimento.creditosLancaveis` deixa `pagamento` de fora de propósito.
Estorno e cashback também são créditos no cartão e não movem nada no caixa. `valor: null`
é "pagar o saldo" e é diferente de mandar o número: a API recalcula no servidor, então um
lançamento que entrou entre o carregamento da tela e o toque não vira pagamento parcial por
acidente.

**`deleteMovimentoCartao(id, idRef)`: o `idRef` é o seletor**, idêntico ao `deleteFluxo` —
positivo apaga a compra parcelada inteira, 0 apaga a linha. O valor vem do checkbox do
modal de exclusão, que só aparece para `idRef > 0`.

**O botão de fechar só aparece a partir do dia do fechamento** (`Fatura.podeFechar`).
Fechar adiantado é legítimo e a API não trava a data, mas oferecer o botão todo dia faria o
fechamento parecer parte do lançamento, e o lojista fecharia um mês que ainda vai receber
compras. Fatura vazia (`id == 0`) também não oferece: não há o que congelar, e ela é um mês
em branco — a API devolve `id = 0` com as datas do ciclo em vez de 404, porque um GET não
cria linha no banco.

Os cartões vêm do `CartoesCache`, gêmeo do `ContasCache` e pelo mesmo motivo (o modal já
faz duas requisições por abertura); `AuthProvider.logout` limpa os dois, e a página de
Cartões invalida depois de cada escrita. Bandeira e banco emissor são **dois** campos com
**dois** catálogos (`utils/bandeiras.dart` e o `utils/bancos.dart` da conta bancária),
porque variam independentemente — existe Nubank Visa e Nubank Mastercard. `LogoBandeira`
não recorta em círculo, ao contrário do `LogoBanco`: símbolo de bandeira é largo e o
círculo cortaria justamente a parte que identifica a marca. Como lá, **a feature funciona
sem PNG nenhum** (`errorBuilder` cai na cor da marca) — ver o README de
`assets/images/bandeiras/`.

`test/cartao_test.dart` trava o que quebra em silêncio: o `id_fatura` fora do `toJson`, o
status desconhecido caindo em *aberta*, `pagamento` fora de `creditosLancaveis`, o
`limite_disponivel` nulo que não pode virar 0, e a tolerância de meio centavo que impede um
resíduo de `decimal(11,2)` de deixar a fatura "paga em parte" para sempre.

**Importação de OFX no cartão** (`lib/utils/ofx.dart`, `lib/utils/ofx_importacao.dart`,
`lib/widgets/importar_ofx_dialog.dart`): o ícone na barra da fatura lê o extrato do banco e
abre uma revisão linha a linha. Seis coisas não se leem no código.

**O parser é à mão porque o formato é SGML, não XML.** O que os bancos brasileiros
exportam é OFX 1.x: cabeçalho em `CHAVE:valor` antes do `<OFX>` e tag de folha que pode vir
**sem fechamento** (`<TRNAMT>-108.99` em vez de `<TRNAMT>-108.99</TRNAMT>`). O Nubank
fecha, outros bancos não, e um parser de XML morre no segundo caso; os pacotes de OFX no pub
ou estão abandonados ou só entendem OFX 2. Daí a leitura por tag tolerante — valor é o que
vem depois da tag até o próximo `<`. O fuso do `DTPOSTED` (`[-3:BRT]`) é **descartado**:
aplicá-lo moveria a meia-noite para as 21h do dia anterior e a compra mudaria de dia —
às vezes de fatura. O encoding tenta UTF-8 e cai para Latin-1, porque há banco que declara
`CHARSET:1252` e escreve UTF-8.

**Cada linha do arquivo é UM movimento, com `total_parcelas = 1`** — inclusive as que o
banco marca "Parcela 5/12". O extrato traz *uma* parcela, já cobrada nesta fatura; mandar 12
faria a API criar doze linhas em doze faturas consecutivas (é o que `total_parcelas > 1`
significa lá), e o arquivo do mês seguinte traria "Parcela 6/12" para duplicar tudo. A
posição fica no texto, que é onde o banco a pôs.

**A conciliação é por (data + valor + descrição), contando repetição — não por `FITID`.**
Duas razões, as duas vistas no primeiro extrato real: o Nubank **repete o `FITID`** entre o
IOF e a compra internacional que o gerou (dois lançamentos legítimos com o mesmo id), e o
mesmo extrato tem **três linhas idênticas** no mesmo dia (`Pjbank *Saipos`, R$ 99,00), todas
verdadeiras — comparando por conjunto, duas seriam dadas como já importadas. O limite
conhecido: editar a descrição de um movimento importado faz a próxima importação oferecê-lo
de novo. Fechar isso exigiria guardar o `FITID` no banco (coluna nova em
`finance_cartao_movimento`, no fim da tabela), e foi deixado de fora de propósito.

**O pagamento da fatura não é importável, e nem fica marcável.** A API recusa
(`"Pagamento de fatura deve ser registrado pela fatura"`) porque é ele que dá baixa na
despesa da fatura no caixa. Importá-lo como estorno — a saída preguiçosa, já que no OFX os
dois são `CREDIT` — abateria o saldo devedor sem contrapartida nenhuma: o dinheiro sairia
do cartão e desapareceria do caixa. Estorno e cashback **são** importáveis, mas nascem
desmarcados: a natureza é escolha de quem está olhando.

**Quem abre o seletor de arquivo é a página, não o diálogo.** Na web o navegador só abre o
seletor dentro do gesto do usuário, e um `pickFile()` disparado depois da animação de um
diálogo pode ser bloqueado sem erro à vista. Isso também deixa o `ImportarOfxDialog` livre
de `file_picker` e testável sem plugin.

**Os POST são sequenciais**, um por lançamento. A API resolve (ou cria) a fatura dentro do
INSERT, e disparar 24 em paralelo viraria 24 tentativas de criar a mesma fatura ao mesmo
tempo. Uma falha no meio não interrompe o resto nem desfaz o que entrou — a importação
seguinte do mesmo arquivo oferece só o que falta. O importador também **avisa quando o
`DTEND` não cai no dia de fechamento cadastrado**: quem decide a fatura é o cadastro, não o
arquivo, e aí os lançamentos se espalhariam entre duas faturas.

`test/ofx_test.dart` trava o parser (tag sem fechamento, Latin-1, fuso, valor em formato
brasileiro, recusa de extrato de conta bancária) e a conciliação com os dois casos reais —
o `FITID` repetido e as três linhas iguais.

**Painel** (`lib/pages/dashboard_page.dart`): a tela tem **dois resumos independentes**, e
cada um aparece só se tiver assunto — o do caixa e o das receitas/despesas.

Quem não usa o PDV não tem linha nenhuma em `finance_caixa`, e o painel abria com um card
escrito "Nenhum caixa disponível" seguido de dois gráficos vazios, para uma loja que lança
contas todo dia. Quem usa o PDV e não lança conta tinha o problema espelhado. O sinal de
cada bloco é a **ausência de dado**, não uma configuração: `getCaixa()` devolve `null`
quando a loja nunca abriu caixa, e `ResumoPainel.vazio` diz que nunca houve lançamento.
Ordem fixa quando os dois existem: caixa primeiro.

Cinco coisas ali não são inferíveis do código.

**A tela é uma grade de cards soltos, em 1, 2 ou 3 colunas** (`GradeCartoes`, em
`widgets/grade_cartoes.dart`; a contagem sai de `AppLayout.colunasResumo`, com os limiares
em 720 e 1500px sobre a largura **da tela**). Três decisões moram aí:

- **Largura decide, não orientação.** O pedido original era "em pé uma coluna, deitado
  duas", mas no navegador "orientação" não diz nada sobre quanto espaço existe — uma janela
  estreitada continua paisagem. Os limiares foram escolhidos para dar o mesmo resultado nos
  aparelhos (celular em pé ≈390 → 1; deitado ≈844 → 2) com a consequência aceita de que
  tablet **em pé** (≈800) também ganha duas.
- **A largura é a que sobra depois do menu lateral**, não a da tela: ver
  `AppLayout.larguraUtil` e a seção do menu. Na prática, com o menu expandido as três
  colunas começam em 1805px de tela; recolhendo o menu elas já cabem em 1573.
- **Todo card é peça solta.** Não existem mais "bloco do caixa" e "bloco de movimentações"
  como unidades de layout: os dois gráficos mensais (`CartaoGraficoMensal`, um por
  `GraficoMensal`) e os cinco cards de movimentações (`CartaoSaldos`, `CartaoNatureza` ×2,
  `CartaoCategorias` ×2, em `widgets/cartoes_movimentacoes.dart`) entram na grade um a um.
  Eram esses dois agrupamentos que faziam uma coluna ficar com 1800px e a outra com 300 — a
  grade só equilibra o que recebe em pedaços. Como não há mais cabeçalho de seção, o título
  "Movimentações" e o mês passaram para dentro do `CartaoSaldos`.
- **A grade é um `RenderBox` próprio, não `GridView` nem `Row` de `Column`s.** `GridView`
  impõe a altura do maior card a toda a linha; uma divisão fixa em colunas precisaria
  decidir antes quem vai onde, e a altura de cada card depende dos dados da loja. O layout
  mede cada filho com a largura da coluna e o põe na coluna mais curta — varredura gulosa,
  uma passada. O empate cai na coluna mais à esquerda, e é isso que faz os primeiros cards
  serem sempre os topos das colunas, na ordem da lista. `test/grade_resumo_test.dart` trava
  os limiares e a distribuição.

**Os dois pedaços do caixa não ficam contíguos de propósito.** Na ordem da lista o card do
último caixa vem primeiro e os gráficos de faturamento/pedidos vêm depois dos boletos e dos
atalhos — e como a grade respeita a ordem nos primeiros cards, isso continua valendo com
qualquer número de colunas. Agrupá-los empurraria o aviso de boleto vencendo para baixo de
dois gráficos. **Boleto fica fora do bloco do caixa**: é cobrança do ERP, e uma loja sem
caixa ainda pode ter boleto vencendo.

**O caminho para a tela de Caixas some junto com o bloco**, nos dois lugares: o atalho do
painel e o item do menu lateral (`AppDrawer`). Sem caixa os dois levavam a uma tela
permanentemente vazia. Quem responde ao menu é o `CaixaCache` — um `bool` por sessão, no
estilo do `ContasCache`, **semeado pelo painel** com o `getCaixa()` que ele já faz, para
abrir o menu não disparar uma requisição por toque. O cache é tri-estado de propósito:
`null` é "ainda não sei" e o menu trata como "esconde", porque mostrar o item e removê-lo
meio segundo depois tiraria a opção de baixo do dedo de quem já estava tocando nela.
`AuthProvider.logout` limpa, como os outros dois caches — herdado, ele decidiria o menu
pela loja da sessão anterior. A rota `/caixas` continua registrada: o que sumiu foi o
caminho até ela, não a tela. `test/menu_caixas_test.dart` trava os três estados.

**Falha de um bloco não apaga o outro** (`_erroCaixa` e `_erroMovimentacoes` são
separados). A tela de erro inteira só aparece quando os dois falharam; um bloco sozinho
que falha mostra um aviso no lugar dele, e não some — sumir é o que a tela faz quando a
loja de fato não tem o dado, e os dois casos não podem parecer iguais.

**Tudo de movimentação vem de uma requisição só** (`getResumoPainel` →
`/fluxo/resumo/painel`), inclusive as 10 últimas de cada natureza. As categorias vêm à
parte porque a API devolve só `id_categoria`: nome, cor e ícone saem do mesmo
`listCategorias` que as telas de Receitas e Despesas usam, e é isso que faz a fatia da
pizza e o card da lista terem a mesma cor. O painel é **somente leitura** — editar e dar
baixa continuam nas telas da natureza, para o `FluxoFormDialog`, o `PagamentoDialog` e a
regra de parcelamento não ganharem uma segunda cópia.

Dois recortes da API valem para quem for ler os números (detalhados no CLAUDE.md de lá):
atraso e pendente **não** são do mês, e o mês em foco é o que o **servidor** resolveu
(`ResumoPainel.mes`) — a tela não recalcula com `DateTime.now()`, porque o relógio do
aparelho pode estar noutro dia.

**Gráficos do painel** (`lib/widgets/charts/`): `FluxoAcumuladoChart` é acumulado e não
barra por dia porque a pergunta é "quanto já entrou e quanto vou fechar", um total
correndo — e 31 colunas num celular ficam com 8px. As duas pontas da curva fecham com o
card de saldos ao lado (fim do previsto = `receitas_previsto`; fim do realizado =
`receitas_realizado`); se não fecharem, uma das duas está somando outra coisa. O realizado
**para em hoje** em vez de seguir reto até o fim do mês: a linha chapada afirmaria "nada
mais entrou" onde o certo é "ainda não aconteceu".

`CategoriasPieChart` desenha **no máximo 5 fatias nomeadas** e agrega o resto em "Outras":
acima disso as vizinhas ficam com poucos graus, e a cor vem do cadastro — duas categorias
finas de matiz parecido viram uma mancha. Pelo mesmo motivo a identidade de cada fatia é a
**legenda com nome e valor**, nunca a cor sozinha: nada impede o lojista de cadastrar duas
categorias da mesma cor. `test/painel_movimentacoes_golden_test.dart` trava o corte do
realizado, a cauda agregada e a aritmética do acumulado.

**Models** (`lib/models/`): json_serializable classes with generated `.g.dart` companions — never edit `.g.dart` by hand; rerun build_runner instead. `lib/models/cartao.dart` is hand-written, like `conta.dart` and `resumo_fluxo.dart`: shallow classes where json_serializable would only add a `.g.dart` to generate what fits in a few lines.

**Responsiveness**: the app uses `responsive_framework` with breakpoints MOBILE (≤450), TABLET (≤800), DESKTOP (≤1920), 4K, plus helpers in `lib/utils/responsive_utils.dart`. Loading states use shimmer placeholders from `lib/widgets/shimmer_widgets.dart`; charts use `fl_chart` under `lib/widgets/charts/`.
