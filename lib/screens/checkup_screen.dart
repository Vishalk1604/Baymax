import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/health_device_service.dart';
import '../baymax/baymax_controller.dart';
import '../baymax/models/baymax_models.dart';
import '../baymax/services/baymax_llm_service.dart';

// Import the dotenv package
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CheckUpScreen extends StatefulWidget {
  const CheckUpScreen({super.key});

  @override
  State<CheckUpScreen> createState() => _CheckUpScreenState();
}

class _CheckUpScreenState extends State<CheckUpScreen> {
  final HealthDeviceService _healthService = HealthDeviceService();
  late final BaymaxController _baymaxController;
  final TextEditingController _observationsController = TextEditingController();
  final TextEditingController _verificationAnswerController = TextEditingController();
  final TextEditingController _tempDebugController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isConnected = false;
  bool _isMeasuring = false;
  bool _isEvaluating = false;
  String _statusMessage = 'Ready to start';
  HealthReading? _lastReading;
  bool _hasTakenReading = false;
  bool _isTestMode = false;

  // Baymax Algorithm States
  RecommendationResult? _recommendationResult;
  VerificationQuestion? _verificationQuestion;
  bool _isSaving = false;
  List<SafetyAlert> _safetyAlerts = [];
  List<StandardSymptom> _detectedSymptoms = [];

  @override
  void initState() {
    super.initState();
    
    // Initialize Baymax Controller with the provided API Key
    // Load the API Key from .env file
    final apiKey = dotenv.env['BAYMAX_API_KEY'];
    if (apiKey == null) {
      // Handle error: API Key not found in .env file
      // For example, throw an exception or show an error message
      throw Exception("BAYMAX_API_KEY not found in .env file");
    }

    final llmService = BaymaxLlmService(
      config: BaymaxLlmConfig(
        apiKey: apiKey,
      ),
    );
    _baymaxController = BaymaxController(llmService: llmService);

    _isConnected = _healthService.isConnected;
    _isMeasuring = _healthService.isMeasuring;
    _statusMessage = _healthService.measurementStatus;
    _lastReading = _healthService.lastReading;
    if (_lastReading != null) _hasTakenReading = true;

    _healthService.connectionStream.listen((connected) {
      if (mounted) setState(() => _isConnected = connected);
    });

    _healthService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _statusMessage = status;
          _isMeasuring = _healthService.isMeasuring;
        });
      }
    });

    _healthService.readingStream.listen((reading) {
      if (mounted) {
        setState(() {
          _lastReading = reading;
          _hasTakenReading = true;
          _isTestMode = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _observationsController.dispose();
    _verificationAnswerController.dispose();
    _tempDebugController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleConnect() async {
    if (_isConnected) {
      _healthService.disconnect();
    } else {
      bool success = await _healthService.connectToBAYMAX();
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to connect')));
      }
    }
  }

  void _startMeasurement() async {
    if (!_isConnected) return;
    await _healthService.startMeasurement();
  }

  void _enableTestMode() {
    setState(() {
      _isTestMode = true;
      _lastReading = HealthReading(temperature: 38.6, heartRate: 75, spo2: 98);
      _tempDebugController.text = "38.6";
      _hasTakenReading = true;
      _recommendationResult = null;
      _verificationQuestion = null;
      _safetyAlerts = [];
      _detectedSymptoms = [];
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Test Mode Enabled: Fever Vitals Applied')));
  }

  Future<void> _evaluateHealth() async {
    if (_lastReading == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Take a reading or enable test mode first')));
      return;
    }

    // Sync edited temp from controller if in test mode
    if (_isTestMode) {
      final editedTemp = double.tryParse(_tempDebugController.text);
      if (editedTemp != null) {
        _lastReading = HealthReading(
          temperature: editedTemp, 
          heartRate: _lastReading!.heartRate, 
          spo2: _lastReading!.spo2
        );
      }
    }

    setState(() {
      _isEvaluating = true;
      _recommendationResult = null;
      _verificationQuestion = null;
      _safetyAlerts = [];
      _detectedSymptoms = [];
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final vitals = VitalsReading(
        temperatureCelsius: _lastReading!.temperature,
        spo2Percent: _lastReading!.spo2.toDouble(),
        heartRateBpm: _lastReading!.heartRate,
        timestamp: DateTime.now(),
      );

      // Step 1: Analyze Vitals
      final vitalsAnalysis = _baymaxController.analyzeVitals(vitals);
      if (vitalsAnalysis.requiresEmergency) {
        setState(() {
          _recommendationResult = _baymaxController.buildEscalationResult(
            reason: vitalsAnalysis.emergencyAlert?.message,
          );
        });
        return;
      }

      // Step 2: Standardize Symptoms (LLM Call)
      final symptomResult = await _baymaxController.standardizeSymptoms(
        rawDescription: _observationsController.text.trim(),
        vitals: vitals,
        vitalsSymptoms: vitalsAnalysis.vitalsSymptoms,
      );

      setState(() {
        _detectedSymptoms = symptomResult.symptoms;
      });

      // Step 3: Run Safety Checks
      final safetyStepResult = _baymaxController.runSafetyChecks();
      setState(() {
        _safetyAlerts = safetyStepResult.safetyResult.alerts;
      });

      if (!safetyStepResult.canProceed) {
        setState(() {
          _recommendationResult = _baymaxController.buildEscalationResult();
        });
        return;
      }

      // Step 4: Match Case
      final caseMatchResult = _baymaxController.matchCase();
      if (!caseMatchResult.hasMatch) {
        setState(() {
          _recommendationResult = _baymaxController.buildNoMatchResult();
        });
        return;
      }

      // Step 5: Get Verification Question
      final question = _baymaxController.getVerificationQuestion();
      if (question != null) {
        setState(() {
          _verificationQuestion = question;
        });
        _scrollToBottom();
      } else {
        setState(() {
          _recommendationResult = _baymaxController.buildNoMatchResult();
        });
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isEvaluating = false);
    }
  }

  Future<void> _submitVerification(String answer, [int optionIndex = -1]) async {
    setState(() {
      _isEvaluating = true;
    });

    try {
      final result = await _baymaxController.submitVerificationAnswer(
        userAnswer: answer,
        optionIndex: optionIndex,
      );

      // Check if this medication already exists in reminders
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !result.escalateToDoctor) {
        final medsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('Medication')
            .where('Name', isEqualTo: result.primaryMedication.simpleName)
            .get();

        if (medsSnapshot.docs.isNotEmpty) {
          // MEDICATION EXISTS - Force Escalation UI
          final existingResult = RecommendationResult(
            primaryMedication: result.primaryMedication,
            secondaryMedication: result.secondaryMedication,
            dosing: result.dosing,
            secondaryDosing: result.secondaryDosing,
            safetyAlerts: [
              ...result.safetyAlerts,
              SafetyAlert(
                level: AlertLevel.danger, 
                message: "⚠️ You are already taking ${result.primaryMedication.simpleName}. If symptoms haven't improved, please consult a doctor instead of self-medicating further.",
                requiresEscalation: true
              )
            ],
            escalateToDoctor: true,
            escalationReason: "Persistent symptoms despite ongoing medication (${result.primaryMedication.simpleName}).",
            summary: "⚠️ Since you are already taking ${result.primaryMedication.simpleName} and symptoms persist, please visit a doctor for a proper evaluation. Do not take extra doses.",
            isWithinOtcBoundary: false
          );
          setState(() {
            _recommendationResult = existingResult;
            _verificationQuestion = null;
          });
          return;
        }
      }

      setState(() {
        _recommendationResult = result;
        _verificationQuestion = null;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isEvaluating = false);
    }
  }

  Future<void> _saveToFirebase() async {
    if (_recommendationResult == null) return;
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 1. Get unique index for this session
      final checkupsRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('Checkups');
      final querySnapshot = await checkupsRef.orderBy('Index', descending: true).limit(1).get();
      int nextIndex = querySnapshot.docs.isNotEmpty ? querySnapshot.docs.first.get('Index') + 1 : 1;

      // 2. Save Checkup History
      await checkupsRef.add({
        'Temp': (_lastReading?.temperature ?? 35.6),
        'SpO2': _lastReading?.spo2 ?? 98,
        'HeartRate': _lastReading?.heartRate ?? 72,
        'TimeStamp': FieldValue.serverTimestamp(),
        'Observation': _observationsController.text.trim(),
        'Recommendation': _recommendationResult!.summary,
        'Medication': _recommendationResult!.primaryMedication.displayName,
        'Escalated': _recommendationResult!.escalateToDoctor,
        'Index': nextIndex,
      });

      // 3. Add Medication to Reminders (ONLY IF NEW)
      if (!_recommendationResult!.escalateToDoctor && _recommendationResult!.primaryMedication != Medication.none) {
        // Double check existence one last time before adding
        final medsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('Medication')
            .where('Name', isEqualTo: _recommendationResult!.primaryMedication.simpleName)
            .get();

        if (medsSnapshot.docs.isEmpty) {
          await _addMedToAlgorithmSection(user.uid, _recommendationResult!.primaryMedication, _recommendationResult!.dosing, nextIndex);
          
          if (_recommendationResult!.secondaryMedication != null) {
            await _addMedToAlgorithmSection(user.uid, _recommendationResult!.secondaryMedication!, _recommendationResult!.secondaryDosing!, nextIndex);
          }
        }
      }

      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _addMedToAlgorithmSection(String userId, Medication med, DosingInfo dosing, int uniqueIndex) async {
    final medsRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('Medication');
    
    // Save medication in the simple format (no alternative name or dosage in string)
    await medsRef.add({
      'Name': med.simpleName,
      'Dosage': 0, 
      'Food Relation': 'As advised',
      'Duration': 3, 
      'Index': uniqueIndex, 
      'Source': 'AI Recommendation',
      'Symptoms': _detectedSymptoms.map((s) => s.name).join(', '),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        title: const Text('Health Check-Up', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _enableTestMode,
            icon: Icon(Icons.bug_report, color: _isTestMode ? Colors.green : Colors.white),
            tooltip: 'Test Mode',
          )
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection & Measurements Section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: theme.cardTheme.color, borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0))),
              child: Column(children: [
                Icon(_isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled, size: 48, color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
                const SizedBox(height: 16),
                Text(_isConnected ? 'Device Connected' : 'Device Not Connected', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _handleConnect, style: ElevatedButton.styleFrom(backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(_isConnected ? 'Disconnect' : 'Connect')))
              ]),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: _buildVitalDebugCard('Temp', _lastReading != null ? '${_lastReading!.temperature.toStringAsFixed(1)}°C' : '--', isDark, theme, _isTestMode)),
              const SizedBox(width: 12),
              Expanded(child: _buildDataCard('HR', _lastReading != null ? '${_lastReading!.heartRate}' : '--', isDark, theme)),
              const SizedBox(width: 12),
              Expanded(child: _buildDataCard('SpO2', _lastReading != null ? '${_lastReading!.spo2}%' : '--', isDark, theme)),
            ]),
            const SizedBox(height: 24),
            if (!_isMeasuring) SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _isEvaluating ? null : _startMeasurement, icon: const Icon(Icons.play_arrow), label: const Text('Take Readings'), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))))),
            
            const SizedBox(height: 32),
            const Text('Observations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(controller: _observationsController, maxLines: 3, decoration: InputDecoration(hintText: 'Describe how you feel...', filled: true, fillColor: isDark ? const Color(0xFF1C1C1C) : Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
            
            // --- DETECTED SYMPTOMS FEEDBACK ---
            if (_detectedSymptoms.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildResultStep('Symptoms Extracted by Baymax', _buildSymptomChips(_detectedSymptoms, Colors.blue, isDark), theme),
            ],

            const SizedBox(height: 24),
            if (_recommendationResult == null && _verificationQuestion == null) SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: _isEvaluating ? null : () => _evaluateHealth(), style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.white : Colors.black, foregroundColor: isDark ? Colors.black : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: _isEvaluating ? const CircularProgressIndicator(color: Colors.grey) : const Text('Evaluate Health', style: TextStyle(fontWeight: FontWeight.bold)))),

            // --- SAFETY ALERTS ---
            if (_safetyAlerts.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text('Safety Notices', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange)),
              const SizedBox(height: 8),
              ..._safetyAlerts.map((alert) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getAlertColor(alert.level).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getAlertColor(alert.level).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(_getAlertIcon(alert.level), color: _getAlertColor(alert.level), size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(alert.message, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87))),
                  ],
                ),
              )).toList(),
            ],

            // --- VERIFICATION CHATBOT INTERFACE ---
            if (_verificationQuestion != null) ...[
              const SizedBox(height: 32),
              _buildChatBotInterface(isDark, theme),
            ],

            // --- FINAL RECOMMENDATION RESULT ---
            if (_recommendationResult != null) ...[
              const SizedBox(height: 32),
              _buildFinalResultCard(isDark, theme),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: _isSaving ? null : _saveToFirebase, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Result', style: TextStyle(fontWeight: FontWeight.bold)))),
            ],
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildSymptomChips(List<StandardSymptom> items, Color color, bool isDark) {
    return Wrap(
      spacing: 8, 
      runSpacing: 8, 
      children: items.map((item) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), 
        decoration: BoxDecoration(
          color: color.withOpacity(0.1), 
          borderRadius: BorderRadius.circular(8), 
          border: Border.all(color: color.withOpacity(0.3))
        ), 
        child: Text(
          item.name.replaceAll('_', ' ').toUpperCase(), 
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white.withOpacity(0.9) : color)
        )
      )).toList()
    );
  }

  Widget _buildChatBotInterface(bool isDark, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(backgroundColor: Colors.blue, radius: 12, child: Icon(Icons.medical_services, size: 14, color: Colors.white)),
              const SizedBox(width: 10),
              Text('Baymax Assistant', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.blue[300] : Colors.blue[700])),
            ],
          ),
          const SizedBox(height: 16),
          Text(_verificationQuestion!.question, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _verificationQuestion!.options.asMap().entries.map((entry) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isEvaluating ? null : () => _submitVerification(entry.value, entry.key),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF333333) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.5), width: 1.5),
                    ),
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.blue[900],
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_verificationQuestion!.allowFreeText) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _verificationAnswerController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Type your answer...',
                hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _isEvaluating ? null : () {
                    if (_verificationAnswerController.text.isNotEmpty) {
                      _submitVerification(_verificationAnswerController.text);
                      _verificationAnswerController.clear();
                    }
                  },
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinalResultCard(bool isDark, ThemeData theme) {
    return _buildResultStep(
      _recommendationResult!.escalateToDoctor ? 'Doctor Consultation Advised' : 'Recommended Action',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_recommendationResult!.summary, style: TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.bold,
            color: _recommendationResult!.escalateToDoctor ? Colors.red : (isDark ? Colors.white : Colors.black87)
          )),
          if (!_recommendationResult!.escalateToDoctor && _recommendationResult!.primaryMedication != Medication.none) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _buildDosingInfo('Primary', _recommendationResult!.primaryMedication.displayName, _recommendationResult!.dosing),
            if (_recommendationResult!.secondaryMedication != null) ...[
              const SizedBox(height: 16),
              _buildDosingInfo('Secondary', _recommendationResult!.secondaryMedication!.displayName, _recommendationResult!.secondaryDosing!),
            ],
          ],
        ],
      ),
      theme,
    );
  }

  Widget _buildDosingInfo(String type, String name, DosingInfo dosing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$type Medication:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(name, style: const TextStyle(fontSize: 14, color: Colors.blue)),
        const SizedBox(height: 4),
        Text('Dose: ${dosing.dose}', style: const TextStyle(fontSize: 13)),
        Text('Frequency: ${dosing.frequency}', style: const TextStyle(fontSize: 13)),
        if (dosing.notes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Note: ${dosing.notes}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey))),
      ],
    );
  }

  Widget _buildResultStep(String title, Widget content, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: theme.cardTheme.color, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1.1)), const SizedBox(height: 12), content]));
  }

  Widget _buildDataCard(String label, String value, bool isDark, ThemeData theme) {
    return Container(padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12), decoration: BoxDecoration(color: theme.cardTheme.color, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0))), child: Column(children: [Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.1)), const SizedBox(height: 8), FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))]));
  }

  Widget _buildVitalDebugCard(String label, String value, bool isDark, ThemeData theme, bool editable) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          if (editable)
            SizedBox(
              height: 40,
              child: TextField(
                controller: _tempDebugController,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
              ),
            )
          else
            FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Color _getAlertColor(AlertLevel level) {
    return switch (level) {
      AlertLevel.info => Colors.blue,
      AlertLevel.warning => Colors.orange,
      AlertLevel.danger => Colors.red,
      AlertLevel.emergency => Colors.red[900]!,
    };
  }

  IconData _getAlertIcon(AlertLevel level) {
    return switch (level) {
      AlertLevel.info => Icons.info_outline,
      AlertLevel.warning => Icons.warning_amber_rounded,
      AlertLevel.danger => Icons.error_outline,
      AlertLevel.emergency => Icons.report_problem_rounded,
    };
  }
}
