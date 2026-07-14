import 'supabase_client.dart';

class SupabaseService {
  Future<Map<String, dynamic>> loadRequests() async {
    final client = await WingaSupabaseClient.init(
      url: const String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://kevdbsyiqelksxvmuped.supabase.co'),
      anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'your_anon_key_here'),
    );

    final response = await client.from('requests').select().limit(5);
    return {'data': response};
  }
}
