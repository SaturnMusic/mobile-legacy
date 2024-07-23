import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:custom_navigator/custom_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:Saturn/api/cache.dart';
import 'package:Saturn/api/definitions.dart';
import 'package:Saturn/ui/library.dart';
import 'package:Saturn/ui/login_screen.dart';
import 'package:Saturn/ui/search.dart';
import 'package:Saturn/ui/updater.dart';
import 'package:i18n_extension/i18n_widget.dart';
import 'package:move_to_background/move_to_background.dart';
import 'package:Saturn/translations.i18n.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:uni_links/uni_links.dart';

import 'api/deezer.dart';
import 'api/download.dart';
import 'api/player.dart';
import 'settings.dart';
import 'ui/home_screen.dart';
import 'ui/player_bar.dart';


Function updateTheme;
Function logOut;
GlobalKey<NavigatorState> mainNavigatorKey = GlobalKey<NavigatorState>();
GlobalKey<NavigatorState> navigatorKey;


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //Initialize globals
  settings = await Settings().loadSettings();
  await downloadManager.init();
  cache = await Cache.load();

  //Do on BG
  playerHelper.authorizeLastFM();

  runApp(freezerApp());
}

class freezerApp extends StatefulWidget {
  @override
  _freezerAppState createState() => _freezerAppState();
}

class _freezerAppState extends State<freezerApp> {

  @override
  void initState() {
    //Make update theme global
    updateTheme = _updateTheme;
    _updateTheme();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _updateTheme() {
    setState(() {
      settings.themeData;
    });
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      systemNavigationBarColor: settings.themeData.bottomAppBarColor,
      systemNavigationBarIconBrightness: settings.isDark ? Brightness.light : Brightness.dark,
    ));
  }

  Locale _locale() {
    if (settings.language == null || settings.language.split('_').length < 2) return null;
    return Locale(settings.language.split('_')[0], settings.language.split('_')[1]);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Saturn',
      //shortcuts: <LogicalKeySet, Intent>{
        //...WidgetsApp.defaultShortcuts,
       // //LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(), // DPAD center key, for remote controls
      //},
      theme: settings.themeData,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: supportedLocales,
      home: WillPopScope(
        onWillPop: () async {
          //For some reason AudioServiceWidget caused the app to freeze after 2 back button presses. "fix"
          if (navigatorKey.currentState.canPop()) {
            await navigatorKey.currentState.maybePop();
            return false;
          }
          await MoveToBackground.moveTaskToBack();
          return false;
        },
        child: I18n(
          initialLocale: _locale(),
          child: LoginMainWrapper(),
        ),
      ),
      navigatorKey: mainNavigatorKey,
    );
  }
}

//Wrapper for login and main screen.
class LoginMainWrapper extends StatefulWidget {
  @override
  _LoginMainWrapperState createState() => _LoginMainWrapperState();
}

class _LoginMainWrapperState extends State<LoginMainWrapper> {
  @override
  void initState() {
    if (settings.arl != null) {
      playerHelper.start();
      //Load token on background
      deezerAPI.arl = settings.arl;
      settings.offlineMode = true;
      deezerAPI.authorize().then((b) async {
        if (b) setState(() => settings.offlineMode = false);
      });
    }
    //Global logOut function
    logOut = _logOut;

    super.initState();
  }

  Future _logOut() async {
    setState(() {
      settings.arl = null;
      settings.offlineMode = false;
      deezerAPI = new DeezerAPI();
    });
    await settings.save();
    await Cache.wipe();
  }

  @override
  Widget build(BuildContext context) {
    if (settings.arl == null)
      return LoginWidget(
        callback: () => setState(() => {}),
      );
    return MainScreen();
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  List<Widget> _screens = [HomeScreen(), SearchScreen(), LibraryScreen()];
  int _selected = 0;
  StreamSubscription _urlLinkStream;
  int _keyPressed = 0;
  bool textFieldVisited = false;

  @override
  void initState() {
    navigatorKey = GlobalKey<NavigatorState>();

    //Set display mode
    if (settings.displayMode != null && settings.displayMode >= 0) {
      FlutterDisplayMode.supported.then((modes) async {
        if (modes.length - 1 >= settings.displayMode)
          FlutterDisplayMode.setPreferredMode(modes[settings.displayMode]);
      });
    }

    _startStreamingServer();

    //Start with parameters
    _setupUniLinks();
    _loadPreloadInfo();
    _prepareQuickActions();

    //Check for updates on background
    Future.delayed(Duration(seconds: 5), () {
      freezerVersions.checkUpdate();
    });

    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _startStreamingServer() async {
    await DownloadManager.platform.invokeMethod("startServer", {"arl": settings.arl});
  }

  void _prepareQuickActions() {
    final QuickActions quickActions = QuickActions();
    quickActions.initialize((type) {
      if (type != null)
        _startPreload(type);
    });

    //Actions
    quickActions.setShortcutItems([
      ShortcutItem(type: 'favorites', localizedTitle: 'Favorites'.i18n, icon: 'ic_favorites'),
      ShortcutItem(type: 'flow', localizedTitle: 'Flow'.i18n, icon: 'ic_flow'),

    ]);
  }

  void _startPreload(String type) async {
    await deezerAPI.authorize();
    if (type == 'flow') {
      await playerHelper.playFromSmartTrackList(SmartTrackList(id: 'flow'));
      return;
    }
    if (type == 'favorites') {
      Playlist p = await deezerAPI.fullPlaylist(deezerAPI.favoritesPlaylistId);
      playerHelper.playFromPlaylist(p, p.tracks[0].id);
    }
  }

  void _loadPreloadInfo() async {
    String info = await DownloadManager.platform.invokeMethod('getPreloadInfo');
    if (info != null) {
      //Used if started from android auto
      await deezerAPI.authorize();
      _startPreload(info);
    }
  }

  @override
  void dispose() {
    if (_urlLinkStream != null)
      _urlLinkStream.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {
        textFieldVisited = false;
      });
    }
  }

  void _setupUniLinks() async {
    //Listen to URLs
    _urlLinkStream = getUriLinksStream().listen((Uri uri) {
      openScreenByURL(context, uri.toString());
    }, onError: (err) {});
    //Get initial link on cold start
    try {
      String link = await getInitialLink();
      if (link != null && link.length > 4)
        openScreenByURL(context, link);
    } catch (e) {}
  }

  ValueChanged<RawKeyEvent> _handleKey(FocusScopeNode navigationBarFocusNode, FocusNode screenFocusNode){
    return (event) {
      FocusNode primaryFocus = FocusManager.instance.primaryFocus;
      // After visiting text field, something goes wrong and KeyDown events are not sent, only KeyUp-s.
      // So, set this flag to indicate a transition to other "mode"
      if (primaryFocus.context.widget.runtimeType.toString() == 'EditableText') {
        setState(() {
          textFieldVisited = true;
        });
      }
      // Movement to navigation bar and back
      if (event.runtimeType.toString() == (textFieldVisited ? 'RawKeyUpEvent' : 'RawKeyDownEvent')) {
        int keyCode = (event.data as RawKeyEventDataAndroid).keyCode;
        switch (keyCode) {
          case 127: // Menu on Android TV
          case 327: // EPG on Hisense TV
            focusToNavbar(navigationBarFocusNode);
            break;
          case 22: // LEFT + RIGHT
          case 21:
            if (_keyPressed == 21 && keyCode == 22 || _keyPressed == 22 && keyCode == 21) {
              focusToNavbar(navigationBarFocusNode);
            }
            _keyPressed = keyCode;
            Future.delayed(Duration(milliseconds: 100), () =>  {
              _keyPressed = 0
            });
            break;
          case 20: // DOWN
            // If it's bottom row, go to navigation bar
            var row = primaryFocus.parent;
            if (row != null) {
              var column = row.parent;   
              if (column.children.last == row) {
                focusToNavbar(navigationBarFocusNode);
              }
            }
            break;
          case 19: // UP
            if (navigationBarFocusNode.hasFocus) {
              screenFocusNode.parent.parent.children.last // children.last is used for handling "playlists" screen in library. Under CustomNavigator 2 screens appears.
                  .nextFocus(); // nextFocus is used instead of requestFocus because it focuses on last, bottom, non-visible tile of main page

            }
            break;
        }
      }
      // After visiting text field, something goes wrong and KeyDown events are not sent, only KeyUp-s.
      // Focus moving works only on KeyDown events, so here we simulate keys handling as it's done in Flutter
      if (textFieldVisited && event is RawKeyUpEvent) {
        //Map<LogicalKeySet, Intent> shortcuts = ShortcutRegistry.maybeOf(context).shortcuts;
        //final BuildContext primaryContext = primaryFocus?.context;
        //Intent intent = shortcuts[LogicalKeySet(event.logicalKey)];
        //if (intent != null) {
          //Actions.invoke(primaryContext, intent);
        //}
        // WA for "Search field -> navigator -> UP -> DOWN" case. Prevents focus hanging.
        FocusNode newFocus = FocusManager.instance.primaryFocus;
        if (newFocus is FocusScopeNode) {
          navigationBarFocusNode.requestFocus();
        }
      }
    };
  }

  void focusToNavbar(FocusScopeNode navigatorFocusNode) {
    navigatorFocusNode.requestFocus();
    navigatorFocusNode.focusInDirection(TraversalDirection.down); // If player bar is hidden, focus won't be visible, so go down once more
  }

  @override
  Widget build(BuildContext context) {
    FocusScopeNode navigationBarFocusNode = FocusScopeNode(); // for bottom navigation bar
    FocusNode screenFocusNode = FocusNode();  // for CustomNavigator
           
    return RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: _handleKey(navigationBarFocusNode, screenFocusNode),
        child: Scaffold(
            bottomNavigationBar:
                FocusScope(
                    node: navigationBarFocusNode,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        PlayerBar(),
                        BottomNavigationBar(
                          backgroundColor: Theme.of(context).bottomAppBarColor,
                          currentIndex: _selected,
                          onTap: (int s) async {
                            //Pop all routes until home screen
                            while (navigatorKey.currentState.canPop()) {
                              await navigatorKey.currentState.maybePop();
                            }

                            await navigatorKey.currentState.maybePop();
                            setState(() {
                              _selected = s;
                            });

                            //Fix statusbar
                            SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
                              statusBarColor: Colors.transparent,
                            ));
                          },
                          selectedItemColor: Theme.of(context).primaryColor,
                          items: <BottomNavigationBarItem>[
                            BottomNavigationBarItem(
                              icon: Icon(Icons.home),
                              label: 'Home'.i18n),
                            BottomNavigationBarItem(
                              icon: Icon(Icons.search),
                              label: 'Search'.i18n,
                            ),
                            BottomNavigationBarItem(
                              icon: Icon(Icons.library_music),
                              label: 'Library'.i18n
                            )
                          ],
                        )
                      ],
                    )),
            body: AudioServiceWidget(
              child: CustomNavigator(
                navigatorKey: navigatorKey,
                home: Focus(
                    focusNode: screenFocusNode,
                    skipTraversal: true,
                    canRequestFocus: false,
                    child: _screens[_selected]
                ),
                pageRoute: PageRoutes.materialPageRoute
              ),
            )));
  }
}
