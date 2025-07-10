import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'login_screen.dart'; // For logout navigation
import '../utils/auth_service.dart'; // For logout functionality

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      _nameController.text = user.displayName ?? 'No Name';
      _emailController.text = user.email ?? 'No Email';
    }
  }

  Future<void> _updateProfile() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Update display name
        if (_nameController.text.trim() != (user.displayName ?? '')) {
          await user.updateDisplayName(_nameController.text.trim());
        }

        // Update email (requires re-authentication for security)
        if (_emailController.text.trim() != (user.email ?? '')) {
          // You would typically prompt for re-authentication here
          // For simplicity, we'll just show a message.
          // In a real app, you'd use showDialog to ask for password
          // and then call user.reauthenticateWithCredential
          // before calling user.updateEmail.
          _showSnackBar(
              'Email update requires re-authentication. Not implemented in this demo.');
        }
        await user.reload(); // Reload user to get updated data
        _loadUserProfile(); // Reload controllers with updated data
        _showSnackBar('Profile updated successfully!', isError: false);
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar('Failed to update profile: ${e.message}');
    } catch (e) {
      _showSnackBar('An unexpected error occurred: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _isEditing = false; // Exit editing mode after update
      });
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[700] : Colors.teal[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      appBar: AppBar(
        title: Text('My Profile', style: TextStyle(color: Colors.white)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal[700]!, Colors.teal[500]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon:
                Icon(_isEditing ? Icons.save : Icons.edit, color: Colors.white),
            onPressed: _isLoading
                ? null
                : () {
                    if (_isEditing) {
                      _updateProfile();
                    } else {
                      setState(() {
                        _isEditing = true;
                      });
                    }
                  },
            tooltip: _isEditing ? 'Save Profile' : 'Edit Profile',
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await AuthService.logout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => LoginScreen()),
              );
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal[600]!),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 30),
                  // Profile Avatar
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 70,
                        backgroundColor: Colors.teal[400],
                        child:
                            Icon(Icons.person, size: 80, color: Colors.white),
                      ),
                      if (_isEditing)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () {
                              _showSnackBar(
                                  'Changing profile picture is not implemented in this demo.');
                            },
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.camera_alt,
                                  size: 20, color: Colors.teal[600]),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 30),

                  // User Name Field
                  _buildProfileField(
                    controller: _nameController,
                    labelText: 'User Name',
                    icon: Icons.person_outline,
                    isEditable: _isEditing,
                  ),
                  SizedBox(height: 20),

                  // Email Field
                  _buildProfileField(
                    controller: _emailController,
                    labelText: 'Email Address',
                    icon: Icons.email_outlined,
                    isEditable: _isEditing,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: 20),

                  // Password Reset (always visible but only functional for editing)
                  _buildProfileField(
                    controller: TextEditingController(
                        text: '********'), // Masked password
                    labelText: 'Password',
                    icon: Icons.lock_outline,
                    isEditable: false, // Not directly editable here
                    suffixIcon: _isEditing
                        ? IconButton(
                            icon: Icon(Icons.refresh, color: Colors.teal[600]),
                            onPressed: () {
                              _showSnackBar(
                                  'Password reset functionality coming soon!');
                            },
                          )
                        : null,
                  ),
                  SizedBox(height: 40),

                  // Save/Cancel Buttons in editing mode
                  if (_isEditing)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _isEditing = false;
                                _loadUserProfile(); // Discard changes
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey[300],
                              padding: EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Cancel',
                                style: TextStyle(
                                    fontSize: 18, color: Colors.blueGrey[800])),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _updateProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal[600],
                              padding: EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : Text('Save Changes',
                                    style: TextStyle(
                                        fontSize: 18, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    required bool isEditable,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.08),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: !isEditable, // Make read-only if not in editing mode
        style: TextStyle(color: Colors.blueGrey[800], fontSize: 16),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(color: Colors.blueGrey[500]),
          prefixIcon: Icon(icon, color: Colors.blueGrey[400], size: 24),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.teal[400]!, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.transparent),
          ),
          filled: true,
          fillColor: isEditable
              ? Colors.white
              : Colors.blueGrey[100], // Visual cue for editability
        ),
      ),
    );
  }
}
