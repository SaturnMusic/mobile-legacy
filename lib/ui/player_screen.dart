import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:Saturn/api/cache.dart';
import 'package:Saturn/api/deezer.dart';
import 'package:Saturn/api/download.dart';
import 'package:Saturn/api/player.dart';
import 'package:Saturn/settings.dart';
import 'package:Saturn/translations.i18n.dart';
import 'package:Saturn/ui/elements.dart';
import 'package:Saturn/ui/lyrics.dart';
import 'package:Saturn/ui/menu.dart';
import 'package:Saturn/ui/settings_screen.dart';
import 'package:Saturn/ui/tiles.dart';
import 'package:async/async.dart';
import 'package:just_audio/just_audio.dart';
import 'package:marquee/marquee.dart';
import 'package:palette_generator/palette_generator.dart';

import 'cached_image.dart';
import '../api/definitions.dart';
import 'player_bar.dart';

import 'dart:ui';
import 'dart:convert';
import 'dart:async';

//Changing item in queue view and pressing back causes the pageView to skip song
bool pageViewLock = false;

//So can be updated when going back from lyrics
Function updateColor;

class PlayerScreen extends StatefulWidget {
  @override
  _PlayerScreenState createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {

  LinearGradient _bgGradient;
  StreamSubscription _mediaItemSub;
  ImageProvider _blurImage;

  //Calculate background color
  Future _updateColor() async {
    if (!settings.colorGradientBackground && !settings.blurPlayerBackground)
      return;

    //BG Image
    if (settings.blurPlayerBackground)
      setState(() {
        _blurImage = NetworkImage(AudioService.currentMediaItem.extras['thumb'] ?? AudioService.currentMediaItem.artUri);
      });

    //Run in isolate
    PaletteGenerator palette = await PaletteGenerator.fromImageProvider(CachedNetworkImageProvider(AudioService.currentMediaItem.extras['thumb'] ?? AudioService.currentMediaItem.artUri));

    //Update notification
    if (settings.blurPlayerBackground)
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: palette.dominantColor.color.withOpacity(0.25),
          systemNavigationBarColor: Color.alphaBlend(palette.dominantColor.color.withOpacity(0.25), Theme.of(context).scaffoldBackgroundColor)
      ));

    //Color gradient
    if (!settings.blurPlayerBackground) {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: palette.dominantColor.color.withOpacity(0.7),
      ));
      setState(() => _bgGradient = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.dominantColor.color.withOpacity(0.7), Color.fromARGB(0, 0, 0, 0)],
          stops: [
            0.0,
            0.6
          ]
      ));
    }
  }

  @override
  void initState() {
    Future.delayed(Duration(milliseconds: 600), _updateColor);
    _mediaItemSub = AudioService.currentMediaItemStream.listen((event) {
      _updateColor();
    });

    updateColor = this._updateColor;
    super.initState();
  }

  @override
  void dispose() {
    if (_mediaItemSub != null)
        _mediaItemSub.cancel();
    //Fix bottom buttons
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      systemNavigationBarColor: settings.themeData.bottomAppBarColor,
      statusBarColor: Colors.transparent
    ));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //Responsive
    ScreenUtil.init(context, allowFontScaling: true);

    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: settings.blurPlayerBackground ? null : _bgGradient
          ),
          child: Stack(
            children: [
              if (settings.blurPlayerBackground && _blurImage != null)
                ClipRect(
                  child: Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: _blurImage,
                        fit: BoxFit.fill,
                        colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.25), BlendMode.dstATop)
                      )
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ),
              StreamBuilder(
                stream: StreamZip([AudioService.playbackStateStream, AudioService.currentMediaItemStream]),
                builder: (BuildContext context, AsyncSnapshot snapshot) {

                  //When disconnected
                  if (AudioService.currentMediaItem == null) {
                    playerHelper.startService();
                    return Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor,),);
                  }

                  return OrientationBuilder(
                    builder: (context, orientation) {
                      //Landscape
                      if (orientation == Orientation.landscape) {
                        return PlayerScreenHorizontal();
                      }
                      //Portrait
                      return PlayerScreenVertical();
                    },
                  );

                },
              ),
            ],
          )
        )
      )
    );
  }
}

//Landscape
class PlayerScreenHorizontal extends StatefulWidget {
  @override
  _PlayerScreenHorizontalState createState() => _PlayerScreenHorizontalState();
}

class _PlayerScreenHorizontalState extends State<PlayerScreenHorizontal> {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
              width: ScreenUtil().setWidth(500),
              child: Stack(
                children: <Widget>[
                  BigAlbumArt(),
                ],
              ),
            ),
        ),
        //Right side
        SizedBox(
          width: ScreenUtil().setWidth(500),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Padding(
                  padding: EdgeInsets.fromLTRB(8, 16, 8, 0),
                  child: Container(
                    child: PlayerScreenTopRow(
                      textSize: ScreenUtil().setSp(24),
                      iconSize: ScreenUtil().setSp(36),
                      textWidth: ScreenUtil().setWidth(350),
                      short: true
                    ),
                  )
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    height: ScreenUtil().setSp(50),
                    child: AudioService.currentMediaItem.displayTitle.length >= 22 ?
                      Marquee(
                        text: AudioService.currentMediaItem.displayTitle,
                        style: TextStyle(
                            fontSize: ScreenUtil().setSp(40),
                            fontWeight: FontWeight.bold
                        ),
                        blankSpace: 32.0,
                        startPadding: 10.0,
                        accelerationDuration: Duration(seconds: 1),
                        pauseAfterRound: Duration(seconds: 2),
                      ):
                      Text(
                        AudioService.currentMediaItem.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: ScreenUtil().setSp(40),
                            fontWeight: FontWeight.bold
                        ),
                      )
                  ),
                  Container(height: 4,),
                  Text(
                    AudioService.currentMediaItem.displaySubtitle ?? '',
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontSize: ScreenUtil().setSp(32),
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SeekBar(),
              ),
              PlaybackControls(ScreenUtil().setSp(60)),
              Padding(
                  padding: EdgeInsets.fromLTRB(8, 0, 8, 16),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 2.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        IconButton(
                          icon: Icon(Icons.subtitles, size: ScreenUtil().setWidth(32),
                            semanticLabel: "Lyrics".i18n,),
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => LyricsScreen(trackId: AudioService.currentMediaItem.id)
                            ));
                          },
                        ),
                        QualityInfoWidget(),
                        RepeatButton(ScreenUtil().setWidth(32)),
                        PlayerMenuButton()
                      ],
                    ),
                  )
              )
            ],
          ),
        )
      ],
    );
  }
}



//Portrait
class PlayerScreenVertical extends StatefulWidget {
  @override
  _PlayerScreenVerticalState createState() => _PlayerScreenVerticalState();
}

class _PlayerScreenVerticalState extends State<PlayerScreenVertical> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(30, 4, 16, 0),
          child: PlayerScreenTopRow()
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Container(
            height: ScreenUtil().setHeight(1000),
            child: Stack(
              children: <Widget>[
                BigAlbumArt(),
              ],
            ),
          ),
        ),
        Container(height: 4.0),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              height: ScreenUtil().setSp(80),
              child: AudioService.currentMediaItem.displayTitle.length >= 26 ?
                Marquee(
                  text: AudioService.currentMediaItem.displayTitle,
                  style: TextStyle(
                    fontSize: ScreenUtil().setSp(64),
                    fontWeight: FontWeight.bold
                  ),
                  blankSpace: 32.0,
                  startPadding: 10.0,
                  accelerationDuration: Duration(seconds: 1),
                  pauseAfterRound: Duration(seconds: 2),
                ):
                Text(
                  AudioService.currentMediaItem.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ScreenUtil().setSp(64),
                    fontWeight: FontWeight.bold
                  ),
                )
            ),
            Container(height: 4,),
            Text(
              AudioService.currentMediaItem.displaySubtitle ?? '',
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: ScreenUtil().setSp(52),
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
        SeekBar(),
        PlaybackControls(ScreenUtil().setWidth(100)),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 0, horizontal: 16.0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              IconButton(
                icon: Icon(Icons.subtitles, size: ScreenUtil().setWidth(46),
                semanticLabel: "Lyrics".i18n,),
                onPressed: () async {
                  //Fix bottom buttons
                  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
                    systemNavigationBarColor: settings.themeData.bottomAppBarColor,
                    statusBarColor: Colors.transparent
                  ));

                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => LyricsScreen(trackId: AudioService.currentMediaItem.id)
                  ));

                  updateColor();
                },
              ),
              IconButton(
                icon: Icon(Icons.file_download, semanticLabel: "Download".i18n,),
                onPressed: () async {
                  Track t = Track.fromMediaItem(AudioService.currentMediaItem);
                  if (await downloadManager.addOfflineTrack(t, private: false, context: context, isSingleton: true) != false)
                    Fluttertoast.showToast(
                      msg: 'Downloads added!'.i18n,
                      gravity: ToastGravity.BOTTOM,
                      toastLength: Toast.LENGTH_SHORT
                    );
                },
              ),
              QualityInfoWidget(),
              RepeatButton(ScreenUtil().setWidth(46)),
              PlayerMenuButton()
            ],
          ),
        )
      ],
    );
  }
}

class QualityInfoWidget extends StatefulWidget {
  @override
  _QualityInfoWidgetState createState() => _QualityInfoWidgetState();
}

class _QualityInfoWidgetState extends State<QualityInfoWidget> {

  String value = '';
  StreamSubscription streamSubscription;

  //Load data from native
  void _load() async {
    if (AudioService.currentMediaItem == null) return;
    Map data = await DownloadManager.platform.invokeMethod("getStreamInfo", {"id": AudioService.currentMediaItem.id});
    debugPrint(data.toString());
    //N/A
    if (data == null) {
      setState(() => value = '');
      //If not show, try again later
      if (AudioService.currentMediaItem.extras['show'] == null)
        Future.delayed(Duration(milliseconds: 200), _load);

      return;
    }
    //Update
    StreamQualityInfo info = StreamQualityInfo.fromJson(data);
    setState(() {
      value = '${info.format} ${info.bitrate(AudioService.currentMediaItem.duration)}kbps';
    });
  }

  @override
  void initState() {
    _load();
    if (streamSubscription == null)
      streamSubscription = AudioService.currentMediaItemStream.listen((event) async {
        await _load();
      });
    super.initState();
  }

  @override
  void dispose() {
    if (streamSubscription != null)
      streamSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      child: Text(value),
      onPressed: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => QualitySettings()));
      },
    );
  }
}


class PlayerMenuButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.more_vert, size: ScreenUtil().setWidth(46),
        semanticLabel: "Options".i18n,),
      onPressed: () {
        Track t = Track.fromMediaItem(AudioService.currentMediaItem);
        MenuSheet m = MenuSheet(context, navigateCallback: () {
          Navigator.of(context).pop();
        });
        if (AudioService.currentMediaItem.extras['show'] == null)
          m.defaultTrackMenu(t, options: [m.sleepTimer(), m.wakelock()]);
        else
          m.defaultShowEpisodeMenu(
            Show.fromJson(jsonDecode(AudioService.currentMediaItem.extras['show'])),
            ShowEpisode.fromMediaItem(AudioService.currentMediaItem),
            options: [m.sleepTimer(), m.wakelock()]
          );
      },
    );
  }
}


class RepeatButton extends StatefulWidget {

  final double iconSize;
  RepeatButton(this.iconSize, {Key key}): super(key: key);

  @override
  _RepeatButtonState createState() => _RepeatButtonState();
}

class _RepeatButtonState extends State<RepeatButton> {

  Icon get repeatIcon {
    switch (playerHelper.repeatType) {
      case LoopMode.off:
        return Icon(
            Icons.repeat,
            size: widget.iconSize,
            semanticLabel: "Repeat off".i18n,
        );
      case LoopMode.all:
        return Icon(
            Icons.repeat,
            color: Theme.of(context).primaryColor,
            size: widget.iconSize,
            semanticLabel: "Repeat".i18n,
        );
      case LoopMode.one:
        return Icon(
          Icons.repeat_one,
          color: Theme.of(context).primaryColor,
          size: widget.iconSize,
          semanticLabel: "Repeat one".i18n,
        );
    }
  }


  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: repeatIcon,
      onPressed: () async {
        await playerHelper.changeRepeat();
        setState(() {});
      },
    );
  }
}


class PlaybackControls extends StatefulWidget {

  final double iconSize;
  PlaybackControls(this.iconSize, {Key key}): super(key: key);

  @override
  _PlaybackControlsState createState() => _PlaybackControlsState();
}

class _PlaybackControlsState extends State<PlaybackControls> {

  Icon get libraryIcon {
    if (cache.checkTrackFavorite(Track.fromMediaItem(AudioService.currentMediaItem))) {
      return Icon(Icons.favorite, size: widget.iconSize * 0.64, semanticLabel: "Unlove".i18n,);
    }
    return Icon(Icons.favorite_border, size: widget.iconSize * 0.64, semanticLabel: "Love".i18n,);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.max,
        children: [
          IconButton(
              icon: Icon(Icons.sentiment_very_dissatisfied, size:  ScreenUtil().setWidth(46), semanticLabel: "Dislike".i18n,),
              onPressed: () async {
                await deezerAPI.dislikeTrack(AudioService.currentMediaItem.id);
                if (playerHelper.queueIndex < (AudioService.queue??[]).length - 1) {
                  AudioService.skipToNext();
                }
              }
          ),
          PrevNextButton(widget.iconSize, prev: true),
          PlayPauseButton(widget.iconSize * 1.25),
          PrevNextButton(widget.iconSize),
          IconButton(
            icon: libraryIcon,
            onPressed: () async {
              if (cache.libraryTracks == null)
                cache.libraryTracks = [];

              if (cache.checkTrackFavorite(Track.fromMediaItem(AudioService.currentMediaItem))) {
                //Remove from library
                setState(() => cache.libraryTracks.remove(AudioService.currentMediaItem.id));
                await deezerAPI.removeFavorite(AudioService.currentMediaItem.id);
                await cache.save();
              } else {
                //Add
                setState(() => cache.libraryTracks.add(AudioService.currentMediaItem.id));
                await deezerAPI.addFavoriteTrack(AudioService.currentMediaItem.id);
                await cache.save();
              }
            },
          )
        ],
      ),
    );
  }
}


class BigAlbumArt extends StatefulWidget {
  @override
  _BigAlbumArtState createState() => _BigAlbumArtState();
}

class _BigAlbumArtState extends State<BigAlbumArt> {

  PageController _pageController = PageController(
    initialPage: playerHelper.queueIndex,
  );
  StreamSubscription _currentItemSub;
  bool _animationLock = true;

  @override
  void initState() {
    _currentItemSub = AudioService.currentMediaItemStream.listen((event) async {
      _animationLock = true;
      await _pageController.animateToPage(playerHelper.queueIndex, duration: Duration(milliseconds: 300), curve: Curves.easeInOut);
      _animationLock = false;
    });
    super.initState();
  }

  @override
  void dispose() {
    if (_currentItemSub != null)
      _currentItemSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (DragUpdateDetails details) {
        if (details.delta.dy > 16) {
          Navigator.of(context).pop();
        }
      },
      child: PageView(
        controller: _pageController,
        onPageChanged: (int index) {
          if (pageViewLock) {
            pageViewLock = false;
            return;
          }
          if (_animationLock) return;
          AudioService.skipToQueueItem(AudioService.queue[index].id);
        },
        children: List.generate(AudioService.queue.length, (i) => ZoomableImage(url: AudioService.queue[i].artUri)),
      ),
    );
  }
}

//Top row containing QueueSource, queue...
class PlayerScreenTopRow extends StatelessWidget {

  double textSize;
  double iconSize;
  double textWidth;
  bool short;
  
  PlayerScreenTopRow({this.textSize, this.iconSize, this.textWidth, this.short });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: this.textWidth??ScreenUtil().setWidth(800),
          child: Text(
            (short??false)?(playerHelper.queueSource.text??''):'Playing from:'.i18n + ' ' + (playerHelper.queueSource?.text??''),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.left,
            style: TextStyle(fontSize: this.textSize??ScreenUtil().setSp(38)),
          ),
        ),
        IconButton(
          icon: Icon(Icons.menu, semanticLabel: "Queue".i18n,),
          iconSize: this.iconSize??ScreenUtil().setSp(52),
          splashRadius: this.iconSize??ScreenUtil().setWidth(52),
          highlightColor: Theme.of(context).primaryColor,
          onPressed: () async {
            //Fix bottom buttons
            SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
                systemNavigationBarColor: settings.themeData.bottomAppBarColor,
                statusBarColor: Colors.transparent
            ));
            //Navigate
            await Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => QueueScreen()
            ));
            //Fix colors
            updateColor();
          },
        ),
      ],
    );
  }
}



class SeekBar extends StatefulWidget {
  @override
  _SeekBarState createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {

  bool _seeking = false;
  double _pos;

  double get position {
    if (_seeking) return _pos;
    if (AudioService.playbackState == null) return 0.0;
    double p = AudioService.playbackState.currentPosition.inMilliseconds.toDouble()??0.0;
    if (p > duration) return duration;
    return p;
  }

  //Duration to mm:ss
  String _timeString(double pos) {
    Duration d = Duration(milliseconds: pos.toInt());
    return "${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}";
  }

  double get duration {
    if (AudioService.currentMediaItem == null) return 1.0;
    return AudioService.currentMediaItem.duration.inMilliseconds.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(Duration(milliseconds: 250)),
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(vertical: 0.0, horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    _timeString(position),
                    style: TextStyle(
                        fontSize: ScreenUtil().setSp(35)
                    ),
                  ),
                  Text(
                    _timeString(duration),
                    style: TextStyle(
                        fontSize: ScreenUtil().setSp(35)
                    ),
                  )
                ],
              ),
            ),
            Container(
              height: 32.0,
              child: Slider(
                focusNode: FocusNode(canRequestFocus: false, skipTraversal: true), // Don't focus on Slider - it doesn't work (and not needed)
                value: position,
                max: duration,
                onChangeStart: (double d) {
                  setState(() {
                    _seeking = true;
                    _pos = d;
                  });
                },
                onChanged: (double d) {
                  setState(() {
                    _pos = d;
                  });
                },
                onChangeEnd: (double d) async {
                  await AudioService.seekTo(Duration(milliseconds: d.round()));
                  setState(() {
                    _pos = d;
                    _seeking = false;
                  });
                },
              ),
            )
          ],
        );
      },
    );
  }
}

class QueueScreen extends StatefulWidget {
  @override
  _QueueScreenState createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {

  StreamSubscription _queueSub;

  @override
  void initState() {
    _queueSub = AudioService.queueStream.listen((event) {setState((){});});
    super.initState();
  }

  @override
  void dispose() {
    if (_queueSub != null)
      _queueSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: freezerAppBar(
          'Queue'.i18n,
          actions: <Widget>[
            IconButton(
              icon: Icon(
                Icons.shuffle,
                semanticLabel: "Shuffle".i18n,
              ),
              onPressed: () async {
                await playerHelper.toggleShuffle();
                setState(() {});
              },
            )
          ],
        ),
        body: ReorderableListView(
          onReorder: (int oldIndex, int newIndex) async {
            if (oldIndex == playerHelper.queueIndex) return;
            await playerHelper.reorder(oldIndex, newIndex);
            setState(() {});
          },
          children: List.generate(AudioService.queue.length, (int i) {
            Track t = Track.fromMediaItem(AudioService.queue[i]);
            return TrackTile(
              t,
              onTap: () async {
                pageViewLock = true;
                await AudioService.skipToQueueItem(t.id);
                Navigator.of(context).pop();
              },
              key: Key(i.toString()),
              trailing: IconButton(
                icon: Icon(Icons.close, semanticLabel: "Close".i18n,),
                onPressed: () async {
                  await AudioService.removeQueueItem(t.toMediaItem());
                  setState(() {});
                },
              ),
            );
          }),
        )
    );
  }
}