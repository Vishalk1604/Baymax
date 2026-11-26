import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../glass/glass_style.dart';
import '../glass/liquid_glass.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Builds one slot of a [LiquidSelector]. [selectedness] goes from 0 (far
/// from the droplet) to 1 (droplet resting on it), so colours can blend while
/// the droplet travels.
typedef LiquidSlotBuilder = Widget Function(BuildContext context, int index, double selectedness);

/// A glass track with a liquid droplet marking the selected slot.
///
/// The droplet travels on a spring. While moving it stretches with its speed
/// and swells beyond the track, merging back into it as it settles (the
/// shader's smooth minimum joins the two shapes). It can also be dragged.
class LiquidSelector extends StatefulWidget {
  const LiquidSelector({
    super.key,
    required this.count,
    required this.index,
    required this.onSelect,
    required this.itemBuilder,
    this.height = 64,
    this.style,
    this.inset = 5,
    this.semanticLabels,
  });

  final int count;
  final int index;
  final ValueChanged<int> onSelect;
  final LiquidSlotBuilder itemBuilder;
  final double height;
  final GlassStyle? style;

  /// Gap between the droplet and the track edge at rest.
  final double inset;
  final List<String>? semanticLabels;

  @override
  State<LiquidSelector> createState() => _LiquidSelectorState();
}

class _LiquidSelectorState extends State<LiquidSelector> with SingleTickerProviderStateMixin {
  late final AnimationController _pos = AnimationController.unbounded(vsync: this, value: widget.index.toDouble());
  double _slotWidth = 1;
  bool _dragging = false;

  @override
  void didUpdateWidget(covariant LiquidSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index && !_dragging) _springTo(widget.index);
  }

  void _springTo(int index) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _pos.value = index.toDouble();
      return;
    }
    _pos.animateWith(SpringSimulation(Springs.droplet, _pos.value, index.toDouble(), _pos.velocity));
  }

  void _select(int i) {
    if (i != widget.index) HapticFeedback.selectionClick();
    widget.onSelect(i);
    _springTo(i);
  }

  double _posFromDx(double dx) => (dx / _slotWidth - 0.5).clamp(0.0, widget.count - 1.0);

  @override
  void dispose() {
    _pos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = widget.style ?? context.glass.bar;
    final inset = widget.inset;

    Rect dropletRect(Size size) {
      final slot = size.width / widget.count;
      final stretch = (_pos.velocity.abs() * 0.085).clamp(0.0, 0.6);
      final swell = _dragging ? 1.0 : stretch / 0.6;
      final x = (_pos.value + 0.5) * slot;
      final w = (slot - inset * 2) * (1 + stretch);
      final h = (size.height - inset * 2) * (1 - stretch * 0.15) + swell * 16;
      return Rect.fromCenter(center: Offset(x, size.height / 2), width: w, height: h);
    }

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(builder: (context, box) {
        _slotWidth = box.maxWidth / widget.count;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _select((d.localPosition.dx / _slotWidth).floor().clamp(0, widget.count - 1)),
          onHorizontalDragStart: (d) {
            setState(() => _dragging = true);
            _pos.stop();
            _pos.value = _posFromDx(d.localPosition.dx);
          },
          onHorizontalDragUpdate: (d) => _pos.value = _posFromDx(d.localPosition.dx),
          onHorizontalDragEnd: (d) {
            setState(() => _dragging = false);
            final target = _pos.value.round().clamp(0, widget.count - 1);
            _select(target);
          },
          child: AnimatedBuilder(
            animation: _pos,
            builder: (context, _) {
              return LiquidGlass(
                style: style,
                shapeBuilder: (size) => [
                  GlassShape(Offset.zero & size, size.height / 2),
                  GlassShape(dropletRect(size), (size.height - inset * 2) / 2),
                ],
                child: CustomPaint(
                  painter: _SelectionPainter(
                    rect: (size) {
                      final r = dropletRect(size);
                      // The visible pill stays inside the track.
                      return Rect.fromLTRB(r.left, inset, r.right, size.height - inset);
                    },
                    color: c.primary.withValues(alpha: context.isDark ? 0.22 : 0.13),
                    pos: _pos.value,
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < widget.count; i++)
                        Expanded(
                          child: Semantics(
                            selected: i == widget.index,
                            button: true,
                            inMutuallyExclusiveGroup: true,
                            label: widget.semanticLabels?[i],
                            onTap: () => _select(i),
                            // The label already says it; don't read the item's text twice.
                            excludeSemantics: widget.semanticLabels != null,
                            child: widget.itemBuilder(
                              context,
                              i,
                              (1 - (i - _pos.value).abs()).clamp(0.0, 1.0),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}

class _SelectionPainter extends CustomPainter {
  _SelectionPainter({required this.rect, required this.color, required this.pos});

  final Rect Function(Size size) rect;
  final Color color;
  final double pos;

  @override
  void paint(Canvas canvas, Size size) {
    final r = rect(size);
    canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(r.height / 2)), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SelectionPainter old) => old.pos != pos || old.color != color;
}
