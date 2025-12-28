// lib/Screens/speech_table_page.dart
import 'package:flutter/material.dart';
import 'package:safe_spend/helper%20and%20module/sql_helper.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../helper and module/Api-Service.dart';
import '../helper and module/AppColor.dart';

class SpeechTablePage extends StatefulWidget {
  const SpeechTablePage({Key? key}) : super(key: key);

  @override
  State<SpeechTablePage> createState() => _SpeechTablePageState();
}

class _SpeechTablePageState extends State<SpeechTablePage> {
  final ApiService apiService = ApiService();
  final DBHelper dbHelper = DBHelper();

  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _currentLine = '';
  final List<String> _lines = [];

  bool _loadingLists = false;
  String? _loadError;

  List<Map<String, dynamic>> _userLists = [];
  String? _selectedListCode;

  Map<String, dynamic>? _apiResponse;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initializeLists();
  }

  // ---------------- Initialize user lists ----------------
  Future<void> _initializeLists() async {
    // Always add personal first
    setState(() {
      _userLists = [
        {'name': 'Personal', 'shareCode': 'personal'},
      ];
      _selectedListCode = 'personal';
      _loadingLists = true;
      _loadError = null;
    });

    try {
      final Map<String, dynamic> data = await apiService.getUserLists();

      final created = (data['createdLists'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final joined = (data['joinedLists'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      setState(() {
        _userLists = [
          {'name': 'Personal', 'shareCode': 'personal'},
          ...created,
          ...joined,
        ];
        if (_userLists.isNotEmpty && _selectedListCode == null) {
          _selectedListCode = _userLists.first['shareCode'];
        }
      });
    } catch (e) {
      setState(() => _loadError = e.toString());
    } finally {
      setState(() => _loadingLists = false);
    }
  }

  // ---------------- Speech capture ----------------
  Future<void> _toggleListening() async {
    if (_isListening) {
      _stopListening();
    } else {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') _stopListening();
        },
        onError: (err) => debugPrint('Speech error: $err'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          listenMode: stt.ListenMode.dictation,
          onResult: (val) {
            final raw = val.recognizedWords.trim();
            setState(() => _currentLine = raw);
          },
        );
      }
    }
  }

  void _stopListening() {
    if (!_isListening) return;
    _speech.stop();
    setState(() {
      _isListening = false;
      if (_currentLine.trim().isNotEmpty) {
        _lines.add(_currentLine.trim());
        _currentLine = '';
      }
    });
  }

  // ---------------- Send to API ----------------
  Future<void> _sendToApi() async {
    if (_lines.isEmpty) return;
    setState(() {
      _apiResponse = null;
    });
    try {
      final result = await apiService.extractTexts(_lines);
      setState(() => _apiResponse = result);
    } catch (e) {
      setState(() => _apiResponse = {'Error': e.toString()});
    }
  }

  // ---------------- Add expense helper ----------------
  Future<void> _addExpense(String description, double amount) async {
    if (_selectedListCode == 'personal') {
      // Save locally
      await dbHelper.insertBill({
        'bill': description,
        'amount': amount,
        'date': DateTime.now().toIso8601String(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $description to Personal')),
      );
    } else {
      // Save to shared list via API
      try {
        await apiService.addSharedExpense(
          shareCode: _selectedListCode!,
          description: description,
          amount: amount,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added $description to Shared List')),
        );
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add $description')),
        );
      }
    }
  }

  // ---------------- Add all API response entries ----------------
  void _openAddSheetForAllItems() {
    if (_apiResponse == null || _apiResponse!.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 20,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Select List',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedListCode,
                    decoration: const InputDecoration(labelText: 'List'),
                    items: _userLists
                        .map((e) => DropdownMenuItem<String>(
                      value: e['shareCode'],
                      child: Text(e['name'] ?? 'Unnamed'),
                    ))
                        .toList(),
                    onChanged: (val) => setModalState(() => _selectedListCode = val),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          if (_selectedListCode == null) return;
                          Navigator.pop(ctx);

                          int success = 0;
                          int fail = 0;

                          for (final entry in _apiResponse!.entries) {
                            final description = entry.key;
                            final amount = double.tryParse(entry.value.toString()) ?? 0.0;
                            try {
                              await _addExpense(description, amount);
                              success++;
                            } catch (_) {
                              fail++;
                            }
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Added $success item(s), failed $fail item(s)"),
                            ),
                          );

                          setState(() => _apiResponse = null);
                        },
                        child: const Text('Add All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 50),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Speech Table'),
        backgroundColor: AppColors.accent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _lines.length + (_currentLine.isNotEmpty ? 1 : 0),
                itemBuilder: (_, index) {
                  if (index < _lines.length) {
                    final text = _lines[index];
                    return ListTile(
                      leading: Text('${index + 1}'),
                      title: Text(text),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () {
                          setState(() => _lines.removeAt(index));
                        },
                      ),
                    );
                  } else {
                    return ListTile(
                      leading: const Text('*'),
                      title: Text(
                        _currentLine,
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    );
                  }
                },
              ),
            ),

            if (_apiResponse != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Category')),
                      DataColumn(label: Text('Amount')),
                      DataColumn(label: Text('Action')),
                    ],
                    rows: _apiResponse!.entries.map((entry) {
                      final amt = double.tryParse(entry.value.toString()) ?? 0.0;
                      return DataRow(cells: [
                        DataCell(Text(entry.key)),
                        DataCell(Text(entry.value.toString())),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () async {
                              await _addExpense(entry.key, amt);
                              setState(() {});
                            },
                          ),
                        ),
                      ]);
                    }).toList(),
                  ),
                ),
              ),

            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    label: const Text('Send'),
                    onPressed: _sendToApi,
                  ),
                  FloatingActionButton(
                    onPressed: _toggleListening,
                    child: Icon(_isListening ? Icons.mic_off : Icons.mic),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add All'),
                    onPressed: _openAddSheetForAllItems,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
