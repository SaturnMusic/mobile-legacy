import 'dart:async';

import 'package:flutter/material.dart';
import 'package:Saturn/api/deezer.dart';
import 'package:Saturn/api/definitions.dart';
import 'package:Saturn/api/download.dart';

Importer importer = Importer();

class Importer {
  //Options
  bool download = false;

  //Preserve context
  BuildContext context;
  String title;
  String description;
  List<ImporterTrack> tracks;
  String playlistId;
  Playlist playlist;

  bool done = false;
  bool busy = false;
  Future _future;
  StreamController _streamController;

  Stream get updateStream => _streamController.stream;
  int get ok => tracks.fold(0, (v, t) => (t.state == TrackImportState.OK) ? v+1 : v);
  int get error => tracks.fold(0, (v, t) => (t.state == TrackImportState.ERROR) ? v+1 : v);

  Importer();

  //Start importing wrapper
  Future<void> start(BuildContext context, String title, String description, List<ImporterTrack> tracks) async {
    //Save variables
    this.playlist = null;
    this.context = context;
    this.title = title;
    this.description = description??'';
    this.tracks = tracks.map((t) {t.state = TrackImportState.NONE; return t;}).toList();

    //Create playlist
    playlistId = await deezerAPI.createPlaylist(title, description: description);

    busy = true;
    done = false;
    _streamController = StreamController.broadcast();
    _future = _start();
  }

  //Start importer
  Future _start() async {
    for (int i=0; i<tracks.length; i++) {
      try {
        String id = await _searchTrack(tracks[i]);
        //Not found
        if (id == null) {
          tracks[i].state = TrackImportState.ERROR;
          _streamController.add(tracks[i]);
          continue;
        }
        //Add to playlist
        await deezerAPI.addToPlaylist(id, playlistId);
        tracks[i].state = TrackImportState.OK;
      } catch (_) {
        //Error occurred, mark as error
        tracks[i].state = TrackImportState.ERROR;
      }
      _streamController.add(tracks[i]);
    }
    //Get full playlist
    playlist = await deezerAPI.playlist(playlistId, nb: 10000);
    playlist.library = true;

    //Download
    if (download) {
      await downloadManager.addOfflinePlaylist(playlist, private: false, context: context);
    }

    //Mark as done
    done = true;
    busy = false;
    //To update UI
    _streamController.add(null);
    _streamController.close();
  }

  //Find track on Deezer servers
  Future<String> _searchTrack(ImporterTrack track) async {
    //Try by ISRC
    if (track.isrc != null && track.isrc.length == 12) {
      Map deezer = await deezerAPI.callPublicApi('track/isrc:' + track.isrc);
      if (deezer["id"] != null) {
        return deezer["id"].toString();
      }
    }

    //Search
    String cleanedTitle = track.title.trim().toLowerCase().replaceAll("-", "").replaceAll("&", "").replaceAll("+", "");
    SearchResults results = await deezerAPI.search("${track.artists[0]} $cleanedTitle");
    for (Track t in results.tracks) {
      //Match title
      if (_cleanMatching(t.title) == _cleanMatching(track.title)) {
        //Match artist
        if (_matchArtists(track.artists, t.artists.map((a) => a.name))) {
          return t.id;
        }
      }
    }
  }

  //Clean title for matching
  String _cleanMatching(String t) {
    return t.toLowerCase()
      .replaceAll(",", "")
      .replaceAll("-", "")
      .replaceAll(" ", "")
      .replaceAll("&", "")
      .replaceAll("+", "")
      .replaceAll("/", "");
  }

  String _cleanArtist(String a) {
    return a.toLowerCase()
        .replaceAll(" ", "")
        .replaceAll(",", "");
  }

  //Match at least 1 artist
  bool _matchArtists(List<String> a, List<String> b) {
    //Clean
    List<String> _a = a.map(_cleanArtist).toList();
    List<String> _b = b.map(_cleanArtist).toList();

    for (String artist in _a) {
      if (_b.contains(artist)) {
        return true;
      }
    }
    return false;
  }

}

class ImporterTrack {
  String title;
  List<String> artists;
  String isrc;
  TrackImportState state;

  ImporterTrack(this.title, this.artists, {this.isrc, this.state = TrackImportState.NONE});
}

enum TrackImportState {
  NONE,
  ERROR,
  OK
}

extension TrackImportStateExtension on TrackImportState {
  Widget get icon {
    switch (this) {
      case TrackImportState.ERROR:
        return Icon(Icons.error, color: Colors.red,);
      case TrackImportState.OK:
        return Icon(Icons.done, color: Colors.green);
      default:
        return Container(width: 0, height: 0);
    }
  }
}