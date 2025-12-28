import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:safe_spend/Screens/speech_table.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helper and module/Api-Service.dart';
import '../helper and module/AppColor.dart';
import '../helper and module/sql_helper.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'ScannerPage.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController billController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final DBHelper dbHelper = DBHelper();
  final ApiService apiService = ApiService();
  String? _alertMessage; // store message from API
  bool _hasAlert = false; // control icon color
  final List<String> allSuggestions = [
    'Rent',
    'Recharge',
    'Restaurant',
    'Groceries',
    'Electricity Bill',
    'Water Bill',
    'Internet',
    'Fuel',
    'Medicine',
    'Travel',
    'Shopping',
    'Snacks',
    'Subscription',
    'Loan EMI',
    'Gym',
  ];

  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _speechText = "";
  List<String> _billList = [];

  List<Map<String, dynamic>> userLists = [];
  String? selectedItem;
  bool loadingLists = true;
  String? loadError;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _fetchUserLists();
    _checkAlertMessage();
  }

  Future<void> _checkAlertMessage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt("userId")?.toString();
      final url = Uri.parse('https://security-system-4.onrender.com/get-message?userId=$userId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // ✅ check message only
        if (data['error'] == "No message found") {
          setState(() {
            _hasAlert = false;
            _alertMessage = null;
          });
        } else {
          // Use 'message' if exists, otherwise fallback to whole response
          final msg = data['message'] ?? data.toString();
          setState(() {
            _hasAlert = true;
            _alertMessage = msg;
          });
        }
      } else {
        debugPrint("Failed to fetch message: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error checking message: $e");
    }
  }

  void _showAlertDialog() {
    if (_alertMessage == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          "⚠️ Security Alert",
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Text(
          _alertMessage!,
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _hasAlert = false;
                _alertMessage = null;
              });
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
  Future<void> _fetchUserLists() async {
    try {
      final Map<String, dynamic> data = await apiService.getUserLists();

      final created = (data['createdLists'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final joined = (data['joinedLists'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      setState(() {
        userLists = [
          {'name': 'Personal'},
          ...created,
          ...joined,
        ];
        selectedItem = 'Personal';
        loadingLists = false;
      });
    } catch (e) {
      setState(() {
        loadError = e.toString();
        loadingLists = false;
      });
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 16) return 'Good Noon';
    if (hour < 23) return 'Good Evening';
    return 'Good Night';
  }

  void _stopListening() {
    _speech.stop();
    setState(() {
      _isListening = false;
      if (_speechText.isNotEmpty) {
        _billList.add(_speechText);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Recognized: $_speechText")));
        _speechText = "";
      }
    });
  }

  /// ✅ Check limit after adding a bill
  Future<void> _checkLimit() async {
    final prefs = await SharedPreferences.getInstance();
    final limit = prefs.getDouble('monthlyLimit') ?? 0.0;
    final total = await dbHelper.getTotalAmount();

    if (limit > 0 && total > limit) {
      // Show alert dialog
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            backgroundColor: Colors.white,
            title: const Text(
              "⚠️ Limit Exceeded!",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            content: Text(
              "Your total expenses ₹${total.toStringAsFixed(2)} have exceeded your monthly limit of ₹${limit.toStringAsFixed(2)}.",
              style: const TextStyle(fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _addRecord() async {
    if (billController.text.isEmpty && _billList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter bill or use Mic")),
      );
      return;
    }

    if (amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter amount")),
      );
      return;
    }

    double amount = double.tryParse(amountController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter valid amount")),
      );
      return;
    }

    List<String> billsToAdd = [];
    if (billController.text.isNotEmpty) billsToAdd.add(billController.text);
    billsToAdd.addAll(_billList);

    try {
      if (selectedItem == 'Personal') {
        // Save locally in SQLite
        for (var bill in billsToAdd) {
          int id = await dbHelper.insertBill({
            'bill': bill,
            'amount': amount,
            'date': DateTime.now().toIso8601String(),
          });
          debugPrint("Inserted bill with id: $id");
        }

        // ✅ Check limit after adding bills
        await _checkLimit();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Saved to Personal list successfully!")),
        );
      } else {
        // Save to shared list via API
        final selectedList =
        userLists.firstWhere((e) => e['name'] == selectedItem);
        final shareCode = selectedList['shareCode'];

        for (var bill in billsToAdd) {
          await apiService.addSharedExpense(
            shareCode: shareCode,
            description: bill,
            amount: amount,
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Saved to Shared list successfully!")),
        );
      }

      // Clear inputs
      billController.clear();
      amountController.clear();
      _billList.clear();
      setState(() {});
    } catch (e, st) {
      debugPrint("Error adding record: $e\n$st");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving record: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dropdownItems = !loadingLists && userLists.isNotEmpty
        ? userLists.map((e) => e['name'].toString()).toList()
        : ['Personal', 'Item 1', 'Item 2'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.accent,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_greeting(), style: const TextStyle(fontSize: 18)),
            GestureDetector(
              onTap: _hasAlert ? _showAlertDialog : null,
              child: CircleAvatar(
                radius: 15,
                backgroundColor: Colors.white,
                child: Icon(
                  _hasAlert
                      ? Icons.warning_amber_rounded
                      : Icons.supervised_user_circle_outlined,
                  color: _hasAlert ? Colors.red : Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Select List"),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Container(
                        height: 55,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              width: 2,
                              color: Colors.grey.withOpacity(0.3)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            hint: loadingLists
                                ? const Text('Loading...')
                                : const Text('Select Item'),
                            value: selectedItem,
                            isExpanded: true,
                            items: dropdownItems.map((item) {
                              return DropdownMenuItem<String>(
                                value: item,
                                child: Text(item),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => selectedItem = value);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text("Type Expense"),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            width: 2,
                            color: AppColors.grey.withOpacity(0.3),
                          ),
                        ),
                        child: Autocomplete<String>(
                          optionsBuilder: (TextEditingValue value) {
                            if (value.text.isEmpty) return const Iterable<String>.empty();
                            return allSuggestions.where((s) =>
                                s.toLowerCase().contains(value.text.toLowerCase()));
                          },
                          onSelected: (String selection) {
                            billController.text = selection;
                          },
                          fieldViewBuilder:
                              (context, controller, focusNode, onEditingComplete) {
                            controller.text = billController.text;
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              onChanged: (value) {
                                // keep whatever user types
                                billController.text = value;
                              },
                              onEditingComplete: () {
                                billController.text = controller.text;
                                focusNode.unfocus();
                              },
                              decoration: const InputDecoration(
                                hintText: "Enter Bill (e.g. Rent, Recharge...)",
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                                border: InputBorder.none,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text("Enter Amount"),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Container(
                        height: 55,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              width: 2,
                              color: AppColors.grey.withOpacity(0.3)),
                        ),
                        child: TextFormField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: "Enter Amount",
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 15),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _addRecord,
                      child: Container(
                        alignment: Alignment.center,
                        width: double.infinity,
                        height: 56,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.blackz,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "SUBMIT",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // Mic & Scan Row
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BillScannerPage(),
                          ),
                        );
                      },
                      child: Container(
                        height: 130,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: AppColors.accent,
                          border: Border.all(
                              width: 1.5,
                              color: AppColors.grey.withOpacity(0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              spreadRadius: 2,
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.document_scanner_outlined,
                                size: 25,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text("Scan to Add"),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SpeechTablePage(),
                          ),
                        );

                        if (result != null && result is List<String>) {
                          setState(() {
                            _billList.addAll(result);
                          });
                        }
                      },
                      onLongPressUp: _stopListening,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 130,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: AppColors.accent,
                          border: Border.all(
                              width: 1.5,
                              color: AppColors.grey.withOpacity(0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              spreadRadius: 2,
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                if (_isListening)
                                  Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.green.withOpacity(0.3),
                                    ),
                                  ),
                                CircleAvatar(
                                  radius: 25,
                                  backgroundColor:
                                  _isListening ? Colors.blue : Colors.white,
                                  child:
                                  const Icon(Icons.mic_none, size: 25),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Column(
                              children: [
                                const Text("Voice to Add"),
                                if (_speechText.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      _speechText,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic),
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
              ),
              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
    );
  }
}
