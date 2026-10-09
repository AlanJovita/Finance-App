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
- `AuthProvider` — login state; persists user + `idLojas` (store IDs) in SharedPreferences when "remember me" or token login is used.
- `ThemeProvider` — light/dark theme (themes defined in `lib/utils/app_theme.dart`).
- `GlobalState` (`lib/services/global_state.dart`) — a plain singleton (not a Provider) holding the logged-in `idLojas`; `ApiService` reads `GlobalState().firstIdLoja` to scope API calls. AuthProvider must keep it in sync on login/logout.

**API layer**: `lib/services/api_service.dart` is the single HTTP client, pointed at `http://api.premiosistemas.com.br`. There is no dependency injection — pages and dialogs instantiate `ApiService()` directly. All endpoints return an envelope `{ success, data, msg }`; `_handleRequest` centralizes decoding and error logging (including detecting HTML-instead-of-JSON responses from unimplemented endpoints).

**Remote error/event logging**: `LoggerService` (singleton) posts errors to `/v1/erro` and events to `/v1/evento` on the **api-master** (`apiBaseUrl`), not on the finance-api — see `lib/services/api_config.dart`. The prevailing pattern is: catch, `await _logger.logError(...)`, then rethrow or return false — follow it in new code. Logging failures are always swallowed so they never break the app.

Every log line carries `id_software = 10` (`idSoftwareFinance`) and `versao = versaoLog`, both in `api_config.dart`. Neither is cosmetic: `id_software` is what attributes the line to the Finance in the support panel, and the api-master accepts the payload without it, writing a NULL in silence. `versao` is the only *persisted* field that distinguishes an app error from a finance-api error — both send `id_software = 10`, and `origem` never reaches the database (`Erro.to_supabase()` in the api-master does not map it). `test/log_contrato_test.dart` locks both.

The finance-api sends to the same place, via `Util/log_api.py` there. Deserialization (`fromJson`) deliberately does **not** log remotely: it runs once per item, so a malformed list would emit one line per record — `ApiService` already logs the whole request once, with endpoint and body.

**Routing and token login** (`lib/main.dart`): named routes exist for `/login`, `/dashboard`, `/caixas`, `/contas`, `/cartoes`, `/receitas`, `/despesas`. Any *other* non-root path is treated as a login token: `onGenerateRoute` hands it to `TokenLoginWrapper`, which decodes it via `TokenService` (URL-safe Base64 of a CNPJ, padding stripped) and calls `AuthProvider.loginByToken`. Keep this in mind when adding routes — a new named route must be added to the known-routes check in `onGenerateRoute` **and** to the `routes` map, or it will be interpreted as a token.

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

**Models** (`lib/models/`): json_serializable classes with generated `.g.dart` companions — never edit `.g.dart` by hand; rerun build_runner instead. `lib/models/cartao.dart` is hand-written, like `conta.dart` and `resumo_fluxo.dart`: shallow classes where json_serializable would only add a `.g.dart` to generate what fits in a few lines.

**Responsiveness**: the app uses `responsive_framework` with breakpoints MOBILE (≤450), TABLET (≤800), DESKTOP (≤1920), 4K, plus helpers in `lib/utils/responsive_utils.dart`. Loading states use shimmer placeholders from `lib/widgets/shimmer_widgets.dart`; charts use `fl_chart` under `lib/widgets/charts/`.
