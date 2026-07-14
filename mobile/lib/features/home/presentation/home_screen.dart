import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../../shared/widgets/primary_button.dart';
import '../data/request_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final repository = RequestRepository();
  List<Map<String, dynamic>> requests = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await repository.loadRequests();
    if (!mounted) return;
    setState(() {
      requests = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Winga Dashboard', style: AppTextStyles.headline),
            const SizedBox(height: 12),
            const Text('Your next ride and booking summary will appear here.', style: AppTextStyles.body),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Next booking', style: AppTextStyles.headline.copyWith(fontSize: 20)),
                  const SizedBox(height: 8),
                  const Text('Airport transfer • 08:30 • Premium ride'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (loading)
              const Text('Loading requests...')
            else
              Expanded(
                child: ListView.builder(
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    return Card(
                      child: ListTile(
                        title: Text(request['id']?.toString() ?? 'Request'),
                        subtitle: Text(request['status']?.toString() ?? 'Unknown'),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 140,
                  child: PrimaryButton(
                    label: 'Book now',
                    onPressed: () => context.go('/booking'),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: OutlinedButton(
                    onPressed: () => context.go('/requests'),
                    child: const Text('Request status'),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: OutlinedButton(
                    onPressed: () => context.go('/tracking'),
                    child: const Text('Track ride'),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: OutlinedButton(
                    onPressed: () => context.go('/support'),
                    child: const Text('Support'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
