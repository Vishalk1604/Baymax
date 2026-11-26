import 'package:flutter/animation.dart';

/// 4-pt spacing scale.
abstract final class Space {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;

  /// Horizontal page gutter.
  static const double gutter = 20;
}

/// Corner radii.
abstract final class Radii {
  static const double xs = 10;
  static const double sm = 14;
  static const double md = 20;
  static const double lg = 28;
  static const double xl = 34;
  static const double pill = 999;
}

/// Durations and curves shared by every animation.
abstract final class Motion {
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration base = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 380);
  static const Duration page = Duration(milliseconds: 420);

  /// Stagger between list items entering.
  static const Duration stagger = Duration(milliseconds: 45);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
}

/// Spring presets. `jelly` overshoots visibly (liquid feel), `snappy`
/// settles fast with a hint of bounce, `gentle` is for large surfaces.
abstract final class Springs {
  static const SpringDescription jelly = SpringDescription(mass: 1, stiffness: 420, damping: 15);
  static const SpringDescription snappy = SpringDescription(mass: 1, stiffness: 560, damping: 34);
  static const SpringDescription gentle = SpringDescription(mass: 1, stiffness: 220, damping: 24);
  static const SpringDescription droplet = SpringDescription(mass: 1, stiffness: 300, damping: 19);
}
