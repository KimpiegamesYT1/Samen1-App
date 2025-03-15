import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class RadioPage extends StatefulWidget {
  const RadioPage({super.key});

  @override
  State<RadioPage> createState() => _RadioPageState();
}

class _RadioPageState extends State<RadioPage> {
  bool _isLoading = true;  // Laadstatus bijhouden
  bool _isWebViewVisible = false;  // Website zichtbaarheid bijhouden
  InAppWebViewController? _webViewController;  // Controller voor de WebView

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();  // Zet het scherm aan zodat deze niet in slaap valt
  }

  @override
  void dispose() {
    WakelockPlus.disable();  // Zet het scherm uit bij het sluiten van de pagina
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (await _webViewController?.canGoBack() ?? false) {
          // Als de webview een geschiedenis heeft, ga dan terug naar de vorige pagina
          _webViewController?.goBack();
          return false;  // Voorkom dat de app sluit
        }
        return true;  // Sluit de app als er geen geschiedenis is
      },
      child: Scaffold(
        body: Stack(
          children: [
            // WebView - deze is verborgen totdat de pagina is geladen
            AnimatedOpacity(
              opacity: _isWebViewVisible ? 1.0 : 0.0,  // Webview zichtbaar maken zodra geladen
              duration: const Duration(milliseconds: 500),
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri('https://samen1.nl/radio/')),
                onLoadStart: (controller, url) {
                  setState(() {
                    _isLoading = true;  // Start loading indicator
                  });
                },
                onLoadStop: (controller, url) async {
                  // Eerst de JavaScript-code uitvoeren voordat we de webview zichtbaar maken
                  await controller.evaluateJavascript(source: '''
                    document.querySelector('.play-button')?.click();
                  ''');

                  await controller.injectCSSCode(source: '''
                    footer, .site-header, .site-footer, #mobilebar, .page-title { display: none !important; }
                    body { padding-top: 0 !important; }
                    #top { padding-top: 1rem; }
                    #anchornav { top: 0; padding-top: 2rem }
                  ''');

                  // Stop de laadindicator als de pagina geladen is
                  setState(() {
                    _isLoading = false;  // Stop loading
                    _isWebViewVisible = true;  // Maak de webpagina zichtbaar
                  });
                },
                onWebViewCreated: (controller) {
                  _webViewController = controller;  // Initialiseer de controller
                },
              ),
            ),
            if (_isLoading)  // Laadindicator zichtbaar zolang _isLoading true is
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
