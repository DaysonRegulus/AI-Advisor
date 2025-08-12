// lib/widgets/daily_summary_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../providers/daily_summary_provider.dart';

class DailySummaryCard extends StatelessWidget {
  const DailySummaryCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Consumer<DailySummaryProvider>(
          builder: (context, summaryProvider, child) {
            if (summaryProvider.error != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "Could not load summary:\n${summaryProvider.error}",
                    style: TextStyle(color: Colors.red.shade700),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (summaryProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (summaryProvider.error != null) {
              return Center(child: Text("Error: ${summaryProvider.error}"));
            }

            if (summaryProvider.summary == null) {
              return const Center(
                child: Text("No summary available for today. Generate one by tapping the refresh icon."),
              );
            }

            // Using the Markdown widget to render the summary
            return MarkdownBody(data: summaryProvider.summary!.summaryText);
          },
        ),
      ),
    );
  }
}