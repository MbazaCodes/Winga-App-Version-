import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import 'ride_detail_screen.dart';

class RideHistoryScreen extends StatelessWidget {
  const RideHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rides = [
      {'title': 'Airport transfer', 'time': 'Yesterday • 08:30', 'status': 'Completed'},
      {'title': 'Downtown drop-off', 'time': '2 days ago • 19:10', 'status': 'Completed'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Ride history')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ride history', style: AppTextStyles.headline),
            const SizedBox(height: 12),
            const Text('Your recent Winga trips and payment activity.', style: AppTextStyles.body),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: rides.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final ride = rides[index];
                  return Card(
                    child: ListTile(
                      title: Text(ride['title']!),
                      subtitle: Text(ride['time']!),
                      trailing: Chip(label: Text(ride['status']!)),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RideDetailScreen()),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
