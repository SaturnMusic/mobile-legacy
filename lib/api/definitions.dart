import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:Saturn/api/cache.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:Saturn/translations.i18n.dart';

import 'dart:convert';
import 'dart:io';

part 'definitions.g.dart';

@JsonSerializable()
class Track {

  String id;
  String title;
  Album album;
  List<Artist> artists;
  Duration duration;
  ImageDetails albumArt;
  int trackNumber;
  bool offline;
  Lyrics lyrics;
  bool favorite;
  int diskNumber;
  bool explicit;
  //Date added to playlist / favorites
  int addedDate;

  List<dynamic> playbackDetails;

  Track({this.id, this.title, this.duration, this.album, this.playbackDetails, this.albumArt,
    this.artists, this.trackNumber, this.offline, this.lyrics, this.favorite, this.diskNumber, this.explicit, this.addedDate});

  String get artistString => artists.map<String>((art) => art.name).join(', ');
  String get durationString => "${duration.inMinutes}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}";

  //MediaItem
  MediaItem toMediaItem() => MediaItem(
      title: this.title,
      album: this.album.title,
      artist: this.artists[0].name,
      displayTitle: this.title,
      displaySubtitle: this.artistString,
      displayDescription: this.album.title,
      artUri: this.albumArt.full,
      duration: this.duration,
      id: this.id,
      extras: {
        "playbackDetails": jsonEncode(this.playbackDetails),
        "thumb": this.albumArt.thumb,
        "lyrics": jsonEncode(this.lyrics.toJson()),
        "albumId": this.album.id,
        "artists": jsonEncode(this.artists.map<Map>((art) => art.toJson()).toList())
      }
  );

  factory Track.fromMediaItem(MediaItem mi) {
    //Load album and artists.
    //It is stored separately, to save id and other metadata
    Album album = Album(title: mi.album);
    List<Artist> artists = [Artist(name: mi.displaySubtitle??mi.artist)];
    if (mi.extras != null) {
      album.id = mi.extras['albumId'];
      if (mi.extras['artists'] != null) {
        artists = jsonDecode(mi.extras['artists']).map<Artist>((j) => Artist.fromJson(j)).toList();
      }
    }
    List<String> playbackDetails;
    if (mi.extras['playbackDetails'] != null)
      playbackDetails = (jsonDecode(mi.extras['playbackDetails'])??[]).map<String>((e) => e.toString()).toList();

    return Track(
      title: mi.title??mi.displayTitle,
      artists: artists,
      album: album,
      id: mi.id,
      albumArt: ImageDetails(
        fullUrl: mi.artUri,
        thumbUrl: mi.extras['thumb']
      ),
      duration: mi.duration,
      playbackDetails: playbackDetails,
      lyrics: Lyrics.fromJson(jsonDecode(((mi.extras??{})['lyrics'])??"{}"))
    );
  }

  //JSON
  factory Track.fromPrivateJson(Map<dynamic, dynamic> json, {bool favorite = false}) {
    String title = json['SNG_TITLE'];
    if (json['VERSION'] != null && json['VERSION'] != '') {
      title = "${json['SNG_TITLE']} ${json['VERSION']}";
    }
    return Track(
      id: json['SNG_ID'].toString(),
      title: title,
      duration: Duration(seconds: int.parse(json['DURATION'])),
      albumArt: ImageDetails.fromPrivateString(json['ALB_PICTURE']),
      album: Album.fromPrivateJson(json),
      artists: (json['ARTISTS']??[json]).map<Artist>((dynamic art) =>
          Artist.fromPrivateJson(art)).toList(),
      trackNumber: int.parse((json['TRACK_NUMBER']??'0').toString()),
      playbackDetails: [json['MD5_ORIGIN'], json['MEDIA_VERSION']],
      lyrics: Lyrics(id: json['LYRICS_ID'].toString()),
      favorite: favorite,
      diskNumber: int.parse(json['DISK_NUMBER']??'1'),
      explicit: (json['EXPLICIT_LYRICS'].toString() == '1') ? true:false,
      addedDate: json['DATE_ADD']
    );
  }
  Map<String, dynamic> toSQL({off = false}) => {
    'id': id,
    'title': title,
    'album': album.id,
    'artists': artists.map<String>((dynamic a) => a.id).join(','),
    'duration': duration.inSeconds,
    'albumArt': albumArt.full,
    'trackNumber': trackNumber,
    'offline': off?1:0,
    'lyrics': jsonEncode(lyrics.toJson()),
    'favorite': (favorite??false) ? 1 : 0,
    'diskNumber': diskNumber,
    'explicit': (explicit??false) ? 1 : 0,
    //'favoriteDate': favoriteDate
  };
  factory Track.fromSQL(Map<String, dynamic> data) => Track(
    id: data['trackId']??data['id'], //If loading from downloads table
    title: data['title'],
    album: Album(id: data['album']),
    duration: Duration(seconds: data['duration']),
    albumArt: ImageDetails(fullUrl: data['albumArt']),
    trackNumber: data['trackNumber'],
    artists: List<Artist>.generate(data['artists'].split(',').length, (i) => Artist(
      id: data['artists'].split(',')[i]
    )),
    offline: (data['offline'] == 1) ? true:false,
    lyrics: Lyrics.fromJson(jsonDecode(data['lyrics'])),
    favorite: (data['favorite'] == 1) ? true:false,
    diskNumber: data['diskNumber'],
    explicit: (data['explicit'] == 1) ? true:false,
    //favoriteDate: data['favoriteDate']
  );

  factory Track.fromJson(Map<String, dynamic> json) => _$TrackFromJson(json);
  Map<String, dynamic> toJson() => _$TrackToJson(this);
}

enum AlbumType {
  ALBUM,
  SINGLE,
  FEATURED
}

@JsonSerializable()
class Album {
  String id;
  String title;
  List<Artist> artists;
  List<Track> tracks;
  ImageDetails art;
  int fans;
  bool offline; //If the album is offline, or just saved in db as metadata
  bool library;
  AlbumType type;
  String releaseDate;
  String favoriteDate;

  Album({this.id, this.title, this.art, this.artists, this.tracks, this.fans, this.offline, this.library, this.type, this.releaseDate, this.favoriteDate});

  String get artistString => artists.map<String>((art) => art.name).join(', ');
  Duration get duration => Duration(seconds: tracks.fold(0, (v, t) => v += t.duration.inSeconds));
  String get durationString => "${duration.inMinutes}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}";
  String get fansString => NumberFormat.compact().format(fans);

  //JSON
  factory Album.fromPrivateJson(Map<dynamic, dynamic> json, {Map<dynamic, dynamic> songsJson = const {}, bool library = false}) {
    AlbumType type = AlbumType.ALBUM;
    if (json['TYPE'] != null && json['TYPE'].toString() == "0") type = AlbumType.SINGLE;
    if (json['ROLE_ID'] == 5) type = AlbumType.FEATURED;

    return Album(
      id: json['ALB_ID'].toString(),
      title: json['ALB_TITLE'],
      art: ImageDetails.fromPrivateString(json['ALB_PICTURE']),
      artists: (json['ARTISTS']??[json]).map<Artist>((dynamic art) => Artist.fromPrivateJson(art)).toList(),
      tracks: (songsJson['data']??[]).map<Track>((dynamic track) => Track.fromPrivateJson(track)).toList(),
      fans: json['NB_FAN'],
      library: library,
      type: type,
      releaseDate: json['DIGITAL_RELEASE_DATE']??json['PHYSICAL_RELEASE_DATE'],
      favoriteDate: json['DATE_FAVORITE']
    );
  }
  Map<String, dynamic> toSQL({off = false}) => {
    'id': id,
    'title': title,
    'artists': (artists??[]).map<String>((dynamic a) => a.id).join(','),
    'tracks': (tracks??[]).map<String>((dynamic t) => t.id).join(','),
    'art': art?.full??'',
    'fans': fans,
    'offline': off?1:0,
    'library': (library??false)?1:0,
    'type': AlbumType.values.indexOf(type),
    'releaseDate': releaseDate,
    //'favoriteDate': favoriteDate
  };
  factory Album.fromSQL(Map<String, dynamic> data) => Album(
    id: data['id'],
    title: data['title'],
    artists: List<Artist>.generate(data['artists'].split(',').length, (i) => Artist(
      id: data['artists'].split(',')[i]
    )),
    tracks: List<Track>.generate(data['tracks'].split(',').length, (i) => Track(
      id: data['tracks'].split(',')[i]
    )),
    art: ImageDetails(fullUrl: data['art']),
    fans: data['fans'],
    offline: (data['offline'] == 1) ? true:false,
    library: (data['library'] == 1) ? true:false,
    type: AlbumType.values[(data['type'] == -1) ? 0 : data['type']],
    releaseDate: data['releaseDate'],
    //favoriteDate: data['favoriteDate']
  );

  factory Album.fromJson(Map<String, dynamic> json) => _$AlbumFromJson(json);
  Map<String, dynamic> toJson() => _$AlbumToJson(this);
}

enum ArtistHighlightType {
  ALBUM
}

@JsonSerializable()
class ArtistHighlight {
  dynamic data;
  ArtistHighlightType type;
  String title;

  ArtistHighlight({this.data, this.type, this.title});

  factory ArtistHighlight.fromPrivateJson(Map<dynamic, dynamic> json) {
    if (json == null || json['ITEM'] == null) return null;
    switch (json['TYPE']) {
      case 'album':
        return ArtistHighlight(data: Album.fromPrivateJson(json['ITEM']), type: ArtistHighlightType.ALBUM, title: json['TITLE']);
    }
    return null;
  }

  //JSON
  factory ArtistHighlight.fromJson(Map<String, dynamic> json) => _$ArtistHighlightFromJson(json);
  Map<String, dynamic> toJson() => _$ArtistHighlightToJson(this);
}

@JsonSerializable()
class Artist {
  String id;
  String name;
  List<Album> albums;
  int albumCount;
  List<Track> topTracks;
  ImageDetails picture;
  int fans;
  bool offline;
  bool library;
  bool radio;
  String favoriteDate;
  ArtistHighlight highlight;

  Artist({this.id, this.name, this.albums, this.albumCount, this.topTracks, this.picture, this.fans, this.offline, this.library, this.radio, this.favoriteDate, this.highlight});

  String get fansString => NumberFormat.compact().format(fans);

  //JSON
  factory Artist.fromPrivateJson(
      Map<dynamic, dynamic> json, {
        Map<dynamic, dynamic> albumsJson = const {},
        Map<dynamic, dynamic> topJson = const {},
        Map<dynamic, dynamic> highlight = null,
        bool library = false
      }) {
    //Get wether radio is available
    bool _radio = false;
    if (json['SMARTRADIO'] == true || json['SMARTRADIO'] == 1) _radio = true;

    return Artist(
      id: json['ART_ID'].toString(),
      name: json['ART_NAME'],
      fans: json['NB_FAN'],
      picture: ImageDetails.fromPrivateString(json['ART_PICTURE'], type: 'artist'),
      albumCount: albumsJson['total'],
      albums: (albumsJson['data']??[]).map<Album>((dynamic data) => Album.fromPrivateJson(data)).toList(),
      topTracks: (topJson['data']??[]).map<Track>((dynamic data) => Track.fromPrivateJson(data)).toList(),
      library: library,
      radio: _radio,
      favoriteDate: json['DATE_FAVORITE'],
      highlight: ArtistHighlight.fromPrivateJson(highlight)
    );
  }
  Map<String, dynamic> toSQL({off = false}) => {
    'id': id,
    'name': name,
    'albums': albums.map<String>((dynamic a) => a.id).join(','),
    'topTracks': topTracks.map<String>((dynamic t) => t.id).join(','),
    'picture': picture.full,
    'fans': fans,
    'albumCount': this.albumCount??(this.albums??[]).length,
    'offline': off?1:0,
    'library': (library??false)?1:0,
    'radio': radio?1:0,
    //'favoriteDate': favoriteDate
  };
  factory Artist.fromSQL(Map<String, dynamic> data) => Artist(
    id: data['id'],
    name: data['name'],
    topTracks: List<Track>.generate(data['topTracks'].split(',').length, (i) => Track(
      id: data['topTracks'].split(',')[i]
    )),
    albums: List<Album>.generate(data['albums'].split(',').length, (i) => Album(
      id: data['albums'].split(',')[i]
    )),
    albumCount: data['albumCount'],
    picture: ImageDetails(fullUrl: data['picture']),
    fans: data['fans'],
    offline: (data['offline'] == 1)?true:false,
    library: (data['library'] == 1)?true:false,
    radio: (data['radio'] == 1)?true:false,
    //favoriteDate: data['favoriteDate']
  );

  factory Artist.fromJson(Map<String, dynamic> json) => _$ArtistFromJson(json);
  Map<String, dynamic> toJson() => _$ArtistToJson(this);
}

@JsonSerializable()
class Playlist {
  String id;
  String title;
  List<Track> tracks;
  ImageDetails image;
  Duration duration;
  int trackCount;
  User user;
  int fans;
  bool library;
  String description;

  Playlist({this.id, this.title, this.tracks, this.image, this.trackCount, this.duration, this.user, this.fans, this.library, this.description});

  String get durationString => "${duration.inHours}:${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}";

  //JSON
  factory Playlist.fromPrivateJson(Map<dynamic, dynamic> json, {Map<dynamic, dynamic> songsJson = const {}, bool library = false}) => Playlist(
    id: json['PLAYLIST_ID'].toString(),
    title: json['TITLE'],
    trackCount: json['NB_SONG']??songsJson['total'],
    image: ImageDetails.fromPrivateString(json['PLAYLIST_PICTURE'], type: json['PICTURE_TYPE']),
    fans: json['NB_FAN'],
    duration: Duration(seconds: json['DURATION']??0),
    description: json['DESCRIPTION'],
    user: User(
      id: json['PARENT_USER_ID'],
      name: json['PARENT_USERNAME']??'',
      picture: ImageDetails.fromPrivateString(json['PARENT_USER_PICTURE'], type: 'user')
    ),
    tracks: (songsJson['data']??[]).map<Track>((dynamic data) => Track.fromPrivateJson(data)).toList(),
    library: library
  );
  Map<String, dynamic> toSQL() => {
    'id': id,
    'title': title,
    'tracks': tracks.map<String>((dynamic t) => t.id).join(','),
    'image': image.full,
    'duration': duration.inSeconds,
    'userId': user.id,
    'userName': user.name,
    'fans': fans,
    'description': description,
    'library': (library??false)?1:0
  };
  factory Playlist.fromSQL(data) => Playlist(
    id: data['id'],
    title: data['title'],
    description: data['description'],
    tracks: List<Track>.generate(data['tracks'].split(',').length, (i) => Track(
      id: data['tracks'].split(',')[i]
    )),
    image: ImageDetails(fullUrl: data['image']),
    duration: Duration(seconds: data['duration']),
    user: User(
      id: data['userId'],
      name: data['userName']
    ),
    fans: data['fans'],
    library: (data['library'] == 1)?true:false
  );

  factory Playlist.fromJson(Map<String, dynamic> json) => _$PlaylistFromJson(json);
  Map<String, dynamic> toJson() => _$PlaylistToJson(this);
}

@JsonSerializable()
class User {
  String id;
  String name;
  ImageDetails picture;

  User({this.id, this.name, this.picture});

  //Mostly handled by playlist

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
}

@JsonSerializable()
class ImageDetails {
  String fullUrl;
  String thumbUrl;

  ImageDetails({this.fullUrl, this.thumbUrl});

  //Get full/thumb with fallback
  String get full => fullUrl??thumbUrl;
  String get thumb => thumbUrl??fullUrl;

  //JSON
  factory ImageDetails.fromPrivateString(String art, {String type='cover'}) => ImageDetails(
    fullUrl: 'https://e-cdns-images.dzcdn.net/images/$type/$art/1000x1000-000000-80-0-0.jpg',
    thumbUrl: 'https://e-cdns-images.dzcdn.net/images/$type/$art/140x140-000000-80-0-0.jpg'
  );
  factory ImageDetails.fromPrivateJson(Map<dynamic, dynamic> json) => ImageDetails.fromPrivateString(
    json['MD5'].split('-').first,
    type: json['TYPE']
  );

  factory ImageDetails.fromJson(Map<String, dynamic> json) => _$ImageDetailsFromJson(json);
  Map<String, dynamic> toJson() => _$ImageDetailsToJson(this);
}

class SearchResults {
  List<Track> tracks;
  List<Album> albums;
  List<Artist> artists;
  List<Playlist> playlists;
  List<Show> shows;
  List<ShowEpisode> episodes;

  SearchResults({this.tracks, this.albums, this.artists, this.playlists, this.shows, this.episodes});

  //Check if no search results
  bool get empty {
    return ((tracks == null || tracks.length == 0) &&
        (albums == null || albums.length == 0) &&
        (artists == null || artists.length == 0) &&
        (playlists == null || playlists.length == 0) &&
        (shows == null || shows.length == 0) &&
        (episodes == null || episodes.length == 0));
  }

  factory SearchResults.fromPrivateJson(Map<dynamic, dynamic> json) => SearchResults(
    tracks: json['TRACK']['data'].map<Track>((dynamic data) => Track.fromPrivateJson(data)).toList(),
    albums: json['ALBUM']['data'].map<Album>((dynamic data) => Album.fromPrivateJson(data)).toList(),
    artists: json['ARTIST']['data'].map<Artist>((dynamic data) => Artist.fromPrivateJson(data)).toList(),
    playlists: json['PLAYLIST']['data'].map<Playlist>((dynamic data) => Playlist.fromPrivateJson(data)).toList(),
    shows: json['SHOW']['data'].map<Show>((dynamic data) => Show.fromPrivateJson(data)).toList(),
    episodes: json['EPISODE']['data'].map<ShowEpisode>((dynamic data) => ShowEpisode.fromPrivateJson(data)).toList()
  );
}

@JsonSerializable()
class Lyrics {
  String id;
  String writers;
  List<Lyric> lyrics;

  Lyrics({this.id, this.writers, this.lyrics});

  static error() => Lyrics(
    id: null,
    writers: null,
    lyrics: [Lyric(
      offset: Duration(milliseconds: 0),
      text: 'Lyrics unavailable, empty or failed to load!'.i18n
    )]
  );

  //JSON
  factory Lyrics.fromPrivateJson(Map<dynamic, dynamic> json) {
    Lyrics l = Lyrics(
      id: json['LYRICS_ID'],
      writers: json['LYRICS_WRITERS'],
      lyrics: (json['LYRICS_SYNC_JSON']??[]).map<Lyric>((l) => Lyric.fromPrivateJson(l)).toList()
    );
    //Clean empty lyrics
    l.lyrics.removeWhere((l) => l.offset == null);
    return l;
  }

  factory Lyrics.fromJson(Map<String, dynamic> json) => _$LyricsFromJson(json);
  Map<String, dynamic> toJson() => _$LyricsToJson(this);
}

@JsonSerializable()
class Lyric {
  Duration offset;
  String text;
  String lrcTimestamp;

  Lyric({this.offset, this.text, this.lrcTimestamp});

  //JSON
  factory Lyric.fromPrivateJson(Map<dynamic, dynamic> json) {
    if (json['milliseconds'] == null || json['line'] == null) return Lyric(); //Empty lyric
    return Lyric(
      offset: Duration(milliseconds: int.parse(json['milliseconds'].toString())),
      text: json['line'],
      lrcTimestamp: json['lrc_timestamp']
    );
  }

  factory Lyric.fromJson(Map<String, dynamic> json) => _$LyricFromJson(json);
  Map<String, dynamic> toJson() => _$LyricToJson(this);
}

@JsonSerializable()
class QueueSource {
  String id;
  String text;
  String source;

  QueueSource({this.id, this.text, this.source});

  factory QueueSource.fromJson(Map<String, dynamic> json) => _$QueueSourceFromJson(json);
  Map<String, dynamic> toJson() => _$QueueSourceToJson(this);
}

@JsonSerializable()
class SmartTrackList {
  String id;
  String title;
  String subtitle;
  String description;
  int trackCount;
  List<Track> tracks;
  ImageDetails cover;

  SmartTrackList({this.id, this.title, this.description, this.trackCount, this.tracks, this.cover, this.subtitle});

  //JSON
  factory SmartTrackList.fromPrivateJson(Map<dynamic, dynamic> json, {Map<dynamic, dynamic> songsJson = const {}}) => SmartTrackList(
    id: json['SMARTTRACKLIST_ID'],
    title: json['TITLE'],
    subtitle: json['SUBTITLE'],
    description: json['DESCRIPTION'],
    trackCount: json['NB_SONG']??(songsJson['total']),
    tracks: (songsJson['data']??[]).map<Track>((t) => Track.fromPrivateJson(t)).toList(),
    cover: ImageDetails.fromPrivateJson(json['COVER'])
  );

  factory SmartTrackList.fromJson(Map<String, dynamic> json) => _$SmartTrackListFromJson(json);
  Map<String, dynamic> toJson() => _$SmartTrackListToJson(this);
}

@JsonSerializable()
class HomePage {

  List<HomePageSection> sections;

  HomePage({this.sections});

  //Save/Load
  Future<String> _getPath() async {
    Directory d = await getApplicationDocumentsDirectory();
    return p.join(d.path, 'homescreen.json');
  }
  Future exists() async {
    String path = await _getPath();
    return await File(path).exists();
  }
  Future save() async {
    String path = await _getPath();
    await File(path).writeAsString(jsonEncode(this.toJson()));
  }
  Future<HomePage> load() async {
    String path = await _getPath();
    Map data = jsonDecode(await File(path).readAsString());
    return HomePage.fromJson(data);
  }
  Future wipe() async {
    await File(await _getPath()).delete();
  }

  //JSON
  factory HomePage.fromPrivateJson(Map<dynamic, dynamic> json) {
    HomePage hp = HomePage(sections: []);
    //Parse every section
    for (var s in (json['sections']??[])) {
      HomePageSection section = HomePageSection.fromPrivateJson(s);
      if (section != null) hp.sections.add(section);
    }
    return hp;
  }

  factory HomePage.fromJson(Map<String, dynamic> json) => _$HomePageFromJson(json);
  Map<String, dynamic> toJson() => _$HomePageToJson(this);
}

@JsonSerializable()
class HomePageSection {

  String title;
  HomePageSectionLayout layout;

  //For loading more items
  String pagePath;
  bool hasMore;

  @JsonKey(fromJson: _homePageItemFromJson, toJson: _homePageItemToJson)
  List<HomePageItem> items;

  HomePageSection({this.layout, this.items, this.title, this.pagePath, this.hasMore});

  //JSON
  factory HomePageSection.fromPrivateJson(Map<dynamic, dynamic> json) {
    HomePageSection hps = HomePageSection(
      title: json['title'],
      items: [],
      pagePath: json['target'],
      hasMore: json['hasMoreItems']??false
    );

    String layout = json['layout'];
    switch (layout) {
      case 'ads':
        return null;
      case 'horizontal-grid':
        hps.layout = HomePageSectionLayout.ROW;
        break;
      case 'grid':
        hps.layout = HomePageSectionLayout.GRID;
        break;
      default:
        return null;
    }

    //Parse items
    for (var i in (json['items']??[])) {
      HomePageItem hpi = HomePageItem.fromPrivateJson(i);
      if (hpi != null) hps.items.add(hpi);
    }
    return hps;
  }

  factory HomePageSection.fromJson(Map<String, dynamic> json) => _$HomePageSectionFromJson(json);
  Map<String, dynamic> toJson() => _$HomePageSectionToJson(this);

  static _homePageItemFromJson(json) => json.map<HomePageItem>((d) => HomePageItem.fromJson(d)).toList();
  static _homePageItemToJson(items) => items.map((i) => i.toJson()).toList();
}

class HomePageItem {
  HomePageItemType type;
  dynamic value;

  HomePageItem({this.type, this.value});

  factory HomePageItem.fromPrivateJson(Map<dynamic, dynamic> json) {
    String type = json['type'];
    switch (type) {
      //Smart Track List
      case 'flow':
      case 'smarttracklist':
        return HomePageItem(type: HomePageItemType.SMARTTRACKLIST, value: SmartTrackList.fromPrivateJson(json['data']));
      case 'playlist':
        return HomePageItem(type: HomePageItemType.PLAYLIST, value: Playlist.fromPrivateJson(json['data']));
      case 'artist':
        return HomePageItem(type: HomePageItemType.ARTIST, value: Artist.fromPrivateJson(json['data']));
      case 'channel':
        return HomePageItem(type: HomePageItemType.CHANNEL, value: DeezerChannel.fromPrivateJson(json));
      case 'album':
        return HomePageItem(type: HomePageItemType.ALBUM, value: Album.fromPrivateJson(json['data']));
      case 'show':
        return HomePageItem(type: HomePageItemType.SHOW, value: Show.fromPrivateJson(json['data']));
      default:
        return null;
    }
  }

  factory HomePageItem.fromJson(Map<String, dynamic> json) {
    String _t = json['type'];
    switch (_t) {
      case 'SMARTTRACKLIST':
        return HomePageItem(type: HomePageItemType.SMARTTRACKLIST, value: SmartTrackList.fromJson(json['value']));
      case 'PLAYLIST':
        return HomePageItem(type: HomePageItemType.PLAYLIST, value: Playlist.fromJson(json['value']));
      case 'ARTIST':
        return HomePageItem(type: HomePageItemType.ARTIST, value: Artist.fromJson(json['value']));
      case 'CHANNEL':
        return HomePageItem(type: HomePageItemType.CHANNEL, value: DeezerChannel.fromJson(json['value']));
      case 'ALBUM':
        return HomePageItem(type: HomePageItemType.ALBUM, value: Album.fromJson(json['value']));
      case 'SHOW':
        return HomePageItem(type: HomePageItemType.SHOW, value: Show.fromPrivateJson(json['value']));
      default:
        return HomePageItem();
    }
  }

  Map<String, dynamic> toJson() {
    String type = this.type.toString().split('.').last;
    return {'type': type, 'value': value.toJson()};
  }

}

@JsonSerializable()
class DeezerChannel {

  String id;
  String target;
  String title;
  @JsonKey(fromJson: _colorFromJson, toJson: _colorToJson)
  Color backgroundColor;

  DeezerChannel({this.id, this.title, this.backgroundColor, this.target});

factory DeezerChannel.fromPrivateJson(Map<dynamic, dynamic> json) {
  String backgroundColorHex = json['background_color'];
  String target = json['target']?.replaceFirst('/', ''); // Ensure 'target' is not null before manipulation

  // Handle null or empty backgroundColorHex gracefully
  Color backgroundColor;
  if (backgroundColorHex != null && backgroundColorHex.isNotEmpty) {
    backgroundColor = Color(int.parse(backgroundColorHex.replaceFirst('#', 'FF'), radix: 16));
  } else {
    backgroundColor = Colors.transparent; // or any default color
    debugPrint('Warning: Background color is missing or invalid for DeezerChannel');
  }

  return DeezerChannel(
    id: json['id'],
    title: json['title'],
    backgroundColor: backgroundColor,
    target: target,
  );
}


  //JSON
  static _colorToJson(Color c) => c.value;
  static _colorFromJson(int v) => Color(v??Colors.blue.value);
  factory DeezerChannel.fromJson(Map<String, dynamic> json) => _$DeezerChannelFromJson(json);
  Map<String, dynamic> toJson() => _$DeezerChannelToJson(this);
}

enum HomePageItemType {
  SMARTTRACKLIST,
  PLAYLIST,
  ARTIST,
  CHANNEL,
  ALBUM,
  SHOW
}

enum HomePageSectionLayout {
  ROW,
  GRID
}

enum RepeatType {
  NONE,
  LIST,
  TRACK
}

enum DeezerLinkType {
  TRACK,
  ALBUM,
  ARTIST,
  PLAYLIST
}

class DeezerLinkResponse {
  DeezerLinkType type;
  String id;

  DeezerLinkResponse({this.type, this.id});

  //String to DeezerLinkType
  static typeFromString(String t) {
    t = t.toLowerCase().trim();
    if (t == 'album') return DeezerLinkType.ALBUM;
    if (t == 'artist') return DeezerLinkType.ARTIST;
    if (t == 'playlist') return DeezerLinkType.PLAYLIST;
    if (t == 'track') return DeezerLinkType.TRACK;
    return null;
  }
}

//Sorting
enum SortType {
  DEFAULT,
  ALPHABETIC,
  ARTIST,
  ALBUM,
  RELEASE_DATE,
  POPULARITY,
  USER,
  TRACK_COUNT,
  DATE_ADDED
}

enum SortSourceTypes {
  //Library
  TRACKS,
  PLAYLISTS,
  ALBUMS,
  ARTISTS,

  PLAYLIST
}

@JsonSerializable()
class Sorting {
  SortType type;
  bool reverse;

  //For preserving sorting
  String id;
  SortSourceTypes sourceType;

  Sorting({this.type = SortType.DEFAULT, this.reverse = false, this.id, this.sourceType});

  //Find index of sorting from cache
  static int index(SortSourceTypes type, {String id}) {
    //Empty cache
    if (cache.sorts == null) {
      cache.sorts = [];
      cache.save();
      return null;
    }
    //Find index
    int index;
    if (id != null)
      index = cache.sorts.indexWhere((s) => s.sourceType == type && s.id == id);
    else
      index = cache.sorts.indexWhere((s) => s.sourceType == type);
    if (index == -1)
      return null;
    return index;
  }

  factory Sorting.fromJson(Map<String, dynamic> json) => _$SortingFromJson(json);
  Map<String, dynamic> toJson() => _$SortingToJson(this);
}

@JsonSerializable()
class Show {

  String name;
  String description;
  ImageDetails art;
  String id;

  Show({this.name, this.description, this.art, this.id});

  //JSON
  factory Show.fromPrivateJson(Map<dynamic, dynamic> json) => Show(
    id: json['SHOW_ID'],
    name: json['SHOW_NAME'],
    art: ImageDetails.fromPrivateString(json['SHOW_ART_MD5'], type: 'talk'),
    description: json['SHOW_DESCRIPTION']
  );

  factory Show.fromJson(Map<String, dynamic> json) => _$ShowFromJson(json);
  Map<String, dynamic> toJson() => _$ShowToJson(this);
}

@JsonSerializable()
class ShowEpisode {

  String id;
  String title;
  String description;
  String url;
  Duration duration;
  String publishedDate;
  //Might not be fully available
  Show show;

  ShowEpisode({this.id, this.title, this.description, this.url, this.duration, this.publishedDate, this.show});

  String get durationString => "${duration.inMinutes}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}";

  //Generate MediaItem for playback
  MediaItem toMediaItem(Show show) {
    return MediaItem(
      title: title,
      displayTitle: title,
      displaySubtitle: show.name,
      album: show.name,
      id: id,
      extras: {
        'showUrl': url,
        'show': jsonEncode(show.toJson()),
        'thumb': show.art.thumb
      },
      displayDescription: description,
      duration: duration,
      artUri: show.art.full,
    );
  }
  factory ShowEpisode.fromMediaItem(MediaItem mi) {
    return ShowEpisode(
      id: mi.id,
      title: mi.title,
      description: mi.displayDescription,
      url: mi.extras['showUrl'],
      duration: mi.duration,
      show: Show.fromPrivateJson(mi.extras['show'])
    );
  }

  //JSON
  factory ShowEpisode.fromPrivateJson(Map<dynamic, dynamic> json) => ShowEpisode(
    id: json['EPISODE_ID'],
    title: json['EPISODE_TITLE'],
    description: json['EPISODE_DESCRIPTION'],
    url: json['EPISODE_DIRECT_STREAM_URL'],
    duration: Duration(seconds: int.parse(json['DURATION'].toString())),
    publishedDate: json['EPISODE_PUBLISHED_TIMESTAMP'],
    show: Show.fromPrivateJson(json)
  );

  factory ShowEpisode.fromJson(Map<String, dynamic> json) => _$ShowEpisodeFromJson(json);
  Map<String, dynamic> toJson() => _$ShowEpisodeToJson(this);
}

class StreamQualityInfo {
  String format;
  int size;
  String source;

  StreamQualityInfo({this.format, this.size, this.source});

  factory StreamQualityInfo.fromJson(Map json) => StreamQualityInfo(
    format: json['format'],
    size: json['size'],
    source: json['source']
  );

  int bitrate(Duration duration) {
    if (size == null || size == 0) return 0;
    int bitrate = (((size * 8) / 1000) / duration.inSeconds).round();
    //Round to known values
    if (bitrate > 122 && bitrate < 134)
      return 128;
    if (bitrate > 315 && bitrate < 325)
      return 320;
    return bitrate;
  }
}