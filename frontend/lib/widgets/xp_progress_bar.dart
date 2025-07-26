// lib/widgets/xp_progress_bar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../providers/user_profile_provider.dart';

class XpProgressBar extends StatelessWidget {
  const XpProgressBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Consumer widget rebuilds when the provider notifies it.
    return Consumer<UserProfileProvider>(
      builder: (context, profileProvider, child) {
        // Show a placeholder while the initial data is loading.
        if (profileProvider.isLoading || profileProvider.userProfile == null) {
          // This container will take up the same space as the real widget,
          // preventing layout shifts and centering the spinner correctly.
          return Container(
            padding: const EdgeInsets.all(16.0),
            height: 160, // A fixed height to match the real widget's approximate height
            child: const Center(child: CircularProgressIndicator(color: Colors.green)),
          );
        }

        final profile = profileProvider.userProfile!;
        final double progressPercent = profile.xpToNextLevel > 0 
            ? (profile.xpPoints / profile.xpToNextLevel)
            : 0.0;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: CircularPercentIndicator(
            radius: 60.0,
            lineWidth: 12.0,
            animation: true,
            percent: progressPercent,
            center: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "LVL",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0, color: Colors.grey[600]),
                ),
                Text(
                  "${profile.level}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24.0),
                ),
              ],
            ),
            footer: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                "${profile.xpPoints} / ${profile.xpToNextLevel} XP",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17.0),
              ),
            ),
            circularStrokeCap: CircularStrokeCap.round,
            progressColor: Colors.green, // Your chosen primary color
          ),
        );
      },
    );
  }
}