import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Decides, once per launch, whether glass surfaces render as real liquid
/// glass (refraction shader) or as the frosted fallback.
///
/// Liquid glass needs Impeller (backdrop shader filters). It also honours the
/// user's "Liquid glass effects" setting, and a crash guard: if a launch that
/// enabled liquid glass never confirmed a healthy first few seconds (the GPU
/// driver crashed the app), the next launch falls back to frosted glass until
/// the user turns the effect back on.
class GlassRuntime {
  GlassRuntime._();

  static const _kUserEnabled = 'glass.liquid.enabled';
  static const _kProbePending = 'glass.liquid.probePending';
  static const _kDisabledByGuard = 'glass.liquid.disabledByGuard';

  static ui.FragmentProgram? _program;
  static bool _deviceSupported = false;
  static bool _userEnabled = true;
  static bool _guardTripped = false;

  /// Whether glass surfaces currently render with the refraction shader.
  static final ValueNotifier<bool> liquid = ValueNotifier<bool>(false);

  static ui.FragmentProgram? get program => _program;

  /// True when this device can render liquid glass at all.
  static bool get deviceSupported => _deviceSupported;

  /// True when liquid glass was switched off because an earlier launch crashed
  /// while rendering it.
  static bool get disabledAfterCrash => _guardTripped;

  /// The user's choice in Settings.
  static bool get userEnabled => _userEnabled;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _userEnabled = prefs.getBool(_kUserEnabled) ?? true;
    _guardTripped = prefs.getBool(_kDisabledByGuard) ?? false;

    if (prefs.getBool(_kProbePending) ?? false) {
      // The last launch turned liquid glass on and never reported back.
      _guardTripped = true;
      await prefs.setBool(_kDisabledByGuard, true);
      await prefs.setBool(_kProbePending, false);
    }

    _deviceSupported = ui.ImageFilter.isShaderFilterSupported;
    if (_deviceSupported) {
      try {
        _program = await ui.FragmentProgram.fromAsset('shaders/liquid_glass.frag');
      } catch (e) {
        debugPrint('Liquid glass shader unavailable: $e');
        _deviceSupported = false;
      }
    }

    final on = _deviceSupported && _userEnabled && !_guardTripped;
    if (on) {
      await prefs.setBool(_kProbePending, true);
      // Survived the first frames with the shader in use: clear the probe.
      Timer(const Duration(seconds: 4), () => prefs.setBool(_kProbePending, false));
    }
    liquid.value = on;
  }

  /// Turns liquid glass on or off from Settings. Turning it on also clears a
  /// tripped crash guard, giving the effect another chance.
  static Future<void> setUserEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    _userEnabled = enabled;
    await prefs.setBool(_kUserEnabled, enabled);
    if (enabled && _guardTripped) {
      _guardTripped = false;
      await prefs.setBool(_kDisabledByGuard, false);
    }
    final on = _deviceSupported && _userEnabled && !_guardTripped;
    if (on && !liquid.value) {
      await prefs.setBool(_kProbePending, true);
      Timer(const Duration(seconds: 4), () => prefs.setBool(_kProbePending, false));
    }
    liquid.value = on;
  }
}
