import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/storage/storage_service.dart';

final authControllerProvider = NotifierProvider<AuthController, bool>(AuthController.new);

class AuthController extends Notifier<bool> {
  late final StorageService storageService = StorageService();

  @override
  bool build() => false;

  Future<void> signIn({required String phoneOrEmail, required String password}) async {
    state = true;
    try {
      final client = await WingaSupabaseClient.init(
        url: const String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://kevdbsyiqelksxvmuped.supabase.co'),
        anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'your_anon_key_here'),
      );

      await client.auth.signInWithOtp(phone: phoneOrEmail);
      await storageService.saveString('auth_session', 'active');
    } finally {
      state = false;
    }
  }

  Future<void> signOut() async {
    await storageService.clear();
    state = false;
  }
}
