import 'package:flutter/material.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';

class AppSegmentedTabBar extends StatelessWidget {
  final TabController controller;
  final List<Tab> tabs;

  const AppSegmentedTabBar({
    super.key,
    required this.controller,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: context.colors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: context.colors.onEmphasis,
        unselectedLabelColor:
            Theme.of(context).colorScheme.onSurfaceVariant,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        dividerHeight: 0,
        tabs: tabs,
      ),
    );
  }
}
