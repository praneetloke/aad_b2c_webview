import 'dart:io';
import 'package:aad_b2c_webview/src/services/client_authentication.dart';
import 'package:aad_b2c_webview/src/services/models/optional_param.dart';
import 'package:aad_b2c_webview/src/services/models/response_data.dart';
import 'package:aad_b2c_webview/src/services/models/token.dart';
import 'package:flutter/material.dart';
import 'package:pkce/pkce.dart';
import 'package:webview_flutter/webview_flutter.dart';
// #docregion platform_imports
// Import for Android features.
import 'package:webview_flutter_android/webview_flutter_android.dart';
// Import for iOS features.
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
// #enddocregion platform_imports

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
  final List<OptionalParam> optionalParameters;

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
  final PkcePair pkcePairInstance = PkcePair.generate();
  final _key = UniqueKey();
  late Function onRedirect;

  bool isLoading = true;
  bool showRedirect = false;

  late final WebViewController _controller;

  @override
  void initState() {
    onRedirect = widget.onRedirect ??
        () {
          Navigator.of(context).pop();
        };

    super.initState();

    // #docregion platform_features
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);
    // #enddocregion platform_features

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                isLoading = false;
              });

              final Uri response = Uri.dataFromString(url);
              //Check that the user is past authentication and current URL is the redirect with the code.
              onPageFinishedTasks(url, response);
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('''
Page resource error:
  code: ${error.errorCode}
  description: ${error.description}
  errorType: ${error.errorType}
  isForMainFrame: ${error.isForMainFrame}
          ''');
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith(widget.redirectUrl)) {
              debugPrint('blocking navigation to ${request.url}');
              return NavigationDecision.prevent;
            }

            debugPrint('allowing navigation to ${request.url}');
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(getUserFlowUrl(
          userFlow: "${widget.tenantBaseUrl}/${Constants.userFlowUrlEnding}")));

    // #docregion platform_features
    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
    // #enddocregion platform_features

    _controller = controller;
  }

  /// Callback function for handling any token received.
  void onAnyTokenRecivedCallback(Token token) {
    if (widget.onAnyTokenRetrieved != null) {
      widget.onAnyTokenRetrieved!(token);
    }
  }

  /// Handles the callbacks for the received tokens.
  void handleTokenCallbacks({required AzureTokenResponse? tokensData}) {
    String? accessTokenValue = tokensData?.accessToken;
    String? idTokenValue = tokensData?.idToken;
    String? refreshTokenValue = tokensData?.refreshToken;

    if (accessTokenValue != null) {
      final Token token =
          Token(type: TokenType.accessToken, value: accessTokenValue);
      widget.onAccessToken(token);
      onAnyTokenRecivedCallback(token);
    }

    if (idTokenValue != null) {
      final token = Token(type: TokenType.idToken, value: idTokenValue);
      widget.onIDToken(token);
      onAnyTokenRecivedCallback(token);
    }

    if (refreshTokenValue != null) {
      final Token token = Token(
          type: TokenType.refreshToken,
          value: refreshTokenValue,
          expirationTime: tokensData?.refreshTokenExpireTime);
      widget.onRefreshToken(token);
      onAnyTokenRecivedCallback(token);
    }
  }

  // Performs the authorization code flow using the provided URL.
  Future<void> authorizationCodeFlow(url) async {
    String authCode = url.split("${Constants.authCode}=")[1];

    ClientAuthentication clientAuthentication =
        ClientAuthentication(pkcePair: pkcePairInstance);

    final AzureTokenResponse? tokensData =
        await clientAuthentication.getAllTokens(
      redirectUri: widget.redirectUrl,
      clientId: widget.clientId,
      authCode: authCode,
      userFlowName: widget.userFlowName,
      tenantBaseUrl: widget.tenantBaseUrl,
    );

    if (tokensData != null) {
      if (!mounted) return;
      // call redirect function
      handleTokenCallbacks(tokensData: tokensData);
      onRedirect(context, url);
    }
  }

  /// Executes tasks when the page finishes loading.
  dynamic onPageFinishedTasks(String url, Uri response) {
    if (response.path.contains(widget.redirectUrl)) {
      if (url.contains(Constants.idToken)) {
        //Navigate to the redirect route screen; check for mounted component
        if (!mounted) return;
        //call redirect function
        onRedirect(context, response.path);
      } else if (url.contains(Constants.accessToken)) {
        //Navigate to the redirect route screen; check for mounted component
        if (!mounted) return;
        //call redirect function
        onRedirect(context, response.path);
      } else if (url.contains(Constants.authCode)) {
        //Run authorization code flow and get access token.
        authorizationCodeFlow(url);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          WebViewWidget(key: _key, controller: _controller),
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

  /// Constructs the user flow URL with optional parameters.
  String getUserFlowUrl({required String userFlow}) {
    List<String>? userFlowSplit = userFlow.split('?');
    //Check if the user added the full user flow or just till 'authorize'
    if (userFlowSplit.length == 1) {
      return concatUserFlow(userFlow);
    }
    return userFlow;
  }

  /// Creates a string representation of the scopes.
  String createScopes(List<String> scopeList) {
    String allScope = '';
    for (String scope in scopeList) {
      scope += '%20';
      allScope += scope;
    }
    return allScope.substring(0, allScope.length - 3);
  }

  /// Concatenates the user flow URL with additional parameters.
  String concatUserFlow(String url) {
    const idClientParam = '&client_id=';
    const nonceParam = '&nonce=defaultNonce&redirect_uri=';
    const scopeParam = '&scope=';
    const responseTypeParam = '&response_type=';
    const promptParam = '&prompt=login';
    const pageParam = '?p=';
    const codeChallengeMethod =
        '&code_challenge_method=${Constants.defaultCodeChallengeCode}';
    final codeChallenge = "&code_challenge=${pkcePairInstance.codeChallenge}";

    String newParameters = "";
    if (widget.optionalParameters.isNotEmpty) {
      for (OptionalParam param in widget.optionalParameters) {
        newParameters += "&${param.key}=${param.value}";
      }
    }

    return url +
        pageParam +
        widget.userFlowName +
        idClientParam +
        widget.clientId +
        nonceParam +
        widget.redirectUrl +
        scopeParam +
        createScopes(widget.scopes) +
        responseTypeParam +
        widget.responseType +
        promptParam +
        codeChallenge +
        codeChallengeMethod +
        newParameters;
  }
}
