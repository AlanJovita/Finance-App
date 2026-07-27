import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'app_tokens.dart';

/// Utilitários para facilitar o uso de valores responsivos.
///
/// Os defaults saem das escalas de `app_tokens.dart` para não existirem duas
/// fontes de verdade: [AppSpacing] e [AppRadius] são o vocabulário de medidas;
/// esta classe só escolhe qual degrau usar em cada breakpoint.
class ResponsiveUtils {
  /// Retorna o espaçamento responsivo baseado no tipo de dispositivo
  static double getSpacing(
    BuildContext context, {
    double mobile = AppSpacing.sm,
    double tablet = AppSpacing.md,
    double desktop = AppSpacing.lg,
  }) {
    if (ResponsiveBreakpoints.of(context).isDesktop) {
      return desktop;
    } else if (ResponsiveBreakpoints.of(context).isTablet) {
      return tablet;
    }
    return mobile;
  }

  /// Retorna padding responsivo
  static EdgeInsets getPadding(
    BuildContext context, {
    double mobile = AppSpacing.lg,
    double tablet = AppSpacing.xl,
    double desktop = AppSpacing.xxl,
  }) {
    if (ResponsiveBreakpoints.of(context).isDesktop) {
      return EdgeInsets.all(desktop);
    } else if (ResponsiveBreakpoints.of(context).isTablet) {
      return EdgeInsets.all(tablet);
    }
    return EdgeInsets.all(mobile);
  }

  /// Retorna o tamanho da fonte responsivo
  static double getFontSize(
    BuildContext context, {
    double mobile = 14.0,
    double tablet = 16.0,
    double desktop = 18.0,
  }) {
    if (ResponsiveBreakpoints.of(context).isDesktop) {
      return desktop;
    } else if (ResponsiveBreakpoints.of(context).isTablet) {
      return tablet;
    }
    return mobile;
  }

  /// Retorna altura responsiva para cards
  static double getCardHeight(
    BuildContext context, {
    double mobile = 120.0,
    double tablet = 140.0,
    double desktop = 160.0,
  }) {
    if (ResponsiveBreakpoints.of(context).isDesktop) {
      return desktop;
    } else if (ResponsiveBreakpoints.of(context).isTablet) {
      return tablet;
    }
    return mobile;
  }

  /// Retorna altura responsiva para gráficos
  static double getChartHeight(
    BuildContext context, {
    double mobile = 250.0,
    double tablet = 350.0,
    double desktop = 400.0,
  }) {
    if (ResponsiveBreakpoints.of(context).isDesktop) {
      return desktop;
    } else if (ResponsiveBreakpoints.of(context).isTablet) {
      return tablet;
    }
    return mobile;
  }

  /// Retorna largura máxima para conteúdo
  static double getMaxWidth(BuildContext context) {
    if (ResponsiveBreakpoints.of(context).isDesktop) {
      return 1200.0;
    } else if (ResponsiveBreakpoints.of(context).isTablet) {
      return 800.0;
    }
    return double.infinity;
  }

  /// Retorna número de colunas para grid
  static int getGridColumns(
    BuildContext context, {
    int mobile = 1,
    int tablet = 2,
    int desktop = 3,
  }) {
    if (ResponsiveBreakpoints.of(context).isDesktop) {
      return desktop;
    } else if (ResponsiveBreakpoints.of(context).isTablet) {
      return tablet;
    }
    return mobile;
  }

  /// Retorna se está em modo mobile
  static bool isMobile(BuildContext context) {
    return ResponsiveBreakpoints.of(context).isMobile;
  }

  /// Retorna se está em modo tablet
  static bool isTablet(BuildContext context) {
    return ResponsiveBreakpoints.of(context).isTablet;
  }

  /// Retorna se está em modo desktop
  static bool isDesktop(BuildContext context) {
    return ResponsiveBreakpoints.of(context).isDesktop;
  }

  /// Retorna valor escalado proporcionalmente à largura da tela
  static double scaleWidth(BuildContext context, double value) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Base: 375 (iPhone padrão)
    return (value * screenWidth) / 375;
  }

  /// Retorna valor escalado proporcionalmente à altura da tela
  static double scaleHeight(BuildContext context, double value) {
    final screenHeight = MediaQuery.of(context).size.height;
    // Base: 812 (iPhone padrão)
    return (value * screenHeight) / 812;
  }

  /// Retorna tamanho de ícone responsivo
  static double getIconSize(
    BuildContext context, {
    double mobile = 24.0,
    double tablet = 28.0,
    double desktop = 32.0,
  }) {
    if (ResponsiveBreakpoints.of(context).isDesktop) {
      return desktop;
    } else if (ResponsiveBreakpoints.of(context).isTablet) {
      return tablet;
    }
    return mobile;
  }

  /// Retorna radius de borda responsivo
  static double getBorderRadius(
    BuildContext context, {
    double mobile = AppRadius.sm,
    double tablet = AppRadius.md,
    double desktop = AppRadius.lg,
  }) {
    if (ResponsiveBreakpoints.of(context).isDesktop) {
      return desktop;
    } else if (ResponsiveBreakpoints.of(context).isTablet) {
      return tablet;
    }
    return mobile;
  }

  /// Retorna elevation responsivo para cards
  static double getCardElevation(
    BuildContext context, {
    double mobile = AppElevation.card,
    double tablet = AppElevation.cardRaised,
    double desktop = AppElevation.floatingRaised,
  }) {
    if (ResponsiveBreakpoints.of(context).isDesktop) {
      return desktop;
    } else if (ResponsiveBreakpoints.of(context).isTablet) {
      return tablet;
    }
    return mobile;
  }
}

/// Extension para facilitar uso direto em widgets
extension ResponsiveContextExtension on BuildContext {
  bool get isMobile => ResponsiveUtils.isMobile(this);
  bool get isTablet => ResponsiveUtils.isTablet(this);
  bool get isDesktop => ResponsiveUtils.isDesktop(this);

  double responsiveSpacing({
    double mobile = AppSpacing.sm,
    double tablet = AppSpacing.md,
    double desktop = AppSpacing.lg,
  }) => ResponsiveUtils.getSpacing(
    this,
    mobile: mobile,
    tablet: tablet,
    desktop: desktop,
  );

  EdgeInsets responsivePadding({
    double mobile = AppSpacing.lg,
    double tablet = AppSpacing.xl,
    double desktop = AppSpacing.xxl,
  }) => ResponsiveUtils.getPadding(
    this,
    mobile: mobile,
    tablet: tablet,
    desktop: desktop,
  );
}
