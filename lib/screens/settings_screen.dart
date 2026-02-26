import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/pdf_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
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
    final settingsService = Provider.of<SettingsService>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        centerTitle: false, // Left align the title
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
            _buildSectionHeader('PREFERENCES', isDark),
            _buildSwitchTile(
              'Dark Mode',
              'Adjust the app theme',
              settingsService.isDarkMode,
              isDark,
              (val) {
                settingsService.toggleTheme(val);
              },
            ),
            _buildSwitchTile(
              'Notifications',
              'Receive health alerts and reminders',
              _notificationsEnabled,
              isDark,
              (val) {
                setState(() => _notificationsEnabled = val);
                _toggleSetting('notificationsEnabled', val);
              },
            ),
            _buildDropdownTile(
              'Temperature Unit',
              'Choose your preferred unit',
              settingsService.tempUnit == 'Celsius' ? 'Celsius (°C)' : 'Fahrenheit (°F)',
              isDark,
              ['Celsius (°C)', 'Fahrenheit (°F)'],
              (val) {
                if (val != null) {
                  settingsService.setTempUnit(val.contains('Celsius') ? 'Celsius' : 'Fahrenheit');
                }
              },
            ),
            
            _buildSectionHeader('DATA', isDark),
            _buildActionTile(
              'Download History',
              'Export your health data as PDF',
              Icons.download_outlined,
              isDark,
              _isDownloading ? null : () async {
                setState(() => _isDownloading = true);
                await PDFService().generateAndShareHistory();
                if (mounted) setState(() => _isDownloading = false);
              },
              trailing: _isDownloading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey)) : null,
            ),

            _buildSectionHeader('ABOUT', isDark),
            _buildActionTile(
              'App Version',
              'v1.0.0 (Demo)',
              Icons.info_outline,
              isDark,
              null,
            ),
            _buildActionTile(
              'Help and Support',
              'Contact our medical team',
              Icons.help_outline,
              isDark,
              () {},
            ),
            _buildActionTile(
              'Terms and Privacy Policy',
              'Read our legal documents',
              Icons.description_outlined,
              isDark,
              () {},
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, bool isDark, Function(bool) onChanged) {
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

  Widget _buildDropdownTile(String title, String subtitle, String value, bool isDark, List<String> options, Function(String?) onChanged) {
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

  Widget _buildActionTile(String title, String subtitle, IconData icon, bool isDark, VoidCallback? onTap, {Widget? trailing}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      onTap: onTap,
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: trailing ?? Icon(icon, size: 20, color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
    );
  }
}
