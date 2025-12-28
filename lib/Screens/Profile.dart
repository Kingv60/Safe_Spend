import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_handler/share_handler.dart'; // 👈 added
import '../Auth/login.dart';
import 'edit_profile.dart';
import 'language page.dart';
import '../helper and module/AppColor.dart';
import '../helper and module/Api-Service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  double _monthlyLimit = 0;
  Map<String, dynamic>? _profileData;
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _savedEmail;

  static bool _initialSharedMediaProcessed = false; // 👈 added

  @override
  void initState() {
    super.initState();
    _loadLimit();
    _loadSavedEmail();
    _fetchProfile();
    _initShareHandler(); // 👈 added
  }

  // 🔹 Handle share intent (salary text)
  Future<void> _initShareHandler() async {
    final handler = ShareHandler.instance;

    if (!_initialSharedMediaProcessed) {
      final initialMedia = await handler.getInitialSharedMedia();
      if (initialMedia?.content?.isNotEmpty == true) {
        _processSharedText(initialMedia!.content!);
      }
      _initialSharedMediaProcessed = true;
    }

    handler.sharedMediaStream.listen((SharedMedia media) {
      if (media.content?.isNotEmpty == true) {
        _processSharedText(media.content!);
      }
    });
  }

  // 🔹 Detect salary and update limit
  Future<void> _processSharedText(String text) async {
    // Improved pattern: captures Rs/₹ followed by whole numbers or commas
    final regex = RegExp(
      r'(?:₹|Rs\.?\s?)(\d+(?:,\d{3})*)',
      caseSensitive: false,
    );

    final match = regex.firstMatch(text);

    if (match != null) {
      String amountString = match.group(1) ?? '';
      amountString = amountString.replaceAll(',', ''); // Remove commas

      int? amount = int.tryParse(amountString);

      if (amount != null && amount > 0) {
        _showConfirmDialog(amount.toDouble()); // keep as double for consistency
      } else {
        _showNoSalaryFoundMessage();
      }
    } else {
      _showNoSalaryFoundMessage();
    }
  }




  void _showConfirmDialog(double amount) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Salary Detected'),
          content: Text('Detected ₹${amount.toInt()} as your salary. '
              'Do you want to set this as your monthly limit?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _saveLimit(amount);
                setState(() {
                  _monthlyLimit = amount;
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Monthly limit set to ₹${amount.toInt()}')),
                  );
                }
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }


  void _showNoSalaryFoundMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No salary amount detected in shared text')),
    );
  }

  // 🔹 Load and save methods
  Future<void> _loadLimit() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _monthlyLimit = prefs.getDouble('monthlyLimit') ?? 0;
    });
  }

  Future<void> _saveLimit(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('monthlyLimit', amount);
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedEmail = prefs.getString('email') ?? '';
    });
  }

  Future<void> _saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('email', email);
    setState(() {
      _savedEmail = email;
    });
  }

  Future<void> _fetchProfile() async {
    final profile = await _apiService.getProfile();

    setState(() {
      if (profile == null || profile.isEmpty) {
        _profileData = {
          'name': 'No Name',
          'email': _savedEmail ?? '',
          'image': null,
        };
      } else {
        _profileData = profile;
        _saveEmail(profile['email'] ?? '');
      }
      _isLoading = false;
    });
  }

  // 🔹 Logout confirmation
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                    (_) => false,
              );
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  // 🔹 UI Helpers
  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Colors.grey[700]),
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300, width: 0.6),
      ),
      tileColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  // 🔹 UI Build
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final name = _profileData?['name'] ?? 'No Name';
    final email = _profileData?['email'] ?? _savedEmail ?? '';
    final imageUrl = _profileData?['image'] != null
        ? 'https://super-duper-carnival.onrender.com/upload/${_profileData!['image']}'
        : null;

    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        backgroundColor: AppColors.accent,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Header
            Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
                  child: imageUrl == null
                      ? const Icon(Icons.person, size: 50, color: Colors.white)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black)),
                Text(email,
                    style: const TextStyle(color: Colors.green, fontSize: 14)),
                const SizedBox(height: 12),
                Text("Current Monthly Limit: ₹$_monthlyLimit",
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 24),
            _buildMenuTile(
              icon: Icons.edit,
              title: 'Edit Profile',
              onTap: () async {
                final updated = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditProfilePage(profileData: _profileData!),
                  ),
                );
                if (updated == true) _fetchProfile();
              },
            ),
            const SizedBox(height: 12),
            _buildMenuTile(
              icon: Icons.language,
              title: 'Languages',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LanguagePage()),
              ),
            ),
            const SizedBox(height: 12),
            _buildMenuTile(icon: Icons.settings_outlined, title: 'Settings'),
            const SizedBox(height: 12),
            _buildMenuTile(icon: Icons.info_outline, title: 'Info'),
            const SizedBox(height: 12),
            _buildMenuTile(
              icon: Icons.production_quantity_limits,
              title: 'Set Limit',
              onTap: () async {
                final TextEditingController controller = TextEditingController();
                controller.text = _monthlyLimit.toString();

                final result = await showDialog<double>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Set Monthly Limit'),
                    content: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Enter limit'),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel')),
                      ElevatedButton(
                          onPressed: () {
                            final value = double.tryParse(controller.text);
                            Navigator.pop(ctx, value);
                          },
                          child: const Text('Save')),
                    ],
                  ),
                );

                if (result != null) {
                  setState(() {
                    _monthlyLimit = result;
                  });
                  await _saveLimit(result);
                }
              },
            ),
            const SizedBox(height: 12),
            _buildMenuTile(
              icon: Icons.logout,
              title: 'Logout',
              onTap: _confirmLogout,
            ),
          ],
        ),
      ),
    );
  }
}
