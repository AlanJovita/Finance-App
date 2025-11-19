# Shimmer Loading - Documentação

## Visão Geral

O projeto utiliza o pacote `shimmer` (v3.0.0) para criar efeitos de loading elegantes e modernos em todas as páginas da aplicação.

## Estrutura

### Arquivo Principal
- **`lib/widgets/shimmer_widgets.dart`**: Contém todos os widgets de shimmer reutilizáveis

### Widgets de Shimmer Disponíveis

#### 1. `dashboardCardShimmer(BuildContext context)`
Shimmer para cards da dashboard.
- Altura: 120px
- Inclui título, valor principal e legenda
- Uso: Cards de resumo financeiro

#### 2. `listCaixasShimmer(BuildContext context)`
Shimmer para lista de caixas.
- Renderiza 5 itens de lista
- Inclui ícone circular, texto e badge
- Uso: Página de lista de caixas

#### 3. `listFluxosShimmer(BuildContext context)`
Shimmer para listas de fluxos (despesas/receitas).
- Renderiza 8 itens intercalados com headers de mês
- Inclui ícone, título, subtítulo e valor
- Uso: Páginas de despesas e receitas

#### 4. `chartShimmer(BuildContext context, {double height = 200})`
Shimmer para gráficos.
- Altura customizável (padrão: 200px)
- Simula barras de gráfico com alturas variadas
- Uso: Widgets de gráficos e dashboards

#### 5. `boletosShimmer(BuildContext context)`
Shimmer para seção de boletos.
- Inclui cabeçalho com ícone
- Renderiza 3 itens de boleto
- Uso: Widget de boletos na dashboard

#### 6. `genericShimmer(BuildContext context)`
Shimmer genérico e centralizado.
- Ícone circular + texto
- Uso: Páginas com loading simples

#### 7. `dashboardFullShimmer(BuildContext context)`
Shimmer completo para toda a dashboard.
- Combina múltiplos shimmers
- Inclui: card de saldo, relatório semanal, gráfico e boletos
- Uso: Página principal da dashboard

## Implementação nas Páginas

### Dashboard Page
```dart
body: _isLoading
    ? ShimmerWidgets.dashboardFullShimmer(context)
    : // conteúdo normal
```

### Lista de Caixas
```dart
if (snapshot.connectionState == ConnectionState.waiting) {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      children: [
        ShimmerWidgets.chartShimmer(context, height: 250),
        const SizedBox(height: 16),
        ShimmerWidgets.listCaixasShimmer(context),
      ],
    ),
  );
}
```

### Despesas/Receitas
```dart
if (snapshot.connectionState == ConnectionState.waiting) {
  return ShimmerWidgets.listFluxosShimmer(context);
}
```

### Log Viewer
```dart
body: _isLoading
    ? ShimmerWidgets.genericShimmer(context)
    : // conteúdo normal
```

## Recursos do Shimmer

### Adaptação ao Tema
- **Dark Mode**: Cores base e highlight mais escuras
- **Light Mode**: Cores base e highlight mais claras
- Automático baseado em `Theme.of(context).brightness`

### Cores Utilizadas

#### Dark Mode
- Base Color: `Colors.grey[800]`
- Highlight Color: `Colors.grey[700]`

#### Light Mode
- Base Color: `Colors.grey[300]`
- Highlight Color: `Colors.grey[100]`

## Boas Práticas

1. **Sempre use shimmer ao invés de CircularProgressIndicator** para melhor UX
2. **Escolha o shimmer apropriado** para cada tipo de conteúdo
3. **Mantenha as dimensões consistentes** entre shimmer e conteúdo real
4. **Use genericShimmer** apenas quando não houver shimmer específico

## Benefícios

- ✅ Melhor experiência do usuário
- ✅ Feedback visual mais elegante
- ✅ Percepção de carregamento mais rápido
- ✅ Interface moderna e profissional
- ✅ Consistência visual em toda aplicação
- ✅ Suporte automático a dark/light mode

## Páginas Implementadas

- ✅ Dashboard Page
- ✅ Lista de Caixas Page
- ✅ Despesas Page
- ✅ Receitas Page
- ✅ Log Viewer Page

## Manutenção

Para adicionar novos shimmer widgets:

1. Adicione o método estático em `ShimmerWidgets`
2. Use `Shimmer.fromColors()` com as cores adaptadas ao tema
3. Mantenha as proporções consistentes com o conteúdo real
4. Documente o uso no código
