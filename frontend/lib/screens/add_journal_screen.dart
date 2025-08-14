// lib/screens/add_journal_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  bool _isSaving = false;

  Future<void> _saveJournalEntry() async {
    if (_controller.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journal entry cannot be empty.')),
      );
      return;
    }

    // Set the local saving state to show the spinner in the AppBar
    setState(() { _isSaving = true; });

    // Get the providers, but don't listen to changes here.
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);
    final userProfileProvider = Provider.of<UserProfileProvider>(context, listen: false);

    try {
      // We call the provider methods but DO NOT use 'await'.
      // This fires off the background tasks without blocking the UI.
      journalProvider.addJournalEntry(_controller.text);
      userProfileProvider.awardXpForEvent('journal_entry_added', 15);

      // Immediately navigate back and signal success.
      if (mounted) {
        // Pass 'true' back to the previous screen.
        Navigator.of(context).pop(true);
      }

    } catch (e) {
      // If the initial call fails, show an error.
      setState(() { _isSaving = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: Could not start save process. $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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