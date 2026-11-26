import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion/jelly.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../theme/tokens.dart';

/// A solid content card. Content lives on solid surfaces (readable, cheap);
/// glass is for floating controls.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Space.lg),
    this.radius = Radii.lg,
    this.color,
    this.borderColor,
    this.gradient,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final Gradient? gradient;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? c.surface) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? c.outline.withValues(alpha: context.isDark ? 0.9 : 0.7)),
        boxShadow: [
          BoxShadow(color: c.shadow.withValues(alpha: context.isDark ? 0.35 : 0.08), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return card;
    return JellyPress(onTap: onTap, intensity: 0.45, semanticLabel: semanticLabel, child: card);
  }
}

/// Section title with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction, this.padding});

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, Space.sm),
      child: Row(
        children: [
          Expanded(child: Semantics(header: true, child: Text(title, style: context.text.titleLarge))),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// Rounded square with a soft colour and an icon.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.color, this.size = 44, this.iconSize});

  final IconData icon;
  final Color? color;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? context.colors.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tone.withValues(alpha: context.isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: tone, size: iconSize ?? size * 0.5),
    );
  }
}

/// A tappable row: badge, title, subtitle, trailing.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.showChevron = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = destructive ? c.danger : (iconColor ?? c.primary);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
        child: Row(
          children: [
            if (icon != null) ...[IconBadge(icon!, color: tone, size: 40), const SizedBox(width: Space.sm + 2)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: context.text.titleSmall!.copyWith(color: destructive ? c.danger : null)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: context.text.bodySmall),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (onTap != null && showChevron && trailing == null)
              Icon(Icons.chevron_right_rounded, color: c.textTertiary),
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return JellyPress(onTap: onTap, intensity: 0.3, semanticLabel: title, child: row);
  }
}

enum Tone { neutral, primary, success, warning, danger, info }

extension ToneColors on Tone {
  Color color(BuildContext context) {
    final c = context.colors;
    return switch (this) {
      Tone.neutral => c.textSecondary,
      Tone.primary => c.primary,
      Tone.success => c.success,
      Tone.warning => c.warning,
      Tone.danger => c.danger,
      Tone.info => c.info,
    };
  }

  Color soft(BuildContext context) {
    final c = context.colors;
    return switch (this) {
      Tone.neutral => c.surfaceMuted,
      Tone.primary => c.primarySoft,
      Tone.success => c.successSoft,
      Tone.warning => c.warningSoft,
      Tone.danger => c.dangerSoft,
      Tone.info => c.infoSoft,
    };
  }
}

/// Small status label. Always pairs colour with an icon and text, so meaning
/// never depends on colour alone.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.tone = Tone.neutral, this.icon, this.dense = false});

  final String label;
  final Tone tone;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = tone.color(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(color: tone.soft(context), borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: dense ? 13 : 15, color: color), const SizedBox(width: 4)],
          // Long labels (e.g. OSM opening hours) shrink with an ellipsis
          // instead of overflowing their row.
          Flexible(
            child: Text(
              label,
              style: AppTypography.style(dense ? 12 : 12.5, 680).copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Toggleable chip with a soft fill and a check that pops in.
class SelectChip extends StatelessWidget {
  const SelectChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
    this.icon,
    this.tone = Tone.primary,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final IconData? icon;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = tone.color(context);
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      onTap: () => onChanged(!selected),
      excludeSemantics: true,
      child: JellyPress(
        onTap: () => onChanged(!selected),
        intensity: 1.2,
        isButton: false,
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.enter,
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? tone.soft(context) : c.surface,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: selected ? color.withValues(alpha: 0.6) : c.outline, width: selected ? 1.5 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: Motion.base,
                transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                child: selected
                    ? Icon(Icons.check_rounded, key: const ValueKey(true), size: 18, color: color)
                    : (icon != null
                        ? Icon(icon, key: const ValueKey(false), size: 18, color: c.textSecondary)
                        : const SizedBox(key: ValueKey('none'), width: 0)),
              ),
              if (selected || icon != null) const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.style(14.5, selected ? 680 : 560)
                      .copyWith(color: selected ? color : c.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline message with an icon on a soft tone.
class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.message, this.title, this.tone = Tone.info, this.icon, this.action});

  final String message;
  final String? title;
  final Tone tone;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final color = tone.color(context);
    final defaultIcon = switch (tone) {
      Tone.success => Icons.check_circle_rounded,
      Tone.warning => Icons.warning_amber_rounded,
      Tone.danger => Icons.error_rounded,
      _ => Icons.info_rounded,
    };
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: tone.soft(context),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? defaultIcon, color: color, size: 22),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(title!, style: context.text.titleSmall!.copyWith(color: context.colors.textPrimary)),
                  const SizedBox(height: 2),
                ],
                Text(message, style: context.text.bodyMedium!.copyWith(color: context.colors.textPrimary)),
                if (action != null) ...[const SizedBox(height: Space.xs), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Labelled text field (visible label, helper and error text below).
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.icon,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.obscure = false,
    this.autofillHints,
    this.onSubmitted,
    this.maxLines = 1,
    this.inputFormatters,
    this.suffixText,
    this.enabled = true,
    this.onChanged,
    this.textCapitalization = TextCapitalization.none,
    this.focusNode,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final IconData? icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final bool obscure;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final String? suffixText;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;
  final FocusNode? focusNode;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      obscureText: _hidden,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      onFieldSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      maxLines: widget.obscure ? 1 : widget.maxLines,
      textCapitalization: widget.textCapitalization,
      inputFormatters: widget.inputFormatters,
      style: context.text.bodyLarge,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        helperText: widget.helper,
        suffixText: widget.suffixText,
        prefixIcon: widget.icon == null ? null : Icon(widget.icon),
        suffixIcon: widget.obscure
            ? IconButton(
                tooltip: _hidden ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _hidden = !_hidden),
                icon: Icon(_hidden ? Icons.visibility_rounded : Icons.visibility_off_rounded),
              )
            : null,
      ),
    );
  }
}
