import 'package:flutter/material.dart';

import '../../core/widgets/glass_nav_bar.dart';
import '../../services/notification_service.dart';
import '../checkup/checkup_flow_screen.dart';
import '../home/home_screen.dart';
import '../medications/medications_screen.dart';
import '../profile/profile_screen.dart';
import '../visits/visits_screen.dart';

/// Signed-in shell: four tabs under a floating liquid-glass tab bar, plus the
/// check-up action. Tabs are built the first time they're opened, so e.g. the
/// Visits tab doesn't ask for location until someone looks at it.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static const home = 0, medicines = 1, visits = 2, profile = 3;

  static void startCheckup(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CheckupFlowScreen()));

  /// Closes any pushed screens and switches to tab [index].
  static void openTab(BuildContext context, int index) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    _tabRequest.value = index;
  }

  static final _tabRequest = ValueNotifier<int?>(null);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final Set<int> _built = {0};

  static const _items = [
    GlassNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    GlassNavItem(icon: Icons.medication_outlined, activeIcon: Icons.medication_rounded, label: 'Medicines'),
    GlassNavItem(icon: Icons.event_outlined, activeIcon: Icons.event_rounded, label: 'Visits'),
    GlassNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    MainShell._tabRequest.addListener(_onTabRequest);
    // Signed in: rebuild reminders (tops up courses, drops finished ones).
    WidgetsBinding.instance.addPostFrameCallback((_) => NotificationService().sync());
  }

  @override
  void dispose() {
    MainShell._tabRequest.removeListener(_onTabRequest);
    super.dispose();
  }

  void _onTabRequest() {
    final i = MainShell._tabRequest.value;
    if (i == null) return;
    MainShell._tabRequest.value = null;
    _select(i);
  }

  void _select(int i) => setState(() {
        _index = i;
        _built.add(i);
      });

  Widget _tab(int i) => switch (i) {
        0 => HomeScreen(onOpenTab: _select),
        1 => const MedicationsScreen(),
        2 => const VisitsScreen(),
        _ => const ProfileScreen(),
      };

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0);
      },
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            IndexedStack(
              index: _index,
              children: [
                for (var i = 0; i < _items.length; i++)
                  _built.contains(i) ? _tab(i) : const SizedBox.shrink(),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GlassNavBar(
                items: _items,
                index: _index,
                onSelect: _select,
                actionIcon: Icons.monitor_heart_rounded,
                actionLabel: 'Start a check-up',
                onAction: () => MainShell.startCheckup(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
