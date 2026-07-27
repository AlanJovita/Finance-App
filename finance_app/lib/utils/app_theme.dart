import 'package:flutter/material.dart';

import 'app_colors_extension.dart';
import 'app_tokens.dart';

/// Tema do app. Os dois modos saem do mesmo [_buildTheme] — o que muda entre
/// claro e escuro são as superfícies, as tintas de texto e a elevação.
///
/// Cores semânticas (status, meios de pagamento) não moram aqui: ficam em
/// [AppColors], registrado como extensão do tema no fim deste arquivo.
class AppTheme {
  // Cores baseadas no logo.
  //
  // primaryBlue era #4A7BA7 e ficava em 4.48:1 com texto branco em cima — 0.02
  // abaixo do mínimo do WCAG, e ele é o fundo do botão principal. Escurecer o
  // canal azul em 3/255 resolve (4.51:1) sem diferença visual perceptível.
  static const Color primaryBlue = Color(0xFF4A7BA4); // Azul médio do logo
  static const Color secondaryBlue = Color(0xFF6B9AC4); // Azul claro do logo
  static const Color darkBlue = Color(0xFF2C5F8D); // Azul escuro do logo
  static const Color accentBlue = Color(0xFF87CEEB); // Azul claro accent

  // Cores para o tema light
  static const Color lightBackground = Color(0xFFE5E7EB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCardBg = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFD1D5DB);
  static const Color lightInputFill = Color(0xFFF9FAFB);

  // Cores para o tema dark
  static const Color darkBackground = Color(0xFF0F1419);
  static const Color darkSurface = Color(0xFF1A1F2E);
  static const Color darkCardBg = Color(0xFF252B3B);
  static const Color darkBorder = Color(0xFF3A4356);

  // Cores de texto
  static const Color lightTextPrimary = Color(0xFF1F2937);

  /// Era #6B7280, que dava 3.90:1 sobre [lightBackground] — reprovava para
  /// texto. Escurecido até 4.82:1, mantendo a mesma família de cinza.
  static const Color lightTextSecondary = Color(0xFF5D6470);
  static const Color darkTextPrimary = Color(0xFFE5E7EB);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);

  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final surface = isDark ? darkSurface : lightSurface;
    final cardBg = isDark ? darkCardBg : lightCardBg;
    final background = isDark ? darkBackground : lightBackground;
    final border = isDark ? darkBorder : lightBorder;
    final textPrimary = isDark ? darkTextPrimary : lightTextPrimary;
    final textSecondary = isDark ? darkTextSecondary : lightTextSecondary;
    final appColors = isDark ? AppColors.dark : AppColors.light;

    // No escuro o azul claro é que carrega a marca: o azul médio não separa o
    // suficiente do fundo escuro.
    final accent = isDark ? secondaryBlue : primaryBlue;
    final onAccent = isDark ? darkBackground : Colors.white;

    final textTheme = _buildTextTheme(textPrimary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,

      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accent,
        secondary: isDark ? accentBlue : secondaryBlue,
        tertiary: isDark ? primaryBlue : darkBlue,
        surface: surface,
        surfaceContainerHighest: cardBg,
        error: appColors.error,
        onPrimary: onAccent,
        onSecondary: onAccent,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
        onError: Colors.white,
        outline: border,
      ),

      scaffoldBackgroundColor: background,
      textTheme: textTheme,

      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? darkSurface : darkBlue,
        foregroundColor: isDark ? darkTextPrimary : Colors.white,
        elevation: AppElevation.none,
        centerTitle: true,
        iconTheme: IconThemeData(
          color: isDark ? darkTextPrimary : Colors.white,
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: isDark ? darkTextPrimary : Colors.white,
        ),
      ),

      cardTheme: CardThemeData(
        color: cardBg,
        elevation: isDark ? AppElevation.cardRaised : AppElevation.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        shadowColor: isDark ? Colors.black54 : Colors.black12,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          elevation: isDark ? AppElevation.buttonRaised : AppElevation.button,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: accent, width: 2),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? darkSurface : lightInputFill,
        border: _inputBorder(border),
        enabledBorder: _inputBorder(border),
        focusedBorder: _inputBorder(accent, width: 2),
        errorBorder: _inputBorder(appColors.error),
        focusedErrorBorder: _inputBorder(appColors.error, width: 2),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: textSecondary),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onAccent,
        elevation: isDark ? AppElevation.floatingRaised : AppElevation.floating,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: secondaryBlue.withValues(alpha: isDark ? 0.2 : 0.1),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: isDark ? accentBlue : primaryBlue,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),

      dividerTheme: DividerThemeData(color: border, thickness: 1),

      iconTheme: IconThemeData(color: textPrimary, size: 24),

      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        tileColor: isDark ? darkCardBg : null,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        elevation: isDark ? AppElevation.overlayRaised : AppElevation.overlay,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? darkCardBg : darkSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: darkTextPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: AppElevation.overlay,
      ),

      drawerTheme: DrawerThemeData(
        backgroundColor: surface,
        elevation: isDark ? AppElevation.overlay : AppElevation.floating,
      ),

      extensions: [appColors],
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  /// A escala tipográfica do app.
  ///
  /// Antes o `textTheme` não era definido: tudo caía no default do Flutter e
  /// cada widget remendava com `TextStyle` inline. Os tamanhos aqui são os que
  /// as telas já usavam na prática.
  static TextTheme _buildTextTheme(Color textPrimary) {
    return TextTheme(
      // Números de destaque (total do caixa, saldo do dashboard).
      displaySmall: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      headlineLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),

      // Títulos de tela, de card e de seção.
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),

      // Corpo.
      bodyLarge: TextStyle(fontSize: 16, color: textPrimary),
      bodyMedium: TextStyle(fontSize: 14, color: textPrimary),
      bodySmall: TextStyle(fontSize: 12, color: textPrimary),

      // Rótulos de controle: botões, chips, legendas.
      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
    );
  }
}
