import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  bool _hasUnsavedChanges = false;
  bool _isLoading = true;
  bool _isSaving = false;

  // Form controllers
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _emailController = TextEditingController();
  final _incomeController = TextEditingController();
  final _otherEmploymentController = TextEditingController();

  // Dropdown values
  String? _selectedEmploymentType;
  String? _selectedRiskAppetite;
  DateTime? _joinedDate;

  // Employment types
  final List<String> _employmentTypes = [
    'Government',
    'Private',
    'Government Aided',
    'Student',
    'Retired',
    'Other',
  ];

  // Risk appetite options
  final List<String> _riskAppetiteOptions = ['High', 'Medium', 'Low'];

  // Original data for comparison
  Map<String, dynamic> _originalData = {};

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _incomeController.dispose();
    _otherEmploymentController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() => _isLoading = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _originalData = Map<String, dynamic>.from(data);

        setState(() {
          _nameController.text = data['Name'] ?? '';
          _ageController.text = data['age']?.toString() ?? '';
          _emailController.text = data['email'] ?? '';
          _incomeController.text = data['income']?.toString() ?? '';
          _selectedEmploymentType = data['employmentType'];
          _selectedRiskAppetite = data['riskAppetite'];
          _joinedDate = data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : null;

          // Handle "Other" employment type
          if (_selectedEmploymentType != null &&
              !_employmentTypes.contains(_selectedEmploymentType)) {
            _otherEmploymentController.text = _selectedEmploymentType!;
            _selectedEmploymentType = 'Other';
          }

          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onFieldChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  Future<bool> _onWillPop() async {
    if (_hasUnsavedChanges && !_isSaving) {
      return await _showUnsavedChangesDialog();
    }
    return true;
  }

  Future<bool> _showUnsavedChangesDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => Container(
            margin: const EdgeInsets.all(16),
            child: AlertDialog(
              backgroundColor: Colors.white.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              title: const Text(
                'Unsaved Changes',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              content: Text(
                'You have unsaved changes. Do you want to save them before leaving?',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    'Discard',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(context).pop(false);
                      await _saveProfile();
                      if (mounted) Navigator.of(context).pop(true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      final employmentType = _selectedEmploymentType == 'Other'
          ? _otherEmploymentController.text.trim()
          : _selectedEmploymentType;

      final updatedData = {
        'Name': _nameController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()) ?? 0,
        'email': _emailController.text.trim(),
        'income': double.tryParse(_incomeController.text.trim()) ?? 0.0,
        'employmentType': employmentType,
        'riskAppetite': _selectedRiskAppetite,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(updatedData);

      setState(() {
        _hasUnsavedChanges = false;
        _isEditing = false;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Profile updated successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }

      // Reload the profile to get fresh data
      _loadUserProfile();
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error updating profile: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E27),
        appBar: AppBar(
          title: const Text(
            "Profile",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.black12,
          surfaceTintColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            if (!_isEditing && !_isLoading)
              Container(
                margin: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit, color: Color(0xFF8B5CF6)),
                  ),
                  onPressed: () => setState(() => _isEditing = true),
                ),
              ),
            if (_isEditing)
              Container(
                margin: const EdgeInsets.only(right: 16),
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close, color: Colors.red),
                  ),
                  onPressed: () async {
                    if (_hasUnsavedChanges) {
                      final shouldDiscard = await _showUnsavedChangesDialog();
                      if (shouldDiscard) {
                        setState(() {
                          _isEditing = false;
                          _hasUnsavedChanges = false;
                        });
                        _loadUserProfile(); // Reload original data
                      }
                    } else {
                      setState(() => _isEditing = false);
                    }
                  },
                ),
              ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0A0E27),
                Color(0xFF1A1B3A),
                Color(0xFF2E1065),
                Color(0xFF4C1D95),
                Color(0xFF5B21B6),
              ],
              stops: [0.0, 0.25, 0.5, 0.75, 1.0],
            ),
          ),
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Profile Header - same style as home page welcome section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Color(0xFF8B5CF6),
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _nameController.text.isNotEmpty
                                        ? _nameController.text
                                        : user?.displayName ?? "User Profile",
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _joinedDate != null
                                        ? 'Member since ${_joinedDate!.year}'
                                        : user?.email ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Full Name Field
                      _buildEnhancedProfileField(
                        label: 'Full Name',
                        controller: _nameController,
                        icon: Icons.person_outline,
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Name is required';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Age and Income Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildEnhancedProfileField(
                              label: 'Age',
                              controller: _ageController,
                              icon: Icons.cake_outlined,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value?.trim().isEmpty ?? true) {
                                  return 'Age is required';
                                }
                                final age = int.tryParse(value!);
                                if (age == null || age < 16 || age > 100) {
                                  return 'Enter valid age (16-100)';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildEnhancedProfileField(
                              label: 'Monthly Income (₹)',
                              controller: _incomeController,
                              icon: Icons.currency_rupee,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value?.trim().isEmpty ?? true) {
                                  return 'Income is required';
                                }
                                final income = double.tryParse(value!);
                                if (income == null || income < 0) {
                                  return 'Enter valid income';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Email Field
                      _buildEnhancedProfileField(
                        label: 'Email',
                        controller: _emailController,
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        enabled: false,
                      ),

                      const SizedBox(height: 16),

                      // Employment Type and Risk Appetite Row
                      Row(
                        children: [
                          Expanded(child: _buildEmploymentTypeField()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildRiskAppetiteField()),
                        ],
                      ),

                      // Other Employment Type Field (if needed)
                      if (_selectedEmploymentType == 'Other') ...[
                        const SizedBox(height: 16),
                        _buildEnhancedProfileField(
                          label: 'Specify Employment Type',
                          controller: _otherEmploymentController,
                          icon: Icons.work_outline,
                          validator: (value) {
                            if (_selectedEmploymentType == 'Other' &&
                                (value?.trim().isEmpty ?? true)) {
                              return 'Please specify your employment type';
                            }
                            return null;
                          },
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Save Button
                      if (_isEditing) ...[
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Save Changes',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 100),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildEnhancedProfileField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          enabled: _isEditing && enabled,
          onChanged: _isEditing ? (_) => _onFieldChanged() : null,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
            prefixIcon: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF8B5CF6), size: 20),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmploymentTypeField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.work_outline,
                color: Color(0xFF8B5CF6),
                size: 20,
              ),
            ),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedEmploymentType,
                decoration: InputDecoration(
                  labelText: 'Employment Type',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                  border: InputBorder.none,
                ),
                dropdownColor: const Color(0xFF1A1B3A),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                items: _employmentTypes.map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(
                      type,
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }).toList(),
                onChanged: _isEditing
                    ? (String? newValue) {
                        setState(() {
                          _selectedEmploymentType = newValue;
                          if (newValue != 'Other') {
                            _otherEmploymentController.clear();
                          }
                        });
                        _onFieldChanged();
                      }
                    : null,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Employment type is required';
                  }
                  if (value == 'Other' &&
                      _otherEmploymentController.text.trim().isEmpty) {
                    return 'Please specify employment type';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskAppetiteField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.trending_up,
                color: Color(0xFF8B5CF6),
                size: 20,
              ),
            ),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedRiskAppetite,
                decoration: InputDecoration(
                  labelText: 'Risk Appetite',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                  border: InputBorder.none,
                ),
                dropdownColor: const Color(0xFF1A1B3A),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                items: _riskAppetiteOptions.map((String risk) {
                  return DropdownMenuItem<String>(
                    value: risk,
                    child: Row(
                      children: [
                        Icon(
                          _getRiskIcon(risk),
                          color: _getRiskColor(risk),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(risk, style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: _isEditing
                    ? (String? newValue) {
                        setState(() => _selectedRiskAppetite = newValue);
                        _onFieldChanged();
                      }
                    : null,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Risk appetite is required';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getRiskIcon(String risk) {
    switch (risk.toLowerCase()) {
      case 'high':
        return Icons.trending_up;
      case 'medium':
        return Icons.trending_flat;
      case 'low':
        return Icons.trending_down;
      default:
        return Icons.help_outline;
    }
  }

  Color _getRiskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
