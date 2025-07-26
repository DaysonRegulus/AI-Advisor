// lib/screens/journal_list_screen.dart
import 'package:flutter/material.dart';
import 'add_journal_screen.dart';

class JournalScreen extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const JournalScreen({Key? key, required this.onRefresh}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Journal')),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: const Center(
          child: Text('Past journal entries will appear here.'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddJournalScreen()),
          );
        },
        tooltip: 'New Journal Entry',
        child: const Icon(Icons.add),
      ),
    );
  }
}