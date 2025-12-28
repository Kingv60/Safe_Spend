import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:safe_spend/helper%20and%20module/Api-Service.dart';
import 'package:safe_spend/helper%20and%20module/AppColor.dart';
import 'package:safe_spend/helper%20and%20module/sql_helper.dart';
import 'package:share_handler/share_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BillScannerPage extends StatefulWidget {
  const BillScannerPage({Key? key}) : super(key: key);

  @override
  State<BillScannerPage> createState() => _BillScannerPageState();
}

class _BillScannerPageState extends State<BillScannerPage> {
  File? _selectedImage;
  bool _uploading = false;
  bool _adding = false;
  final ImagePicker _picker = ImagePicker();

  final ApiService apiService = ApiService();
  final DBHelper dbHelper = DBHelper();

  // Editable controllers
  final TextEditingController _vendorController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  // List selection variables
  List<Map<String, dynamic>> _userLists = [];
  String? _selectedListCode; // 'personal' for local

  // Flag to prevent re-processing shared image
  static bool _initialSharedMediaProcessed = false;

  @override
  void initState() {
    super.initState();
    _initShareHandler();
  }

  /// ---------------- Handle shared images ----------------
  Future<void> _initShareHandler() async {
    final handler = ShareHandler.instance;

    if (!_initialSharedMediaProcessed) {
      final initialMedia = await handler.getInitialSharedMedia();
      if (initialMedia?.attachments?.isNotEmpty == true) {
        setState(() {
          _selectedImage = File(initialMedia!.attachments!.first!.path!);
        });
        _extractData();
      }
      _initialSharedMediaProcessed = true;
    }

    handler.sharedMediaStream.listen((SharedMedia media) {
      if (media.attachments?.isNotEmpty == true) {
        setState(() {
          _selectedImage = File(media.attachments!.first!.path!);
        });
        _extractData();
      }
    });
  }

  /// ---------------- Pick Image ----------------
  Future<void> _pickImage(ImageSource source) async {
    final XFile? picked =
    await _picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) setState(() => _selectedImage = File(picked.path));
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.deepPurple),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.deepPurpleAccent),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// ---------------- OCR ----------------
  Future<void> _extractData() async {
    if (_selectedImage == null) return;

    setState(() => _uploading = true);

    try {
      final result = await apiService.uploadBillImage(_selectedImage!);
      setState(() {
        _vendorController.text = result['vendor_name'] ?? '';
        _amountController.text = result['total_amount']?.toString() ?? '';
        _dateController.text = result['transaction_date'] ?? '';
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _uploading = false);
    }
  }

  /// ---------------- Fetch Shared Lists ----------------
  Future<void> _fetchUserLists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt("userId")?.toString();
      final Uri url = Uri.parse('${apiService.baseUrl}/api/shared/user?userId=$userId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final created = (data['createdLists'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        final joined = (data['joinedLists'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        setState(() {
          _userLists = [
            {'name': 'Personal', 'shareCode': 'personal'}, // add personal
            ...created,
            ...joined,
          ];
          _selectedListCode = _userLists.first['shareCode'];
        });
      } else {
        throw Exception('Failed to fetch lists: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error fetching lists: $e')));
    }
  }

  /// ---------------- Choose list ----------------
  Future<void> _chooseListDialog() async {
    if (_userLists.isEmpty) await _fetchUserLists();

    if (_userLists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No lists available")));
      return;
    }

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text("Select List"),
          children: _userLists
              .map((list) => SimpleDialogOption(
            child: Text(list['name']),
            onPressed: () => Navigator.pop(ctx, list['shareCode']),
          ))
              .toList(),
        );
      },
    );

    if (selected != null) setState(() => _selectedListCode = selected);
  }

  /// ---------------- Add expense ----------------
  Future<void> _addExpense() async {
    if (_vendorController.text.isEmpty || _amountController.text.isEmpty) return;

    // Choose list if not selected
    if (_selectedListCode == null) await _chooseListDialog();
    if (_selectedListCode == null) return;

    setState(() => _adding = true);

    try {
      if (_selectedListCode == 'personal') {
        await dbHelper.insertBill({
          'bill': _vendorController.text,
          'amount': double.tryParse(_amountController.text) ?? 0,
          'date': _dateController.text,
        });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Added ${_vendorController.text} to Personal")));
      } else {
        await apiService.addSharedExpense(
          shareCode: _selectedListCode!,
          description: _vendorController.text,
          amount: double.tryParse(_amountController.text) ?? 0,
        );
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Added ${_vendorController.text} to Shared List")));
      }

      setState(() {
        _selectedImage = null;
        _vendorController.clear();
        _amountController.clear();
        _dateController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed to add: $e")));
    } finally {
      setState(() => _adding = false);
    }
  }

  /// ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final themeColor = Colors.deepPurple;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Scanner'),
        backgroundColor: AppColors.accent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Image section
              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _selectedImage != null
                      ? Column(
                    children: [
                      GestureDetector(
                        onTap: () => _previewImage(_selectedImage!),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _selectedImage!,
                            height: 250,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Retake Button
                      SizedBox(
                        height: 45,
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade500,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text('Retake', style: TextStyle(color: Colors.white)),
                          onPressed: _showImageSourceOptions,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Extract Data Button
                      SizedBox(
                        height: 45,
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navColor,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: _uploading
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Icon(Icons.search),
                          label: Text(
                              _uploading ? 'Extracting...' : 'Extract Data'),
                          onPressed: _uploading ? null : _extractData,
                        ),
                      ),
                    ],
                  )
                      : GestureDetector(
                    onTap: _showImageSourceOptions,
                    child: Container(
                      width: double.infinity,
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: themeColor.withOpacity(0.6),
                          width: 2,
                        ),
                        color: themeColor.withOpacity(0.05),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.upload_file_outlined,
                                size: 40, color: Colors.deepPurple),
                            SizedBox(height: 8),
                            Text(
                              "Tap to upload image",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Editable text fields always visible
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // List selection
                      ListTile(
                        title: Text(
                          "List: ${_userLists.firstWhere(
                                  (l) => l['shareCode'] == _selectedListCode,
                              orElse: () => {'name': 'Select List'})['name']}",
                        ),
                        trailing: const Icon(Icons.arrow_drop_down),
                        onTap: _chooseListDialog,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _vendorController,
                        decoration: const InputDecoration(
                          labelText: 'Vendor',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _dateController,
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: GestureDetector(
                          onTap: _adding ? null : _addExpense,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _adding
                                  ? themeColor.withOpacity(0.6)
                                  : themeColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: _adding
                                  ? const CircularProgressIndicator(
                                  color: Colors.white)
                                  : const Text(
                                "Add to List",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _previewImage(File image) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(0),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: Image.file(
              image,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
