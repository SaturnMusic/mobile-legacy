import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:Saturn/api/cache.dart';
import 'package:Saturn/api/download.dart';
import 'package:Saturn/ui/elements.dart';
import 'package:Saturn/translations.i18n.dart';
import 'package:Saturn/ui/error.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:package_info/package_info.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:convert';

import 'package:version/version.dart';


class UpdaterScreen extends StatefulWidget {
  @override
  _UpdaterScreenState createState() => _UpdaterScreenState();
}

class _UpdaterScreenState extends State<UpdaterScreen> {

  bool _loading = true;
  bool _error = false;
  freezerVersions _versions;
  String _current;
  String _arch;
  double _progress = 0.0;
  bool _buttonEnabled = true;

  Future _load() async {
    //Load current version
    PackageInfo info = await PackageInfo.fromPlatform();
    setState(() => _current = info.version);

    //Get architecture
    _arch = await DownloadManager.platform.invokeMethod("arch");
    if (_arch == 'armv8l')
      _arch = 'arm32';

    //Load from website
    try {
      freezerVersions versions = await freezerVersions.fetch();
      setState(() {
        _versions = versions;
        _loading = false;
      });
    } catch (e, st) {
      print(e + st);
      _error = true;
      _loading = false;
    }
  }

  freezerDownload get _versionDownload {
    return _versions.versions[0].downloads.firstWhere((d) => d.version.toLowerCase().contains(_arch.toLowerCase()), orElse: () => null);
  }

  Future _download() async {
    String url = _versionDownload.directUrl;
    //Start request
    http.Client client = new http.Client();
    http.StreamedResponse res = await client.send(http.Request('GET', Uri.parse(url)));
    int size = res.contentLength;
    //Open file
    String path = p.join((await getExternalStorageDirectory()).path, 'update.apk');
    File file = File(path);
    IOSink fileSink = file.openWrite();
    //Update progress
    Future.doWhile(() async {
      int received = await file.length();
      setState(() => _progress = received/size);
      return received != size;
    });
    //Pipe
    await res.stream.pipe(fileSink);
    fileSink.close();

    OpenFile.open(path);
    setState(() => _buttonEnabled = true);
  }


  @override
  void initState() {
    _load();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: freezerAppBar('Updates'.i18n),
      body: ListView(
        children: [

          if (_error)
            ErrorScreen(),

          if (_loading)
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [CircularProgressIndicator()],
              ),
            ),

          if (!_error && !_loading && Version.parse(_versions.latest) <= Version.parse(_current))
            Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'You are running latest version!'.i18n,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26.0
                  )
                ),
              )
            ),

          if (!_error && !_loading && Version.parse(_versions.latest) > Version.parse(_current))
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'New update available!'.i18n + ' ' + _versions.latest,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold
                    ),
                  ),
                ),
                Text(
                  'Current version: ' + _current,
                  style: TextStyle(
                    fontSize: 14.0,
                    fontStyle: FontStyle.italic
                  ),
                ),
                Container(height: 8.0),
                freezerDivider(),
                Container(height: 8.0),
                Text(
                  'Changelog',
                  style: TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    _versions.versions[0].changelog,
                    style: TextStyle(fontSize: 16.0),
                  ),
                ),
                freezerDivider(),
                Container(height: 8.0),
                //Available download
                if (_versionDownload != null)
                  Column(children: [
                    ElevatedButton(
                      child: Text('Download'.i18n + ' (${_versionDownload.version})'),
                      onPressed: _buttonEnabled ? () {
                        setState(() => _buttonEnabled = false);
                        _download();
                      }:null
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: LinearProgressIndicator(value: _progress),
                    )
                  ]),
                //Unsupported arch
                if (_versionDownload == null)
                  Text(
                    'Unsupported platform!'.i18n + ' $_arch',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16.0),
                  )
              ],
            )

        ],
      )
    );
  }
}

class freezerVersions {
  String latest;
  List<freezerVersion> versions;

  freezerVersions({this.latest, this.versions});

  factory freezerVersions.fromJson(Map data) => freezerVersions(
    latest: data['android']['latest'],
    versions: data['android']['versions'].map<freezerVersion>((v) => freezerVersion.fromJson(v)).toList()
  );

  //Fetch from website API
  static Future<freezerVersions> fetch() async {
    http.Response response = await http.get('https://saturnclient.dev/api/versions');
//    http.Response response = await http.get('https://freezer.life/api/versions');
//    http.Response response = await http.get('https://cum.freezerapp.workers.dev/api/versions');
    return freezerVersions.fromJson(jsonDecode(response.body));
  }

  static Future checkUpdate() async {
    //Check only each 24h
    int updateDelay = 86400000;
    if ((DateTime.now().millisecondsSinceEpoch - (cache.lastUpdateCheck??0)) < updateDelay) return;
    cache.lastUpdateCheck = DateTime.now().millisecondsSinceEpoch;
    await cache.save();

    freezerVersions versions = await freezerVersions.fetch();

    //Load current version
    PackageInfo info = await PackageInfo.fromPlatform();
    if (Version.parse(versions.latest) <= Version.parse(info.version)) return;

    //Get architecture
    String _arch = await DownloadManager.platform.invokeMethod("arch");
    if (_arch == 'armv8l')
      _arch = 'arm32';
    //Check compatible architecture
    if (versions.versions[0].downloads.firstWhere((d) => d.version.toLowerCase().contains(_arch.toLowerCase()), orElse: () => null) == null) return;

// Show notification
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings androidInitializationSettings = AndroidInitializationSettings('drawable/ic_logo');
  final InitializationSettings initializationSettings = InitializationSettings(android: androidInitializationSettings, iOS: null);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
    'freezerupdates', // Channel ID
    'freezer Updates', // Channel Name
    'freezer Updates', // Channel Description
    importance: Importance.high,
    priority: Priority.high,
  );

  NotificationDetails notificationDetails = NotificationDetails(android: androidNotificationDetails, iOS: null);

  await flutterLocalNotificationsPlugin.show(
    0, // Notification ID
    'New update available!'.i18n, // Notification title
    'Update to latest version in the settings.'.i18n, // Notification body
    notificationDetails,
  );
  }
}

class freezerVersion {
  String version;
  String changelog;
  List<freezerDownload> downloads;

  freezerVersion({this.version, this.changelog, this.downloads});

  factory freezerVersion.fromJson(Map data) => freezerVersion(
    version: data['version'],
    changelog: data['changelog'],
    downloads: data['downloads'].map<freezerDownload>((d) => freezerDownload.fromJson(d)).toList()
  );
}

class freezerDownload {
  String version;
  String directUrl;

  freezerDownload({this.version, this.directUrl});

  factory freezerDownload.fromJson(Map data) => freezerDownload(
    version: data['version'],
    directUrl: data['links'].first['url']
  );
}
