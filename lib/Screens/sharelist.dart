import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helper and module/Api-Service.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';

import '../helper and module/AppColor.dart';
import 'expense-page.dart'; // Expenses page

// Model for Shared List
class SharedList {
  final int id; // List ID
  final String name;
  final String shareCode;

  SharedList({required this.id, required this.name, required this.shareCode});

  factory SharedList.fromJson(Map<String, dynamic> json) {
    return SharedList(
      id: json['id'],
      name: json['name'],
      shareCode: json['shareCode'],
    );
  }
}

class ShareListPage extends StatefulWidget {
  const ShareListPage({Key? key}) : super(key: key);

  @override
  State<ShareListPage> createState() => _ShareListPageState();
}

class _ShareListPageState extends State<ShareListPage> {
  final TextEditingController _listNameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final ApiService _apiService = ApiService();

  final List<SharedList> _sharedLists = [];
  final Set<SharedList> _selectedLists = {};
  bool _isDeleteMode = false;

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _loadUserLists();
    _initDeepLinkListener();
  }

  void _initDeepLinkListener() async {
    // Handle app opened from terminated state
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      _handleJoinCode(initialUri);
    }

    // Handle app opened while running
    _linkSub = _appLinks.uriLinkStream.listen((uri) {
      if (uri != null) _handleJoinCode(uri);
    }, onError: (err) {
      print("Error handling deep link: $err");
    });
  }

  void _handleJoinCode(Uri uri) async {
    try {
      // Check if this is a join link
      if (uri.scheme == 'safespend' && uri.host == 'join') {
        final code = uri.queryParameters['code'];
        if (code != null && code.isNotEmpty) {
          // Join the list
          await _apiService.joinSharedList(shareCode: code);
          await _loadUserLists();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Joined shared list automatically!')),
          );
        }
      }
    } catch (e) {
      print('Error joining shared list: $e');
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _listNameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// Load all lists (created + joined)
  Future<void> _loadUserLists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt("userId")?.toString();
      if (userId == null) return;

      final result = await _apiService.getUserLists();

      final createdLists = (result['createdLists'] as List)
          .map((json) => SharedList.fromJson(json))
          .toList();

      final joinedLists = (result['joinedLists'] as List)
          .map((json) => SharedList.fromJson(json))
          .toList();

      setState(() {
        _sharedLists.clear();
        _sharedLists.addAll([...createdLists, ...joinedLists]);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading lists: $e')),
      );
    }
  }

  /// Show action sheet to create or join list
  void _showActionSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Create List'),
              onTap: () {
                Navigator.pop(context);
                _showCreateDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add),
              title: const Text('Join List'),
              onTap: () {
                Navigator.pop(context);
                _showJoinDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Create Shared List Dialog
  void _showCreateDialog() {
    _listNameController.clear();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create Shared List'),
        content: TextField(
          controller: _listNameController,
          decoration: const InputDecoration(
            labelText: 'Enter list name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = _listNameController.text.trim();
              if (name.isEmpty) return;

              try {
                final prefs = await SharedPreferences.getInstance();
                final userId = prefs.getInt("userId")?.toString();
                if (userId == null) throw Exception('User not logged in');

                final result = await _apiService.createSharedList(
                  name: name,
                );

                Navigator.pop(context);

                setState(() {
                  _sharedLists.add(SharedList.fromJson(result));
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('List created: ${result['name']}')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  /// Join Shared List Dialog
  void _showJoinDialog() {
    _codeController.clear();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Join Shared List'),
        content: TextField(
          controller: _codeController,
          decoration: const InputDecoration(
            labelText: 'Enter invite code',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = _codeController.text.trim();
              if (code.isEmpty) return;

              try {
                final prefs = await SharedPreferences.getInstance();
                final userId = prefs.getInt("userId")?.toString();
                if (userId == null) throw Exception('User not logged in');

                await _apiService.joinSharedList(
                  shareCode: code,
                );

                Navigator.pop(context);

                await _loadUserLists();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Joined shared list successfully!')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  /// Long press to start delete mode
  void _onLongPressListItem(SharedList list) {
    setState(() {
      _isDeleteMode = true;
      _selectedLists.add(list);
    });
  }

  /// Tap to select/deselect in delete mode or navigate to ExpensesPage
  void _onTapListItem(SharedList list) {
    if (_isDeleteMode) {
      // Select/deselect for deletion
      setState(() {
        if (_selectedLists.contains(list)) {
          _selectedLists.remove(list);
          if (_selectedLists.isEmpty) _isDeleteMode = false;
        } else {
          _selectedLists.add(list);
        }
      });
    } else {
      // Normal tap: navigate to ExpensesPage
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExpensesPage(
            sharedListId: list.id,
            sharedListName: list.name,
            sharecode: list.shareCode, // pass share code
          ),
        ),
      );
    }
  }

  /// Delete all selected lists
  Future<void> _deleteSelectedLists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt("userId")?.toString();
      if (userId == null) throw Exception('User not logged in');

      for (var list in _selectedLists) {
        await _apiService.deleteSharedList(
          id: list.id.toString(),
        );
        _sharedLists.remove(list);
      }

      setState(() {
        _selectedLists.clear();
        _isDeleteMode = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected list(s) deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting list(s): $e')),
      );
    }
  }

  /// Cancel delete mode
  void _cancelDeleteMode() {
    setState(() {
      _selectedLists.clear();
      _isDeleteMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isDeleteMode
            ? Text('${_selectedLists.length} selected')
            : const Text('Share List'),
        backgroundColor: AppColors.accent,
        actions: _isDeleteMode
            ? [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteSelectedLists,
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _cancelDeleteMode,
          ),
        ]
            : [],
      ),
      body: _sharedLists.isEmpty
          ? const Center(
        child: Text(
          'Your shared lists will appear here.',
          style: TextStyle(fontSize: 16),
        ),
      )
          : ListView.builder(
        itemCount: _sharedLists.length,
        itemBuilder: (context, index) {
          final list = _sharedLists[index];
          final isSelected = _selectedLists.contains(list);

          return Card(
            margin:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isSelected ? Colors.red[100] : null,
            child: ListTile(
              title: Text(list.name),
              subtitle: Row(
                children: [
                  Text('Code: ${list.shareCode}'),
                  const SizedBox(width: 10),
                  // Copy code icon
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: list.shareCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied!')),
                      );
                    },
                    child: const Icon(Icons.copy, size: 18),
                  ),
                  const SizedBox(width: 10),
                  // Share link icon
                  GestureDetector(
                    onTap: () {
                      // Use share_plus to share
                      final link =
                          "safespend://join?code=${list.shareCode}";
                      Share.share(
                        "Join my shared list using this link: $link",
                      );
                    },
                    child: const Icon(Icons.link, size: 18),
                  ),
                ],
              ),
              onLongPress: () => _onLongPressListItem(list),
              onTap: () => _onTapListItem(list),
            ),
          );
        },
      ),
      floatingActionButton: !_isDeleteMode
          ? FloatingActionButton(
        onPressed: _showActionSheet,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        backgroundColor: AppColors.navColor,
        child: const Icon(Icons.add),
      )
          : null,
    );
  }
}
