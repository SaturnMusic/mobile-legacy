import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:Saturn/main.dart';
import 'package:wakelock/wakelock.dart';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:Saturn/api/cache.dart';
import 'package:Saturn/api/deezer.dart';
import 'package:Saturn/api/download.dart';
import 'package:Saturn/api/player.dart';
import 'package:Saturn/ui/details_screens.dart';
import 'package:Saturn/ui/error.dart';
import 'package:Saturn/translations.i18n.dart';
import 'package:Saturn/api/definitions.dart';
import 'package:Saturn/ui/cached_image.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:share/share.dart';
import 'package:url_launcher/url_launcher.dart';



class MenuSheet {

  BuildContext context;
  Function navigateCallback;

  MenuSheet(this.context, {this.navigateCallback});

  //===================
  // DEFAULT
  //===================

  void show(List<Widget> options) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (BuildContext context) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: (MediaQuery.of(context).orientation == Orientation.landscape)?220:350,
          ),
          child: SingleChildScrollView(
            child: Column(
                children: options
            ),
          ),
        );
      }
    );
  }

  //===================
  // TRACK
  //===================

  void showWithTrack(Track track, List<Widget> options) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(height: 16.0,),
            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Semantics(
                  child: CachedImage(
                    url: track.albumArt.full,
                    height: 128,
                    width: 128,
                  ),
                  label: "Album art".i18n,
                  image: true,
                ),
                Container(
                  width: 240.0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        track.title,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 22.0,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      Text(
                        track.artistString,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 20.0
                        ),
                      ),
                      Container(height: 8.0,),
                      Text(
                        track.album.title,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        track.durationString
                      )
                    ],
                  ),
                ),
              ],
            ),
            Container(height: 16.0,),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (MediaQuery.of(context).orientation == Orientation.landscape)?220:350,
              ),
              child: SingleChildScrollView(
                child: Column(
                    children: options
                ),
              ),
            )
          ],
        );
      }
    );
  }

  //Default track options
  void defaultTrackMenu(Track track, {List<Widget> options = const [], Function onRemove}) async {
    showWithTrack(track, [
      addToQueueNext(track),
      addToQueue(track),
      (await cache.checkTrackFavorite(track))?removeFavoriteTrack(track, onUpdate: onRemove):addTrackFavorite(track),
      addToPlaylist(track),
      downloadTrack(track),
      offlineTrack(track),
      shareTile('track', track.id),
      playMix(track),
      showAlbum(track.album),
      ...List.generate(track.artists.length, (i) => showArtist(track.artists[i])),
      ...options
    ]);
  }

  //===================
  // TRACK OPTIONS
  //===================

  Widget addToQueueNext(Track t) => ListTile(
      title: Text('Play next'.i18n),
      leading: Icon(Icons.playlist_play),
      onTap: () async {
        //-1 = next
        await AudioService.addQueueItemAt(t.toMediaItem(), -1);
        _close();
      });

  Widget addToQueue(Track t) => ListTile(
      title: Text('Add to queue'.i18n),
      leading: Icon(Icons.playlist_add),
      onTap: () async {
        await AudioService.addQueueItem(t.toMediaItem());
        _close();
      }
  );

  Widget addTrackFavorite(Track t) => ListTile(
      title: Text('Add track to favorites'.i18n),
      leading: Icon(Icons.favorite),
      onTap: () async {
        await deezerAPI.addFavoriteTrack(t.id);
        //Make track offline, if favorites are offline
        Playlist p = Playlist(id: deezerAPI.favoritesPlaylistId);
        if (await downloadManager.checkOffline(playlist: p)) {
          downloadManager.addOfflinePlaylist(p);
        }
        Fluttertoast.showToast(
            msg: 'Added to library'.i18n,
            gravity: ToastGravity.BOTTOM,
            toastLength: Toast.LENGTH_SHORT
        );
        //Add to cache
        if (cache.libraryTracks == null)
          cache.libraryTracks = [];
        cache.libraryTracks.add(t.id);

        _close();
      }
  );

  Widget downloadTrack(Track t) => ListTile(
    title: Text('Download'.i18n),
    leading: Icon(Icons.file_download),
    onTap: () async {
      if (await downloadManager.addOfflineTrack(t, private: false, context: context, isSingleton: true) != false)
        showDownloadStartedToast();
      _close();
    },
  );

  Widget addToPlaylist(Track t) => ListTile(
    title: Text('Add to playlist'.i18n),
    leading: Icon(Icons.playlist_add),
    onTap: () async {
      //Show dialog to pick playlist
      await showDialog(
        context: context,
        builder: (context) {
          return SelectPlaylistDialog(track: t, callback: (Playlist p) async {
            await deezerAPI.addToPlaylist(t.id, p.id);
            //Update the playlist if offline
            if (await downloadManager.checkOffline(playlist: p)) {
              downloadManager.addOfflinePlaylist(p);
            }
            Fluttertoast.showToast(
              msg: "Track added to".i18n + " ${p.title}",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
            );
          });
        }
      );
      _close();
    },
  );

  Widget removeFromPlaylist(Track t, Playlist p) => ListTile(
    title: Text('Remove from playlist'.i18n),
    leading: Icon(Icons.delete),
    onTap: () async {
      await deezerAPI.removeFromPlaylist(t.id, p.id);
      Fluttertoast.showToast(
        msg: 'Track removed from'.i18n + ' ${p.title}',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      _close();
    },
  );

  Widget removeFavoriteTrack(Track t, {onUpdate}) => ListTile(
    title: Text('Remove favorite'.i18n),
    leading: Icon(Icons.delete),
    onTap: () async {
      await deezerAPI.removeFavorite(t.id);
      //Check if favorites playlist is offline, update it
      Playlist p = Playlist(id: deezerAPI.favoritesPlaylistId);
      if (await downloadManager.checkOffline(playlist: p)) {
        await downloadManager.addOfflinePlaylist(p);
      }
      //Remove from cache
      if (cache.libraryTracks != null)
        cache.libraryTracks.removeWhere((i) => i == t.id);
      Fluttertoast.showToast(
        msg: 'Track removed from library'.i18n,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM
      );
      if (onUpdate != null)
        onUpdate();
      _close();
    },
  );

  //Redirect to artist page (ie from track)
  Widget showArtist(Artist a) => ListTile(
    title: Text(
      'Go to'.i18n + ' ${a.name}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    leading: Icon(Icons.recent_actors),
    onTap: () {
      _close();
      navigatorKey.currentState.push(
          MaterialPageRoute(builder: (context) => ArtistDetails(a))
      );

      if (this.navigateCallback != null) {
        this.navigateCallback();
      }
    },
  );

  Widget showAlbum(Album a) => ListTile(
    title: Text(
      'Go to'.i18n + ' ${a.title}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    leading: Icon(Icons.album),
    onTap: () {
      _close();
      navigatorKey.currentState.push(
          MaterialPageRoute(builder: (context) => AlbumDetails(a))
      );

      if (this.navigateCallback != null) {
        this.navigateCallback();
      }
    },
  );

  Widget playMix(Track track) => ListTile(
    title: Text('Play mix'.i18n),
    leading: Icon(Icons.online_prediction),
    onTap: () async {
      playerHelper.playMix(track.id, track.title);
      _close();
    },
  );

  Widget offlineTrack(Track track) => FutureBuilder(
    future: downloadManager.checkOffline(track: track),
    builder: (context, snapshot) {
      bool isOffline = snapshot.data??(track.offline??false);
      return ListTile(
        title: Text(isOffline ? 'Remove offline'.i18n : 'Offline'.i18n),
        leading: Icon(Icons.offline_pin),
        onTap: () async {
          if (isOffline) {
            await downloadManager.removeOfflineTracks([track]);
            Fluttertoast.showToast(msg: "Track removed from offline!".i18n, gravity: ToastGravity.BOTTOM, toastLength: Toast.LENGTH_SHORT);
          } else {
            await downloadManager.addOfflineTrack(track, private: true, context: context);
          }
          _close();
        },
      );
    },
  );

  //===================
  // ALBUM
  //===================

  //Default album options
  void defaultAlbumMenu(Album album, {List<Widget> options = const [], Function onRemove}) {
    show([
      album.library?removeAlbum(album, onRemove: onRemove):libraryAlbum(album),
      downloadAlbum(album),
      offlineAlbum(album),
      shareTile('album', album.id),
      ...options
    ]);
  }

  //===================
  // ALBUM OPTIONS
  //===================

  Widget downloadAlbum(Album a) => ListTile(
      title: Text('Download'.i18n),
      leading: Icon(Icons.file_download),
      onTap: () async {
        _close();
        if (await downloadManager.addOfflineAlbum(a, private: false, context: context) != false)
          showDownloadStartedToast();
      }
  );

  Widget offlineAlbum(Album a) => ListTile(
    title: Text('Make offline'.i18n),
    leading: Icon(Icons.offline_pin),
    onTap: () async {
      await deezerAPI.addFavoriteAlbum(a.id);
      await downloadManager.addOfflineAlbum(a, private: true);
      _close();
      showDownloadStartedToast();
    },
  );

  Widget libraryAlbum(Album a) => ListTile(
    title: Text('Add to library'.i18n),
    leading: Icon(Icons.library_music),
    onTap: () async {
      await deezerAPI.addFavoriteAlbum(a.id);
      Fluttertoast.showToast(
          msg: 'Added to library'.i18n,
          gravity: ToastGravity.BOTTOM
      );
      _close();
    },
  );

  //Remove album from favorites
  Widget removeAlbum(Album a, {Function onRemove}) => ListTile(
    title: Text('Remove album'.i18n),
    leading: Icon(Icons.delete),
    onTap: () async {
      await deezerAPI.removeAlbum(a.id);
      await downloadManager.removeOfflineAlbum(a.id);
      Fluttertoast.showToast(
        msg: 'Album removed'.i18n,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      if (onRemove != null) onRemove();
      _close();
    },
  );

  //===================
  // ARTIST
  //===================

  void defaultArtistMenu(Artist artist, {List<Widget> options = const [], Function onRemove}) {
    show([
      artist.library?removeArtist(artist, onRemove: onRemove):favoriteArtist(artist),
      shareTile('artist', artist.id),
      ...options
    ]);
  }

  //===================
  // ARTIST OPTIONS
  //===================

  Widget removeArtist(Artist a, {Function onRemove}) => ListTile(
    title: Text('Remove from favorites'.i18n),
    leading: Icon(Icons.delete),
    onTap: () async {
      await deezerAPI.removeArtist(a.id);
      Fluttertoast.showToast(
          msg: 'Artist removed from library'.i18n,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM
      );
      if (onRemove != null) onRemove();
      _close();
    },
  );

  Widget favoriteArtist(Artist a) => ListTile(
    title: Text('Add to favorites'.i18n),
    leading: Icon(Icons.favorite),
    onTap: () async {
      await deezerAPI.addFavoriteArtist(a.id);
      Fluttertoast.showToast(
          msg: 'Added to library'.i18n,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM
      );
      _close();
    },
  );

  //===================
  // PLAYLIST
  //===================

  void defaultPlaylistMenu(Playlist playlist, {List<Widget> options = const [], Function onRemove, Function onUpdate}) {
    show([
      playlist.library?removePlaylistLibrary(playlist, onRemove: onRemove):addPlaylistLibrary(playlist),
      addPlaylistOffline(playlist),
      downloadPlaylist(playlist),
      shareTile('playlist', playlist.id),
      if (playlist.user.id == deezerAPI.userId)
        editPlaylist(playlist, onUpdate: onUpdate),
      ...options
    ]);
  }

  //===================
  // PLAYLIST OPTIONS
  //===================

  Widget removePlaylistLibrary(Playlist p, {Function onRemove}) => ListTile(
    title: Text('Remove from library'.i18n),
    leading: Icon(Icons.delete),
    onTap: () async {
      if (p.user.id.trim() == deezerAPI.userId) {
        //Delete playlist if own
        await deezerAPI.deletePlaylist(p.id);
      } else {
        //Just remove from library
        await deezerAPI.removePlaylist(p.id);
      }
      downloadManager.removeOfflinePlaylist(p.id);
      if (onRemove != null) onRemove();
      _close();
    },
  );

  Widget addPlaylistLibrary(Playlist p) => ListTile(
    title: Text('Add playlist to library'.i18n),
    leading: Icon(Icons.favorite),
    onTap: () async {
      await deezerAPI.addPlaylist(p.id);
      Fluttertoast.showToast(
          msg: 'Added playlist to library'.i18n,
          gravity: ToastGravity.BOTTOM
      );
      _close();
    },
  );

  Widget addPlaylistOffline(Playlist p) => ListTile(
    title: Text('Make playlist offline'.i18n),
    leading: Icon(Icons.offline_pin),
    onTap: () async {
      //Add to library
      await deezerAPI.addPlaylist(p.id);
      downloadManager.addOfflinePlaylist(p, private: true);
      _close();
      showDownloadStartedToast();
    },
  );

  Widget downloadPlaylist(Playlist p) => ListTile(
    title: Text('Download playlist'.i18n),
    leading: Icon(Icons.file_download),
    onTap: () async {
      _close();
      if (await downloadManager.addOfflinePlaylist(p, private: false, context: context) != false)
        showDownloadStartedToast();
    },
  );

  Widget editPlaylist(Playlist p, {Function onUpdate}) => ListTile(
    title: Text('Edit playlist'.i18n),
    leading: Icon(Icons.edit),
    onTap: () async {
      await showDialog(
        context: context,
        builder: (context) => CreatePlaylistDialog(playlist: p)
      );
      _close();
      if (onUpdate != null)
        onUpdate();
    },
  );

  //===================
  // SHOW/EPISODE
  //===================

  defaultShowEpisodeMenu(Show s, ShowEpisode e, {List<Widget> options = const []}) {
    show([
      shareTile('episode', e.id),
      shareShow(s.id),
      downloadExternalEpisode(e),
      ...options
    ]);
  }

  Widget shareShow(String id) => ListTile(
    title: Text('Share show'.i18n),
    leading: Icon(Icons.share),
    onTap: () async {
      Share.share('https://deezer.com/show/$id');
    },
  );

  //Open direct download link in browser
  Widget downloadExternalEpisode(ShowEpisode e) => ListTile(
    title: Text('Download externally'.i18n),
    leading: Icon(Icons.file_download),
    onTap: () async {
      launch(e.url);
    },
  );

  //===================
  // OTHER
  //===================

  showDownloadStartedToast() {
    Fluttertoast.showToast(
      msg: 'Downloads added!'.i18n,
      gravity: ToastGravity.BOTTOM,
      toastLength: Toast.LENGTH_SHORT
    );
  }

  //Create playlist
  Future createPlaylist() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return CreatePlaylistDialog();
      }
    );
  }

  Widget shareTile(String type, String id) => ListTile(
    title: Text('Share'.i18n),
    leading: Icon(Icons.share),
    onTap: () async {
      Share.share('https://deezer.com/$type/$id');
    },
  );

  Widget sleepTimer() => ListTile(
    title: Text('Sleep timer'.i18n),
    leading: Icon(Icons.access_time),
    onTap: () async {
      showDialog(
        context: context,
        builder: (context) {
          return SleepTimerDialog();
        }
      );
    },
  );

  Widget wakelock() => ListTile(
    title: Text('Keep the screen on'.i18n),
    leading: Icon(Icons.screen_lock_portrait),
    onTap: () async {
      _close();
      if (cache.wakelock == null)
        cache.wakelock = false;
      //Enable
      if (!cache.wakelock) {
        Wakelock.enable();
        Fluttertoast.showToast(
            msg: 'Wakelock enabled!'.i18n,
            gravity: ToastGravity.BOTTOM
        );
        cache.wakelock = true;
        return;
      }
      //Disable
      Wakelock.disable();
      Fluttertoast.showToast(
          msg: 'Wakelock disabled!'.i18n,
          gravity: ToastGravity.BOTTOM
      );
      cache.wakelock = false;
    },
  );

  void _close() => Navigator.of(context).pop();
}

class SleepTimerDialog extends StatefulWidget {
  @override
  _SleepTimerDialogState createState() => _SleepTimerDialogState();
}

class _SleepTimerDialogState extends State<SleepTimerDialog> {
  int hours = 0;
  int minutes = 30;

  String _endTime() {
    return '${cache.sleepTimerTime.hour.toString().padLeft(2, '0')}:${cache.sleepTimerTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Sleep timer'.i18n),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Hours:'.i18n),
                  NumberPicker.integer(
                    initialValue: hours,
                    minValue: 0,
                    maxValue: 69,
                    onChanged: (v) => setState(() => hours = v),
                    highlightSelectedValue: true,
                  ),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Minutes:'.i18n),
                  NumberPicker.integer(
                      initialValue: minutes,
                      minValue: 0,
                      maxValue: 60,
                      onChanged: (v) => setState(() => minutes = v),
                      highlightSelectedValue: true
                  ),
                ],
              ),
            ],
          ),
          Container(height: 4.0),
          if (cache.sleepTimerTime != null)
            Text(
              'Current timer ends at'.i18n + ': ' +_endTime(),
              textAlign: TextAlign.center,
            )
        ],
      ),
      actions: [
        TextButton(
          child: Text('Dismiss'.i18n),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        if (cache.sleepTimer != null)
          TextButton(
            child: Text('Cancel current timer'.i18n),
            onPressed: () {
              cache.sleepTimer.cancel();
              cache.sleepTimer = null;
              cache.sleepTimerTime = null;
              Navigator.of(context).pop();
            },
          ),

        TextButton(
          child: Text('Save'.i18n),
          onPressed: () {
            Duration duration = Duration(hours: hours, minutes: minutes);
            if (cache.sleepTimer != null) {
              cache.sleepTimer.cancel();
            }
            //Create timer
            cache.sleepTimer = Stream.fromFuture(Future.delayed(duration)).listen((_) {
              AudioService.pause();
              cache.sleepTimer.cancel();
              cache.sleepTimerTime = null;
              cache.sleepTimer = null;
            });
            cache.sleepTimerTime = DateTime.now().add(duration);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}



class SelectPlaylistDialog extends StatefulWidget {

  final Track track;
  final Function callback;
  SelectPlaylistDialog({this.track, this.callback, Key key}): super(key: key);

  @override
  _SelectPlaylistDialogState createState() => _SelectPlaylistDialogState();
}

class _SelectPlaylistDialogState extends State<SelectPlaylistDialog> {

  bool createNew = false;

  @override
  Widget build(BuildContext context) {

    //Create new playlist
    if (createNew) {
      if (widget.track == null) {
        return CreatePlaylistDialog();
      }
      return CreatePlaylistDialog(tracks: [widget.track]);
    }


    return AlertDialog(
      title: Text('Select playlist'.i18n),
      content: FutureBuilder(
        future: deezerAPI.getPlaylists(),
        builder: (context, snapshot) {

          if (snapshot.hasError) SizedBox(
            height: 100,
            child: ErrorScreen(),
          );
          if (snapshot.connectionState != ConnectionState.done) return SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor,),),
          );

          List<Playlist> playlists = snapshot.data;
          return SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...List.generate(playlists.length, (i) => ListTile(
                    title: Text(playlists[i].title),
                    leading: CachedImage(
                      url: playlists[i].image.thumb,
                    ),
                    onTap: () {
                      if (widget.callback != null) {
                        widget.callback(playlists[i]);
                      }
                      Navigator.of(context).pop();
                    },
                  )),
                  ListTile(
                    title: Text('Create new playlist'.i18n),
                    leading: Icon(Icons.add),
                    onTap: () async {
                      setState(() {
                        createNew = true;
                      });
                    },
                  )
                ]
            ),
          );
        },
      ),
    );
  }
}



class CreatePlaylistDialog extends StatefulWidget {

  final List<Track> tracks;
  //If playlist not null, update
  final Playlist playlist;
  CreatePlaylistDialog({this.tracks, this.playlist, Key key}): super(key: key);

  @override
  _CreatePlaylistDialogState createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<CreatePlaylistDialog> {

  int _playlistType = 1;
  String _title = '';
  String _description = '';
  TextEditingController _titleController;
  TextEditingController _descController;

  //Create or edit mode
  bool get edit => widget.playlist != null;

  @override
  void initState() {

    //Edit playlist mode
    if (edit) {
      _titleController = TextEditingController(text: widget.playlist.title);
      _descController = TextEditingController(text: widget.playlist.description);
    }

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(edit ? 'Edit playlist'.i18n : 'Create playlist'.i18n),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            decoration: InputDecoration(
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Theme.of(context).primaryColor), // Color of the underline when focused
              ),
              floatingLabelStyle: TextStyle(color: Theme.of(context).primaryColor), // Label color when focused
              labelText: 'Title'.i18n
            ),
            controller: _titleController ?? TextEditingController(),
            onChanged: (String s) => _title = s,
          ),
          TextField(
            onChanged: (String s) => _description = s,
            controller: _descController ?? TextEditingController(),
            decoration: InputDecoration(
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Theme.of(context).primaryColor), // Color of the underline when focused
              ),
              floatingLabelStyle: TextStyle(color: Theme.of(context).primaryColor), // Label color when focused
              labelText: 'Description'.i18n
            ),
          ),
          Container(height: 4.0,),
          DropdownButton<int>(
            value: _playlistType,
            onChanged: (int v) {
              setState(() => _playlistType = v);
            },
            items: [
              DropdownMenuItem<int>(
                value: 1,
                child: Text('Private'.i18n),
              ),
              DropdownMenuItem<int>(
                value: 2,
                child: Text('Collaborative'.i18n),
              ),
            ],
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          child: Text('Cancel'.i18n),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: Text(edit ? 'Update'.i18n : 'Create'.i18n),
          onPressed: () async {
            if (edit) {
              //Update
              await deezerAPI.updatePlaylist(
                widget.playlist.id,
                _titleController.value.text,
                _descController.value.text,
                status: _playlistType
              );
              Fluttertoast.showToast(
                  msg: 'Playlist updated!'.i18n,
                  gravity: ToastGravity.BOTTOM
              );
            } else {
              List<String> tracks = [];
              if (widget.tracks != null) {
                tracks = widget.tracks.map<String>((t) => t.id).toList();
              }
              await deezerAPI.createPlaylist(
                  _title,
                  status: _playlistType,
                  description: _description,
                  trackIds: tracks
              );
              Fluttertoast.showToast(
                  msg: 'Playlist created!'.i18n,
                  gravity: ToastGravity.BOTTOM
              );
            }
            Navigator.of(context).pop();
          },
        )
      ],
    );
  }
}
