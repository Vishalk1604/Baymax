import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'liquid_button.dart';
import 'liquid_selector.dart';

class GlassNavItem {
  const GlassNavItem({required this.icon, required this.activeIcon, required this.label});
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Height of the floating tab bar, excluding the bottom safe area.
const double kGlassNavBarHeight = 66;

/// Space screens must leave at the bottom so content clears the tab bar.
double glassNavBarInset(BuildContext context) =>
    kGlassNavBarHeight + 12 + MediaQuery.paddingOf(context).bottom + 20;

/// Floating liquid-glass tab bar with a droplet selection indicator, plus a
/// separate round glass action button (Apple-style: tabs + one action).
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.items,
    required this.index,
    required this.onSelect,
    required this.actionIcon,
    required this.actionLabel,
    required this.onAction,
  });

  final List<GlassNavItem> items;
  final int index;
  final ValueChanged<int> onSelect;
  final IconData actionIcon;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, bottom + 12),
      child: Row(
        children: [
          Expanded(
            child: LiquidSelector(
              count: items.length,
              index: index,
              onSelect: onSelect,
              height: kGlassNavBarHeight,
              semanticLabels: [for (final i in items) i.label],
              itemBuilder: (context, i, t) {
                final item = items[i];
                final color = Color.lerp(c.textSecondary, c.primary, t)!;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(t > 0.5 ? item.activeIcon : item.icon, color: color, size: 25),
                    const SizedBox(height: 3),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: AppTypography.style(11.5, 560 + 140 * t).copyWith(color: color),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          LiquidIconButton(
            icon: actionIcon,
            tooltip: actionLabel,
            onPressed: onAction,
            size: kGlassNavBarHeight,
            primary: true,
            iconSize: 30,
          ),
        ],
      ),
    );
  }
}

/// Segmented control on the same liquid droplet.
class GlassSegmented<T> extends StatelessWidget {
  const GlassSegmented({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.height = 46,
  });

  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final index = values.indexOf(selected).clamp(0, values.length - 1);
    return LiquidSelector(
      count: values.length,
      index: index,
      height: height,
      inset: 4,
      style: context.glass.control,
      semanticLabels: labels,
      onSelect: (i) => onChanged(values[i]),
      itemBuilder: (context, i, t) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            labels[i],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.style(14.5, 560 + 160 * t).copyWith(color: Color.lerp(c.textSecondary, c.textPrimary, t)),
          ),
        ),
      ),
    );
  }
}
