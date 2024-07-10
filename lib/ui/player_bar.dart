import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Saturn/settings.dart';
import 'package:Saturn/translations.i18n.dart';

import '../api/player.dart';
import 'cached_image.dart';
import 'player_screen.dart';

class PlayerBar extends StatelessWidget {
  double get progress {
    if (AudioService.playbackState == null) return 0.0;
    if (AudioService.currentMediaItem == null) return 0.0;
    if (AudioService.currentMediaItem.duration.inSeconds == 0) return 0.0; //Division by 0
    return AudioService.playbackState.currentPosition.inSeconds / AudioService.currentMediaItem.duration.inSeconds;
  }

  double iconSize = 28;
  bool _gestureRegistered = false;

  @override
  Widget build(BuildContext context) {
    var focusNode = FocusNode();
    return GestureDetector(
      onHorizontalDragUpdate: (details) async {
        if (_gestureRegistered) return;
        final double sensitivity = 12.69;
        //Right swipe
        _gestureRegistered = true;
        if (details.delta.dx > sensitivity) {
          await AudioService.skipToPrevious();
        }
        //Left
        if (details.delta.dx < -sensitivity) {

          await AudioService.skipToNext();
        }
        _gestureRegistered = false;
        return;
      },
      child: StreamBuilder(
        stream: Stream.periodic(Duration(milliseconds: 250)),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (AudioService.currentMediaItem == null)
            return Container(width: 0, height: 0,);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                // For Android TV: indicate focus by grey
                color: focusNode.hasFocus ? Colors.black26 : Theme.of(context).bottomAppBarColor,
                child: ListTile(
                  dense: true,
                  focusNode: focusNode,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (BuildContext context) => PlayerScreen()));
                    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
                      systemNavigationBarColor: settings.themeData
                          .scaffoldBackgroundColor,
                    ));
                  },
                  leading: CachedImage(
                    width: 50,
                    height: 50,
                    url: AudioService.currentMediaItem.extras['thumb'] ??
                        AudioService.currentMediaItem.artUri,
                  ),
                  title: Text(
                    AudioService.currentMediaItem.displayTitle,
                    overflow: TextOverflow.clip,
                    maxLines: 1,
                  ),
                  subtitle: Text(
                    AudioService.currentMediaItem.displaySubtitle ?? '',
                    overflow: TextOverflow.clip,
                    maxLines: 1,
                  ),
                  trailing: IconTheme(
                    data: IconThemeData(
                      color: settings.isDark ? Colors.white : Colors.grey[600]
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        PrevNextButton(iconSize, prev: true, hidePrev: true,),
                        PlayPauseButton(iconSize),
                        PrevNextButton(iconSize)
                      ],
                    ),
                  )
                ),
              ),
              Container(
                height: 3.0,
                child: LinearProgressIndicator(
                  color: Theme.of(context).primaryColor,
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0),
                  value: progress,
                ),
              )
            ],
          );
        }
      ),
    );
  }
}

class PrevNextButton extends StatelessWidget {
  final double size;
  final bool prev;
  final bool hidePrev;
  int i;
  PrevNextButton(this.size, {this.prev = false, this.hidePrev = false});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AudioService.queueStream,
      builder: (context, _snapshot) {
        if (!prev) {
          if (playerHelper.queueIndex == (AudioService.queue??[]).length - 1) {
            return IconButton(
              icon: Icon(Icons.skip_next, semanticLabel: "Play next".i18n,),
              iconSize: size,
              onPressed: null,
            );
          }
          return IconButton(
            icon: Icon(Icons.skip_next, semanticLabel: "Play next".i18n,),
            iconSize: size,
            onPressed: () => AudioService.skipToNext(),
          );
        }
        if (prev) {
          if (i == 0) {
            if (hidePrev) {
              return Container(height: 0, width: 0,);
            }
            return IconButton(
              icon: Icon(Icons.skip_previous, semanticLabel: "Play previous".i18n,),
              iconSize: size,
              onPressed: null,
            );
          }
          return IconButton(
            icon: Icon(Icons.skip_previous, semanticLabel: "Play previous".i18n,),
            iconSize: size,
            onPressed: () => AudioService.skipToPrevious(),
          );
        }
        return Container();
      },
    );
  }
}


class PlayPauseButton extends StatefulWidget {

  final double size;
  PlayPauseButton(this.size, {Key key}): super(key: key);

  @override
  _PlayPauseButtonState createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<PlayPauseButton> with SingleTickerProviderStateMixin {

  AnimationController _controller;
  Animation<double> _animation;

  @override
  void initState() {
    _controller = AnimationController(vsync: this, duration: Duration(milliseconds: 200));
    _animation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AudioService.playbackStateStream,
      builder: (context, snapshot) {
        //Animated icon by pato05
        bool _playing = AudioService.playbackState?.playing ?? false;
        if (_playing || AudioService.playbackState?.processingState == AudioProcessingState.ready ||
            AudioService.playbackState?.processingState == AudioProcessingState.none) {
          if (_playing)
            _controller.forward();
          else
            _controller.reverse();

          return IconButton(
            splashRadius: widget.size,
            icon: AnimatedIcon(
              icon: AnimatedIcons.play_pause,
              progress: _animation,
              semanticLabel: _playing ? "Pause".i18n : "Play".i18n,
            ),
            iconSize: widget.size,
            onPressed: _playing
              ? () => AudioService.pause()
              : () => AudioService.play()
          );
        }

        switch (AudioService.playbackState.processingState) {
          //Stopped/Error
          case AudioProcessingState.error:
          case AudioProcessingState.none:
          case AudioProcessingState.stopped:
            return Container(width: widget.size, height: widget.size);
          //Loading, connecting, rewinding...
          default:
            return Container(
              width: widget.size,
              height: widget.size,
              child: CircularProgressIndicator(color: Theme.of(context).primaryColor,),
            );
        }
      },
    );
  }
}



