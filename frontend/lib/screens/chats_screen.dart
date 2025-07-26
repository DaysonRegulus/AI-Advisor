// lib/screens/chats_screen.dart

import 'package:flutter/material.dart';
import 'agent_chat_screen.dart';

// A simple data class for our agents
class Agent {
  final String id; // This is the agent_name for the API
  final String title;
  final String subtitle;
  final IconData icon;

  Agent({required this.id, required this.title, required this.subtitle, required this.icon});
}

class ChatsScreen extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const ChatsScreen({Key? key, required this.onRefresh}) : super(key: key);

  // Define our list of agents here
  static final List<Agent> _agents = [
    Agent(id: 'financial_advisor', title: 'Financial Advisor', subtitle: 'Clarity on your finances.', icon: Icons.monetization_on),
    Agent(id: 'personal_trainer', title: 'Personal Trainer', subtitle: 'Your partner in fitness.', icon: Icons.fitness_center),
    Agent(id: 'mental_health_professional', title: 'Mental Health Coach', subtitle: 'A safe space to talk.', icon: Icons.psychology),
    Agent(id: 'career_coach', title: 'Career Coach', subtitle: 'Navigate your career path.', icon: Icons.work),
    Agent(id: 'communication_coach', title: 'Communication Coach', subtitle: 'Speak with confidence.', icon: Icons.record_voice_over),
    Agent(id: 'productivity_coach', title: 'Productivity Coach', subtitle: 'Master your time.', icon: Icons.timer),
    Agent(id: 'personal_stylist', title: 'Personal Stylist', subtitle: 'Define your style.', icon: Icons.style),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Coaches'),
        // We can add search functionality here later
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView.builder(
          itemCount: _agents.length,
          itemBuilder: (context, index) {
            final agent = _agents[index];
            return ListTile(
              leading: CircleAvatar(
                child: Icon(agent.icon),
                backgroundColor: Colors.grey[200],
              ),
              title: Text(agent.title),
              subtitle: Text(agent.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AgentChatScreen(agentName: agent.id, agentTitle: agent.title),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}