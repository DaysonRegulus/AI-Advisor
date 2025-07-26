// lib/models/user_profile.dart

class UserProfile {
  final String userId;
  final String? username;
  final int level;
  final int xpPoints;
  final int xpToNextLevel;
  final bool leveledUp;

  UserProfile({
    required this.userId,
    this.username,
    required this.level,
    required this.xpPoints,
    required this.xpToNextLevel,
    required this.leveledUp,
  });

  // A 'factory constructor' to create a UserProfile from a JSON map.
  // This is used to parse the response from our FastAPI server.
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'],
      username: json['username'],
      level: json['level'],
      xpPoints: json['xp_points'],
      xpToNextLevel: json['xp_to_next_level'],
      leveledUp: json['leveled_up'],
    );
  }
}