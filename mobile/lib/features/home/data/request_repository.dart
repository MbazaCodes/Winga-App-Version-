import '../../../core/network/supabase_service.dart';

class RequestRepository {
  RequestRepository({SupabaseService? service}) : _service = service ?? SupabaseService();

  final SupabaseService _service;

  Future<List<Map<String, dynamic>>> loadRequests() async {
    final payload = await _service.loadRequests();
    final data = payload['data'];
    if (data is List) {
      return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }
    return [];
  }
}
