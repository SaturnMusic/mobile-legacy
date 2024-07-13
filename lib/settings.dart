import 'package:audio_service/audio_service.dart';
import 'package:flutter/scheduler.dart';
import 'package:Saturn/api/download.dart';
import 'package:Saturn/main.dart';
import 'package:Saturn/ui/cached_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';

import 'dart:io';
import 'dart:convert';
import 'dart:async';


part 'settings.g.dart';

Settings settings;

@JsonSerializable()
class Settings {

  //Language
  @JsonKey(defaultValue: null)
  String language;

  //Main
  @JsonKey(defaultValue: false)
  bool ignoreInterruptions;
  @JsonKey(defaultValue: false)
  bool enableEqualizer;

  //Account
  String arl;
  @JsonKey(ignore: true)
  bool offlineMode = false;

  //Quality
  @JsonKey(defaultValue: AudioQuality.MP3_320)
  AudioQuality wifiQuality;
  @JsonKey(defaultValue: AudioQuality.MP3_128)
  AudioQuality mobileQuality;
  @JsonKey(defaultValue: AudioQuality.FLAC)
  AudioQuality offlineQuality;
  @JsonKey(defaultValue: AudioQuality.FLAC)
  AudioQuality downloadQuality;


  //Download options
  String downloadPath;

  @JsonKey(defaultValue: "%artist% - %title%")
  String downloadFilename;
  @JsonKey(defaultValue: true)
  bool albumFolder;
  @JsonKey(defaultValue: true)
  bool artistFolder;
  @JsonKey(defaultValue: false)
  bool albumDiscFolder;
  @JsonKey(defaultValue: false)
  bool overwriteDownload;
  @JsonKey(defaultValue: 2)
  int downloadThreads;
  @JsonKey(defaultValue: false)
  bool playlistFolder;
  @JsonKey(defaultValue: true)
  bool downloadLyrics;
  @JsonKey(defaultValue: false)
  bool trackCover;
  @JsonKey(defaultValue: true)
  bool albumCover;
  @JsonKey(defaultValue: false)
  bool nomediaFiles;
  @JsonKey(defaultValue: ", ")
  String artistSeparator;
  @JsonKey(defaultValue: "%artist% - %title%")
  String singletonFilename;
  @JsonKey(defaultValue: 1400)
  int albumArtResolution;
  @JsonKey(defaultValue: ["title", "album", "artist", "track", "disc",
    "albumArtist", "date", "label", "isrc", "upc", "trackTotal", "bpm",
    "lyrics", "genre", "contributors", "art"])
  List<String> tags;


  //Appearance
  @JsonKey(defaultValue: Themes.Dark)
  Themes theme;
  @JsonKey(defaultValue: false)
  bool useSystemTheme;
  @JsonKey(defaultValue: true)
  bool colorGradientBackground;
  @JsonKey(defaultValue: false)
  bool blurPlayerBackground;
  @JsonKey(defaultValue: "Deezer")
  String font;
  @JsonKey(defaultValue: false)
  bool lyricsVisualizer;
  @JsonKey(defaultValue: null)
  int displayMode;

  //Colors
  @JsonKey(toJson: _colorToJson, fromJson: _colorFromJson)
  Color primaryColor = Colors.blue;

  static _colorToJson(Color c) => c.value;
  static _colorFromJson(int v) => Color(v??Colors.blue.value);

  @JsonKey(defaultValue: false)
  bool useArtColor = false;
  StreamSubscription _useArtColorSub;

  //Deezer
  @JsonKey(defaultValue: 'en')
  String deezerLanguage;
  @JsonKey(defaultValue: 'US')
  String deezerCountry;
  @JsonKey(defaultValue: false)
  bool logListen;
  @JsonKey(defaultValue: null)
  String proxyAddress;

  //LastFM
  @JsonKey(defaultValue: null)
  String lastFMUsername;
  @JsonKey(defaultValue: null)
  String lastFMPassword;
  @JsonKey(defaultValue: null)
  String lastFMAPIKey;
  @JsonKey(defaultValue: null)
  String lastFMAPISecret;

  //Spotify
  @JsonKey(defaultValue: null)
  String spotifyClientId;
  @JsonKey(defaultValue: null)
  String spotifyClientSecret;
  @JsonKey(defaultValue: null)
  SpotifyCredentialsSave spotifyCredentials;


  Settings({this.downloadPath, this.arl});

  ThemeData get themeData {
    //System theme
    if (useSystemTheme) {
      if (SchedulerBinding.instance.window.platformBrightness == Brightness.light) {
        return _themeData[Themes.Light];
      } else {
        if (theme == Themes.Light) return _themeData[Themes.Dark];
        return _themeData[theme];
      }
    }
    //Theme
    return _themeData[theme]??ThemeData();
  }

  //Get all available fonts
  List<String> get fonts {
    return ['Deezer', ...GoogleFonts.asMap().keys];
  }

  //JSON to forward into download service
  Map getServiceSettings() {
    return {"json": jsonEncode(this.toJson())};
  }

  void updateUseArtColor(bool v) {
    useArtColor = v;
    if (v) {
      //On media item change set color
      _useArtColorSub = AudioService.currentMediaItemStream.listen((event) async {
        if (event == null || event.artUri == null) return;
        this.primaryColor = await imagesDatabase.getPrimaryColor(event.artUri);
        updateTheme();
      });
    } else {
      //Cancel stream subscription
      if (_useArtColorSub != null) {
        _useArtColorSub.cancel();
        _useArtColorSub = null;
      }
    }
  }

  SliderThemeData get _sliderTheme => SliderThemeData(
    thumbColor: primaryColor,
    activeTrackColor: primaryColor,
    inactiveTrackColor: primaryColor.withOpacity(0.2)
  );

  //Load settings/init
  Future<Settings> loadSettings() async {
    String path = await getPath();
    File f = File(path);
    if (await f.exists()) {
      String data = await f.readAsString();
      return Settings.fromJson(jsonDecode(data));
    }

  Settings s = Settings.fromJson({});
  // Set default path, because async
  final directory = await getExternalStorageDirectory();
  if (directory != null) {
    s.downloadPath = p.join(directory.path, 'Music');
  } else {
    // Handle the case where the directory is null
    // You might want to set a default path or throw an error
    s.downloadPath = '/storage/emulated/0/Music'; // Replace with your default path
  }
  s.save();
  return s;
}

  Future save() async {
    File f = File(await getPath());
    await f.writeAsString(jsonEncode(this.toJson()));
    downloadManager.updateServiceSettings();
  }

  Future updateAudioServiceQuality() async {
    //Send wifi & mobile quality to audio service isolate
    await AudioService.customAction('updateQuality', {
      'mobileQuality': getQualityInt(mobileQuality),
      'wifiQuality': getQualityInt(wifiQuality)
    });
  }

  //AudioQuality to deezer int
  int getQualityInt(AudioQuality q) {
    switch (q) {
      case AudioQuality.MP3_128: return 1;
      case AudioQuality.MP3_320: return 3;
      case AudioQuality.FLAC: return 9;
      //Deezer default
      default: return 8;
    }
  }

  //Check if is dark, can't use theme directly, because of system themes, and Theme.of(context).brightness broke
  bool get isDark {
    if (useSystemTheme) {
      if (SchedulerBinding.instance.window.platformBrightness == Brightness.light) return false;
      return true;
    }
    if (theme == Themes.Light) return false;
    return true;
  }

  static const deezerBg = Color(0xFF1F1A16);
  static const deezerBottom = Color(0xFF1b1714);
  TextTheme get _textTheme => (font == 'Deezer')
      ? null
      : GoogleFonts.getTextTheme(font, isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme);
  String get _fontFamily => (font == 'Deezer') ? 'MabryPro' : null;

  //Overrides for the non-deprecated buttons to look like the old ones
  OutlinedButtonThemeData get outlinedButtonTheme => OutlinedButtonThemeData(
    style: ButtonStyle(
      foregroundColor: MaterialStateProperty.all(isDark ? Colors.white : Colors.black),
    )
  );
  TextButtonThemeData get textButtonTheme => TextButtonThemeData(
    style: ButtonStyle(
      foregroundColor: MaterialStateProperty.all(isDark ? Colors.white : Colors.black),
    )
  );

  Map<Themes, ThemeData> get _themeData => {
    Themes.Light: ThemeData(
      textTheme: _textTheme,
      fontFamily: _fontFamily,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      accentColor: primaryColor,
      sliderTheme: _sliderTheme,
      toggleableActiveColor: primaryColor,
      bottomAppBarColor: Color(0xfff5f5f5),
      outlinedButtonTheme: outlinedButtonTheme,
      textButtonTheme: textButtonTheme
    ),
    Themes.Dark: ThemeData(
      textTheme: _textTheme,
      fontFamily: _fontFamily,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      accentColor: primaryColor,
      sliderTheme: _sliderTheme,
      toggleableActiveColor: primaryColor,
      outlinedButtonTheme: outlinedButtonTheme,
      textButtonTheme: textButtonTheme
    ),
    Themes.Deezer: ThemeData(
      textTheme: _textTheme,
      fontFamily: _fontFamily,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      accentColor: primaryColor,
      sliderTheme: _sliderTheme,
      toggleableActiveColor: primaryColor,
      backgroundColor: deezerBg,
      scaffoldBackgroundColor: deezerBg,
      bottomAppBarColor: deezerBottom,
      dialogBackgroundColor: deezerBottom,
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: deezerBottom
      ),
      cardColor: deezerBg,
      outlinedButtonTheme: outlinedButtonTheme,
      textButtonTheme: textButtonTheme
    ),
    Themes.Black: ThemeData(
      textTheme: _textTheme,
      fontFamily: _fontFamily,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      accentColor: primaryColor,
      backgroundColor: Colors.black,
      scaffoldBackgroundColor: Colors.black,
      bottomAppBarColor: Colors.black,
      dialogBackgroundColor: Colors.black,
      sliderTheme: _sliderTheme,
      toggleableActiveColor: primaryColor,
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.black,
      ),
      outlinedButtonTheme: outlinedButtonTheme,
      textButtonTheme: textButtonTheme
    )
  };

  Future<String> getPath() async => p.join((await getApplicationDocumentsDirectory()).path, 'settings.json');

  //JSON
  factory Settings.fromJson(Map<String, dynamic> json) => _$SettingsFromJson(json);
  Map<String, dynamic> toJson() => _$SettingsToJson(this);
}

enum AudioQuality {
  MP3_128,
  MP3_320,
  FLAC,
  ASK
}

enum Themes {
  Light,
  Dark,
  Deezer,
  Black
}

@JsonSerializable()
class SpotifyCredentialsSave {
  String accessToken;
  String refreshToken;
  List<String> scopes;
  DateTime expiration;

  SpotifyCredentialsSave({this.accessToken, this.refreshToken, this.scopes, this.expiration});

  //JSON
  factory SpotifyCredentialsSave.fromJson(Map<String, dynamic> json) => _$SpotifyCredentialsSaveFromJson(json);
  Map<String, dynamic> toJson() => _$SpotifyCredentialsSaveToJson(this);
}