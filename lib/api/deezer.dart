import 'package:audio_service/audio_service.dart';
import 'package:Saturn/api/download.dart';
import 'package:Saturn/api/player.dart';
import 'package:crypto/crypto.dart';
import 'package:Saturn/api/definitions.dart';
import 'package:Saturn/api/spotify.dart';
import 'package:Saturn/settings.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; //logging
import 'package:flutter/services.dart';

import 'dart:convert';
import 'dart:async';

import '../settings.dart';
import '../main.dart';


DeezerAPI deezerAPI = DeezerAPI();

class DeezerAPI {

  DeezerAPI({this.arl});

  String arl;
  String token;
  String userId;
  String userName;
  String favoritesPlaylistId;
  String sid;

  Future _authorizing;

  //Get headers
  Map<String, String> get headers => {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.99 Safari/537.36",
    "Content-Language": '${settings.deezerLanguage??"en"}-${settings.deezerCountry??'US'}',
    "Cache-Control": "max-age=0",
    "Accept": "*/*",
    "Accept-Charset": "utf-8,ISO-8859-1;q=0.7,*;q=0.3",
    "Accept-Language": "${settings.deezerLanguage??"en"}-${settings.deezerCountry??'US'},${settings.deezerLanguage??"en"};q=0.9,en-US;q=0.8,en;q=0.7",
    "Connection": "keep-alive",
    "Cookie": "arl=${arl}" + ((sid == null) ? '' : '; sid=${sid}')
  };

  //Call private API
  Future<Map<dynamic, dynamic>> callApi(String method, {Map<dynamic, dynamic> params, String gatewayInput}) async {
    //Generate URL
    Uri uri = Uri.https('www.deezer.com', '/ajax/gw-light.php', {
      'api_version': '1.0',
      'api_token': this.token,
      'input': '3',
      'method': method,
      //Used for homepage
      if (gatewayInput != null)
        'gateway_input': gatewayInput
    });
    //Post
    http.Response res = await http.post(uri, headers: headers, body: jsonEncode(params));
    dynamic body = jsonDecode(res.body);
    //Grab SID
    if (method == 'deezer.getUserData') {
      for (String cookieHeader in res.headers['set-cookie'].split(';')) {
        if (cookieHeader.startsWith('sid=')) {
          sid = cookieHeader.split('=')[1];
        }
      }
    }
    // In case of error "Invalid CSRF token" retrieve new one and retry the same call
    if (body['error'].isNotEmpty && body['error'].containsKey('VALID_TOKEN_REQUIRED') && await rawAuthorize()) {
        return callApi(method, params: params, gatewayInput: gatewayInput);
    }
    return body;
  }

  Future<Map<dynamic, dynamic>> callPublicApi(String path) async {
    http.Response res = await http.get('https://api.deezer.com/' + path);
    return jsonDecode(res.body);
  }

  //Wrapper so it can be globally awaited
  Future authorize() async {
    if (_authorizing == null) {
      this._authorizing = this.rawAuthorize();
    }
    return _authorizing;
  }

  //Login with email
  static Future<String> getArlByEmail(String email, String password) async {
    //Get MD5 of password
    Digest digest = md5.convert(utf8.encode(password));
    String md5password = '$digest';
    //Get access token
    String url = "https://tv.deezer.com/smarttv/8caf9315c1740316053348a24d25afc7/user_auth.php?login=$email&password=$md5password&device=panasonic&output=json";
    http.Response response = await http.get(url);
    String accessToken = jsonDecode(response.body)["access_token"];
    //Get SID
    url = "https://api.deezer.com/platform/generic/track/42069";
    response = await http.get(url, headers: {"Authorization": "Bearer $accessToken"});
    String sid;
    for (String cookieHeader in response.headers['set-cookie'].split(';')) {
      if (cookieHeader.startsWith('sid=')) {
        sid = cookieHeader.split('=')[1];
      }
    }
    if (sid == null) return null;
    //Get ARL
    url = "https://deezer.com/ajax/gw-light.php?api_version=1.0&api_token=null&input=3&method=user.getArl";
    response = await http.get(url, headers: {"Cookie": "sid=$sid"});
    return jsonDecode(response.body)["results"];
  }


  //Authorize, bool = success
  Future<bool> rawAuthorize({Function onError}) async {
    try {
      Map<dynamic, dynamic> data = await callApi('deezer.getUserData');
      if (data['results']['USER']['USER_ID'] == 0) {
        return false;
      } else {
        this.token = data['results']['checkForm'];
        this.userId = data['results']['USER']['USER_ID'].toString();
        this.userName = data['results']['USER']['BLOG_NAME'];
        this.favoritesPlaylistId = data['results']['USER']['LOVEDTRACKS_ID'];
        return true;
      }
    } catch (e) {
      if (onError != null)
        onError(e);
      print('Login Error (D): ' + e.toString());
      return false;
    }
  }

  //URL/Link parser
  Future<DeezerLinkResponse> parseLink(String url) async {
    Uri uri = Uri.parse(url);
    //https://www.deezer.com/NOTHING_OR_COUNTRY/TYPE/ID
    if (uri.host == 'www.deezer.com' || uri.host == 'deezer.com') {
      if (uri.pathSegments.length < 2) return null;
      DeezerLinkType type = DeezerLinkResponse.typeFromString(uri.pathSegments[uri.pathSegments.length-2]);
      return DeezerLinkResponse(type: type, id: uri.pathSegments[uri.pathSegments.length-1]);
    }
    //Share URL
    if (uri.host == 'deezer.page.link' || uri.host == 'www.deezer.page.link') {
      http.BaseRequest request = http.Request('HEAD', Uri.parse(url));
      request.followRedirects = false;
      http.StreamedResponse response = await request.send();
      String newUrl = response.headers['location'];
      return parseLink(newUrl);
    }
    //Spotify
    if (uri.host == 'open.spotify.com') {
      if (uri.pathSegments.length < 2) return null;
      String spotifyUri = 'spotify:' + uri.pathSegments.sublist(0, 2).join(':');
      try {
        //Tracks
        if (uri.pathSegments[0] == 'track') {
          String id = await SpotifyScrapper.convertTrack(spotifyUri);
          return DeezerLinkResponse(type: DeezerLinkType.TRACK, id: id);
        }
        //Albums
        if (uri.pathSegments[0] == 'album') {
          String id = await SpotifyScrapper.convertAlbum(spotifyUri);
          return DeezerLinkResponse(type: DeezerLinkType.ALBUM, id: id);
        }
      } catch (e) {}
    }
  }

  //Check if Deezer available in country
  static Future<bool> chceckAvailability() async {
      try {
        http.Response res = await http.get("https://api.deezer.com/infos");
        return jsonDecode(res.body)["open"];
      } catch (e) {
        return null;
      }
  }

  //Search
  Future<SearchResults> search(String query) async {
    Map<dynamic, dynamic> data = await callApi('deezer.pageSearch', params: {
      'nb': 128,
      'query': query,
      'start': 0
    });
    return SearchResults.fromPrivateJson(data['results']);
  }

  Future<Track> track(String id) async {
    Map<dynamic, dynamic> data = await callApi('song.getListData', params: {'sng_ids': [id]});
    return Track.fromPrivateJson(data['results']['data'][0]);
  }

  //Get album details, tracks
  Future<Album> album(String id) async {
      Map<dynamic, dynamic> data = await callApi('deezer.pageAlbum', params: {
        'alb_id': id,
        'header': true,
        'lang': settings.deezerLanguage??'en'
      });
      return Album.fromPrivateJson(data['results']['DATA'], songsJson: data['results']['SONGS']);
  }

  //Get artist details
  Future<Artist> artist(String id) async {
    Map<dynamic, dynamic> data = await callApi('deezer.pageArtist', params: {
      'art_id': id,
      'lang': settings.deezerLanguage??'en',
    });
    return Artist.fromPrivateJson(
      data['results']['DATA'],
      topJson: data['results']['TOP'],
      albumsJson: data['results']['ALBUMS'],
      highlight: data['results']['HIGHLIGHT']
    );
  }

  //Get playlist tracks at offset
  Future<List<Track>> playlistTracksPage(String id, int start, {int nb = 50}) async {
    Map data = await callApi('deezer.pagePlaylist', params: {
      'playlist_id': id,
      'lang': settings.deezerLanguage??'en',
      'nb': nb,
      'tags': true,
      'start': start
    });
    return data['results']['SONGS']['data'].map<Track>((json) => Track.fromPrivateJson(json)).toList();
  }

  //Get playlist details
  Future<Playlist> playlist(String id, {int nb = 100}) async {
    Map<dynamic, dynamic> data = await callApi('deezer.pagePlaylist', params: {
      'playlist_id': id,
      'lang': settings.deezerLanguage??'en',
      'nb': nb,
      'tags': true,
      'start': 0
    });
    return Playlist.fromPrivateJson(data['results']['DATA'], songsJson: data['results']['SONGS']);
  }

  //Get playlist with all tracks
  Future<Playlist> fullPlaylist(String id) async {
    return await playlist(id, nb: 100000);
  }

  //Add track to favorites
  Future addFavoriteTrack(String id) async {
    await callApi('favorite_song.add', params: {'SNG_ID': id});
  }

  //Add album to favorites/library
  Future addFavoriteAlbum(String id) async {
    await callApi('album.addFavorite', params: {'ALB_ID': id});
  }

  //Add artist to favorites/library
  Future addFavoriteArtist(String id) async {
    await callApi('artist.addFavorite', params: {'ART_ID': id});
  }

  //Remove artist from favorites/library
  Future removeArtist(String id) async {
    await callApi('artist.deleteFavorite', params: {'ART_ID': id});
  }

  // Mark track as disliked
  Future dislikeTrack(String id) async {
    await callApi('favorite_dislike.add', params: {'ID': id, 'TYPE': 'song'});
  }

  //Add tracks to playlist
  Future addToPlaylist(String trackId, String playlistId, {int offset = -1}) async {
    await callApi('playlist.addSongs', params: {
      'offset': offset,
      'playlist_id': playlistId,
      'songs': [[trackId, 0]]
    });
  }

  //Remove track from playlist
  Future removeFromPlaylist(String trackId, String playlistId) async {
    await callApi('playlist.deleteSongs', params: {
      'playlist_id': playlistId,
      'songs': [[trackId, 0]]
    });
  }

  //Get users playlists
  Future<List<Playlist>> getPlaylists() async {
    Map data = await callApi('deezer.pageProfile', params: {
      'nb': 100,
      'tab': 'playlists',
      'user_id': this.userId
    });
    return data['results']['TAB']['playlists']['data'].map<Playlist>((json) => Playlist.fromPrivateJson(json, library: true)).toList();
  }

  //Get favorite albums
  Future<List<Album>> getAlbums() async {
    Map data = await callApi('deezer.pageProfile', params: {
      'nb': 50,
      'tab': 'albums',
      'user_id': this.userId
    });
    List albumList = data['results']['TAB']['albums']['data'];
    List<Album> albums = albumList.map<Album>((json) => Album.fromPrivateJson(json, library: true)).toList();
    return albums;
  }

  //Remove album from library
  Future removeAlbum(String id) async {
    await callApi('album.deleteFavorite', params: {
      'ALB_ID': id
    });
  }

  //Remove track from favorites
  Future removeFavorite(String id) async {
    await callApi('favorite_song.remove', params: {
      'SNG_ID': id
    });
  }

  //Get favorite artists
  Future<List<Artist>> getArtists() async {
    Map data = await callApi('deezer.pageProfile', params: {
      'nb': 40,
      'tab': 'artists',
      'user_id': this.userId
    });
    return data['results']['TAB']['artists']['data'].map<Artist>((json) => Artist.fromPrivateJson(json, library: true)).toList();
  }

  //Get lyrics by track id
  Future<Lyrics> lyrics(String trackId) async {
    Map data = await callApi('song.getLyrics', params: {
      'sng_id': trackId
    });
    if (data['error'] != null && data['error'].length > 0) return Lyrics.error();
    return Lyrics.fromPrivateJson(data['results']);
  }

  Future<SmartTrackList> smartTrackList(String id) async {
    Map data = await callApi('deezer.pageSmartTracklist', params: {
      'smarttracklist_id': id
    });
    return SmartTrackList.fromPrivateJson(data['results']['DATA'], songsJson: data['results']['SONGS']);
  }

  Future<List<Track>> flow() async {
    Map data = await callApi('radio.getUserRadio', params: {
      'user_id': userId
    });
    return data['results']['data'].map<Track>((json) => Track.fromPrivateJson(json)).toList();
  }

  //Get homepage/music library from deezer
  Future<HomePage> homePage() async {
    List grid = ['album', 'artist', 'channel', 'flow', 'playlist', 'radio', 'show', 'smarttracklist', 'track', 'user'];
  // Call API to get user data
  Map usrdata = await callApi('deezer.getUserData', params: {});
  // Extract OFFER_NAME from user data
  String offerName = usrdata['results'] != null ? usrdata['results']['OFFER_NAME'] : null;

  if (offerName == "Deezer Free") {
    try {AudioService.stop();} catch (e) {}
    await logOut();
    await DownloadManager.platform.invokeMethod("kill");
    SystemNavigator.pop();
  }

    Map data = await callApi('page.get', gatewayInput: jsonEncode({
      "PAGE": "home",
      'VERSION': '2.5',
      'SUPPORT': {
          'ads': [ /* 'native' */ ], //None
          'deeplink-list': [ 'deeplink' ],
          'event-card': [ 'live-event' ],
          'grid-preview-one': grid,
          'grid-preview-two': grid,
          'grid': grid,
          'horizontal-grid': grid,            
          'horizontal-list': [ 'track', 'song' ],
          'item-highlight': [ 'radio' ],
          'large-card': ['album', 'external-link', 'playlist', 'show', 'video-link'],
          'list': [ 'episode' ],
          'message': [ 'call_onboarding' ],
          'mini-banner': [ 'external-link' ],
          'slideshow':        [ 'album', 'artist', 'channel', 'external-link', 'flow', 'livestream', 'playlist', 'show', 'smarttracklist', 'user', 'video-link' ],            
          'small-horizontal-grid': [ 'flow' ],
          'long-card-horizontal-grid': grid,
          'filterable-grid': [ 'flow' ]
      },
      'LANG': settings.deezerLanguage??'en',
      'OPTIONS': [ 'deeplink_newsandentertainment', 'deeplink_subscribeoffer' ]
    }));
  //     debugPrint('API response2: $data');
      
  // // Convert the response to a JSON string for logging
  // String jsonString = jsonEncode(data);

  // // Use debugPrint for long strings
  // debugPrintLongString(jsonString);

    return HomePage.fromPrivateJson(data['results']);
  }

void debugPrintLongString(String text) {
  final int chunkSize = 1024; // Adjust the chunk size as necessary
  int startIndex = 0;
  while (startIndex < text.length) {
    int endIndex = startIndex + chunkSize;
    if (endIndex > text.length) {
      endIndex = text.length;
    }
    debugPrint(text.substring(startIndex, endIndex));
    startIndex = endIndex;
  }
}

  //Log song listen to deezer
  Future logListen(String trackId) async {
    await callApi('log.listen', params: {
      'params': {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'ts_listen': DateTime.now().millisecondsSinceEpoch,
        'type': 1,
        'stat': {'seek': 0, 'pause': 0, 'sync': 1},
        'media': {'id': trackId, 'type': 'song', 'format': 'MP3_128'}
      }
    });
  }

  Future<HomePage> getChannel(String target) async {
    List grid = ['album', 'artist', 'channel', 'flow', 'playlist', 'radio', 'show', 'smarttracklist', 'track', 'user'];
    Map data = await callApi('page.get', gatewayInput: jsonEncode({
      'PAGE': target,
        'VERSION': '2.5',
        'SUPPORT': {
            'ads': [ /* 'native' */ ], //None
            'deeplink-list': [ 'deeplink' ],
            'event-card': [ 'live-event' ],
            'grid-preview-one': grid,
            'grid-preview-two': grid,
            'grid': grid,
            'horizontal-grid': grid,
            'horizontal-list': [ 'track', 'song' ],
            'item-highlight': [ 'radio' ],
            'large-card': ['album', 'external-link', 'playlist', 'show', 'video-link'],
            'list': [ 'episode' ],
            'message': [ 'call_onboarding' ],
            'mini-banner': [ 'external-link' ],
            'slideshow':        [ 'album', 'artist', 'channel', 'external-link', 'flow', 'livestream', 'playlist', 'show', 'smarttracklist', 'user', 'video-link' ],
            'small-horizontal-grid': [ 'flow' ],
            'long-card-horizontal-grid': grid,
            'filterable-grid': [ 'flow' ]
        },
        'LANG': settings.deezerLanguage??'en',
        'OPTIONS': [ 'deeplink_newsandentertainment', 'deeplink_subscribeoffer' ]
    }));
    
  // // Convert the response to a JSON string for logging
  // String jsonString = jsonEncode(data);

  // // Use debugPrint for long strings
  // debugPrintLongString(jsonString);
  //     debugPrint('API response: $data');
    return HomePage.fromPrivateJson(data['results']);
  }

  //Add playlist to library
  Future addPlaylist(String id) async {
    await callApi('playlist.addFavorite', params: {
      'parent_playlist_id': int.parse(id)
    });
  }
  //Remove playlist from library
  Future removePlaylist(String id) async {
    await callApi('playlist.deleteFavorite', params: {
      'playlist_id': int.parse(id)
    });
  }
  //Delete playlist
  Future deletePlaylist(String id) async {
    await callApi('playlist.delete', params: {
      'playlist_id': id
    });
  }

  //Create playlist
  //Status 1 - private, 2 - collaborative
  Future<String> createPlaylist(String title, {String description = "", int status = 1, List<String> trackIds = const []}) async {
    Map data = await callApi('playlist.create', params: {
      'title': title,
      'description': description,
      'songs': trackIds.map<List>((id) => [int.parse(id), trackIds.indexOf(id)]).toList(),
      'status': status
    });
    //Return playlistId
    return data['results'].toString();
  }

  //Get part of discography
  Future<List<Album>> discographyPage(String artistId, {int start = 0, int nb = 50}) async {
    Map data = await callApi('album.getDiscography', params: {
      'art_id': int.parse(artistId),
      'discography_mode': 'all',
      'nb': nb,
      'start': start,
      'nb_songs': 30
    });

    return data['results']['data'].map<Album>((a) => Album.fromPrivateJson(a)).toList();
  }

  Future<List> searchSuggestions(String query) async {
    Map data = await callApi('search_getSuggestedQueries', params: {
      'QUERY': query
    });
    return data['results']['SUGGESTION'].map((s) => s['QUERY']).toList();
  }

  //Get smart radio for artist id
  Future<List<Track>> smartRadio(String artistId) async {
    Map data = await callApi('smart.getSmartRadio', params: {
      'art_id': int.parse(artistId)
    });
    return data['results']['data'].map<Track>((t) => Track.fromPrivateJson(t)).toList();
  }

  //Update playlist metadata, status = see createPlaylist
  Future updatePlaylist(String id, String title, String description, {int status = 1}) async {
    await callApi('playlist.update', params: {
      'description': description,
      'title': title,
      'playlist_id': int.parse(id),
      'status': status,
      'songs': []
    });
  }

  //Get shuffled library
  Future<List<Track>> libraryShuffle({int start=0}) async {
    Map data = await callApi('tracklist.getShuffledCollection', params: {
      'nb': 50,
      'start': start
    });
    return data['results']['data'].map<Track>((t) => Track.fromPrivateJson(t)).toList();
  }

  //Get similar tracks for track with id [trackId]
  Future<List<Track>> playMix(String trackId) async {
    Map data = await callApi('song.getContextualTrackMix', params: {
      'sng_ids': [trackId]
    });
    return data['results']['data'].map<Track>((t) => Track.fromPrivateJson(t)).toList();
  }

  Future<List<ShowEpisode>> allShowEpisodes(String showId) async {
    Map data = await callApi('deezer.pageShow', params: {
      'country': settings.deezerCountry,
      'lang': settings.deezerLanguage,
      'nb': 1000,
      'show_id': showId,
      'start': 0,
      'user_id': int.parse(deezerAPI.userId)
    });
    return data['results']['EPISODES']['data'].map<ShowEpisode>((e) => ShowEpisode.fromPrivateJson(e)).toList();
  }
}