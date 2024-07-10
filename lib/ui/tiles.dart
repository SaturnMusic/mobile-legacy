import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:fluttericon/octicons_icons.dart';
import 'package:Saturn/api/deezer.dart';
import 'package:Saturn/api/download.dart';
import 'package:Saturn/translations.i18n.dart';

import '../api/definitions.dart';
import 'cached_image.dart';

import 'dart:async';


class TrackTile extends StatefulWidget {

  final Track track;
  final Function onTap;
  final Function onHold;
  final Widget trailing;

  TrackTile(this.track, {this.onTap, this.onHold, this.trailing, Key key}): super(key: key);

  @override
  _TrackTileState createState() => _TrackTileState();
}

class _TrackTileState extends State<TrackTile> {

  StreamSubscription _subscription;
  bool _isOffline = false;

  bool get nowPlaying {
    if (AudioService.currentMediaItem == null) return false;
    return AudioService.currentMediaItem.id == widget.track.id;
  }

  @override
  void initState() {
    //Listen to media item changes, update text color if currently playing
    _subscription = AudioService.currentMediaItemStream.listen((event) {
      setState(() {});
    });
    //Check if offline
    downloadManager.checkOffline(track: widget.track).then((b) => setState(() => _isOffline = b));

    super.initState();
  }

  @override
  void dispose() {
    if (_subscription != null) _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        widget.track.title,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: TextStyle(
          color: nowPlaying?Theme.of(context).primaryColor:null
        ),
      ),
      subtitle: Text(
        widget.track.artistString,
        maxLines: 1,
      ),
      leading: CachedImage(
        url: widget.track.albumArt.thumb,
        width: 48,
      ),
      onTap: widget.onTap,
      onLongPress: widget.onHold,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if ((_isOffline??false))
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 2.0),
              child: Icon(
                Octicons.primitive_dot,
                color: Colors.green,
                size: 12.0,
              ),
            ),
          if (widget.track.explicit??false)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 2.0),
              child: Text(
                'E',
                style: TextStyle(
                  color: Colors.red
                ),
              ),
            ),
          Container(
            width: 42.0,
            child: Text(
              widget.track.durationString,
              textAlign: TextAlign.center,
            ),
          ),
          widget.trailing??Container(width: 0, height: 0)
        ],
      ),
    );
  }
}

class AlbumTile extends StatelessWidget {

  final Album album;
  final Function onTap;
  final Function onHold;
  final Widget trailing;

  AlbumTile(this.album, {this.onTap, this.onHold, this.trailing});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        album.title,
        maxLines: 1,
      ),
      subtitle: Text(
        album.artistString,
        maxLines: 1,
      ),
      leading: CachedImage(
        url: album.art.thumb,
        width: 48,
      ),
      onTap: onTap,
      onLongPress: onHold,
      trailing: trailing,
    );
  }
}

class ArtistTile extends StatelessWidget {

  final Artist artist;
  final Function onTap;
  final Function onHold;

  ArtistTile(this.artist, {this.onTap, this.onHold});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Container(
        child: InkWell(
          onTap: onTap,
          onLongPress: onHold,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(height: 4,),
              CachedImage(
                url: artist.picture.thumb,
                circular: true,
                width: 100,
              ),
              Container(height: 8,),
              Text(
                artist.name,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.0
                ),
              ),
              Container(height: 4,),
            ],
          ),
        ),
      )
    );
  }
}

class PlaylistTile extends StatelessWidget {

  final Playlist playlist;
  final Function onTap;
  final Function onHold;
  final Widget trailing;

  PlaylistTile(this.playlist, {this.onHold, this.onTap, this.trailing});

  String get subtitle {
    if (playlist.user == null || playlist.user.name == null || playlist.user.name == '' || playlist.user.id == deezerAPI.userId) {
      if (playlist.trackCount == null) return '';
      return '${playlist.trackCount} ' + 'Tracks'.i18n;
    }
    return playlist.user.name;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        playlist.title,
        maxLines: 1,
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
      ),
      leading: CachedImage(
        url: playlist.image.thumb,
        width: 48,
      ),
      onTap: onTap,
      onLongPress: onHold,
      trailing: trailing,
    );
  }
}

class ArtistHorizontalTile extends StatelessWidget {

  final Artist artist;
  final Function onTap;
  final Function onHold;
  final Widget trailing;

  ArtistHorizontalTile(this.artist, {this.onHold, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.0),
      child: ListTile(
        title: Text(
          artist.name,
          maxLines: 1,
        ),
        leading: CachedImage(
          url: artist.picture.thumb,
          circular: true,
        ),
        onTap: onTap,
        onLongPress: onHold,
        trailing: trailing,
      ),
    );
  }
}

class PlaylistCardTile extends StatelessWidget {

  final Playlist playlist;
  final Function onTap;
  final Function onHold;
  PlaylistCardTile(this.playlist, {this.onTap, this.onHold});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180.0,
      child: InkWell(
        onTap: onTap,
        onLongPress: onHold,
        child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.all(8),
              child: CachedImage(
                url: playlist.image.thumb,
                width: 128,
                height: 128,
                rounded: true,
              ),
            ),
            Container(height: 2.0),
            Container(
              width: 144,
              child: Text(
                playlist.title,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14.0),
              ),
            ),
            Container(height: 4.0,)
          ],
        ),
      )
    );
  }
}


class SmartTrackListTile extends StatelessWidget {

  final SmartTrackList smartTrackList;
  final Function onTap;
  final Function onHold;
  SmartTrackListTile(this.smartTrackList, {this.onHold, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210.0,
      child: InkWell(
        onTap: onTap,
        onLongPress: onHold,
        child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Stack(
                children: [
                  CachedImage(
                    width: 128,
                    height: 128,
                    url: smartTrackList.cover.thumb,
                    rounded: true,
                  ),
                  Container(
                    width: 128.0,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                      child: Text(
                        smartTrackList.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 18.0,
                            shadows: [
                              Shadow(
                                offset: Offset(1, 1),
                                blurRadius: 2,
                                color: Colors.black
                              )
                            ],
                          color: Colors.white
                        ),
                      ),
                    ),
                  )
                ],
              )
            ),
            Container(
              width: 144.0,
              child: Text(
                smartTrackList.subtitle,
                maxLines: 3,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.0
                ),
              ),
            ),
            Container(height: 8.0,)
          ],
        ),
      ),
    );
  }
}

class AlbumCard extends StatelessWidget {

  final Album album;
  final Function onTap;
  final Function onHold;

  AlbumCard(this.album, {this.onTap, this.onHold});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: InkWell(
        onTap: onTap,
        onLongPress: onHold,
        child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.all(8.0),
              child: CachedImage(
                width: 128.0,
                height: 128.0,
                url: album.art.thumb,
                rounded: true
              ),
            ),
            Container(
              width: 144.0,
              child: Text(
                album.title,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14.0
                ),
              ),
            ),
            Container(height: 4.0),
            Container(
              width: 144.0,
              child: Text(
                album.artistString,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.0,
                  color: (Theme.of(context).brightness == Brightness.light) ? Colors.grey[800] : Colors.white70
                ),
              ),
            ),
            Container(height: 8.0,)
          ],
        ),
      )
    );
  }
}

class ChannelTile extends StatelessWidget {

  final DeezerChannel channel;
  final Function onTap;
  ChannelTile(this.channel, {this.onTap});

  Color _textColor() {
    double luminance = channel.backgroundColor.computeLuminance();
    return (luminance>0.5)?Colors.black:Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.0),
      child: Card(
        color: channel.backgroundColor,
        child: InkWell(
          onTap: this.onTap,
          child: Container(
            width: 150,
            height: 75,
            child: Center(
              child: Text(
                channel.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: _textColor()
                ),
              ),
            ),
          ),
        )
      ),
    );
  }
}

class ShowCard extends StatelessWidget {

  final Show show;
  final Function onTap;
  final Function onHold;

  ShowCard(this.show, {this.onTap, this.onHold});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: InkWell(
        onTap: onTap,
        onLongPress: onHold,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(8.0),
              child: CachedImage(
                url: show.art.thumb,
                width: 128.0,
                height: 128.0,
                rounded: true,
              ),
            ),
            Container(
              width: 144.0,
              child: Text(
                show.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.0
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShowTile extends StatelessWidget {

  final Show show;
  final Function onTap;
  final Function onHold;

  ShowTile(this.show, {this.onTap, this.onHold});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        show.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        show.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
      onLongPress: onHold,
      leading: CachedImage(
        url: show.art.thumb,
        width: 48,
      ),
    );
  }
}


class ShowEpisodeTile extends StatelessWidget {

  final ShowEpisode episode;
  final Function onTap;
  final Function onHold;
  final Widget trailing;

  ShowEpisodeTile(this.episode, {this.onTap, this.onHold, this.trailing});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onLongPress: onHold,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(episode.title, maxLines: 2),
            trailing: trailing,
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              episode.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).textTheme.subtitle1.color.withOpacity(0.9)
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8.0, 0, 0),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Text(
                  '${episode.publishedDate} | ${episode.durationString}',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.subtitle1.color.withOpacity(0.6)
                  ),
                ),
              ],
            ),
          ),
          Divider(),
        ],
      ),
    );
  }
}
