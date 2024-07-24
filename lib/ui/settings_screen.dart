import 'package:audio_service/audio_service.dart';
import 'package:country_pickers/country.dart';
import 'package:country_pickers/country_picker_dialog.dart';
import 'package:filesize/filesize.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_material_color_picker/flutter_material_color_picker.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:fluttericon/web_symbols_icons.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:Saturn/api/cache.dart';
import 'package:Saturn/api/deezer.dart';
import 'package:Saturn/api/download.dart';
import 'package:Saturn/api/player.dart';
import 'package:Saturn/ui/downloads_screen.dart';
import 'package:Saturn/ui/elements.dart';
import 'package:Saturn/ui/error.dart';
import 'package:Saturn/ui/home_screen.dart';
import 'package:Saturn/ui/updater.dart';
import 'package:package_info/package_info.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:Saturn/translations.i18n.dart';
import 'package:clipboard/clipboard.dart';
import 'package:scrobblenaut/scrobblenaut.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';

import '../settings.dart';
import '../main.dart';

import 'dart:io';


class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: freezerAppBar('Settings'.i18n),
      body: ListView(
        children: <Widget>[
          ListTile(
            title: Text('General'.i18n),
            leading: LeadingIcon(Icons.settings, color: Color(0xffeca704)),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => GeneralSettings()
            )),
          ),
          ListTile(
            title: Text('Download Settings'.i18n),
            leading: LeadingIcon(Icons.cloud_download, color: Color(0xffbe3266)),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => DownloadsSettings()
            )),
          ),
          ListTile(
            title: Text('Appearance'.i18n),
            leading: LeadingIcon(Icons.color_lens, color: Color(0xff4b2e7e)),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AppearanceSettings())
            ),
          ),
          ListTile(
            title: Text('Quality'.i18n),
            leading: LeadingIcon(Icons.high_quality, color: Color(0xff384697)),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => QualitySettings())
            ),
          ),
          ListTile(
            title: Text('Deezer'.i18n),
            leading: LeadingIcon(Icons.equalizer, color: Color(0xff0880b5)),
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (context) => DeezerSettings()
            )),
          ),
          //Language select
          ListTile(
            title: Text('Language'.i18n),
            leading: LeadingIcon(Icons.language, color: Color(0xff009a85)),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => SimpleDialog(
                  title: Text('Select language'.i18n),
                  children: List.generate(languages.length, (int i) {
                    Language l = languages[i];
                    return ListTile(
                      title: Text(l.name),
                      subtitle: Text("${l.locale}-${l.country}"),
                      onTap: () async {
                        setState(() => settings.language = "${l.locale}_${l.country}");
                        await settings.save();
                        showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: Text('Language'.i18n),
                                content: Text('Language changed, please restart freezer to apply!'.i18n),
                                actions: [
                                  TextButton(
                                    child: Text('OK'),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      Navigator.of(context).pop();
                                    },
                                  )
                                ],
                              );
                            }
                        );
                      },
                    );
                  })
                )
              );
            },
          ),
          ListTile(
            title: Text('Updates'.i18n),
            leading: LeadingIcon(Icons.update, color: Color(0xff2ba766)),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (context) => UpdaterScreen()
            )),
          ),
          ListTile(
            title: Text('About'.i18n),
            leading: LeadingIcon(Icons.info, color: Colors.grey),
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (context) => CreditsScreen()
            )),
          ),
        ],
      ),
    );
  }
}

class AppearanceSettings extends StatefulWidget {
  @override
  _AppearanceSettingsState createState() => _AppearanceSettingsState();
}

class _AppearanceSettingsState extends State<AppearanceSettings> {


  ColorSwatch<dynamic> _swatch(int c) => ColorSwatch(c, {500: Color(c)});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: freezerAppBar('Appearance'.i18n),
      body: ListView(
        children: <Widget>[
          ListTile(
            title: Text('Theme'.i18n),
            subtitle: Text('Currently'.i18n + ': ${settings.theme.toString().split('.').last}'),
            leading: Icon(Icons.color_lens),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) {
                  return SimpleDialog(
                    title: Text('Select theme'.i18n),
                    children: <Widget>[
                      SimpleDialogOption(
                        child: Text('Light'.i18n),
                        onPressed: () {
                          setState(() => settings.theme = Themes.Light);
                          settings.save();
                          updateTheme();
                          Navigator.of(context).pop();
                        },
                      ),
                      SimpleDialogOption(
                        child: Text('Dark'.i18n),
                        onPressed: () {
                          setState(() => settings.theme = Themes.Dark);
                          settings.save();
                          updateTheme();
                          Navigator.of(context).pop();
                        },
                      ),
                      SimpleDialogOption(
                        child: Text('Black (AMOLED)'.i18n),
                        onPressed: () {
                          setState(() => settings.theme = Themes.Black);
                          settings.save();
                          updateTheme();
                          Navigator.of(context).pop();
                        },
                      ),
                      SimpleDialogOption(
                        child: Text('Deezer (Dark)'.i18n),
                        onPressed: () {
                          setState(() => settings.theme = Themes.Deezer);
                          settings.save();
                          updateTheme();
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  );
                }
              );
            },
          ),
          ListTile(
            title: Text('Use system theme'.i18n),
            trailing: Switch(
              value: settings.useSystemTheme,
              onChanged: (bool v) async {
                setState(() {
                  settings.useSystemTheme = v;
                });
                updateTheme();
                await settings.save();
              },
            ),
            leading: Icon(Icons.android)
          ),
          ListTile(
            title: Text('Font'.i18n),
            leading: Icon(Icons.font_download),
            subtitle: Text(settings.font),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => FontSelector(() => Navigator.of(context).pop())
              );
            },
          ),
          ListTile(
            title: Text('Player gradient background'.i18n),
            leading: Icon(Icons.colorize),
            trailing: Switch(
              value: settings.colorGradientBackground,
              onChanged: (bool v) async {
                setState(() => settings.colorGradientBackground = v);
                await settings.save();
              },
            ),
          ),
          ListTile(
            title: Text('Blur player background'.i18n),
            subtitle: Text('Might have impact on performance'.i18n),
            leading: Icon(Icons.blur_on),
            trailing: Switch(
              value: settings.blurPlayerBackground,
              onChanged: (bool v) async {
                setState(() => settings.blurPlayerBackground = v);
                await settings.save();
              },
            ),
          ),
          ListTile(
            title: Text('Visualizer'.i18n),
            subtitle: Text('Show visualizers on lyrics page. WARNING: Requires microphone permission and may be buggy!'.i18n),
            leading: Icon(Icons.equalizer),
            trailing: Switch(
              value: settings.lyricsVisualizer,
              onChanged: (bool v) async {
                if (await Permission.microphone.request().isGranted) {
                  setState(() => settings.lyricsVisualizer = v);
                  await settings.save();
                  return;
                }
              },
            ),
          ),
          ListTile(
            title: Text('Primary color'.i18n),
            leading: Icon(Icons.format_paint),
            subtitle: Text(
              'Selected color'.i18n,
              style: TextStyle(
                color: settings.primaryColor
              ),
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: Text('Primary color'.i18n),
                    content: Container(
                      height: 240,
                      child: MaterialColorPicker(
                        colors: [
                          ...Colors.primaries,
                          //Logo colors
                          _swatch(0xffeca704),
                          _swatch(0xffbe3266),
                          _swatch(0xff4b2e7e),
                          _swatch(0xff384697),
                          _swatch(0xff0880b5),
                          _swatch(0xff009a85),
                          _swatch(0xff2ba766)
                        ],
                        allowShades: false,
                        selectedColor: settings.primaryColor,
                        onMainColorChange: (ColorSwatch color) {
                          setState(() {
                            settings.primaryColor = color;
                          });
                          settings.save();
                          updateTheme();
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  );
                }
              );
            },
          ),
          ListTile(
            title: Text('Use album art primary color'.i18n),
            subtitle: Text('Warning: might be buggy'.i18n),
            leading: Icon(Icons.invert_colors),
            trailing: Switch(
              value: settings.useArtColor,
              onChanged: (v) => setState(() => settings.updateUseArtColor(v)),
            ),
          ),
          //Display mode
          ListTile(
            leading: Icon(Icons.screen_lock_portrait),
            title: Text('Change display mode'.i18n),
            subtitle: Text('Enable high refresh rates'.i18n),
            onTap: () async {
              List modes = await FlutterDisplayMode.supported;
              showDialog(
                context: context,
                builder: (context) {
                  return SimpleDialog(
                    title: Text('Display mode'.i18n),
                    children: List.generate(modes.length, (i) => SimpleDialogOption(
                      child: Text(modes[i].toString()),
                      onPressed: () async {
                        settings.displayMode = i;
                        await settings.save();
                        await FlutterDisplayMode.setPreferredMode(modes[i]);
                        Navigator.of(context).pop();
                      },
                    ))
                  );
                }
              );
            },
          )
        ],
      ),
    );
  }
}

class FontSelector extends StatefulWidget {
  final Function callback;

  FontSelector(this.callback, {Key key}): super(key: key);

  @override
  _FontSelectorState createState() => _FontSelectorState();
}

class _FontSelectorState extends State<FontSelector> {

  String query = '';
  List<String> get fonts {
    return settings.fonts.where((f) => f.toLowerCase().contains(query)).toList();
  }

  //Font selected
  void onTap(String font) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Warning'.i18n),
        content: Text("This app isn't made for supporting many fonts, it can break layouts and overflow. Use at your own risk!".i18n),
        actions: [
          TextButton(
            onPressed: () async {
              setState(() => settings.font = font);
              await settings.save();
              Navigator.of(context).pop();
              widget.callback();
              //Global setState
              updateTheme();
            },
            child: Text('Apply'.i18n),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.callback();
            },
            child: Text('Cancel'),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text("Select font".i18n),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: TextField(
            cursorColor: Theme.of(context).primaryColor,
            decoration: InputDecoration(
              hintText: 'Search'.i18n,
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Theme.of(context).primaryColor), // Color of the underline when focused
              ),
            ),
            onChanged: (q) => setState(() => query = q),
          ),
        ),
        ...List.generate(fonts.length, (i) => SimpleDialogOption(
          child: Text(fonts[i]),
          onPressed: () => onTap(fonts[i]),
        ))
      ],
    );
  }
}



class QualitySettings extends StatefulWidget {
  @override
  _QualitySettingsState createState() => _QualitySettingsState();
}

class _QualitySettingsState extends State<QualitySettings> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: freezerAppBar('Quality'.i18n),
      body: ListView(
        children: <Widget>[
          ListTile(
            title: Text('Mobile streaming'.i18n),
            leading: LeadingIcon(Icons.network_cell, color: Color(0xff384697)),
          ),
          QualityPicker('mobile'),
          freezerDivider(),
          ListTile(
            title: Text('Wifi streaming'.i18n),
            leading: LeadingIcon(Icons.network_wifi, color: Color(0xff0880b5)),
          ),
          QualityPicker('wifi'),
          freezerDivider(),
          ListTile(
            title: Text('Offline'.i18n),
            leading: LeadingIcon(Icons.offline_pin, color: Color(0xff009a85)),
          ),
          QualityPicker('offline'),
          freezerDivider(),
          ListTile(
            title: Text('External downloads'.i18n),
            leading: LeadingIcon(Icons.file_download, color: Color(0xff2ba766)),
          ),
          QualityPicker('download'),
        ],
      ),
    );
  }
}

class QualityPicker extends StatefulWidget {

  final String field;
  QualityPicker(this.field, {Key key}): super(key: key);

  @override
  _QualityPickerState createState() => _QualityPickerState();
}

class _QualityPickerState extends State<QualityPicker> {

  AudioQuality _quality;

  @override
  void initState() {
    _getQuality();
    super.initState();
  }

  //Get current quality
  void _getQuality() {
    switch (widget.field) {
      case 'mobile':
        _quality = settings.mobileQuality; break;
      case 'wifi':
        _quality = settings.wifiQuality; break;
      case 'download':
        _quality = settings.downloadQuality; break;
      case 'offline':
        _quality = settings.offlineQuality; break;
    }
  }

  //Update quality in settings
  void _updateQuality(AudioQuality q) async {
    setState(() {
      _quality = q;
    });
    switch (widget.field) {
      case 'mobile':
        settings.mobileQuality = _quality;
        settings.updateAudioServiceQuality();
        break;
      case 'wifi':
        settings.wifiQuality = _quality;
        settings.updateAudioServiceQuality();
        break;
      case 'download':
        settings.downloadQuality = _quality; break;
      case 'offline':
        settings.offlineQuality = _quality; break;
    }
    await settings.save();
    await settings.updateAudioServiceQuality();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        ListTile(
          title: Text('MP3 128kbps'),
          leading: Radio(
            groupValue: _quality,
            value: AudioQuality.MP3_128,
            onChanged: (q) => _updateQuality(q),
          ),
        ),
        ListTile(
          title: Text('MP3 320kbps'),
          leading: Radio(
            groupValue: _quality,
            value: AudioQuality.MP3_320,
            onChanged: (q) => _updateQuality(q),
          ),
        ),
        ListTile(
          title: Text('FLAC'),
          leading: Radio(
            groupValue: _quality,
            value: AudioQuality.FLAC,
            onChanged: (q) => _updateQuality(q),
          ),
        ),
        if (widget.field == 'download')
          ListTile(
            title: Text('Ask before downloading'.i18n),
            leading: Radio(
              groupValue: _quality,
              value: AudioQuality.ASK,
              onChanged: (q) => _updateQuality(q),
            )
          )
      ],
    );
  }
}

class ContentLanguage {
  String code;
  String name;
  ContentLanguage(this.code, this.name);

  static List<ContentLanguage> get all => [
    ContentLanguage("cs", "Čeština"),
    ContentLanguage("da", "Dansk"),
    ContentLanguage("de", "Deutsch"),
    ContentLanguage("en", "English"),
    ContentLanguage("us", "English (us)"),
    ContentLanguage("es", "Español"),
    ContentLanguage("mx", "Español (latam)"),
    ContentLanguage("fr", "Français"),
    ContentLanguage("hr", "Hrvatski"),
    ContentLanguage("id", "Indonesia"),
    ContentLanguage("it", "Italiano"),
    ContentLanguage("hu", "Magyar"),
    ContentLanguage("ms", "Melayu"),
    ContentLanguage("nl", "Nederlands"),
    ContentLanguage("no", "Norsk"),
    ContentLanguage("pl", "Polski"),
    ContentLanguage("br", "Português (br)"),
    ContentLanguage("pt", "Português (pt)"),
    ContentLanguage("ro", "Română"),
    ContentLanguage("sk", "Slovenčina"),
    ContentLanguage("sl", "Slovenščina"),
    ContentLanguage("sq", "Shqip"),
    ContentLanguage("sr", "Srpski"),
    ContentLanguage("fi", "Suomi"),
    ContentLanguage("sv", "Svenska"),
    ContentLanguage("tr", "Türkçe"),
    ContentLanguage("bg", "Български"),
    ContentLanguage("ru", "Pусский"),
    ContentLanguage("uk", "Українська"),
    ContentLanguage("he", "עִברִית"),
    ContentLanguage("ar", "العربیة"),
    ContentLanguage("cn", "中文"),
    ContentLanguage("ja", "日本語"),
    ContentLanguage("ko", "한국어"),
    ContentLanguage("th", "ภาษาไทย"),
  ];
}

class DeezerSettings extends StatefulWidget {
  @override
  _DeezerSettingsState createState() => _DeezerSettingsState();
}

class _DeezerSettingsState extends State<DeezerSettings> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: freezerAppBar('Deezer'.i18n),
      body: ListView(
        children: <Widget>[
          ListTile(
            title: Text('Content language'.i18n),
            subtitle: Text('Not app language, used in headers. Now'.i18n + ': ${settings.deezerLanguage}'),
            leading: Icon(Icons.language),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => SimpleDialog(
                  title: Text('Select language'.i18n),
                  children: List.generate(ContentLanguage.all.length, (i) => ListTile(
                    title: Text(ContentLanguage.all[i].name),
                    subtitle: Text(ContentLanguage.all[i].code),
                    onTap: () async {
                      setState(() => settings.deezerLanguage = ContentLanguage.all[i].code);
                      await settings.save();
                      Navigator.of(context).pop();
                    },
                  )),
                )
              );
            },
          ),
          ListTile(
            title: Text('Content country'.i18n),
            subtitle: Text('Country used in headers. Now'.i18n + ': ${settings.deezerCountry}'),
            leading: Icon(Icons.vpn_lock),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => CountryPickerDialog(
                  titlePadding: EdgeInsets.all(8.0),
                  isSearchable: true,
                  onValuePicked: (Country country) {
                    setState(() => settings.deezerCountry = country.isoCode);
                    settings.save();
                  },
                )
              );
            },
          ),
          ListTile(
            title: Text('Log tracks'.i18n),
            subtitle: Text('Send track listen logs to Deezer, enable it for features like Flow to work properly'.i18n),
            trailing: Switch(
              value: settings.logListen,
              onChanged: (bool v) {
                setState(() => settings.logListen = v);
                settings.save();
              },
            ),
            leading: Icon(Icons.history_toggle_off),
          ),
          //TODO: Reimplement proxy
//          ListTile(
//            title: Text('Proxy'.i18n),
//            leading: Icon(Icons.vpn_key),
//            subtitle: Text(settings.proxyAddress??'Not set'.i18n),
//            onTap: () {
//              String _new;
//              showDialog(
//                context: context,
//                builder: (BuildContext context) {
//                  return AlertDialog(
//                    title: Text('Proxy'.i18n),
//                    content: TextField(
//                      onChanged: (String v) => _new = v,
//                      decoration: InputDecoration(
//                        hintText: 'IP:PORT'
//                      ),
//                    ),
//                    actions: [
//                      TextButton(
//                        child: Text('Cancel'.i18n),
//                        onPressed: () => Navigator.of(context).pop(),
//                      ),
//                      TextButton(
//                        child: Text('Reset'.i18n),
//                        onPressed: () async {
//                          setState(() {
//                            settings.proxyAddress = null;
//                          });
//                          await settings.save();
//                          Navigator.of(context).pop();
//                        },
//                      ),
//                      TextButton(
//                        child: Text('Save'.i18n),
//                        onPressed: () async {
//                          setState(() {
//                            settings.proxyAddress = _new;
//                          });
//                          await settings.save();
//                          Navigator.of(context).pop();
//                        },
//                      )
//                    ],
//                  );
//                }
//              );
//            },
//          )
        ],
      ),
    );
  }
}

class FilenameTemplateDialog extends StatefulWidget {

  final String initial;
  final Function onSave;
  FilenameTemplateDialog(this.initial, this.onSave, {Key key}): super(key: key);

  @override
  _FilenameTemplateDialogState createState() => _FilenameTemplateDialogState();
}

class _FilenameTemplateDialogState extends State<FilenameTemplateDialog> {

  TextEditingController _controller;
  String _new;

  @override
  void initState() {
    _controller = TextEditingController(text: widget.initial);
    _new = _controller.value.text;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    //Dialog with filename format
    return AlertDialog(
      title: Text('Downloaded tracks filename'.i18n),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            cursorColor: Theme.of(context).primaryColor,
            controller: _controller,
            onChanged: (String s) => _new = s,
            decoration: InputDecoration(
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Theme.of(context).primaryColor), // Color of the underline when focused
              ),
            ),
          ),
          Container(height: 8.0),
          Text(
            'Valid variables are'.i18n + ': %artists%, %artist%, %title%, %album%, %trackNumber%, %0trackNumber%, %feats%, %playlistTrackNumber%, %0playlistTrackNumber%, %year%, %date%\n\n' +
                "If you want to use custom directory naming - use '/' as directory separator.".i18n,
            style: TextStyle(
              fontSize: 12.0,
            ),
          )
        ],
      ),
      actions: [
        TextButton(
          child: Text('Cancel'.i18n),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: Text('Reset'.i18n),
          onPressed: () {
            _controller.value = _controller.value.copyWith(text: '%artist% - %title%');
            _new = '%artist% - %title%';
          },
        ),
        TextButton(
          child: Text('Clear'.i18n),
          onPressed: () => _controller.clear(),
        ),
        TextButton(
          child: Text('Save'.i18n),
          onPressed: () async {
            widget.onSave(_new);
            Navigator.of(context).pop();
          },
        )
      ],
    );
  }
}


class DownloadsSettings extends StatefulWidget {
  @override
  _DownloadsSettingsState createState() => _DownloadsSettingsState();
}

class _DownloadsSettingsState extends State<DownloadsSettings> {

  double _downloadThreads = settings.downloadThreads.toDouble();
  TextEditingController _artistSeparatorController = TextEditingController(text: settings.artistSeparator);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: freezerAppBar('Download Settings'.i18n),
      body: ListView(
        children: [
          ListTile(
            title: Text('Download path'.i18n),
            leading: Icon(Icons.folder),
            subtitle: Text(settings.downloadPath),
            onTap: () async {
              //Check permissions
              if (!(await Permission.storage.request().isGranted)) return;
              //Navigate
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => DirectoryPicker(settings.downloadPath, onSelect: (String p) async {
                    setState(() => settings.downloadPath = p);
                    await settings.save();
                  },)
              ));
            },
          ),
          ListTile(
            title: Text('Downloads naming'.i18n),
            subtitle: Text('Currently'.i18n + ': ${settings.downloadFilename}'),
            leading: Icon(Icons.text_format),
            onTap: () {
              showDialog(
                  context: context,
                  builder: (context) {
                    return FilenameTemplateDialog(settings.downloadFilename, (f) async {
                      setState(() => settings.downloadFilename = f);
                      await settings.save();
                    });
                  }
              );
            },
          ),
          ListTile(
            title: Text('Singleton naming'.i18n),
            subtitle: Text('Currently'.i18n + ': ${settings.singletonFilename}'),
            leading: Icon(Icons.text_format),
            onTap: () {
              showDialog(
                  context: context,
                  builder: (context) {
                    return FilenameTemplateDialog(settings.singletonFilename, (f) async {
                      setState(() => settings.singletonFilename = f);
                      await settings.save();
                    });
                  }
              );
            },
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Download threads'.i18n + ': ${_downloadThreads.round().toString()}',
              style: TextStyle(
                fontSize: 16.0
              ),
            ),
          ),
          Slider(
            min: 1,
            max: 16,
            divisions: 15,
            value: _downloadThreads,
            label: _downloadThreads.round().toString(),
            onChanged: (double v) => setState(() => _downloadThreads = v),
            onChangeEnd: (double val) async {
              _downloadThreads = val;
              setState(() {
                settings.downloadThreads = _downloadThreads.round();
                _downloadThreads = settings.downloadThreads.toDouble();
              });
              await settings.save();

              //Prevent null
              if (val > 8 && cache.threadsWarning != true) {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text('Warning'.i18n),
                      content: Text('Using too many concurrent downloads on older/weaker devices might cause crashes!'.i18n),
                      actions: [
                        TextButton(
                          child: Text('Dismiss'.i18n),
                          onPressed: () => Navigator.of(context).pop(),
                        )
                      ],
                    );
                  }
                );

                cache.threadsWarning = true;
                await cache.save();
              }
            }
          ),
          freezerDivider(),
          ListTile(
            title: Text('Tags'.i18n),
            leading: Icon(Icons.label),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => TagSelectionScreen()
            )),
          ),
          ListTile(
            title: Text('Create folders for artist'.i18n),
            trailing: Switch(
              value: settings.artistFolder,
              onChanged: (v) {
                setState(() => settings.artistFolder = v);
                settings.save();
              },
            ),
            leading: Icon(Icons.folder),
          ),
          ListTile(
            title: Text('Create folders for albums'.i18n),
            trailing: Switch(
              value: settings.albumFolder,
              onChanged: (v) {
                setState(() => settings.albumFolder = v);
                settings.save();
              },
            ),
            leading: Icon(Icons.folder)
          ),
          ListTile(
            title: Text('Create folder for playlist'.i18n),
            trailing: Switch(
              value: settings.playlistFolder,
              onChanged: (v) {
                setState(() => settings.playlistFolder = v);
                settings.save();
              },
            ),
            leading: Icon(Icons.folder)
          ),
          freezerDivider(),
          ListTile(
            title: Text('Separate albums by discs'.i18n),
            trailing: Switch(
              value: settings.albumDiscFolder,
              onChanged: (v) {
                setState(() => settings.albumDiscFolder = v);
                settings.save();
              },
            ),
            leading: Icon(Icons.album)
          ),
          ListTile(
            title: Text('Overwrite already downloaded files'.i18n),
            trailing: Switch(
              value: settings.overwriteDownload,
              onChanged: (v) {
                setState(() => settings.overwriteDownload = v);
                settings.save();
              },
            ),
            leading: Icon(Icons.delete)
          ),
          ListTile(
            title: Text('Download .LRC lyrics'.i18n),
            trailing: Switch(
              value: settings.downloadLyrics,
              onChanged: (v) {
                setState(() => settings.downloadLyrics = v);
                settings.save();
              },
            ),
            leading: Icon(Icons.subtitles)
          ),
          freezerDivider(),
          ListTile(
            title: Text('Save cover file for every track'.i18n),
            trailing: Switch(
              value: settings.trackCover,
              onChanged: (v) {
                setState(() => settings.trackCover = v);
                settings.save();
              },
            ),
            leading: Icon(Icons.image)
          ),
          ListTile(
            title: Text('Save album cover'.i18n),
            trailing: Switch(
              value: settings.albumCover,
              onChanged: (v) {
                setState(() => settings.albumCover = v);
                settings.save();
              },
            ),
            leading: Icon(Icons.image)
          ),
          ListTile(
            title: Text('Album cover resolution'.i18n),
            subtitle: Text("WARNING: Resolutions above 1200 aren't officially supported".i18n),
            leading: Icon(Icons.image),
            trailing: Container(
              width: 75.0,
              child: DropdownButton<int>(
                value: settings.albumArtResolution,
                items: [400, 800, 1000, 1200, 1400, 1600, 1800].map<DropdownMenuItem<int>>((int i) => DropdownMenuItem<int>(
                  value: i,
                  child: Text(i.toString()),
                )).toList(),
                onChanged: (int n) async {
                  setState(() {
                    settings.albumArtResolution = n;
                  });
                  await settings.save();
                },
              )
            )
          ),
          ListTile(
            title: Text('Create .nomedia files'.i18n),
            subtitle: Text('To prevent gallery being filled with album art'.i18n),
            trailing: Switch(
              value: settings.nomediaFiles,
              onChanged: (v) {
                setState(() => settings.nomediaFiles = v);
                settings.save();
              },
            ),
            leading: Icon(Icons.insert_drive_file)
          ),
          ListTile(
            title: Text('Artist separator'.i18n),
            leading: Icon(WebSymbols.tag),
            trailing: Container(
              width: 75.0,
              child: TextField(
                cursorColor: Theme.of(context).primaryColor,
                controller: _artistSeparatorController,
                onChanged: (s) async {
                  settings.artistSeparator = s;
                  await settings.save();
                },
                decoration: InputDecoration(
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(context).primaryColor), // Color of the underline when focused
                  ),
                ),
              ),
            ),
          ),
          freezerDivider(),
          ListTile(
            title: Text('Download Log'.i18n),
            leading: Icon(Icons.sticky_note_2),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => DownloadLogViewer())
            ),
          )
        ],
      ),
    );
  }
}

class TagOption {
  String title;
  String value;
  TagOption(this.title, this.value);
}

class TagSelectionScreen extends StatefulWidget {
  @override
  _TagSelectionScreenState createState() => _TagSelectionScreenState();
}

class _TagSelectionScreenState extends State<TagSelectionScreen> {

  List<TagOption> tags = [
    TagOption("Title".i18n, 'title'),
    TagOption("Album".i18n, 'album'),
    TagOption('Artist'.i18n, 'artist'),
    TagOption('Track number'.i18n, 'track'),
    TagOption('Disc number'.i18n, 'disc'),
    TagOption('Album artist'.i18n, 'albumArtist'),
    TagOption('Date/Year'.i18n, 'date'),
    TagOption('Label'.i18n, 'label'),
    TagOption('ISRC'.i18n, 'isrc'),
    TagOption('UPC'.i18n, 'upc'),
    TagOption('Track total'.i18n, 'trackTotal'),
    TagOption('BPM'.i18n, 'bpm'),
    TagOption('Unsynchronized lyrics'.i18n, 'lyrics'),
    TagOption('Genre'.i18n, 'genre'),
    TagOption('Contributors'.i18n, 'contributors'),
    TagOption('Album art'.i18n, 'art')
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: freezerAppBar('Tags'.i18n),
      body: ListView(
        children: List.generate(tags.length, (i) => ListTile(
          title: Text(tags[i].title),
          leading: Switch(
            value: settings.tags.contains(tags[i].value),
            onChanged: (v) async {
              //Update
              if (v) settings.tags.add(tags[i].value);
              else settings.tags.remove(tags[i].value);
              setState((){});
              await settings.save();
            },
          ),
        )),
      ),
    );
  }
}



class GeneralSettings extends StatefulWidget {
  @override
  _GeneralSettingsState createState() => _GeneralSettingsState();
}

class _GeneralSettingsState extends State<GeneralSettings> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: freezerAppBar('General'.i18n),
      body: ListView(
        children: <Widget>[
          ListTile(
            title: Text('Offline mode'.i18n),
            subtitle: Text('Will be overwritten on start.'.i18n),
            trailing: Switch(
              value: settings.offlineMode,
              onChanged: (bool v) {
                if (v) {
                  setState(() => settings.offlineMode = true);
                  return;
                }
                showDialog(
                    context: context,
                    builder: (context) {
                      deezerAPI.authorize().then((v) {
                        if (v) {
                          setState(() => settings.offlineMode = false);
                        } else {
                          Fluttertoast.showToast(
                              msg: 'Error logging in, check your internet connections.'.i18n,
                              gravity: ToastGravity.BOTTOM,
                              toastLength: Toast.LENGTH_SHORT
                          );
                        }
                        Navigator.of(context).pop();
                      });
                      return AlertDialog(
                          title: Text('Logging in...'.i18n),
                          content: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              CircularProgressIndicator(color: Theme.of(context).primaryColor,)
                            ],
                          )
                      );
                    }
                );
              },
            ),
            leading: Icon(Icons.lock),
          ),
          ListTile(
            title: Text('Copy ARL'.i18n),
            subtitle: Text('Copy userToken/ARL Cookie for use in other apps.'.i18n),
            leading: Icon(Icons.lock),
            onTap: () async {
              await FlutterClipboard.copy(settings.arl);
              await Fluttertoast.showToast(
                msg: 'Copied'.i18n,
              );
            },
          ),
          ListTile(
            title: Text('Enable equalizer'.i18n),
            subtitle: Text('Might enable some equalizer apps to work. Requires restart of freezer'.i18n),
            leading: Icon(Icons.equalizer),
            trailing: Switch(
              value: settings.enableEqualizer,
              onChanged: (v) async {
                setState(() => settings.enableEqualizer = v);
                settings.save();
              },
            ),
          ),
          ListTile(
            title: Text('LastFM'.i18n),
            subtitle: Text(
                (settings.lastFMPassword != null && settings.lastFMUsername != null)
                ? 'Log out'.i18n
                : 'Login to enable scrobbling.'.i18n
            ),
            leading: Icon(FontAwesome5.lastfm),
            onTap: () async {
              //Log out
              if (settings.lastFMPassword != null && settings.lastFMUsername != null) {
                settings.lastFMUsername = null;
                settings.lastFMPassword = null;
                await settings.save();
                await AudioService.customAction("disableLastFM");
                setState(() {});
                Fluttertoast.showToast(msg: 'Logged out!'.i18n);
                return;
              }
              await showDialog(
                context: context,
                builder: (context) => LastFMLogin()
              );
              setState(() {});
            },
          ),
          ListTile(
            title: Text('LastFM API Key'.i18n),
            leading: Icon(Icons.key),
            trailing: Container(
              width: 75.0,
              child: TextField(
                cursorColor: Theme.of(context).primaryColor,
                onChanged: (s) async {
                  settings.lastFMAPIKey = s;
                  await settings.save();
                },
                  decoration: InputDecoration(
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(context).primaryColor), // Color of the underline when focused
                  ),
                ),
              ),
            ),
          ),
          ListTile(
            title: Text('LastFM API Secret'.i18n),
            leading: Icon(Icons.warning),
            trailing: Container(
              width: 75.0,
              child: TextField(
                cursorColor: Theme.of(context).primaryColor,
                onChanged: (s) async {
                  settings.lastFMAPISecret = s;
                  await settings.save();
                },
                  decoration: InputDecoration(
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(context).primaryColor), // Color of the underline when focused
                  ),
                ),
              ),
            ),
          ),
          ListTile(
            title: Text('Log out'.i18n, style: TextStyle(color: Colors.red),),
            leading: Icon(Icons.exit_to_app),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: Text('Log out'.i18n),
//                    content: Text('Due to plugin incompatibility, login using browser is unavailable without restart.'.i18n),
                    content: Text('Restart of app is required to properly log out!'.i18n),
                    actions: <Widget>[
                      TextButton(
                        child: Text('Cancel'.i18n),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
//                      TextButton(
//                        child: Text('(ARL ONLY) Continue'.i18n),
//                        onPressed: () async {
//                          await logOut();
//                          Navigator.of(context).pop();
//                        },
//                      ),
                      TextButton(
                        child: Text('Log out & Exit'.i18n),
                        onPressed: () async {
                          try {AudioService.stop();} catch (e) {}
                          await logOut();
                          await DownloadManager.platform.invokeMethod("kill");
                          SystemNavigator.pop();
                        },
                      )
                    ],
                  );
                }
              );
            }
          ),
          ListTile(
            title: Text('Ignore interruptions'.i18n),
            subtitle: Text('Requires app restart to apply!'.i18n),
            leading: Icon(Icons.not_interested),
            trailing: Switch(
              value: settings.ignoreInterruptions,
              onChanged: (bool v) async {
                setState(() => settings.ignoreInterruptions = v);
                await settings.save();
              },
            ),
          )
        ],
      ),
    );
  }
}

class LastFMLogin extends StatefulWidget {
  @override
  _LastFMLoginState createState() => _LastFMLoginState();
}

class _LastFMLoginState extends State<LastFMLogin> {

  String _username = '';
  String _password = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Login to LastFM'.i18n),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            cursorColor: Theme.of(context).primaryColor,
            decoration: InputDecoration(
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Theme.of(context).primaryColor), // Color of the underline when focused
              ),
              hintText: 'Username'.i18n
            ),
            onChanged: (v) => _username = v,
          ),
          Container(height: 8.0),
          TextField(
            cursorColor: Theme.of(context).primaryColor,
            obscureText: true,
            decoration: InputDecoration(
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Theme.of(context).primaryColor), // Color of the underline when focused
              ),
              hintText: 'Password'.i18n
            ),
            onChanged: (v) => _password = v,
          )
        ],
      ),
      actions: [
        TextButton(
          child: Text('Cancel'.i18n),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: Text('Login'.i18n),
          onPressed: () async {
            LastFM last;
            try {
              last = await LastFM.authenticate(
                  apiKey: 'b6ab5ae967bcd8b10b23f68f42493829',
                  apiSecret: '861b0dff9a8a574bec747f9dab8b82bf',
                  username: _username,
                  password: _password
              );
            } catch (e) {
              Fluttertoast.showToast(msg: 'Authorization error!'.i18n);
              return;
            }
            //Save
            settings.lastFMUsername = last.username;
            settings.lastFMPassword = last.passwordHash;
            await settings.save();
            await playerHelper.authorizeLastFM();
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}


class DirectoryPicker extends StatefulWidget {

  final String initialPath;
  final Function onSelect;
  DirectoryPicker(this.initialPath, {this.onSelect, Key key}): super(key: key);

  @override
  _DirectoryPickerState createState() => _DirectoryPickerState();
}

class _DirectoryPickerState extends State<DirectoryPicker> {

  String _path;
  String _previous;
  String _root;

  @override
  void initState() {
    _path = widget.initialPath;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: freezerAppBar(
        'Pick-a-Path'.i18n,
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.done),
        onPressed: () {
          //When folder confirmed
          if (widget.onSelect != null) widget.onSelect(_path);
          Navigator.of(context).pop();
        },
      ),
      body: FutureBuilder(
        future: Directory(_path).list().toList(),
        builder: (BuildContext context, AsyncSnapshot snapshot) {

          //On error go to last good path
          if (snapshot.hasError) Future.delayed(Duration(milliseconds: 50), () {
            if (_previous == null) {
              return;
            }
            setState(() => _path = _previous);
          });
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor,),);

          List<FileSystemEntity> data = snapshot.data;
          return ListView(
            children: <Widget>[
              ListTile(
                title: Text(_path),
              ),
              ListTile(
                title: Text('Go up'.i18n),
                leading: Icon(Icons.arrow_upward),
                onTap: () {
                  setState(() {
                    if (_root == _path) {
                      Fluttertoast.showToast(
                          msg: 'Permission denied'.i18n,
                          gravity: ToastGravity.BOTTOM
                      );
                      return;
                    }
                    _previous = _path;
                    _path = Directory(_path).parent.path;
                  });
                },
              ),
              ...List.generate(data.length, (i) {
                FileSystemEntity f = data[i];
                if (f is Directory) {
                  return ListTile(
                    title: Text(f.path.split('/').last),
                    leading: Icon(Icons.folder),
                    onTap: () {
                      setState(() {
                        _previous = _path;
                        _path = f.path;
                      });
                    },
                  );
                }
                return Container(height: 0, width: 0,);
              })
            ],
          );
        },
      ),
    );
  }
}

class CreditsScreen extends StatefulWidget {
  @override
  _CreditsScreenState createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {

  String _version = '';

  @override
  void initState() {
    PackageInfo.fromPlatform().then((info) {
      setState(() {
        _version = 'v${info.version}';
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: freezerAppBar('About'.i18n),
      body: ListView(
        children: [
          freezerTitle(),
          Text(
            _version,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontStyle: FontStyle.italic
            ),
          ),
          freezerDivider(),
          ListTile(
            title: Text('Telegram Channel'.i18n),
            subtitle: Text('To get latest releases'.i18n),
            leading: Icon(FontAwesome5.telegram, color: Color(0xFF27A2DF), size: 36.0),
            onTap: () {
              launch('https://t.me/SaturnReleases');
            },
          ),
          ListTile(
            title: Text('Telegram Group'.i18n),
            subtitle: Text('Official chat'.i18n),
            leading: Icon(FontAwesome5.telegram, color: Colors.cyan, size: 36.0),
            onTap: () {
              launch('https://t.me/SaturnDiscuss');
            },
          ),
          ListTile(
            title: Text('Discord'.i18n),
            subtitle: Text('Official Discord server'.i18n),
            leading: Icon(FontAwesome5.discord, color: Color(0xff7289da), size: 36.0),
            onTap: () {
              launch('https://saturnclient.dev/discord');
            },
          ),
          ListTile(
            title: Text('Repository'.i18n),
            subtitle: Text('Source code, report issues there.'.i18n),
            leading: Icon(Icons.code, color: Colors.green, size: 36.0),
            onTap: () {
              launch('https://github.com/SaturnMusic/Mobile');
            },
          ),
          ListTile(
            title: Text('Donate'),
            subtitle: Text('Send crypto to the Saturn fund to support the development.'),
            leading: Icon(FontAwesome5.bitcoin, color: Color.fromRGBO(247,147,26, 58), size: 36.0),
            onTap: () {
              launch('https://fund.saturnclient.dev/');
            },
          ),
          freezerDivider(),
          ListTile(
            title: Text('bw86'),
            subtitle: Text('Logo Designer, Developer'),
          ),
          ListTile(
            title: Text('Matt'),
            subtitle: Text('Developer'),
          ),
          ListTile(
            title: Text('ettex, Xander Null, Francesco, Tobs'),
            subtitle: Text('Original Freezer App'),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(0, 4, 0, 8),
            child: Text(
              'Translations provided by Crowdin supporters of the original Freezer app'.i18n,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.0
              ),
            ),
          )
        ],
      ),
    );
  }
}