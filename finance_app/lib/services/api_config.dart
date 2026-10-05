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
