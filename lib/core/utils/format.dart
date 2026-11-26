import 'package:intl/intl.dart';

/// Display formatting shared by every screen.
abstract final class Fmt {
  static final _time = DateFormat.jm();
  static final _dayMonth = DateFormat('d MMM');
  static final _dayMonthYear = DateFormat('d MMM yyyy');
  static final _weekday = DateFormat('EEEE');
  static final _monthYear = DateFormat('MMMM yyyy');
  static final _short = DateFormat('EEE, d MMM');

  static String time(DateTime d) => _time.format(d);
  static String monthYear(DateTime d) => _monthYear.format(d);
  static String shortDate(DateTime d) => _short.format(d);

  /// "Today", "Yesterday", "Tomorrow", weekday within a week, else "3 Mar".
  static String day(DateTime d, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final diff = _dateOnly(d).difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    if (diff == 1) return 'Tomorrow';
    if (diff > 1 && diff < 7) return _weekday.format(d);
    if (d.year == today.year) return _dayMonth.format(d);
    return _dayMonthYear.format(d);
  }

  /// "Today · 9:30 AM".
  static String dayTime(DateTime d) => '${day(d)} · ${time(d)}';

  /// "2h 15m", "45m", "3d".
  static String duration(Duration d) {
    if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes.clamp(1, 59)}m';
  }

  /// "Good morning" / "Good afternoon" / "Good evening".
  static String greeting([DateTime? now]) {
    final h = (now ?? DateTime.now()).hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String temperature(double celsius, {required bool fahrenheit, bool unit = true}) {
    if (fahrenheit) {
      final f = celsius * 9 / 5 + 32;
      return '${f.toStringAsFixed(1)}${unit ? ' °F' : ''}';
    }
    return '${celsius.toStringAsFixed(1)}${unit ? ' °C' : ''}';
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
