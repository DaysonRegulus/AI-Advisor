// lib/screens/main_scaffold.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/daily_summary_provider.dart';
import 'home_screen.dart';
import 'chats_screen.dart';
import 'journal_list_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({Key? key}) : super(key: key);

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 1; // Default to the HomeScreen (middle item)

  // Define the list of widgets here now
  late final List<Widget> _widgetOptions;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _refreshAllData() async {
    print("--- Global Refresh Triggered ---");
    // We use context.read which is a safe way to call providers inside functions.
    // We call all our data-fetching methods from our providers.
    // Using Future.wait allows them to run in parallel for better performance.
    await Future.wait([
      context.read<UserProfileProvider>().fetchUserProfile(),
      context.read<DailySummaryProvider>().fetchLatestSummary(),
      // When we add a ChatProvider or JournalProvider, we will add their fetch methods here too.
      // e.g., context.read<ChatProvider>().fetchRecentChats(),
    ]);
    print("--- Global Refresh Complete ---");
  }

  @override
  void initState() {
    super.initState();

    // Initialize the list of widgets here, where we have access to _refreshAllData
    _widgetOptions = <Widget>[
      // For now, Chats and Journal don't have refresh, but we could pass the function to them too.
      ChatsScreen(onRefresh: _refreshAllData), 
      HomeScreen(onRefresh: _refreshAllData), // <-- Pass the function here
      JournalScreen(onRefresh: _refreshAllData),
    ];

    // This is where we trigger the initial data fetch for the app!
    // We use addPostFrameCallback to ensure the Provider is available when we call it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAllData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Journal',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green, // Your chosen primary color
        onTap: _onItemTapped,
      ),
    );
  }
}