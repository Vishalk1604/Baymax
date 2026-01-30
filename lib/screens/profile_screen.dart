import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  bool _isEditing = false;
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _bloodController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _ageController = TextEditingController();
    _bloodController = TextEditingController();
    _heightController = TextEditingController();
    _weightController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _bloodController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  String? _validateBloodType(String? value) {
    if (value == null || value.isEmpty) return 'Enter blood type';
    final cleanValue = value.trim().toUpperCase();
    final validTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    if (!validTypes.contains(cleanValue)) return 'Invalid';
    return null;
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'name': _nameController.text.trim(),
          'age': int.parse(_ageController.text.trim()),
          'blood': _bloodController.text.trim().toUpperCase(),
          'height': int.parse(_heightController.text.trim()),
          'weight': int.parse(_weightController.text.trim()),
        });
        setState(() => _isEditing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('No profile data found.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          
          if (!_isEditing) {
            _nameController.text = data['name'] ?? '';
            _ageController.text = (data['age'] ?? '').toString();
            _bloodController.text = data['blood'] ?? '';
            _heightController.text = (data['height'] ?? '').toString();
            _weightController.text = (data['weight'] ?? '').toString();
          }

          return _isEditing ? _buildEditView(theme, isDark) : _buildProfileView(data, theme, isDark);
        },
      ),
    );
  }

  Widget _buildProfileView(Map<String, dynamic> data, ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Top Header Section (Dark)
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white, size: 20),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SettingsScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  data['name'] ?? 'User Name',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  data['email'] ?? '',
                  style: TextStyle(
                    color: Colors.white.withAlpha(150),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Edit Profile Button
                ElevatedButton.icon(
                  onPressed: () => setState(() => _isEditing = true),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withAlpha(30),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: BorderSide(color: Colors.white.withAlpha(50)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Stats Section
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildStatCell('AGE', '${data['age'] ?? '--'}', isDark)),
                    Expanded(child: _buildStatCell('BLOOD TYPE', data['blood']?.toString().toUpperCase() ?? '--', isDark)),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(child: _buildStatCell('HEIGHT', '${data['height'] ?? '--'} cm', isDark)),
                    Expanded(child: _buildStatCell('WEIGHT', '${data['weight'] ?? '--'} kg', isDark)),
                  ],
                ),
                const SizedBox(height: 40),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'RECENT HISTORY',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey[400] : Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: Text(
                      'No recent check-ups found',
                      style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  onTap: () => FirebaseAuth.instance.signOut(),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditView(ThemeData theme, bool isDark) {
    return Column(
      children: [
        // Dark Header
        Container(
          width: double.infinity,
          color: const Color(0xFF1A1A1A),
          padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                  onPressed: () => setState(() => _isEditing = false),
                ),
              ),
              const Text(
                'Edit Profile',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              _isLoading
                  ? const SizedBox(width: 40, height: 40, child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                  : ElevatedButton(
                      onPressed: _updateProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        minimumSize: const Size(0, 36),
                      ),
                      child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
            ],
          ),
        ),
        
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BASIC INFORMATION',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey, letterSpacing: 1.1),
                  ),
                  const SizedBox(height: 20),
                  _buildLabel('FULL NAME', isDark),
                  _buildImageStyledTextField(_nameController, 'Enter your name', isDark),
                  const SizedBox(height: 40),
                  Text(
                    'PERSONAL DETAILS',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey, letterSpacing: 1.1),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('AGE', isDark),
                            _buildImageStyledTextField(_ageController, '28', isDark, keyboardType: TextInputType.number, digitsOnly: true),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('BLOOD TYPE', isDark),
                            _buildImageStyledTextField(_bloodController, 'A+', isDark, validator: _validateBloodType),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('HEIGHT', isDark),
                            _buildImageStyledTextField(_heightController, "5'10\"", isDark, keyboardType: TextInputType.number, digitsOnly: true),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('WEIGHT', isDark),
                            _buildImageStyledTextField(_weightController, '165 lbs', isDark, keyboardType: TextInputType.number, digitsOnly: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildImageStyledTextField(TextEditingController controller, String hint, bool isDark, {TextInputType? keyboardType, bool digitsOnly = false, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : [],
      validator: validator,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
        filled: true,
        fillColor: isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF5F7F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: isDark ? const BorderSide(color: Color(0xFF2C2C2C)) : BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildStatCell(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.1),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
        ),
      ],
    );
  }
}
