import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:Saturn/api/deezer.dart';
import 'package:Saturn/api/player.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:Saturn/translations.i18n.dart';

import '../settings.dart';
import '../api/definitions.dart';
import 'home_screen.dart';

class LoginWidget extends StatefulWidget {

  final Function callback;
  LoginWidget({this.callback, Key key}): super(key: key);

  @override
  _LoginWidgetState createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> {

  String _arl;
  String _error;

  //Initialize deezer etc
  Future _init() async {
    deezerAPI.arl = settings.arl;
    await playerHelper.start();

    //Pre-cache homepage
    if (!await HomePage().exists()) {
      await deezerAPI.authorize();
      settings.offlineMode = false;
      HomePage hp = await deezerAPI.homePage();
      await hp.save();
    }
  }
  //Call _init()
  void _start() async {
    if (settings.arl != null) {
      _init().then((_) {
        if (widget.callback != null) widget.callback();
      });
    }
  }

  //Check if deezer available in current country
  void _checkAvailability() async {
    bool available = await DeezerAPI.chceckAvailability();
    if (!(available??true)) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Deezer is unavailable".i18n),
          content: Text("Deezer is unavailable in your country, freezer might not work properly. Please use a VPN".i18n),
          actions: [
            TextButton(
              child: Text('Continue'.i18n),
              onPressed: () => Navigator.of(context).pop(),
            )
          ],
        )
      );
    }
  }

  @override
  void didUpdateWidget(LoginWidget oldWidget) {
    _start();
    super.didUpdateWidget(oldWidget);
  }

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
              Text('Error logging in! Please check your token and internet connection and try again.'.i18n),
              if (_error != null)
                Text('\n\n$_error')
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Dismiss'.i18n),
              onPressed: () {
                Navigator.of(context).pop();
              },
            )
          ],
        );
      }
    );
  }

  void _update() async {
    setState(() => {});

    //Try logging in
    try {
      deezerAPI.arl = settings.arl;
      bool resp = await deezerAPI.rawAuthorize(onError: (e) => setState(() => _error = e.toString()));
      if (resp == false) { //false, not null
        if (settings.arl.length != 192) {
          if (_error == null) _error = '';
            _error += 'Invalid ARL length!';
        }
        setState(() => settings.arl = null);
        errorDialog();
      }
      //On error show dialog and reset to null
    } catch (e) {
      _error = e.toString();
      print('Login error: ' + e.toString());
      setState(() => settings.arl = null);
      errorDialog();
    }

    await settings.save();
    _start();
  }

  // ARL auth: called on "Save" click, Enter and DPAD_Center press
  void goARL(FocusNode node, TextEditingController _controller) {
    if (node != null) {
      node.unfocus();
    }
    _controller.clear();
    settings.arl = _arl.trim();
    Navigator.of(context).pop();
    _update();
  }

  @override
  Widget build(BuildContext context) {

    //If arl non null, show loading
    if (settings.arl != null)
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Theme.of(context).primaryColor,),
        ),
      );
    TextEditingController _controller = new TextEditingController();
// For "DPAD center" key handling on remote controls
FocusNode focusNode = FocusNode(
  skipTraversal: true,
  descendantsAreFocusable: false,
  onKey: (node, event) {
    if (event.logicalKey == LogicalKeyboardKey.select) {
      goARL(node, _controller);
      return KeyEventResult.handled; // Return handled when the key event is processed
    }
    return KeyEventResult.ignored; // Return ignored if the key event is not processed
  },
);
    if (settings.arl == null)
      return Scaffold(
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: ListView(
            children: <Widget>[
              freezerTitle(),
              Container(height: 8.0,),
              Text(
                "Please login using your Deezer account.".i18n,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16.0
                ),
              ),
              Container(height: 16.0,),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.0),
                child: OutlinedButton(
                  child: Text('Login using browser'.i18n),
                  onPressed: () {
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => LoginBrowser(_update))
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.0),
                child: OutlinedButton(
                  child: Text('Login using token'.i18n),
                  onPressed: () {
                    showDialog(
                        context: context,
                        builder: (context) {
                          Future.delayed(Duration(seconds: 1), () => {focusNode.requestFocus()}); // autofocus doesn't work - it's replacement
                          return AlertDialog(
                            title: Text('Enter ARL'.i18n),
                            content: Container(
                              child: TextField(
                                onChanged: (String s) => _arl = s,
                                decoration: InputDecoration(
                                  labelText: 'Token (ARL)'.i18n
                                ),
                                focusNode: focusNode,
                                controller: _controller,
                                onSubmitted: (String s) {
                                  goARL(focusNode, _controller);
                                },
                              ),
                            ),
                            actions: <Widget>[
                              TextButton(
                                child: Text('Save'.i18n),
                                onPressed: () => goARL(null, _controller),
                              )
                            ],
                          );
                        }
                    );
                  },
                ),
              ),
              Container(height: 16.0,),
              Text(
                "If you don't have account, you can register on deezer.com for free.".i18n,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.0
                ),
              ),

              Container(height: 8.0,),
              Divider(),
              Container(height: 8.0,),
              Text(
                "2k24 saturnclient.dev",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.0
                ),
              )
            ],
          ),
        ),
      );
    return null;
  }
}


class LoginBrowser extends StatelessWidget {
  final Function updateParent;
  
  LoginBrowser(this.updateParent);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: Container(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: Uri.parse('https://deezer.com/login')),
              onLoadStart: (controller, url) async {
                // Offers URL handling
                if (!url.toString().contains('/login') && !url.toString().contains('/register')) {
                  await controller.evaluateJavascript(source: 'window.location.href = "/open_app"');
                }

                // Parse arl from URL
                if (url.toString().startsWith('intent://deezer.page.link')) {
                  try {
                    // Parse URL
                    Uri uri = Uri.parse(url.toString());
                    // Actual URL is in `link` query parameter
                    Uri linkUri = Uri.parse(uri.queryParameters['link']);
                    String arl = linkUri.queryParameters['arl'];
                    if (arl != null) {
                      settings.arl = arl;
                      Navigator.of(context).pop();
                      updateParent();
                    }
                  } catch (e) {
                    print('Error parsing URL: $e');
                  }
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}


class EmailLogin extends StatefulWidget {

  final Function callback;
  EmailLogin(this.callback, {Key key}): super(key: key);

  @override
  _EmailLoginState createState() => _EmailLoginState();
}

class _EmailLoginState extends State<EmailLogin> {

  String _email;
  String _password;
  bool _loading = false;

  Future _login() async {
    setState(() => _loading = true);
    //Try logging in
    String arl;
    String exception;
    try {
      arl = await DeezerAPI.getArlByEmail(_email, _password);
    } catch (e, st) {
      exception = e.toString();
      print(e);
      print(st);
    }
    setState(() => _loading = false);

    //Success
    if (arl != null) {
      settings.arl = arl;
      Navigator.of(context).pop();
      widget.callback();
      return;
    }

    //Error
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Error logging in!".i18n),
        content: Text("Error logging in using email, please check your credentials.\nError: " + exception),
        actions: [
          TextButton(
            child: Text('Dismiss'.i18n),
            onPressed: () {
              Navigator.of(context).pop();
            },
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Email Login'.i18n),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children:
        _loading ? [
          CircularProgressIndicator(color: Theme.of(context).primaryColor,)
        ]: [
          TextField(
            decoration: InputDecoration(
              labelText: 'Email'.i18n
            ),
            onChanged: (s) => _email = s,
          ),
          Container(height: 8.0,),
          TextField(
            obscureText: true,
            decoration: InputDecoration(
              labelText: "Password".i18n
            ),
            onChanged: (s) => _password = s,
          )
        ],
      ),
      actions: [
        if (!_loading)
          TextButton(
            child: Text('Login'),
            onPressed: () async {
              if (_email != null && _password != null)
                await _login();
              else
                Fluttertoast.showToast(
                  msg: "Missing email or password!".i18n,
                  gravity: ToastGravity.BOTTOM,
                  toastLength: Toast.LENGTH_SHORT
                );
            },
          )
      ],
    );
  }
}
