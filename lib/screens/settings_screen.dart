import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  String _tempUnit = 'Celsius (°C)';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _tempUnit = prefs.getString('tempUnit') ?? 'Celsius (°C)';
    });
  }

  Future<void> _toggleSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('PREFERENCES'),
            _buildSwitchTile(
              'Dark Mode',
              'Adjust the app theme',
              themeService.isDarkMode,
              (val) {
                themeService.toggleTheme(val);
              },
            ),
            _buildSwitchTile(
              'Notifications',
              'Receive health alerts and reminders',
              _notificationsEnabled,
              (val) {
                setState(() => _notificationsEnabled = val);
                _toggleSetting('notificationsEnabled', val);
              },
            ),
            _buildDropdownTile(
              'Temperature Unit',
              'Choose your preferred unit',
              _tempUnit,
              ['Celsius (°C)', 'Fahrenheit (°F)'],
              (val) {
                setState(() => _tempUnit = val!);
                _toggleSetting('tempUnit', val);
              },
            ),
            
            _buildSectionHeader('DATA'),
            _buildActionTile(
              'Download History',
              'Export your health data as PDF',
              Icons.download_outlined,
              () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('History download started...')),
                );
              },
            ),

            _buildSectionHeader('ABOUT'),
            _buildActionTile(
              'App Version',
              'v1.0.0 (Stable)',
              Icons.info_outline,
              null,
            ),
            _buildActionTile(
              'Help and Support',
              'Contact our medical team',
              Icons.help_outline,
              () {},
            ),
            _buildActionTile(
              'Terms and Privacy Policy',
              'Read our legal documents',
              Icons.description_outlined,
              () {},
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).brightness == Brightness.dark ? Colors.grey : Colors.grey[600],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: isDark ? Colors.white : const Color(0xFF1A1A1A),
      ),
    );
  }

  Widget _buildDropdownTile(String title, String subtitle, String value, List<String> options, Function(String?) onChanged) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: DropdownButton<String>(
        value: value,
        dropdownColor: isDark ? const Color(0xFF1C1C1C) : Colors.white,
        underline: const SizedBox(),
        items: options.map((String val) {
          return DropdownMenuItem<String>(
            value: val,
            child: Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildActionTile(String title, String subtitle, IconData icon, VoidCallback? onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      onTap: onTap,
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: Icon(icon, size: 20, color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
    );
  }
}
