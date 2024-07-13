import 'package:sqflite/sqflite.dart';
import 'package:sqflite/sql.dart';
import 'package:disk_space/disk_space.dart';
import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:Saturn/api/deezer.dart';
import 'package:Saturn/api/definitions.dart';
import 'package:Saturn/settings.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:Saturn/translations.i18n.dart';

import 'dart:io';
import 'dart:async';


DownloadManager downloadManager = DownloadManager();

class DownloadManager {

  //Platform channels
  static MethodChannel platform = MethodChannel('s.s.saturn/native');
  static EventChannel eventChannel = EventChannel('s.s.saturn/downloads');

  bool running = false;
  int queueSize = 0;

  StreamController serviceEvents = StreamController.broadcast();
  String offlinePath;
  Database db;

  //Start/Resume downloads
  Future start() async {
    //Returns whether service is bound or not, the delay is really shitty/hacky way, until i find a real solution
    await updateServiceSettings();
    await platform.invokeMethod('start');
  }

  //Stop/Pause downloads
  Future stop() async {
    await platform.invokeMethod('stop');
  }

  Future init() async {
    //Remove old DB
    File oldDbFile = File(p.join((await getDatabasesPath()), 'offline.db'));
    if (await oldDbFile.exists()) {
      await oldDbFile.delete();
    }

    String dbPath = p.join((await getDatabasesPath()), 'offline2.db');
    //Open db
    db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (Database db, int version) async {
        Batch b = db.batch();
        //Create tables, if doesn't exit
        b.execute("""CREATE TABLE Tracks (
        id TEXT PRIMARY KEY, title TEXT, album TEXT, artists TEXT, duration INTEGER, albumArt TEXT, trackNumber INTEGER, offline INTEGER, lyrics TEXT, favorite INTEGER, diskNumber INTEGER, explicit INTEGER)""");
        b.execute("""CREATE TABLE Albums (
        id TEXT PRIMARY KEY, title TEXT, artists TEXT, tracks TEXT, art TEXT, fans INTEGER, offline INTEGER, library INTEGER, type INTEGER, releaseDate TEXT)""");
        b.execute("""CREATE TABLE Artists (
        id TEXT PRIMARY KEY, name TEXT, albums TEXT, topTracks TEXT, picture TEXT, fans INTEGER, albumCount INTEGER, offline INTEGER, library INTEGER, radio INTEGER)""");
        b.execute("""CREATE TABLE Playlists (
        id TEXT PRIMARY KEY, title TEXT, tracks TEXT, image TEXT, duration INTEGER, userId TEXT, userName TEXT, fans INTEGER, library INTEGER, description TEXT)""");
        await b.commit();
      }
    );

    //Create offline directory
    offlinePath = p.join((await getExternalStorageDirectory()).path, 'offline/');
    await Directory(offlinePath).create(recursive: true);

    //Update settings
    await updateServiceSettings();

    //Listen to state change event
    eventChannel.receiveBroadcastStream().listen((e) {
      if (e['action'] == 'onStateChange') {
        running = e['running'];
        queueSize = e['queueSize'];
      }

      //Forward
      serviceEvents.add(e);
    });

    await platform.invokeMethod('loadDownloads');
  }

  //Get all downloads from db
  Future<List<Download>> getDownloads() async {
    List raw = await platform.invokeMethod('getDownloads');
    return raw.map((d) => Download.fromJson(d)).toList();
  }

  //Insert track and metadata to DB
  Future _addTrackToDB(Batch batch, Track track, bool overwriteTrack) async {
    batch.insert('Tracks', track.toSQL(off: true), conflictAlgorithm: overwriteTrack?ConflictAlgorithm.replace:ConflictAlgorithm.ignore);
    batch.insert('Albums', track.album.toSQL(off: false), conflictAlgorithm: ConflictAlgorithm.ignore);
    //Artists
    for (Artist a in track.artists) {
      batch.insert('Artists', a.toSQL(off: false), conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    return batch;
  }

  //Quality selector for custom quality
  Future qualitySelect(BuildContext context) async {
    AudioQuality quality;
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(0, 12, 0, 2),
              child: Text(
                'Quality'.i18n,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20.0
                ),
              ),
            ),
            ListTile(
              title: Text('MP3 128kbps'),
              onTap: () {
                quality = AudioQuality.MP3_128;
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: Text('MP3 320kbps'),
              onTap: () {
                quality = AudioQuality.MP3_320;
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: Text('FLAC'),
              onTap: () {
                quality = AudioQuality.FLAC;
                Navigator.of(context).pop();
              },
            )
          ],
        );
      }
    );
    return quality;
  }

  Future<bool> addOfflineTrack(Track track, {private = true, BuildContext context, isSingleton = false}) async {
    //Permission
    if (!private && !(await checkPermission())) return false;

    //Ask for quality
    AudioQuality quality;
    if (!private && settings.downloadQuality == AudioQuality.ASK) {
       quality = await qualitySelect(context);
      if (quality == null) return false;
    }

    //Fetch track if missing meta
    if (track.artists == null || track.artists.length == 0 || track.album == null)
      track = await deezerAPI.track(track.id);

    //Add to DB
    if (private) {
      Batch b = db.batch();
      b = await _addTrackToDB(b, track, true);
      await b.commit();

      //Cache art
      DefaultCacheManager().getSingleFile(track.albumArt.thumb);
      DefaultCacheManager().getSingleFile(track.albumArt.full);
    }

    //Get path
    String path = _generatePath(track, private, isSingleton: isSingleton);
    await platform.invokeMethod('addDownloads', [await Download.jsonFromTrack(track, path, private: private, quality: quality)]);
    await start();
    return true;
  }

  Future addOfflineAlbum(Album album, {private = true, BuildContext context}) async {
    //Permission
    if (!private && !(await checkPermission())) return;

    //Ask for quality
    AudioQuality quality;
    if (!private && settings.downloadQuality == AudioQuality.ASK) {
      quality = await qualitySelect(context);
      if (quality == null) return false;
    }

    //Get from API if no tracks
    if (album.tracks == null || album.tracks.length == 0) {
      album = await deezerAPI.album(album.id);
    }

    //Add to DB
    if (private) {
      //Cache art
      DefaultCacheManager().getSingleFile(album.art.thumb);
      DefaultCacheManager().getSingleFile(album.art.full);

      Batch b = db.batch();
      b.insert('Albums', album.toSQL(off: true), conflictAlgorithm: ConflictAlgorithm.replace);
      for (Track t in album.tracks) {
        b = await _addTrackToDB(b, t, false);
      }
      await b.commit();
    }

    //Create downloads
    List<Map> out = [];
    for (Track t in album.tracks) {
      out.add(await Download.jsonFromTrack(t, _generatePath(t, private), private: private, quality: quality));
    }
    await platform.invokeMethod('addDownloads', out);
    await start();
  }

  Future addOfflinePlaylist(Playlist playlist, {private = true, BuildContext context, AudioQuality quality}) async {
    //Permission
    if (!private && !(await checkPermission())) return;

    //Ask for quality
    if (!private && settings.downloadQuality == AudioQuality.ASK && quality == null) {
      quality = await qualitySelect(context);
      if (quality == null) return false;
    }

    //Get tracks if missing
    if (playlist.tracks == null || playlist.tracks.length < playlist.trackCount) {
      playlist = await deezerAPI.fullPlaylist(playlist.id);
    }

    //Add to DB
    if (private) {
      Batch b = db.batch();
      b.insert('Playlists', playlist.toSQL(), conflictAlgorithm: ConflictAlgorithm.replace);
      for (Track t in playlist.tracks) {
        b = await _addTrackToDB(b, t, false);
        //Cache art
        DefaultCacheManager().getSingleFile(t.albumArt.thumb);
        DefaultCacheManager().getSingleFile(t.albumArt.full);
      }
      await b.commit();
    }

    //Generate downloads
    List<Map> out = [];
    for (int i=0; i<playlist.tracks.length; i++) {
      Track t = playlist.tracks[i];
      out.add(await Download.jsonFromTrack(t, _generatePath(
          t,
          private,
          playlistName: playlist.title,
          playlistTrackNumber: i,
      ), private: private, quality: quality));
    }
    await platform.invokeMethod('addDownloads', out);
    await start();
  }

  //Get track and meta from offline DB
  Future<Track> getOfflineTrack(String id, {Album album, List<Artist> artists}) async {
    List tracks = await db.query('Tracks', where: 'id == ?', whereArgs: [id]);
    if (tracks.length == 0) return null;
    Track track = Track.fromSQL(tracks[0]);

    //Get album
    if (album == null) {
      List rawAlbums = await db.query('Albums', where: 'id == ?', whereArgs: [track.album.id]);
      if (rawAlbums.length > 0)
        track.album = Album.fromSQL(rawAlbums[0]);
    } else {
      track.album = album;
    }

    //Get artists
    if (artists == null) {
      List<Artist> newArtists = [];
      for (Artist artist in track.artists) {
        List rawArtist = await db.query('Artists', where: 'id == ?', whereArgs: [artist.id]);
        if (rawArtist.length > 0)
          newArtists.add(Artist.fromSQL(rawArtist[0]));
      }
      if (newArtists.length > 0)
        track.artists = newArtists;
    } else {
      track.artists = artists;
    }
    return track;
  }

  //Get offline library tracks
  Future<List<Track>> getOfflineTracks() async {
    List rawTracks = await db.query('Tracks', where: 'library == 1 AND offline == 1', columns: ['id']);
    List<Track> out = [];
    //Load track meta individually
    for (Map rawTrack in rawTracks) {
      out.add(await getOfflineTrack(rawTrack['id']));
    }
    return out;
  }

  //Get all offline available tracks
  Future<List<Track>> allOfflineTracks() async {
    List rawTracks = await db.query('Tracks', where: 'offline == 1', columns: ['id']);
    List<Track> out = [];
    //Load track meta individually
    for (Map rawTrack in rawTracks) {
      out.add(await getOfflineTrack(rawTrack['id']));
    }
    return out;
  }

  //Get all offline albums
  Future<List<Album>> getOfflineAlbums() async {
    List rawAlbums = await db.query('Albums', where: 'offline == 1', columns: ['id']);
    List<Album> out = [];
    //Load each album
    for (Map rawAlbum in rawAlbums) {
      out.add(await getOfflineAlbum(rawAlbum['id']));
    }
    return out;
  }

  //Get offline album with meta
  Future<Album> getOfflineAlbum(String id) async {
    List rawAlbums = await db.query('Albums', where: 'id == ?', whereArgs: [id]);
    if (rawAlbums.length == 0) return null;
    Album album = Album.fromSQL(rawAlbums[0]);

    List<Track> tracks = [];
    //Load tracks
    for (int i=0; i<album.tracks.length; i++) {
      tracks.add(await getOfflineTrack(album.tracks[i].id, album: album));
    }
    album.tracks = tracks;
    //Load artists
    List<Artist> artists = [];
    for (int i=0; i<album.artists.length; i++) {
      artists.add((await getOfflineArtist(album.artists[i].id))??album.artists[i]);
    }
    album.artists = artists;

    return album;
  }

  //Get offline artist METADATA, not tracks
  Future<Artist> getOfflineArtist(String id) async {
    List rawArtists = await db.query("Artists", where: 'id == ?', whereArgs: [id]);
    if (rawArtists.length == 0) return null;
    return Artist.fromSQL(rawArtists[0]);
  }

  //Get all offline playlists
  Future<List<Playlist>> getOfflinePlaylists() async {
    List rawPlaylists = await db.query('Playlists', columns: ['id']);
    List<Playlist> out = [];
    for (Map rawPlaylist in rawPlaylists) {
      out.add(await getPlaylist(rawPlaylist['id']));
    }
    return out;
  }

  //Get offline playlist
  Future<Playlist> getPlaylist(String id) async {
    List rawPlaylists = await db.query('Playlists', where: 'id == ?', whereArgs: [id]);
    if (rawPlaylists.length == 0) return null;
    Playlist playlist = Playlist.fromSQL(rawPlaylists[0]);
    //Load tracks
    List<Track> tracks = [];
    for (Track t in playlist.tracks) {
      tracks.add(await getOfflineTrack(t.id));
    }
    playlist.tracks = tracks;
    return playlist;
  }

  Future removeOfflineTracks(List<Track> tracks) async {
    for (Track t in tracks) {
      //Check if library
      List rawTrack = await db.query('Tracks', where: 'id == ?', whereArgs: [t.id], columns: ['favorite']);
      if (rawTrack.length > 0) {
        //Count occurrences in playlists and albums
        List albums = await db.rawQuery('SELECT (id) FROM Albums WHERE tracks LIKE "%${t.id}%"');
        List playlists = await db.rawQuery('SELECT (id) FROM Playlists WHERE tracks LIKE "%${t.id}%"');
        if (albums.length + playlists.length == 0 && rawTrack[0]['favorite'] == 0) {
          //Safe to remove
          await db.delete('Tracks', where: 'id == ?', whereArgs: [t.id]);
        } else {
          await db.update('Tracks', {'offline': 0}, where: 'id == ?', whereArgs: [t.id]);
        }
      }

      //Remove file
      try {
        File(p.join(offlinePath, t.id)).delete();
      } catch (e) {
        print(e);
      }
    }
  }

  Future removeOfflineAlbum(String id) async {
    //Get album
    List rawAlbums = await db.query('Albums', where: 'id == ?', whereArgs: [id]);
    if (rawAlbums.length == 0) return;
    Album album = Album.fromSQL(rawAlbums[0]);
    //Remove album
    await db.delete('Albums', where: 'id == ?', whereArgs: [id]);
    //Remove tracks
    await removeOfflineTracks(album.tracks);
  }

  Future removeOfflinePlaylist(String id) async {
    //Fetch playlist
    List rawPlaylists = await db.query('Playlists', where: 'id == ?', whereArgs: [id]);
    if (rawPlaylists.length == 0) return;
    Playlist playlist = Playlist.fromSQL(rawPlaylists[0]);
    //Remove playlist
    await db.delete('Playlists', where: 'id == ?', whereArgs: [id]);
    await removeOfflineTracks(playlist.tracks);
  }

  //Check if album, track or playlist is offline
  Future<bool> checkOffline({Album album, Track track, Playlist playlist}) async {
    //Track
    if (track != null) {
      List res = await db.query('Tracks', where: 'id == ? AND offline == 1', whereArgs: [track.id]);
      if (res.length == 0) return false;
      return true;
    }
    //Album
    if (album != null) {
      List res = await db.query('Albums', where: 'id == ? AND offline == 1', whereArgs: [album.id]);
      if (res.length == 0) return false;
      return true;
    }
    //Playlist
    if (playlist != null && playlist.id != null) {
      List res = await db.query('Playlists', where: 'id == ?', whereArgs: [playlist.id]);
      if (res.length == 0) return false;
      return true;
    }
    return false;
  }

  //Offline search
  Future<SearchResults> search(String query) async {
    SearchResults results = SearchResults(tracks: [], albums: [], artists: [], playlists: []);
    //Tracks
    List tracksData = await db.rawQuery('SELECT * FROM Tracks WHERE offline == 1 AND title like "%$query%"');
    for (Map trackData in tracksData) {
      results.tracks.add(await getOfflineTrack(trackData['id']));
    }
    //Albums
    List albumsData = await db.rawQuery('SELECT (id) FROM Albums WHERE offline == 1 AND title like "%$query%"');
    for (Map rawAlbum in albumsData) {
      results.albums.add(await getOfflineAlbum(rawAlbum['id']));
    }
    //Playlists
    List playlists = await db.rawQuery('SELECT * FROM Playlists WHERE title like "%$query%"');
    for (Map playlist in playlists) {
      results.playlists.add(await getPlaylist(playlist['id']));
    }
    return results;
  }

  //Sanitize filename
  String sanitize(String input) {
    RegExp sanitize = RegExp(r'[\/\\\?\%\*\:\|\"\<\>]');
    return input.replaceAll(sanitize, '');
  }

  //Generate track download path
  String _generatePath(Track track, bool private, {String playlistName, int playlistTrackNumber, bool isSingleton = false}) {
    String path;
    if (private) {
      path = p.join(offlinePath, track.id);
    } else {
      //Download path
      path = settings.downloadPath;

      if (settings.playlistFolder && playlistName != null)
        path = p.join(path, sanitize(playlistName));

      if (settings.artistFolder)
        path = p.join(path, '%albumArtist%');

      //Album folder / with disk number
      if (settings.albumFolder) {
        if (settings.albumDiscFolder) {
          path = p.join(path, '%album%' + ' - Disk ' + (track.diskNumber??1).toString());
        } else {
          path = p.join(path, '%album%');
        }
      }
      //Final path
      path = p.join(path, isSingleton ? settings.singletonFilename : settings.downloadFilename);
      //Playlist track number variable (not accessible in service)
      if (playlistTrackNumber != null) {
        path = path.replaceAll('%playlistTrackNumber%', playlistTrackNumber.toString());
        path = path.replaceAll('%0playlistTrackNumber%', playlistTrackNumber.toString().padLeft(2, '0'));
      } else {
        path = path.replaceAll('%playlistTrackNumber%', '');
        path = path.replaceAll('%0playlistTrackNumber%', '');
      }
    }
    return path;
  }

  //Get stats for library screen
  Future<List<String>> getStats() async {
    //Get offline counts
    int trackCount = (await db.rawQuery('SELECT COUNT(*) FROM Tracks WHERE offline == 1'))[0]['COUNT(*)'];
    int albumCount = (await db.rawQuery('SELECT COUNT(*) FROM Albums WHERE offline == 1'))[0]['COUNT(*)'];
    int playlistCount = (await db.rawQuery('SELECT COUNT(*) FROM Playlists'))[0]['COUNT(*)'];
    //Free space
    double diskSpace = await DiskSpace.getFreeDiskSpace;
    //Used space
    List<FileSystemEntity> offlineStat = await Directory(offlinePath).list().toList();
    int offlineSize = 0;
    for (var fs in offlineStat) {
      offlineSize += (await fs.stat()).size;
    }
    //Return in list, //TODO: Make into class in future
    return ([
      trackCount.toString(),
      albumCount.toString(),
      playlistCount.toString(),
      filesize(offlineSize),
      filesize((diskSpace * 1000000).floor())
    ]);
  }

  //Send settings to download service
  Future updateServiceSettings() async {
    await platform.invokeMethod('updateSettings', settings.getServiceSettings());
  }

  //Check storage permission
  Future<bool> checkPermission() async {
    if (await Permission.storage.request().isGranted) {
      return true;
    } else {
      Fluttertoast.showToast(
        msg: 'Storage permission denied!'.i18n,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM
      );
      return false;
    }
  }

  //Remove download from queue/finished
  Future removeDownload(int id) async {
    await platform.invokeMethod('removeDownload', {'id': id});
  }

  //Restart failed downloads
  Future retryDownloads() async {
    await platform.invokeMethod('retryDownloads');
  }

  //Delete downloads by state
  Future removeDownloads(DownloadState state) async {
    await platform.invokeMethod('removeDownloads', {'state': DownloadState.values.indexOf(state)});
  }

}

class Download {
  int id;
  String path;
  bool private;
  String trackId;
  String md5origin;
  String mediaVersion;
  String title;
  String image;
  int quality;
  //Dynamic
  DownloadState state;
  int received;
  int filesize;

  Download({this.id, this.path, this.private, this.trackId, this.md5origin, this.mediaVersion,
    this.title, this.image, this.state, this.received, this.filesize, this.quality});

  //Get progress between 0 - 1
  double get progress {
    return ((received.toDouble()??0.0)/(filesize.toDouble()??1.0)).toDouble();
  }

  factory Download.fromJson(Map<dynamic, dynamic> data) {
    return Download(
      path: data['path'],
      image: data['image'],
      private: data['private'],
      trackId: data['trackId'],
      id: data['id'],
      state: DownloadState.values[data['state']],
      title: data['title'],
      quality: data['quality']
    );
  }

  //Change values from "update json"
  void updateFromJson(Map<dynamic, dynamic> data) {
    this.quality = data['quality'];
    this.received = data['received']??0;
    this.state = DownloadState.values[data['state']];
    //Prevent null division later
    this.filesize = ((data['filesize']??0) <= 0) ? 1 : (data['filesize']??1);
  }
  
  //Track to download JSON for service
  static Future<Map> jsonFromTrack(Track t, String path, {private = true, AudioQuality quality}) async {
    //Get download info
    if (t.playbackDetails == null || t.playbackDetails == []) {
      t = await deezerAPI.track(t.id);
    }
    return {
      "private": private,
      "trackId": t.id,
      "md5origin": t.playbackDetails[0],
      "mediaVersion": t.playbackDetails[1],
      "quality": private
      ? settings.getQualityInt(settings.offlineQuality)
      : settings.getQualityInt((quality??settings.downloadQuality)),
      "title": t.title,
      "path": path,
      "image": t.albumArt.thumb
    };
  }
}

//Has to be same order as in java
enum DownloadState {
  NONE,
  DOWNLOADING,
  POST,
  DONE,
  DEEZER_ERROR,
  ERROR
}