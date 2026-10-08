/// Nomes de mês em português e o rótulo "Mês Ano".
///
/// Lista fixa em vez de `DateFormat('MMMM yyyy', 'pt_BR')`: o rótulo aparece em
/// navegador de mês, que reconstrói a cada toque na seta, e a lista constante
/// resolve em um acesso por índice — sem instanciar formatador nem carregar dados
/// de locale. O app só suporta `pt_BR` (ver `main.dart`), então não há outro
/// idioma a cobrir.
///
/// Vive aqui porque três telas precisam do mesmo rótulo: Receitas, Despesas e
/// Contas. Era uma constante privada da `FluxosPage`.
library;

const List<String> nomesMeses = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

/// "Outubro 2026".
String rotuloMes(DateTime mes) => '${nomesMeses[mes.month - 1]} ${mes.year}';

/// Último dia do mês de [mes], à meia-noite.
///
/// Dia 0 do mês seguinte é o último deste — evita a tabela de 28/30/31 e o ano
/// bissexto. O mês 13 é normalizado pelo próprio `DateTime`, então dezembro
/// funciona sem caso especial.
DateTime fimDoMes(DateTime mes) => DateTime(mes.year, mes.month + 1, 0);
