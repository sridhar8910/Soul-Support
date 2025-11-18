import 'package:flutter_test/flutter_test.dart';

import 'package:common/common.dart';

void main() {
  test('common package exports work', () {
    // Test that classes exist
    expect(ApiClient, isNotNull);
    expect(TokenManager, isNotNull);
    
    // Test that classes can be instantiated
    final apiClient = ApiClient();
    expect(apiClient, isA<ApiClient>());
    
    final tokenManager = TokenManager();
    expect(tokenManager, isA<TokenManager>());
  });
}
