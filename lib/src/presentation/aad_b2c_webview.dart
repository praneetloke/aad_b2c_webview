import 'package:aad_b2c_webview/src/services/models/token.dart';
import 'package:flutter/material.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

import '../constants.dart';

/// A widget that embeds the Azure AD B2C web view for authentication purposes.
class ADB2CEmbedWebView extends StatefulWidget {
  final String tenantBaseUrl;
  final String clientId;
  final String redirectUrl;
  final String userFlowName;
  final Function(BuildContext context, String url)? onRedirect;
  final ValueChanged<Token> onAccessToken;
  final ValueChanged<Token> onIDToken;
  final ValueChanged<Token> onRefreshToken;
  final ValueChanged<Token>? onAnyTokenRetrieved;
  final List<String> scopes;
  final String responseType;
  final Map<String, String> optionalParameters;

  const ADB2CEmbedWebView({
    super.key,
    // Required to work
    required this.tenantBaseUrl,
    required this.clientId,
    required this.redirectUrl,
    required this.userFlowName,
    required this.scopes,
    required this.onAccessToken,
    required this.onIDToken,
    required this.onRefreshToken,
    required this.optionalParameters,

    // Optionals
    this.onRedirect,
    this.onAnyTokenRetrieved,

    // Optionals with default value
    this.responseType = Constants.defaultResponseType,
  });

  @override
  ADB2CEmbedWebViewState createState() => ADB2CEmbedWebViewState();
}

class ADB2CEmbedWebViewState extends State<ADB2CEmbedWebView> {
  final FlutterAppAuth _appAuth = const FlutterAppAuth();

  late AuthorizationServiceConfiguration _serviceConfiguration;
  late Function onRedirect;

  bool isLoading = true;
  bool showRedirect = false;

  @override
  void initState() {
    onRedirect = widget.onRedirect ??
        () {
          Navigator.of(context).pop();
        };

    _serviceConfiguration = AuthorizationServiceConfiguration(
      authorizationEndpoint:
          "${widget.tenantBaseUrl}/${Constants.userFlowUrlEnding}",
      tokenEndpoint:
          "{widget.tenantBaseUrl}/${widget.userFlowName}/${Constants.userGetTokenUrlEnding}",
    );

    super.initState();

    _signInWithAutoCodeExchange(preferEphemeralSession: true);
  }

  Future<void> _signInWithAutoCodeExchange(
      {bool preferEphemeralSession = false}) async {
    try {
      _setBusyState();

      var additionalParams = {"p": widget.userFlowName};
      additionalParams.addAll(widget.optionalParameters);

      /*
        This shows that we can also explicitly specify the endpoints rather than
        getting from the details from the discovery document.
      */
      final AuthorizationTokenResponse? result =
          await _appAuth.authorizeAndExchangeCode(AuthorizationTokenRequest(
        widget.clientId,
        widget.redirectUrl,
        serviceConfiguration: _serviceConfiguration,
        scopes: widget.scopes,
        preferEphemeralSession: preferEphemeralSession,
        promptValues: ["login"],
        additionalParameters: additionalParams,
      ));

      /* 
        This code block demonstrates passing in values for the prompt
        parameter. In this case it prompts the user login even if they have
        already signed in. the list of supported values depends on the
        identity provider

        ```dart
        final AuthorizationTokenResponse result = await _appAuth
        .authorizeAndExchangeCode(
          AuthorizationTokenRequest(_clientId, _redirectUrl,
              serviceConfiguration: _serviceConfiguration,
              scopes: _scopes,
              promptValues: ['login']),
        );
        ```
      */

      if (result != null) {
        handleTokenCallbacks(result);
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      _clearBusyState();
    }
  }

  void _clearBusyState() {
    setState(() {
      isLoading = true;
      showRedirect = true;
    });
  }

  void _setBusyState() {
    setState(() {
      isLoading = false;
      showRedirect = false;
    });
  }

  /// Callback function for handling any token received.
  void onAnyTokenReceivedCallback(Token token) {
    if (widget.onAnyTokenRetrieved != null) {
      widget.onAnyTokenRetrieved!(token);
    }
  }

  /// Handles the callbacks for the received tokens.
  void handleTokenCallbacks(AuthorizationTokenResponse tokensData) {
    String? accessTokenValue = tokensData.accessToken;
    String? idTokenValue = tokensData.idToken;
    String? refreshTokenValue = tokensData.refreshToken;

    if (accessTokenValue != null) {
      final Token token = Token(
          type: TokenType.accessToken,
          value: accessTokenValue,
          expirationTime: tokensData.accessTokenExpirationDateTime
              ?.difference(DateTime.now())
              .inSeconds);
      widget.onAccessToken(token);
      onAnyTokenReceivedCallback(token);
    }

    if (idTokenValue != null) {
      final token = Token(type: TokenType.idToken, value: idTokenValue);
      widget.onIDToken(token);
      onAnyTokenReceivedCallback(token);
    }

    if (refreshTokenValue != null) {
      final Token token = Token(
          type: TokenType.refreshToken,
          value: refreshTokenValue,
          expirationTime: tokensData
              .tokenAdditionalParameters?[Constants.refreshTokenExpiresIn]);
      widget.onRefreshToken(token);
      onAnyTokenReceivedCallback(token);
    }

    if (!mounted) {
      return;
    }
    onRedirect(context, widget.redirectUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          Visibility(
              visible: (isLoading || showRedirect),
              child: const Center(
                child: SizedBox(
                  height: 250,
                  width: 250,
                  child: CircularProgressIndicator(
                    backgroundColor: Colors.white,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
              )),
          Visibility(
            visible: isLoading,
            child: const Positioned(
              child: Center(
                child: Text('Redirecting to Secure Login...'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
