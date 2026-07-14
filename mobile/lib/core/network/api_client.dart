class ApiClient {
  ApiClient({this.baseUrl = 'https://api.winga.example'});

  final String baseUrl;

  Future<Map<String, dynamic>> get(String path) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return {'path': path, 'status': 'ok'};
  }

  Future<Map<String, dynamic>> post(String path, {required Map<String, dynamic> body}) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return {'path': path, 'body': body, 'status': 'created'};
  }
}
