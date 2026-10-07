// URLs base das APIs consumidas pelo app.
//
// São duas de propósito. O módulo financeiro saiu da api-master para a
// finance-api, mas log de erro e de evento continuam na api-master — eles não
// têm nada de financeiro e não foram portados. Com uma constante só, apontar o
// app para a API nova derrubaria o log remoto em silêncio.

/// finance-api — fluxo de caixa, categorias, caixas, relatórios e boletos.
/// Usada pelo [ApiService].
const String financeApiBaseUrl = 'https://finance-api.premiosistemas.com.br';

/// api-master — só `/v1/erro` e `/v1/evento`. Usada pelo [LoggerService].
const String apiBaseUrl = 'https://api.premiosistemas.com.br';

/// id do Finance na tabela `softwares` do api-master.
///
/// Vai em toda linha gravada em `/v1/erro` e `/v1/evento` e é o que separa estes
/// logs dos dos outros produtos que escrevem na mesma tabela. A finance-api manda
/// o mesmo valor (`Util/log_api.py`, lá).
const int idSoftwareFinance = 10;

/// Carimbo de quem gravou a linha de log.
///
/// App e API mandam o mesmo [idSoftwareFinance], e o campo `origem` do payload
/// nem chega ao banco — o api-master não o mapeia em `Erro.to_supabase()`. Então
/// `versao` é o único campo gravado que distingue um erro do app de um erro da
/// API no painel do suporte.
const String versaoLog = 'finance-app v1.0.0.0';
