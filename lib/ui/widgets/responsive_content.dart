import 'package:flutter/material.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';

/// Shared transparent page scaffold with responsive, width-constrained content.
class ResponsivePageScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final double maxContentWidth;

  const ResponsivePageScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.maxContentWidth = AppBreakpoints.expanded,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: appBar,
      body: ResponsiveContent(maxContentWidth: maxContentWidth, child: body),
    );
  }
}

/// Applies shared horizontal page padding and a safe maximum content width.
class ResponsiveContent extends StatelessWidget {
  final Widget child;
  final double maxContentWidth;

  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxContentWidth = AppBreakpoints.expanded,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = AppBreakpoints.isMobile(constraints.maxWidth)
            ? AppDimensions.paddingMobile
            : AppDimensions.paddingDesktop;

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
