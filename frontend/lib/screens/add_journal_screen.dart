// lib/screens/add_journal_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_service.dart';
import '../providers/user_profile_provider.dart';
import '../providers/journal_provider.dart';

// The class name is 'AddJournalScreen'
class AddJournalScreen extends StatefulWidget {
  const AddJournalScreen({Key? key}) : super(key: key);

  @override
  _AddJournalScreenState createState() => _AddJournalScreenState();
}

class _AddJournalScreenState extends State<AddJournalScreen> {
  final TextEditingController _controller = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isSaving = false;

  Future<void> _saveJournalEntry() async {
    if (_controller.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journal entry cannot be empty.')),
      );
      return;
    }

    setState(() { _isSaving = true; });

    // Call the provider to add the entry and trigger background tasks
    await Provider.of<JournalProvider>(context, listen: false).addJournalEntry(_controller.text);
    
    // Also award XP via the UserProfileProvider
    await Provider.of<UserProfileProvider>(context, listen: false).awardXpForEvent('journal_entry_added', 15);

    setState(() { _isSaving = false; });

    if (mounted) { // Check if the widget is still in the tree
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Journal entry saved! Agents are now reviewing it.'),
          backgroundColor: Colors.green,
        ),
      );
      // Pass 'true' back to signal that an entry was added
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Journal Entry'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveJournalEntry,
              tooltip: 'Save Entry',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _controller,
          autofocus: true,
          maxLines: null,
          expands: true,
          decoration: const InputDecoration(
            hintText: 'What\'s on your mind today?',
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}