import 'package:aad_b2c_webview/src/src.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class MockBuildContext extends Mock implements BuildContext {}

void main() {
  ADB2CEmbedWebView embedWebView;
  MockBuildContext mockContext;

  test('testing embed webview', () {
    embedWebView = ADB2CEmbedWebView(
      onAccessToken: (_) {},
      onIDToken: (_) {},
      onRefreshToken: (_) {},
      tenantBaseUrl: '',
      userFlowName: '',
      clientId: '',
      redirectUrl: '',
      onRedirect: (context, _) {},
      scopes: const ['openId'],
      optionalParameters: const {"key": "value"},
    );
    mockContext = MockBuildContext();
    var mockEmbedWebViewstate = embedWebView.createState().build(mockContext);

    expect(mockEmbedWebViewstate, isNotNull);
  });
}
