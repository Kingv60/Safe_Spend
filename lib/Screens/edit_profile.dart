import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:safe_spend/helper%20and%20module/AppColor.dart';
import '../helper and module/Api-Service.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> profileData;
  const EditProfilePage({super.key, required this.profileData});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Use empty string if name/email is null
    _nameController = TextEditingController(text: widget.profileData['name'] ?? "");
    _emailController = TextEditingController(text: widget.profileData['email'] ?? "");
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await showModalBottomSheet<XFile?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () async {
                final file = await _picker.pickImage(source: ImageSource.camera);
                Navigator.pop(ctx, file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () async {
                final file = await _picker.pickImage(source: ImageSource.gallery);
                Navigator.pop(ctx, file);
              },
            ),
          ],
        ),
      ),
    );

    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final success = await _apiService.updateProfile(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      image: _imageFile, // can be null
    );

    setState(() => _isLoading = false);

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        Navigator.pop(context, true); // return true to refresh ProfileScreen
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.profileData['image'] != null
        ? 'https://super-duper-carnival.onrender.com/upload/${widget.profileData['image']}'
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: AppColors.accent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profile Image
              Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: _imageFile != null
                        ? FileImage(_imageFile!)
                        : (imageUrl != null ? NetworkImage(imageUrl) : null),
                    child: (_imageFile == null && imageUrl == null)
                        ? const Icon(Icons.person, size: 50, color: Colors.white)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt),
                      onPressed: _pickImage,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) =>
                value == null || value.isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 16),

              // Email Field
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) =>
                value == null || value.isEmpty ? 'Enter email' : null,
              ),
              const SizedBox(height: 32),

              _isLoading
                  ? const CircularProgressIndicator()
                  : GestureDetector(
                onTap: _updateProfile,
                child: Container(
                  height: 45,
                  decoration: BoxDecoration(
                    color: AppColors.navColor,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25), // darker shadow
                        spreadRadius: 1,  // small spread
                        blurRadius: 12,   // soft edges
                        offset: const Offset(0, 6), // shadow slightly below, gives lifted effect
                      ),
                    ],
                  ),

                  alignment: Alignment.center,
                  child: const Text(
                    'Update Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              )

            ],
          ),
        ),
      ),
    );
  }
}
