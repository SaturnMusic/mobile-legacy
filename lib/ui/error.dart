import 'package:connectivity/connectivity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:Saturn/translations.i18n.dart';

int counter = 0;

class ErrorScreen extends StatefulWidget {
  final String message;
  const ErrorScreen({this.message, Key key}) : super(key: key);

  @override
  _ErrorScreenState createState() => _ErrorScreenState();
}

class _ErrorScreenState extends State<ErrorScreen> {

  bool checkArl = false;

  @override
  void initState() {

    Connectivity().checkConnectivity().then((connectivity) {
      if (connectivity != ConnectivityResult.none && counter > 3) {
        setState(() {
          checkArl = true;
        });
      }
    });

    counter += 1;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.error,
            color: Colors.red,
            size: 64.0,
          ),
          Container(height: 4.0,),
          Text(widget.message ?? 'Please check your connection and try again later...'.i18n),
          if (checkArl)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 32.0),
              child: Text(
                "Your ARL might be expired, try logging out and logging back in using new ARL or browser.".i18n,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.0,
                ),
              ),
            )
        ],
      ),
    );
  }
}
