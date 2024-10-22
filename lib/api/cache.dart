import 'package:Saturn/api/definitions.dart';
import 'package:Saturn/api/deezer.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'dart:io';
import 'dart:convert';
import 'dart:async';


part 'cache.g.dart';

Cache cache;

//Cache for miscellaneous things
@JsonSerializable()
class Cache {

  //ID's of tracks that are in library
  List<String> libraryTracks = [];

  //Track ID of logged track, to prevent duplicates
  @JsonKey(ignore: true)
  String loggedTrackId;

  @JsonKey(defaultValue: [])
  List<Track> history = [];

  //All sorting cached
  @JsonKey(defaultValue: [])
  List<Sorting> sorts = [];

  //Sleep timer
  @JsonKey(ignore: true)
  DateTime sleepTimerTime;
  @JsonKey(ignore: true)
  StreamSubscription sleepTimer;

  //Search history
  @JsonKey(name: 'searchHistory2', toJson: _searchHistoryToJson, fromJson: _searchHistoryFromJson)
  List<SearchHistoryItem> searchHistory;

  //If download threads warning was shown
  @JsonKey(defaultValue: false)
  bool threadsWarning;

  //Last time update check
  @JsonKey(defaultValue: 0)
  int lastUpdateCheck;

  @JsonKey(ignore: true)
  bool wakelock = false;

  Cache({this.libraryTracks});

  //Wrapper to test if track is favorite against cache
  Future<bool> checkTrackFavorite(Track t) async {
      //LOAD FAVORITE TRACKS INTO CACHE
    Future<List<Track>> futureTracks = deezerAPI.playlistTracksPage(deezerAPI.favoritesPlaylistId, 0);
    List<Track> tracks = await futureTracks;
    for (Track track in tracks) {
      cache.libraryTracks.add(track.id); // add track id to cached favorites
    }
    if (t.favorite != null && t.favorite) return true;
    if (libraryTracks == null || libraryTracks.length == 0) return false;
    return libraryTracks.contains(t.id);
  }



  //Add to history
  void addToSearchHistory(dynamic item) async {
    if (searchHistory == null)
      searchHistory = [];

    // Remove duplicate
    int i = searchHistory.indexWhere((e) => e.data.id == item.id);
    if (i != -1) {
      searchHistory.removeAt(i);
    }

    if (item is Track)
      searchHistory.add(SearchHistoryItem(item, SearchHistoryItemType.TRACK));
    if (item is Album)
      searchHistory.add(SearchHistoryItem(item, SearchHistoryItemType.ALBUM));
    if (item is Artist)
      searchHistory.add(SearchHistoryItem(item, SearchHistoryItemType.ARTIST));
    if (item is Playlist)
      searchHistory.add(SearchHistoryItem(item, SearchHistoryItemType.PLAYLIST));

    await save();
  }

  //Save, load
  static Future<String> getPath() async {
    return p.join((await getApplicationDocumentsDirectory()).path, 'metacache.json');
  }

  static Future wipe() async {
    await File(await getPath()).delete();
  }

  static Future<Cache> load() async {
    File file = File(await Cache.getPath());
    //Doesn't exist, create new
    if (!(await file.exists())) {
      Cache c = Cache();
      await c.save();
      return c;
    }
    return Cache.fromJson(jsonDecode(await file.readAsString()));
  }

  Future save() async {
    File file = File(await Cache.getPath());
    file.writeAsString(jsonEncode(this.toJson()));
  }

  //JSON
  factory Cache.fromJson(Map<String, dynamic> json) => _$CacheFromJson(json);
  Map<String, dynamic> toJson() => _$CacheToJson(this);

  //Search History JSON
  static List<SearchHistoryItem> _searchHistoryFromJson(List<dynamic> json) {
    return (json??[]).map<SearchHistoryItem>((i) => _searchHistoryItemFromJson(i)).toList();
  }
  static SearchHistoryItem _searchHistoryItemFromJson(Map<String, dynamic> json) {
    SearchHistoryItemType type = SearchHistoryItemType.values[json['type']];
    dynamic data;
    switch (type) {
      case SearchHistoryItemType.TRACK:
        data = Track.fromJson(json['data']);
        break;
      case SearchHistoryItemType.ALBUM:
        data = Album.fromJson(json['data']);
        break;
      case SearchHistoryItemType.ARTIST:
        data = Artist.fromJson(json['data']);
        break;
      case SearchHistoryItemType.PLAYLIST:
        data = Playlist.fromJson(json['data']);
        break;
    }
    return SearchHistoryItem(data, type);
  }
  static List<Map<String, dynamic>> _searchHistoryToJson(List<SearchHistoryItem> data) => (data??[]).map<Map<String, dynamic>>((i) => {"type": i.type.index, "data": i.data.toJson()}).toList();
}

@JsonSerializable()
class SearchHistoryItem {
  dynamic data;
  SearchHistoryItemType type;

  SearchHistoryItem(this.data, this.type);
}


enum SearchHistoryItemType {
  TRACK,
  ALBUM,
  ARTIST,
  PLAYLIST
}