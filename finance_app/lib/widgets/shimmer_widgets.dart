import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../utils/app_colors_extension.dart';
import '../utils/app_tokens.dart';

/// Esqueletos de carregamento.
///
/// As cores vêm de [AppColors.shimmerBase] e [AppColors.shimmerHighlight] —
/// antes cada método rededuzia o brilho do tema e escolhia o próprio cinza.
class ShimmerWidgets {
  /// Envelopa o esqueleto com o brilho do tema atual.
  static Widget _shimmer(BuildContext context, {required Widget child}) {
    final cores = context.appColors;
    return Shimmer.fromColors(
      baseColor: cores.shimmerBase,
      highlightColor: cores.shimmerHighlight,
      child: child,
    );
  }

  /// Um bloco vazio do esqueleto. A cor é sempre branca: quem pinta é o
  /// [Shimmer] por cima.
  static Widget _bloco({
    double? width,
    required double height,
    double radius = AppSpacing.xs,
    EdgeInsets? margin,
  }) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  static Widget _circulo(double diametro) {
    return Container(
      width: diametro,
      height: diametro,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }

  /// Shimmer para cards da dashboard
  static Widget dashboardCardShimmer(BuildContext context) {
    return _shimmer(
      context,
      child: Card(
        child: Container(
          height: 120,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bloco(width: 100, height: 16),
              const SizedBox(height: AppSpacing.md),
              _bloco(width: double.infinity, height: 32),
              const Spacer(),
              _bloco(width: 60, height: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// Shimmer para lista de caixas
  static Widget listCaixasShimmer(BuildContext context) {
    return _shimmer(
      context,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Card(
            elevation: AppElevation.cardRaised,
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  _circulo(40),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _bloco(width: double.infinity, height: 16),
                        const SizedBox(height: AppSpacing.sm),
                        _bloco(width: 120, height: 12),
                      ],
                    ),
                  ),
                  _bloco(width: 80, height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Shimmer para lista de fluxos (despesas/receitas)
  static Widget listFluxosShimmer(BuildContext context) {
    return _shimmer(
      context,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 8,
        itemBuilder: (context, index) {
          if (index % 4 == 0) {
            // Header do mês
            return Container(
              margin: const EdgeInsets.only(
                top: AppSpacing.lg,
                bottom: AppSpacing.sm,
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _bloco(width: 150, height: 24),
            );
          }
          // Item da lista
          return Card(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: ListTile(
              leading: _circulo(40),
              title: _bloco(width: double.infinity, height: 16),
              subtitle: _bloco(
                width: 100,
                height: 12,
                margin: const EdgeInsets.only(top: AppSpacing.sm),
              ),
              trailing: _bloco(width: 80, height: 20),
            ),
          );
        },
      ),
    );
  }

  /// Shimmer para gráficos
  static Widget chartShimmer(BuildContext context, {double height = 200}) {
    return _shimmer(
      context,
      child: Card(
        child: Container(
          height: height,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              _bloco(width: 120, height: 16),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var i = 0; i < 7; i++)
                      _bloco(width: 30, height: (i + 1) * 20.0),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shimmer para boletos
  static Widget boletosShimmer(BuildContext context) {
    return _shimmer(
      context,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _circulo(40),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _bloco(width: 100, height: 16),
                        const SizedBox(height: AppSpacing.sm),
                        _bloco(width: 60, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _bloco(width: double.infinity, height: 1, radius: 0),
              const SizedBox(height: AppSpacing.md),
              for (var i = 0; i < 3; i++)
                _bloco(
                  width: double.infinity,
                  height: 40,
                  radius: AppRadius.sm,
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shimmer genérico para loading
  static Widget genericShimmer(BuildContext context) {
    return Center(
      child: _shimmer(
        context,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _circulo(80),
            const SizedBox(height: AppSpacing.lg),
            _bloco(width: 120, height: 16),
          ],
        ),
      ),
    );
  }

  /// Shimmer para dashboard completa
  static Widget dashboardFullShimmer(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          // Card de saldo
          dashboardCardShimmer(context),
          const SizedBox(height: AppSpacing.lg),
          // Card de relatório semanal
          dashboardCardShimmer(context),
          const SizedBox(height: AppSpacing.lg),
          // Gráfico
          chartShimmer(context, height: 300),
          const SizedBox(height: AppSpacing.lg),
          // Boletos
          boletosShimmer(context),
        ],
      ),
    );
  }
}
