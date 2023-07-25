import 'package:aad_b2c_webview/src/constants.dart';
import 'package:aad_b2c_webview/src/services/models/response_data.dart';
import 'package:dio/dio.dart';

class ClientAuthentication {
  /// Refresh token: This method also returns a new refresh token [AzureTokenResponse]
  static Future<AzureTokenResponse?> refreshTokens({
    required String refreshToken,
    required String tenant,
    required String policy,
    required String clientId,
  }) async {
    var url =
        "https://$tenant.b2clogin.com/$tenant.onmicrosoft.com/$policy/${Constants.userGetTokenUrlEnding}";
    Response response = await Dio().post(
      url,
      data: {
        'grant_type': Constants.refreshToken,
        'scope': Constants.defaultScopes,
        'client_id': clientId,
        'refresh_token': refreshToken,
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    if (response.statusCode == 200 && response.data.toString().isNotEmpty) {
      return AzureTokenResponse.fromJson(response.data);
    } else {
      return null;
    }
  }
}
