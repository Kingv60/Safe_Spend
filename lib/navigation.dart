import 'package:flutter/material.dart';
import 'Screens/ScannerPage.dart';
import 'Screens/sharelist.dart';
import 'Screens/home.dart';
import 'Screens/Profile.dart';
import 'Screens/show_table.dart';
import 'helper and module/AppColor.dart';

class BottomNavScreen extends StatefulWidget {
  @override
  _BottomNavScreenState createState() => _BottomNavScreenState();
}

class _BottomNavScreenState extends State<BottomNavScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    HomeScreen(),
    BillsPage(),
    ShareListPage(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: AppColors.navColor,
        unselectedItemColor: Colors.black54,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Bills',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_shared_outlined),
            label: 'Shared',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
