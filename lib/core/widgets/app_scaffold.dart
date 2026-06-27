import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Standard TrueCircle page shell — alabaster background, themed app bar.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.title,
    this.showBackButton = true,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.padding,
    this.safeAreaBottom = true,
    this.backgroundColor,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final String? title;
  final bool showBackButton;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final EdgeInsetsGeometry? padding;
  final bool safeAreaBottom;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.background,
      appBar: appBar ?? _buildAppBar(context),
      body: SafeArea(
        bottom: safeAreaBottom,
        child: padding != null ? Padding(padding: padding!, child: body) : body,
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      bottomSheet: bottomSheet,
    );
  }

  PreferredSizeWidget? _buildAppBar(BuildContext context) {
    if (title == null && actions == null && !showBackButton) return null;

    return AppBar(
      leading: showBackButton && Navigator.of(context).canPop()
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
      automaticallyImplyLeading: false,
      title: title != null ? Text(title!, style: AppTypography.h2) : null,
      actions: actions != null
          ? [...actions!, const SizedBox(width: 8)]
          : null,
    );
  }
}

/// Scrollable page shell with optional pull-to-refresh.
class AppScrollScaffold extends StatelessWidget {
  const AppScrollScaffold({
    super.key,
    required this.slivers,
    this.title,
    this.showBackButton = true,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.onRefresh,
    this.physics,
  });

  final List<Widget> slivers;
  final String? title;
  final bool showBackButton;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Future<void> Function()? onRefresh;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    Widget scrollView = CustomScrollView(
      physics: physics ?? const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverAppBar(
          pinned: true,
          floating: false,
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          leading: showBackButton && Navigator.of(context).canPop()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
          automaticallyImplyLeading: false,
          title: title != null ? Text(title!, style: AppTypography.h2) : null,
          actions: actions,
        ),
        ...slivers,
      ],
    );

    if (onRefresh != null) {
      scrollView = RefreshIndicator(
        onRefresh: onRefresh!,
        color: AppColors.accent,
        child: scrollView,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: scrollView,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
