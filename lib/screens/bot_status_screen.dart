import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/feed_service.dart';
import '../models/topic.dart';

class BotStatusScreen extends StatelessWidget {
  const BotStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedService>();
    final status = feed.getBotStatus();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Bot • Status'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.blue.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ManagerBot',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Central orchestrator. Nag-a-assign ng tasks sa bawat Topic Bot. '
                    'Nagpapatakbo ng auto-refresh every 60 seconds. '
                    'Tanging fresh content (max 2 hours) ang pinapayagan. '
                    'Walang external links – lahat ng stories at videos ay pinapanood sa loob ng app.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Topic Bots',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ...kTopics.map((topic) {
            final botStatus = status[topic.id] ?? 'Unknown';
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(topic.emoji),
                ),
                title: Text('${topic.nameTagalog} • ${topic.botName}'),
                subtitle: Text(botStatus),
                trailing: Icon(
                  botStatus.startsWith('Active') ? Icons.check_circle : Icons.hourglass_empty,
                  color: botStatus.startsWith('Active') ? Colors.green : Colors.orange,
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          const Text(
            'Rules enforced by ManagerBot',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('• Auto-refresh every 1 minute'),
          const Text('• Only content newer than 2 hours is shown'),
          const Text('• Old stories & videos are automatically purged'),
          const Text('• Stories and videos play inside the app only'),
          const Text('• No external links for media'),
          const Text('• Each column has its own dedicated Topic Bot'),
        ],
      ),
    );
  }
}
