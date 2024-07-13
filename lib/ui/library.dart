import 'package:connectivity/connectivity.dart';
import 'package:flutter/material.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:Saturn/api/cache.dart';
import 'package:Saturn/api/deezer.dart';
import 'package:Saturn/api/definitions.dart';
import 'package:Saturn/api/importer.dart';
import 'package:Saturn/api/player.dart';
import 'package:Saturn/settings.dart';
import 'package:Saturn/ui/details_screens.dart';
import 'package:Saturn/ui/downloads_screen.dart';
import 'package:Saturn/ui/elements.dart';
import 'package:Saturn/ui/error.dart';
import 'package:Saturn/ui/importer_screen.dart';
import 'package:Saturn/ui/tiles.dart';
import 'package:Saturn/translations.i18n.dart';
import 'package:draggable_scrollbar/draggable_scrollbar.dart';

import 'menu.dart';
import 'settings_screen.dart';
import '../api/spotify.dart';
import '../api/download.dart';


class LibraryAppBar extends StatelessWidget implements PreferredSizeWidget {

  @override
  Size get preferredSize => AppBar().preferredSize;

  @override
  Widget build(BuildContext context) {
    return freezerAppBar(
      'Library'.i18n,
      actions: <Widget>[
        IconButton(
          icon: Icon(Icons.file_download, semanticLabel: "Download".i18n,),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => DownloadsScreen())
            );
          },
        ),
        IconButton(
          icon: Icon(Icons.settings, semanticLabel: "Settings".i18n,),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => SettingsScreen())
            );
          },
        ),
      ],
    );
  }

}

class LibraryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: LibraryAppBar(),
      body: ListView(
        children: <Widget>[
          Container(height: 4.0,),
          if (!downloadManager.running && downloadManager.queueSize > 0)
            ListTile(
              title: Text('Downloads'.i18n),
              leading: LeadingIcon(Icons.file_download, color: Colors.grey),
              subtitle: Text('Downloading is currently stopped, click here to resume.'.i18n),
              onTap: () {
                downloadManager.start();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => DownloadsScreen()
                ));
              },
            ),
          ListTile(
            title: Text('Shuffle'.i18n),
            leading: LeadingIcon(Icons.shuffle, color: Color(0xffeca704)),
            onTap: () async {
              List<Track> tracks = await deezerAPI.libraryShuffle();
              playerHelper.playFromTrackList(tracks, tracks[0].id, QueueSource(
                id: 'libraryshuffle',
                source: 'libraryshuffle',
                text: 'Library shuffle'.i18n
              ));
            },
          ),
          freezerDivider(),
          ListTile(
            title: Text('Tracks'.i18n),
            leading: LeadingIcon(Icons.audiotrack, color: Color(0xffbe3266)),
            onTap: () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => LibraryTracks())
              );
            },
          ),
          ListTile(
            title: Text('Albums'.i18n),
            leading: LeadingIcon(Icons.album, color: Color(0xff4b2e7e)),
            onTap: () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => LibraryAlbums())
              );
            },
          ),
          ListTile(
            title: Text('Artists'.i18n),
            leading: LeadingIcon(Icons.recent_actors, color: Color(0xff384697)),
            onTap: () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => LibraryArtists())
              );
            },
          ),
          ListTile(
            title: Text('Playlists'.i18n),
            leading: LeadingIcon(Icons.playlist_play, color: Color(0xff0880b5)),
            onTap: () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => LibraryPlaylists())
              );
            },
          ),
          freezerDivider(),
          ListTile(
            title: Text('History'.i18n),
            leading: LeadingIcon(Icons.history, color: Color(0xff009a85)),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => HistoryScreen())
              );
            },
          ),
          freezerDivider(),
          ExpansionTile(
            title: Text('Statistics'.i18n),
            leading: LeadingIcon(Icons.insert_chart, color: Colors.grey),
            textColor: Theme.of(context).primaryColor,
            iconColor: Theme.of(context).primaryColor,
            children: <Widget>[
              FutureBuilder(
                future: downloadManager.getStats(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return ErrorScreen();
                  if (!snapshot.hasData) return Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        CircularProgressIndicator(color: Theme.of(context).primaryColor,)
                      ],
                    ),
                  );
                  List<String> data = snapshot.data;
                  return Column(
                    children: <Widget>[
                      ListTile(
                        title: Text('Offline tracks'.i18n),
                        leading: Icon(Icons.audiotrack),
                        trailing: Text(data[0]),
                      ),
                      ListTile(
                        title: Text('Offline albums'.i18n),
                        leading: Icon(Icons.album),
                        trailing: Text(data[1]),
                      ),
                      ListTile(
                        title: Text('Offline playlists'.i18n),
                        leading: Icon(Icons.playlist_add),
                        trailing: Text(data[2]),
                      ),
                      ListTile(
                        title: Text('Offline size'.i18n),
                        leading: Icon(Icons.sd_card),
                        trailing: Text(data[3]),
                      ),
                      ListTile(
                        title: Text('Free space'.i18n),
                        leading: Icon(Icons.disc_full),
                        trailing: Text(data[4]),
                      ),
                    ],
                  );
                },
              )
            ],
          )
        ],
      ),
    );
  }
}

class LibraryTracks extends StatefulWidget {
  @override
  _LibraryTracksState createState() => _LibraryTracksState();
}

class _LibraryTracksState extends State<LibraryTracks> {

  bool _loading = false;
  bool _loadingTracks = false;
  ScrollController _scrollController = ScrollController();
  List<Track> tracks = [];
  List<Track> allTracks = [];
  int trackCount;
  Sorting _sort = Sorting(sourceType: SortSourceTypes.TRACKS);

  Playlist get _playlist => Playlist(id: deezerAPI.favoritesPlaylistId);

  List<Track> get _sorted {
    List<Track> tcopy = List.from(tracks);
    tcopy.sort((a, b) => a.addedDate.compareTo(b.addedDate));
    switch (_sort.type) {
      case SortType.ALPHABETIC:
        tcopy.sort((a, b) => a.title.compareTo(b.title));
        break;
      case SortType.ARTIST:
        tcopy.sort((a, b) => a.artists[0].name.toLowerCase().compareTo(b.artists[0].name.toLowerCase()));
        break;
      case SortType.DEFAULT:
      default:
        break;
    }
    //Reverse
    if (_sort.reverse)
      return tcopy.reversed.toList();
    return tcopy;
  }

  Future _reverse() async {
    setState(() => _sort.reverse = !_sort.reverse);
    //Save sorting in cache
    int index = Sorting.index(SortSourceTypes.TRACKS);
    if (index != null) {
      cache.sorts[index] = _sort;
    } else {
      cache.sorts.add(_sort);
    }
    await cache.save();

    //Preload for sorting
    if (tracks.length < (trackCount??0))
      _loadFull();
  }

  Future _load() async {
    //Already loaded
    if (trackCount != null && tracks.length >= trackCount) {
      //Update tracks cache if fully loaded
      if (cache.libraryTracks == null || cache.libraryTracks.length != trackCount) {
        setState(() {
          cache.libraryTracks = tracks.map((t) => t.id).toList();
        });
        await cache.save();
      }
      return;
    }

    ConnectivityResult connectivity = await Connectivity().checkConnectivity();
    if (connectivity != ConnectivityResult.none) {
      setState(() => _loading = true);
      int pos = tracks.length;

      if (trackCount == null || tracks.length == 0) {
        //Load tracks as a playlist
        Playlist favPlaylist;
        try {
          favPlaylist = await deezerAPI.playlist(deezerAPI.favoritesPlaylistId);
        } catch (e) {}
        //Error loading
        if (favPlaylist == null) {
          setState(() => _loading = false);
          return;
        }
        //Update
        setState(() {
          trackCount = favPlaylist.trackCount;
          if (tracks.length == 0)
            tracks = favPlaylist.tracks;
          _makeFavorite();
          _loading = false;
        });
        return;
      }

      //Load another page of tracks from deezer
      if (_loadingTracks) return;
      _loadingTracks = true;

      List<Track> _t;
      try {
        _t = await deezerAPI.playlistTracksPage(deezerAPI.favoritesPlaylistId, pos);
      } catch (e) {}
      //On error load offline
      if (_t == null) {
        await _loadOffline();
        return;
      }
      setState(() {
        tracks.addAll(_t);
        _makeFavorite();
        _loading = false;
        _loadingTracks = false;
      });

    }
  }

  //Load all tracks
  Future _loadFull() async {
    if (tracks.length == 0 || tracks.length < (trackCount??0)) {
      Playlist p;
      try {
        p = await deezerAPI.fullPlaylist(deezerAPI.favoritesPlaylistId);
      } catch (e) {}
      if (p != null) {
        setState(() {
          tracks = p.tracks;
          trackCount = p.trackCount;
          _sort = _sort;
        });
      }
    }
  }

  Future _loadOffline() async {
    Playlist p = await downloadManager.getPlaylist(deezerAPI.favoritesPlaylistId);
    if (p != null) setState(() {
      tracks = p.tracks;
    });
  }

  Future _loadAllOffline() async {
    List tracks = await downloadManager.allOfflineTracks();
    setState(() {
      allTracks = tracks;
    });
  }

  //Update tracks with favorite true
  void _makeFavorite() {
    for (int i=0; i<tracks.length; i++)
      tracks[i].favorite = true;
  }

  @override
  void initState() {
    _scrollController.addListener(() {
      //Load more tracks on scroll
      double off = _scrollController.position.maxScrollExtent * 0.90;
      if (_scrollController.position.pixels > off) _load();
    });

    _load();
    //Load all offline tracks
    _loadAllOffline();

    //Load sorting
    int index = Sorting.index(SortSourceTypes.TRACKS);
    if (index != null)
      setState(() => _sort = cache.sorts[index]);

    if (_sort.type != SortType.DEFAULT || _sort.reverse)
      _loadFull();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: freezerAppBar(
        'Tracks'.i18n,
        actions: [
          IconButton(
            icon: Icon(_sort.reverse ? FontAwesome5.sort_alpha_up : FontAwesome5.sort_alpha_down,
              semanticLabel: _sort.reverse ? "Sort descending".i18n : "Sort ascending".i18n,),
            onPressed: () async {
              await _reverse();
            }
          ),
          PopupMenuButton(
            child: Icon(Icons.sort, size: 32.0, semanticLabel: "Sort".i18n,),
            color: Theme.of(context).scaffoldBackgroundColor,
            onSelected: (SortType s) async {
              //Preload for sorting
              if (tracks.length < (trackCount??0))
                await _loadFull();

              setState(() => _sort.type = s);
              //Save sorting in cache
              int index = Sorting.index(SortSourceTypes.TRACKS);
              if (index != null) {
                cache.sorts[index] = _sort;
              } else {
                cache.sorts.add(_sort);
              }
              await cache.save();
            },
            itemBuilder: (context) => <PopupMenuEntry<SortType>>[
              PopupMenuItem(
                value: SortType.DEFAULT,
                child: Text('Default'.i18n, style: popupMenuTextStyle()),
              ),
              PopupMenuItem(
                value: SortType.ALPHABETIC,
                child: Text('Alphabetic'.i18n, style: popupMenuTextStyle()),
              ),
              PopupMenuItem(
                value: SortType.ARTIST,
                child: Text('Artist'.i18n, style: popupMenuTextStyle()),
              ),
            ],
          ),
          Container(width: 8.0),
        ],
      ),
      body: DraggableScrollbar.rrect(
        controller: _scrollController,
        backgroundColor: Theme.of(context).primaryColor,
        child: ListView(
          controller: _scrollController,
          children: <Widget>[
            Container(
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  MakePlaylistOffline(_playlist),
                  TextButton(
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.file_download, size: 32.0,),
                        Container(width: 4,),
                        Text('Download'.i18n)
                      ],
                    ),
                    onPressed: () async {
                      if (await downloadManager.addOfflinePlaylist(_playlist, private: false, context: context) != false)
                        MenuSheet(context).showDownloadStartedToast();
                    },
                  )
                ],
              )
            ),
            freezerDivider(),
            //Loved tracks
            ...List.generate(tracks.length, (i) {
              Track t = (tracks.length == (trackCount??0))?_sorted[i]:tracks[i];
              return TrackTile(
                t,
                onTap: () {
                  playerHelper.playFromTrackList((tracks.length == (trackCount??0))?_sorted:tracks, t.id, QueueSource(
                    id: deezerAPI.favoritesPlaylistId,
                    text: 'Favorites'.i18n,
                    source: 'playlist'
                  ));
                },
                onHold: () {
                  MenuSheet m = MenuSheet(context);
                  m.defaultTrackMenu(
                    t,
                    onRemove: () {
                      setState(() {
                        tracks.removeWhere((track) => t.id == track.id);
                      });
                    }
                  );
                },
              );
            }),
            if (_loading)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: CircularProgressIndicator(color: Theme.of(context).primaryColor,),
                  )
                ],
              ),
            freezerDivider(),
            Text(
              'All offline tracks'.i18n,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold
              ),
            ),
            Container(height: 8,),
            ...List.generate(allTracks.length, (i) {
              Track t = allTracks[i];
              return TrackTile(
                t,
                onTap: () {
                  playerHelper.playFromTrackList(allTracks, t.id, QueueSource(
                    id: 'allTracks',
                    text: 'All offline tracks'.i18n,
                    source: 'offline'
                  ));
                },
                onHold: () {
                  MenuSheet m = MenuSheet(context);
                  m.defaultTrackMenu(t);
                },
              );
            })
          ],
      )
      ));
  }
}


class LibraryAlbums extends StatefulWidget {
  @override
  _LibraryAlbumsState createState() => _LibraryAlbumsState();
}

class _LibraryAlbumsState extends State<LibraryAlbums> {

  List<Album> _albums;
  Sorting _sort = Sorting(sourceType: SortSourceTypes.ALBUMS);
  ScrollController _scrollController = ScrollController();

  List<Album> get _sorted {
    List<Album> albums = List.from(_albums);
    albums.sort((a, b) => a.favoriteDate.compareTo(b.favoriteDate));
    switch (_sort.type) {
      case SortType.DEFAULT:
        break;
      case SortType.ALPHABETIC:
        albums.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SortType.ARTIST:
        albums.sort((a, b) => a.artists[0].name.toLowerCase().compareTo(b.artists[0].name.toLowerCase()));
        break;
      case SortType.RELEASE_DATE:
        albums.sort((a, b) => DateTime.parse(a.releaseDate).compareTo(DateTime.parse(b.releaseDate)));
        break;
    }
    //Reverse
    if (_sort.reverse)
      return albums.reversed.toList();
    return albums;
  }


  Future _load() async {
    if (settings.offlineMode) return;
    try {
      List<Album> albums = await deezerAPI.getAlbums();
      setState(() => _albums = albums);
    } catch (e) {}
  }

  @override
  void initState() {
    _load();
    //Load sorting
    int index = Sorting.index(SortSourceTypes.ALBUMS);
    if (index != null)
      _sort = cache.sorts[index];

    super.initState();
  }

  Future _reverse() async {
    setState(() => _sort.reverse = !_sort.reverse);
    //Save sorting in cache
    int index = Sorting.index(SortSourceTypes.ALBUMS);
    if (index != null) {
      cache.sorts[index] = _sort;
    } else {
      cache.sorts.add(_sort);
    }
    await cache.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: freezerAppBar(
        'Albums'.i18n,
        actions: [
          IconButton(
            icon: Icon(_sort.reverse ? FontAwesome5.sort_alpha_up : FontAwesome5.sort_alpha_down,
              semanticLabel: _sort.reverse ? "Sort descending".i18n : "Sort ascending".i18n,),
            onPressed: () => _reverse(),
          ),
          PopupMenuButton(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Icon(Icons.sort, size: 32.0),
            onSelected: (SortType s) async {
              setState(() => _sort.type = s);
              //Save to cache
              int index = Sorting.index(SortSourceTypes.ALBUMS);
              if (index == null) {
                cache.sorts.add(_sort);
              } else {
                cache.sorts[index] = _sort;
              }
              await cache.save();
            },
            itemBuilder: (context) => <PopupMenuEntry<SortType>>[
              PopupMenuItem(
                value: SortType.DEFAULT,
                child: Text('Default'.i18n, style: popupMenuTextStyle()),
              ),
              PopupMenuItem(
                value: SortType.ALPHABETIC,
                child: Text('Alphabetic'.i18n, style: popupMenuTextStyle()),
              ),
              PopupMenuItem(
                value: SortType.ARTIST,
                child: Text('Artist'.i18n, style: popupMenuTextStyle()),
              ),
              PopupMenuItem(
                value: SortType.RELEASE_DATE,
                child: Text('Release date'.i18n, style: popupMenuTextStyle()),
              ),
            ],
          ),
          Container(width: 8.0),
        ],
      ),
      body: DraggableScrollbar.rrect(
        controller: _scrollController,
        backgroundColor: Theme.of(context).primaryColor,
        child: ListView(
          controller: _scrollController,
          children: <Widget>[
            Container(height: 8.0,),
            if (!settings.offlineMode && _albums == null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  CircularProgressIndicator(color: Theme.of(context).primaryColor,)
                ],
              ),

            if (_albums != null)
              ...List.generate(_albums.length, (int i) {
                Album a = _sorted[i];
                return AlbumTile(
                  a,
                  onTap: () {
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => AlbumDetails(a))
                    );
                  },
                  onHold: () async {
                    MenuSheet m = MenuSheet(context);
                    m.defaultAlbumMenu(a, onRemove: () {
                      setState(() => _albums.remove(a));
                    });
                  },
                );
              }),

            FutureBuilder(
              future: downloadManager.getOfflineAlbums(),
              builder: (context, snapshot) {
                if (snapshot.hasError || !snapshot.hasData || snapshot.data.length == 0) return Container(height: 0, width: 0,);

                List<Album> albums = snapshot.data;
                return Column(
                  children: <Widget>[
                    freezerDivider(),
                    Text(
                      'Offline albums'.i18n,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24.0
                      ),
                    ),
                    ...List.generate(albums.length, (i) {
                      Album a = albums[i];
                      return AlbumTile(
                        a,
                        onTap: () {
                          Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => AlbumDetails(a))
                          );
                        },
                        onHold: () async {
                          MenuSheet m = MenuSheet(context);
                          m.defaultAlbumMenu(a, onRemove: () {
                            setState(() {
                              albums.remove(a);
                              _albums.remove(a);
                            });
                          });
                        },
                      );
                    })
                  ],
                );
              },
            )
          ],
        ),
      ));
  }
}


class LibraryArtists extends StatefulWidget {
  @override
  _LibraryArtistsState createState() => _LibraryArtistsState();
}

class _LibraryArtistsState extends State<LibraryArtists> {

  List<Artist> _artists;
  Sorting _sort = Sorting(sourceType: SortSourceTypes.ARTISTS);
  bool _loading = true;
  bool _error = false;
  ScrollController _scrollController = ScrollController();

  List<Artist> get _sorted {
    List<Artist> artists = List.from(_artists);
    artists.sort((a, b) => a.favoriteDate.compareTo(b.favoriteDate));
    switch (_sort.type) {
      case SortType.DEFAULT:
        break;
      case SortType.POPULARITY:
        artists.sort((a, b) => b.fans - a.fans);
        break;
      case SortType.ALPHABETIC:
        artists.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
    }
    //Reverse
    if (_sort.reverse)
      return artists.reversed.toList();
    return artists;
  }

  //Load data
  Future _load() async {
    setState(() => _loading = true);
    //Fetch
    List<Artist> data;
    try {
      data = await deezerAPI.getArtists();
    } catch (e) {}
    //Update UI
    setState(() {
      if (data != null) {
        _artists = data;
      } else {
        _error = true;
      }
      _loading = false;
    });
  }

  Future _reverse() async {
    setState(() => _sort.reverse = !_sort.reverse);
    //Save sorting in cache
    int index = Sorting.index(SortSourceTypes.ARTISTS);
    if (index != null) {
      cache.sorts[index] = _sort;
    } else {
      cache.sorts.add(_sort);
    }
    await cache.save();
  }


  @override
  void initState() {
    //Restore sort
    int index = Sorting.index(SortSourceTypes.ARTISTS);
    if (index != null)
      _sort = cache.sorts[index];

    _load();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: freezerAppBar(
        'Artists'.i18n,
        actions: [
          IconButton(
            icon: Icon(_sort.reverse ? FontAwesome5.sort_alpha_up : FontAwesome5.sort_alpha_down,
              semanticLabel: _sort.reverse ? "Sort descending".i18n : "Sort ascending".i18n,),
            onPressed: () => _reverse(),
          ),
          PopupMenuButton(
            child: Icon(Icons.sort, size: 32.0),
            color: Theme.of(context).scaffoldBackgroundColor,
            onSelected: (SortType s) async {
              setState(() => _sort.type = s);
              //Save
              int index = Sorting.index(SortSourceTypes.ARTISTS);
              if (index == null) {
                cache.sorts.add(_sort);
              } else {
                cache.sorts[index] = _sort;
              }
              await cache.save();
            },
            itemBuilder: (context) => <PopupMenuEntry<SortType>>[
              PopupMenuItem(
                value: SortType.DEFAULT,
                child: Text('Default'.i18n, style: popupMenuTextStyle()),
              ),
              PopupMenuItem(
                value: SortType.ALPHABETIC,
                child: Text('Alphabetic'.i18n, style: popupMenuTextStyle()),
              ),
              PopupMenuItem(
                value: SortType.POPULARITY,
                child: Text('Popularity'.i18n, style: popupMenuTextStyle()),
              ),
            ],
          ),
          Container(width: 8.0),
        ],
      ),
      body: DraggableScrollbar.rrect(
        controller: _scrollController,
        backgroundColor: Theme.of(context).primaryColor,
        child: ListView(
          controller: _scrollController,
          children: <Widget>[
            if (_loading)
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [CircularProgressIndicator(color: Theme.of(context).primaryColor,)],
                ),
              ),

            if (_error)
              Center(child: ErrorScreen()),

            if (!_loading && !_error)
              ...List.generate(_artists.length, (i) {
                Artist a = _sorted[i];
                return ArtistHorizontalTile(
                  a,
                  onTap: () {
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => ArtistDetails(a))
                    );
                  },
                  onHold: () {
                    MenuSheet m = MenuSheet(context);
                    m.defaultArtistMenu(a, onRemove: () {
                      setState(() {
                        _artists.remove(a);
                      });
                    });
                  },
                );
              }),
          ],
      ),
    ));
  }
}

class LibraryPlaylists extends StatefulWidget {
  @override
  _LibraryPlaylistsState createState() => _LibraryPlaylistsState();
}

class _LibraryPlaylistsState extends State<LibraryPlaylists> {

  List<Playlist> _playlists;
  Sorting _sort = Sorting(sourceType: SortSourceTypes.PLAYLISTS);
  ScrollController _scrollController = ScrollController();
  String _filter = '';

  List<Playlist> get _sorted {
    List<Playlist> playlists = List.from(_playlists.where((p) => p.title.toLowerCase().contains(_filter.toLowerCase())));
    switch (_sort.type) {
      case SortType.DEFAULT:
        break;
      case SortType.USER:
        playlists.sort((a, b) => (a.user.name??deezerAPI.userName).toLowerCase().compareTo((b.user.name??deezerAPI.userName).toLowerCase()));
        break;
      case SortType.TRACK_COUNT:
        playlists.sort((a, b) => b.trackCount - a.trackCount);
        break;
      case SortType.ALPHABETIC:
        playlists.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
    }
    if (_sort.reverse)
      return playlists.reversed.toList();
    return playlists;
  }

  Future _load() async {
    if (!settings.offlineMode) {
      try {
        List<Playlist> playlists = await deezerAPI.getPlaylists();
        setState(() => _playlists = playlists);
      } catch (e) {}
    }
  }

  Future _reverse() async {
    setState(() => _sort.reverse = !_sort.reverse);
    //Save sorting in cache
    int index = Sorting.index(SortSourceTypes.PLAYLISTS);
    if (index != null) {
      cache.sorts[index] = _sort;
    } else {
      cache.sorts.add(_sort);
    }
    await cache.save();
  }

  @override
  void initState() {
    //Restore sort
    int index = Sorting.index(SortSourceTypes.PLAYLISTS);
    if (index != null)
      _sort = cache.sorts[index];

    _load();
    super.initState();
  }

  Playlist get favoritesPlaylist => Playlist(
    id: deezerAPI.favoritesPlaylistId,
    title: 'Favorites'.i18n,
    user: User(name: deezerAPI.userName),
    image: ImageDetails(thumbUrl: 'assets/favorites_thumb.jpg'),
    tracks: [],
    trackCount: 1,
    duration: Duration(seconds: 0)
  );


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: freezerAppBar(
        'Playlists'.i18n,
        actions: [
          IconButton(
            icon: Icon(_sort.reverse ? FontAwesome5.sort_alpha_up : FontAwesome5.sort_alpha_down,
              semanticLabel: _sort.reverse ? "Sort descending".i18n : "Sort ascending".i18n,),
            onPressed: () => _reverse(),
          ),
          PopupMenuButton(
            child: Icon(Icons.sort, size: 32.0),
            color: Theme.of(context).scaffoldBackgroundColor,
            onSelected: (SortType s) async {
              setState(() => _sort.type = s);
              //Save to cache
              int index = Sorting.index(SortSourceTypes.PLAYLISTS);
              if (index == null)
                cache.sorts.add(_sort);
              else
                cache.sorts[index] = _sort;

              await cache.save();
            },
            itemBuilder: (context) => <PopupMenuEntry<SortType>>[
              PopupMenuItem(
                value: SortType.DEFAULT,
                child: Text('Default'.i18n, style: popupMenuTextStyle()),
              ),
              PopupMenuItem(
                value: SortType.USER,
                child: Text('User'.i18n, style: popupMenuTextStyle()),
              ),
              PopupMenuItem(
                value: SortType.TRACK_COUNT,
                child: Text('Track count'.i18n, style: popupMenuTextStyle()),
              ),
              PopupMenuItem(
                value: SortType.ALPHABETIC,
                child: Text('Alphabetic'.i18n, style: popupMenuTextStyle()),
              ),
            ],
          ),
          Container(width: 8.0),
        ],
      ),
      body: DraggableScrollbar.rrect(
        controller: _scrollController,
        backgroundColor: Theme.of(context).primaryColor,
        child: ListView(
          controller: _scrollController,
          children: <Widget>[
            //Search
            Padding(
              padding: EdgeInsets.all(8.0),
              child: TextField(
                onChanged: (String s) => setState(() => _filter = s),
                decoration: InputDecoration(
                  labelText: 'Search'.i18n,
                  fillColor: Theme.of(context).bottomAppBarColor,
                  filled: true,
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey)
                  ),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey)
                  ),
                )
              ),
            ),
            ListTile(
              title: Text('Create new playlist'.i18n),
              leading: LeadingIcon(Icons.playlist_add, color: Color(0xff009a85)),
              onTap: () async {
                if (settings.offlineMode) {
                  Fluttertoast.showToast(
                    msg: 'Cannot create playlists in offline mode'.i18n,
                    gravity: ToastGravity.BOTTOM
                  );
                  return;
                }
                MenuSheet m = MenuSheet(context);
                await m.createPlaylist();
                await _load();
              },
            ),
            freezerDivider(),

            if (!settings.offlineMode && _playlists == null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  CircularProgressIndicator(color: Theme.of(context).primaryColor,),
                ],
              ),

            //Favorites playlist
            PlaylistTile(
              favoritesPlaylist,
              onTap: () async {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => PlaylistDetails(favoritesPlaylist)
                ));
              },
              onHold: () {
                MenuSheet m = MenuSheet(context);
                favoritesPlaylist.library = true;
                m.defaultPlaylistMenu(favoritesPlaylist);
              },
            ),

            if (_playlists != null)
              ...List.generate(_sorted.length, (int i) {
                Playlist p = (_sorted??[])[i];
                return PlaylistTile(
                  p,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => PlaylistDetails(p)
                  )),
                  onHold: () {
                    MenuSheet m = MenuSheet(context);
                    m.defaultPlaylistMenu(
                      p,
                      onRemove: () {setState(() => _playlists.remove(p));},
                      onUpdate: () {_load();});
                  },
                );
              }),

            FutureBuilder(
              future: downloadManager.getOfflinePlaylists(),
              builder: (context, snapshot) {
                if (snapshot.hasError || !snapshot.hasData) return Container(height: 0, width: 0,);
                if (snapshot.data.length == 0) return Container(height: 0, width: 0,);

                List<Playlist> playlists = snapshot.data;
                return Column(
                  children: <Widget>[
                    freezerDivider(),
                    Text(
                      'Offline playlists'.i18n,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24.0,
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    ...List.generate(playlists.length, (i) {
                      Playlist p = playlists[i];
                      return PlaylistTile(
                        p,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => PlaylistDetails(p)
                        )),
                        onHold: () {
                          MenuSheet m = MenuSheet(context);
                          m.defaultPlaylistMenu(p, onRemove: () {
                            setState(() {
                              playlists.remove(p);
                              _playlists.remove(p);
                            });
                          });
                        },
                      );
                    })
                  ],
                );
              },
            )

        ],
      ),
    ));
  }
}

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  ScrollController _scrollController = ScrollController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: freezerAppBar(
        'History'.i18n,
        actions: [
          IconButton(
            icon: Icon(Icons.delete_sweep, semanticLabel: "Clear all".i18n,),
            onPressed: () {
              setState(() => cache.history = []);
              cache.save();
            },
          )
        ],
      ),
      body: DraggableScrollbar.rrect(
        controller: _scrollController,
        backgroundColor: Theme.of(context).primaryColor,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: (cache.history??[]).length,
          itemBuilder: (BuildContext context, int i) {
            Track t = cache.history[cache.history.length - i - 1];
            return TrackTile(
              t,
              onTap: () {
                playerHelper.playFromTrackList(cache.history.reversed.toList(), t.id, QueueSource(
                  id: null,
                  text: 'History'.i18n,
                  source: 'history'
                ));
              },
              onHold: () {
                MenuSheet m = MenuSheet(context);
                m.defaultTrackMenu(t);
              },
            );
          },
        )
      ),
    );
  }
}

