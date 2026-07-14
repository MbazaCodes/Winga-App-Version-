import 'package:supabase_flutter/supabase_flutter.dart';

class WingaSupabaseClient {
  static SupabaseClient? _client;

  static Future<SupabaseClient> init({required String url, required String anonKey}) async {
    if (_client != null) return _client!;

    await Supabase.initialize(url: url, anonKey: anonKey);
    _client = Supabase.instance.client;
    return _client!;
  }

  static SupabaseClient? get instance => _client;
}
