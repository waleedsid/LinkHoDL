import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import '../services/app_settings.dart';
import '../services/link_service.dart';
import '../main.dart'; // For UserProfile model

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppSettings _settings = AppSettings();
  final LinkService _linkService = LinkService();
  bool _isDarkMode = false;
  String _activityFilter = 'all';
  UserProfile _userProfile = UserProfile.defaultProfile();
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _isDarkMode = _settings.isDarkMode;
    _activityFilter = _settings.activityFilter;
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userData = await _linkService.getUserProfile();
      setState(() {
        _userProfile = UserProfile.fromMap(userData);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _linkService.saveUserProfile(_userProfile.toMap());
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error saving user profile: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedImage = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedImage != null) {
        // Read the image file
        try {
          final bytes = await File(pickedImage.path).readAsBytes();

          // Convert to base64 with proper format
          final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

          setState(() {
            _userProfile = _userProfile.copyWith(avatarUrl: base64Image);
          });

          await _saveUserProfile();
        } catch (e) {
          debugPrint('Error processing image: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error processing image: $e')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
    }
  }

  void _editUserProfile() async {
    final result = await showDialog<UserProfile>(
      context: context,
      builder: (context) => _buildEditProfileDialog(),
    );

    if (result != null) {
      setState(() {
        _userProfile = result;
      });
      await _saveUserProfile();
    }
  }

  Widget _buildEditProfileDialog() {
    final nameController = TextEditingController(text: _userProfile.name);
    final emailController =
        TextEditingController(text: _userProfile.email ?? '');

    return AlertDialog(
      title: const Text('Edit Profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: () {
            final updatedProfile = _userProfile.copyWith(
              name: nameController.text,
              email: emailController.text.isEmpty ? null : emailController.text,
            );
            Navigator.pop(context, updatedProfile);
          },
          child: const Text('SAVE'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // User Profile Section
                _buildUserProfileSection(),
                const Divider(),

                // Display Section
                _buildSectionHeader('Display'),
                _buildDarkModeSwitch(),
                const Divider(),

                // Activity Chart Section
                _buildSectionHeader('Activity Chart'),
                _buildActivityFilterOptions(),
                const Divider(),

                // About Section
                _buildSectionHeader('About'),
                _buildAboutTile(),
              ],
            ),
    );
  }

  Widget _buildUserProfileSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('User Profile'),
          const SizedBox(height: 16),
          Row(
            children: [
              InkWell(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.2),
                      backgroundImage: _getAvatarProvider(),
                      child: _userProfile.avatarUrl == null
                          ? Icon(
                              Icons.person,
                              size: 40,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userProfile.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (_userProfile.email != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _userProfile.email!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Joined: ${_formatJoinDate(_userProfile.joinDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _editUserProfile,
                tooltip: 'Edit profile',
              ),
            ],
          ),
        ],
      ),
    );
  }

  ImageProvider? _getAvatarProvider() {
    if (_userProfile.avatarUrl != null) {
      try {
        // Check if it's a base64 image
        if (_userProfile.avatarUrl!.startsWith('data:image')) {
          // Extract only the base64 part after the comma
          final base64Data = _userProfile.avatarUrl!.split(',');
          if (base64Data.length > 1) {
            final bytes = base64Decode(base64Data[1]);
            return MemoryImage(Uint8List.fromList(bytes));
          } else {
            debugPrint('Invalid base64 image format');
            return null;
          }
        } else if (_isBase64(_userProfile.avatarUrl!)) {
          try {
            final bytes = base64Decode(_userProfile.avatarUrl!);
            return MemoryImage(Uint8List.fromList(bytes));
          } catch (e) {
            debugPrint('Error decoding base64: $e');
            return null;
          }
        } else {
          // Assume it's a network image
          try {
            return NetworkImage(_userProfile.avatarUrl!);
          } catch (e) {
            debugPrint('Error loading network image: $e');
            return null;
          }
        }
      } catch (e) {
        debugPrint('Error loading avatar: $e');
        return null;
      }
    }
    return null;
  }

  bool _isBase64(String str) {
    try {
      // Check for valid base64 string
      const base64Regex = r'^[A-Za-z0-9+/=]+$';
      if (!RegExp(base64Regex).hasMatch(str)) {
        return false;
      }

      // Try to decode to validate further
      base64Decode(str);
      return true;
    } catch (e) {
      return false;
    }
  }

  String _formatJoinDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildDarkModeSwitch() {
    return SwitchListTile(
      title: const Text('Dark Mode'),
      subtitle: const Text('Enable dark theme for the app'),
      value: _isDarkMode,
      onChanged: (value) async {
        setState(() {
          _isDarkMode = value;
        });
        await _settings.setDarkMode(value);
      },
      secondary: Icon(
        _isDarkMode ? Icons.dark_mode : Icons.light_mode,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildActivityFilterOptions() {
    return Column(
      children: [
        RadioListTile<String>(
          title: const Text('Last 7 days'),
          value: 'week',
          groupValue: _activityFilter,
          onChanged: _updateActivityFilter,
        ),
        RadioListTile<String>(
          title: const Text('Last month'),
          value: 'month',
          groupValue: _activityFilter,
          onChanged: _updateActivityFilter,
        ),
        RadioListTile<String>(
          title: const Text('Last year'),
          value: 'year',
          groupValue: _activityFilter,
          onChanged: _updateActivityFilter,
        ),
        RadioListTile<String>(
          title: const Text('All time'),
          value: 'all',
          groupValue: _activityFilter,
          onChanged: _updateActivityFilter,
        ),
      ],
    );
  }

  void _updateActivityFilter(String? value) async {
    if (value != null) {
      setState(() {
        _activityFilter = value;
      });
      await _settings.setActivityFilter(value);
    }
  }

  Widget _buildAboutTile() {
    return ListTile(
      title: const Text('About LinkHoDL'),
      subtitle: const Text('Version 1.0.0'),
      leading: const Icon(Icons.info_outline),
      onTap: () {
        showAboutDialog(
          context: context,
          applicationName: 'LinkHoDL',
          applicationVersion: '1.0.0',
          applicationIcon: Image.asset(
            'assets/images/a-flat-minimalist-app-icon-design-featur_e8CDdSS-SO2a-oa1mhikeQ_2TxyglIbTaino_aXMEeRvg.jpeg',
            width: 50,
            height: 50,
          ),
          children: const [
            SizedBox(height: 16),
            Text(
              'LinkHoDL is a modern link management app that helps you organize and access your important links.',
            ),
            SizedBox(height: 8),
            Text(
              '© 2023 LinkHoDL',
            ),
          ],
        );
      },
    );
  }
}
