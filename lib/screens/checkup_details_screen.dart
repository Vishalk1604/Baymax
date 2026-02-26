import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../baymax/models/baymax_models.dart';

class CheckupDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> checkup;

  const CheckupDetailsScreen({super.key, required this.checkup});

  @override
  State<CheckupDetailsScreen> createState() => _CheckupDetailsScreenState();
}

class _CheckupDetailsScreenState extends State<CheckupDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = Provider.of<SettingsService>(context);
    
    final timestamp = widget.checkup['TimeStamp'] as dynamic;
    DateTime dateTime = DateTime.now();
    if (timestamp != null) {
      dateTime = timestamp.toDate();
    }

    final String recommendation = widget.checkup['Recommendation'] ?? 'No recommendation recorded.';
    final String medName = widget.checkup['Medication'] ?? 'None';
    final bool isEscalated = widget.checkup['Escalated'] ?? false;

    // Resolve detailed info for the primary medication if it exists
    Medication primaryMed = Medication.none;
    try {
      primaryMed = Medication.values.firstWhere(
        (m) => m.displayName == medName || medName.contains(m.name),
        orElse: () => Medication.none,
      );
    } catch (_) {}

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Check-Up Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('MMMM dd, yyyy').format(dateTime),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            Text(
              DateFormat('hh:mm a').format(dateTime),
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            
            _buildSectionHeader('VITALS', isDark),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildVitalCard(
                    'Temp', 
                    settings.formatTemp((widget.checkup['Temp'] as num).toDouble()), 
                    isDark, 
                    theme
                  )
                ),
                const SizedBox(width: 12),
                Expanded(child: _buildVitalCard('Heart Rate', '${widget.checkup['HeartRate']} BPM', isDark, theme)),
                const SizedBox(width: 12),
                Expanded(child: _buildVitalCard('SpO2', '${widget.checkup['SpO2']}%', isDark, theme)),
              ],
            ),
            
            const SizedBox(height: 40),
            _buildSectionHeader('OBSERVATIONS', isDark),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0)),
              ),
              child: Text(
                widget.checkup['Observation']?.toString().isNotEmpty == true 
                    ? widget.checkup['Observation'] 
                    : 'No observations recorded.',
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.grey[300] : const Color(0xFF1A1A1A),
                  height: 1.5,
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            _buildSectionHeader('BAYMAX RECOMMENDATION', isDark),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isEscalated 
                    ? Colors.red.withOpacity(0.1) 
                    : (isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF5F7F9)),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isEscalated ? Colors.red.withOpacity(0.3) : (isDark ? const Color(0xFF2C2C2C) : Colors.transparent),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recommendation,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isEscalated ? Colors.red : (isDark ? Colors.white : Colors.black87),
                      height: 1.5,
                    ),
                  ),
                  
                  if (!isEscalated && primaryMed != Medication.none) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildMedicationDetails(primaryMed, isDark),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationDetails(Medication med, bool isDark) {
    final info = med.standardAdultDosing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          med.displayName.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        _buildInfoRow('Dose', info.dose, isDark),
        _buildInfoRow('Frequency', info.frequency, isDark),
        _buildInfoRow('Max Daily', info.maxDailyDose, isDark),
        const SizedBox(height: 12),
        Text(
          'Note: ${info.notes}',
          style: TextStyle(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: isDark ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.grey[400] : Colors.grey[600],
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildVitalCard(String label, String value, bool isDark, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0)),
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
