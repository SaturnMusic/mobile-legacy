import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:Saturn/api/deezer.dart';
import 'package:Saturn/api/definitions.dart';
import 'package:Saturn/api/player.dart';
import 'package:Saturn/settings.dart';
import 'package:Saturn/ui/elements.dart';
import 'package:Saturn/translations.i18n.dart';
import 'package:Saturn/ui/error.dart';


class LyricsScreen extends StatefulWidget {

  final Lyrics lyrics;
  final String trackId;

  LyricsScreen({this.lyrics, this.trackId, Key key}): super(key: key);

  @override
  _LyricsScreenState createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {

  Lyrics lyrics;
  bool _loading = true;
  bool _error = false;
  int _currentIndex = 0;
  int _prevIndex = 0;
  Timer _timer;
  ScrollController _controller = ScrollController();
  StreamSubscription _mediaItemSub;
  final double height = 90;

  Future _load() async {
    //Already available
    if (this.lyrics != null) return;
    if (widget.lyrics != null && widget.lyrics.lyrics != null && widget.lyrics.lyrics.length > 0) {
      setState(() {
        lyrics = widget.lyrics;
        _loading = false;
        _error = false;
      });
      return;
    }

    //Fetch
    try {
      Lyrics l = await deezerAPI.lyrics(widget.trackId);
      setState(() {
        _loading = false;
        lyrics = l;
      });
    } catch (e) {
      setState(() {
        _error = true;
      });
    }
  }

  @override
  void initState() {
    _load();

    //Enable visualizer
    if (settings.lyricsVisualizer)
      playerHelper.startVisualizer();

    Timer.periodic(Duration(milliseconds: 350), (timer) {
      _timer = timer;
      if (_loading) return;

      //Update current lyric index
      setState(() => _currentIndex = lyrics.lyrics.lastIndexWhere((l) => l.offset <= AudioService.playbackState.currentPosition));

      //Scroll to current lyric
      if (_currentIndex <= 0) return;
      if (_prevIndex == _currentIndex) return;
      _prevIndex = _currentIndex;
      _controller.animateTo(
        //Lyric height, screen height, appbar height
        (height * _currentIndex) - (MediaQuery.of(context).size.height / 2) + (height / 2) + 56,
        duration: Duration(milliseconds: 250),
        curve: Curves.ease
      );
    });

    //Track change = exit lyrics
    _mediaItemSub = AudioService.currentMediaItemStream.listen((event) {
      if (event.id != widget.trackId)
        Navigator.of(context).pop();
    });

    super.initState();
  }

  @override
  void dispose() {
    if (_timer != null)
      _timer.cancel();
    if (_mediaItemSub != null)
      _mediaItemSub.cancel();
    //Stop visualizer
    if (settings.lyricsVisualizer)
      playerHelper.stopVisualizer();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: freezerAppBar('Lyrics'.i18n),
      body: Stack(
        children: [
          //Visualizer
          if (settings.lyricsVisualizer)
            Align(
              alignment: Alignment.bottomCenter,
              child: StreamBuilder(
                stream: playerHelper.visualizerStream,
                builder: (BuildContext context, AsyncSnapshot snapshot) {
                  List<double> data = snapshot.data??[];
                  double width = MediaQuery.of(context).size.width / data.length - 0.25;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(data.length, (i) => AnimatedContainer(
                      duration: Duration(milliseconds: 130),
                      color: Theme.of(context).primaryColor,
                      height: data[i] * 100,
                      width: width,
                    )),
                  );
                }
              ),
            ),

          //Lyrics
          Padding(
            padding: EdgeInsets.fromLTRB(0, 0, 0, settings.lyricsVisualizer ? 100 : 0),
            child: ListView(
              controller: _controller,
              children: [
                //Shouldn't really happen, empty lyrics have own text
                if (_error)
                  ErrorScreen(),

                //Loading
                if (_loading)
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Theme.of(context).primaryColor,)
                      ],
                    ),
                  ),

                if (lyrics != null)
                  ...List.generate(lyrics.lyrics.length, (i) {
                    return Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8.0),
                              color: (_currentIndex == i) ? Colors.grey.withOpacity(0.25) : Colors.transparent,
                            ),
                            height: height,
                            child: Center(
                              child: Text(
                                lyrics.lyrics[i].text,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 26.0,
                                    fontWeight: (_currentIndex == i) ? FontWeight.bold : FontWeight.normal
                                ),
                              ),
                            )
                        )
                    );
                  }),
              ],
            ),
          )
        ],
      )
    );
  }
}
