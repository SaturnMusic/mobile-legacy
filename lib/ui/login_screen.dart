import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:logging/logging.dart';

import '../api/deezer.dart';
import '../api/definitions.dart';
import '../utils/navigator_keys.dart';
import '../settings.dart';
import '../translations.i18n.dart';
import 'home_screen.dart';

class LoginWidget extends StatefulWidget {
  final Function? callback;
  const LoginWidget({required this.callback, super.key});

  @override
  _LoginWidgetState createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> {
  String? _arl;
  String? _error;

  //Initialize deezer etc
  Future _init() async {
    deezerAPI.arl = settings.arl;
    //await GetIt.I<AudioPlayerHandler>().start();

    //Pre-cache homepage
    if (!await HomePage().exists()) {
      await deezerAPI.authorize();
      settings.offlineMode = false;
      HomePage hp = await deezerAPI.homePage();
      if (hp.sections.isNotEmpty) await hp.save();
    }
  }

  //Call _init()
  void _start() async {
    if (settings.arl != null) {
      _init().then((_) {
        if (widget.callback != null) widget.callback!();
      });
    }
  }

  //Check if deezer available in current country
  void _checkAvailability() async {
    bool? available = await DeezerAPI.checkAvailability();
    if (!(available ?? false)) {
      showDialog(
          context: mainNavigatorKey.currentContext!,
          builder: (context) => AlertDialog(
                title: Text('Deezer is unavailable'.i18n),
                content: Text(
                    'Deezer is unavailable in your country, Saturn might not work properly. Please use a VPN'
                        .i18n),
                actions: [
                  TextButton(
                    child: Text('Continue'.i18n),
                    onPressed: () {
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  )
                ],
              ));
    }
  }

  /* No idea why this is needed, seems to trigger superfluous _start() execution...
  @override
  void didUpdateWidget(LoginWidget oldWidget) {
    _start();
    super.didUpdateWidget(oldWidget);
  }*/

  @override
  void initState() {
    _start();
    _checkAvailability();
    super.initState();
  }

  void errorDialog() {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Error'.i18n),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    'Error logging in! Please check your token and internet connection and try again.'
                        .i18n),
                if (_error != null) Text('\n\n$_error')
              ],
            ),
            actions: <Widget>[
              TextButton(
                child: Text('Dismiss'.i18n),
                onPressed: () {
                  _error = null;
                  Navigator.of(context).pop();
                },
              )
            ],
          );
        });
  }

  void _update() async {
    setState(() => {});

    //Try logging in
    try {
      deezerAPI.arl = settings.arl;
      bool resp = await deezerAPI.rawAuthorize(
          onError: (e) => setState(() => _error = e.toString()));
      if (resp == false) {
        //false, not null
        if ((settings.arl ?? '').length != 192) {
          _error = '${(_error ?? '')}Invalid ARL length!';
        }
        setState(() => settings.arl = null);
        errorDialog();
      }
      //On error show dialog and reset to null
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('Login error: $e');
      }
      setState(() => settings.arl = null);
      errorDialog();
    }

    await settings.save();
    _start();
  }

  // ARL auth: called on "Save" click, Enter and DPAD_Center press
  void goARL(FocusNode? node, TextEditingController controller) {
    node?.unfocus();
    controller.clear();
    settings.arl = _arl?.trim();
    Navigator.of(context).pop();
    _update();
  }

  @override
  Widget build(BuildContext context) {
    //If arl is null, show loading
    if (settings.arl != null) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Theme.of(context).primaryColor,),
        ),
      );
    }
    TextEditingController controller = TextEditingController();
    // For "DPAD center" key handling on remote controls
    FocusNode focusNode = FocusNode(
        skipTraversal: true,
        descendantsAreFocusable: false,
        onKeyEvent: (node, event) {
          if (event.logicalKey == LogicalKeyboardKey.select) {
            goARL(node, controller);
          }
          return KeyEventResult.handled;
        });
    if (settings.arl == null) {
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: ListView(
            children: <Widget>[
              const FreezerTitle(),
              Container(
                height: 8.0,
              ),
              Text(
                'Please login using your Deezer account.'.i18n,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16.0),
              ),
              Container(
                height: 16.0,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: OutlinedButton(
                  child: Text('Login using browser'.i18n),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => LoginBrowser(_update)));
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: OutlinedButton(
                  child: Text('Login using token'.i18n),
                  onPressed: () {
                    showDialog(
                        context: context,
                        builder: (context) {
                          Future.delayed(
                              const Duration(seconds: 1),
                              () => {
                                    focusNode.requestFocus()
                                  }); // autofocus doesn't work - it's replacement
                          return AlertDialog(
                            title: Text('Enter ARL'.i18n),
                            content: TextField(
                              onChanged: (String s) => _arl = s,
                              decoration: InputDecoration(
                                  labelText: 'Token (ARL)'.i18n,
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: Theme.of(context).primaryColor), // Color of the underline when focused
                                  ),
                                  ),
                              focusNode: focusNode,
                              controller: controller,
                              onSubmitted: (String s) {
                                goARL(focusNode, controller);
                              },
                            ),
                            actions: <Widget>[
                              TextButton(
                                child: Text('Save'.i18n),
                                onPressed: () => goARL(null, controller),
                              )
                            ],
                          );
                        });
                  },
                ),
              ),
              Container(
                height: 16.0,
              ),
              Container(
                height: 8.0,
              ),
              const Divider(),
              Container(
                height: 8.0,
              ),
              Text(
                "2k24 saturn.kim".i18n,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16.0),
              )
            ],
          ),
        ),
      );
    }
    return Container();
  }
}

class LoginBrowser extends StatelessWidget {
  final Function updateParent;
  const LoginBrowser(this.updateParent, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: InAppWebView(
            initialUrlRequest:
                URLRequest(url: WebUri('https://deezer.com/login')),
            onLoadStart:
                (InAppWebViewController controller, WebUri? loadedUri) async {
              //Offers URL
              if (!loadedUri!.path.contains('/login') &&
                  !loadedUri.path.contains('/register')) {
                controller.evaluateJavascript(
                    source: 'window.location.href = "/open_app"');
              }

              //Parse arl from url
              if (loadedUri
                  .toString()
                  .startsWith('intent://deezer.page.link')) {
                try {
                  //Actual url is in `link` query parameter
                  Uri linkUri = Uri.parse(loadedUri.queryParameters['link']!);
                  String? arl = linkUri.queryParameters['arl'];
                  settings.arl = arl;
                  // Clear cookies for next login after logout
                  CookieManager.instance().deleteAllCookies();
                  Navigator.of(context).pop();
                  updateParent();
                } catch (e) {
                  Logger.root
                      .severe('Error loading ARL from browser login: $e');
                }
              }
            },
          ),
        ),
      ],
    );
  }
}
