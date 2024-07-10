// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'definitions.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Track _$TrackFromJson(Map<String, dynamic> json) {
  return Track(
    id: json['id'] as String,
    title: json['title'] as String,
    duration: json['duration'] == null
        ? null
        : Duration(microseconds: json['duration'] as int),
    album: json['album'] == null
        ? null
        : Album.fromJson(json['album'] as Map<String, dynamic>),
    playbackDetails: json['playbackDetails'] as List,
    albumArt: json['albumArt'] == null
        ? null
        : ImageDetails.fromJson(json['albumArt'] as Map<String, dynamic>),
    artists: (json['artists'] as List)
        ?.map((e) =>
            e == null ? null : Artist.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    trackNumber: json['trackNumber'] as int,
    offline: json['offline'] as bool,
    lyrics: json['lyrics'] == null
        ? null
        : Lyrics.fromJson(json['lyrics'] as Map<String, dynamic>),
    favorite: json['favorite'] as bool,
    diskNumber: json['diskNumber'] as int,
    explicit: json['explicit'] as bool,
    addedDate: json['addedDate'] as int,
  );
}

Map<String, dynamic> _$TrackToJson(Track instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'album': instance.album,
      'artists': instance.artists,
      'duration': instance.duration?.inMicroseconds,
      'albumArt': instance.albumArt,
      'trackNumber': instance.trackNumber,
      'offline': instance.offline,
      'lyrics': instance.lyrics,
      'favorite': instance.favorite,
      'diskNumber': instance.diskNumber,
      'explicit': instance.explicit,
      'addedDate': instance.addedDate,
      'playbackDetails': instance.playbackDetails,
    };

Album _$AlbumFromJson(Map<String, dynamic> json) {
  return Album(
    id: json['id'] as String,
    title: json['title'] as String,
    art: json['art'] == null
        ? null
        : ImageDetails.fromJson(json['art'] as Map<String, dynamic>),
    artists: (json['artists'] as List)
        ?.map((e) =>
            e == null ? null : Artist.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    tracks: (json['tracks'] as List)
        ?.map(
            (e) => e == null ? null : Track.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    fans: json['fans'] as int,
    offline: json['offline'] as bool,
    library: json['library'] as bool,
    type: _$enumDecodeNullable(_$AlbumTypeEnumMap, json['type']),
    releaseDate: json['releaseDate'] as String,
    favoriteDate: json['favoriteDate'] as String,
  );
}

Map<String, dynamic> _$AlbumToJson(Album instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'artists': instance.artists,
      'tracks': instance.tracks,
      'art': instance.art,
      'fans': instance.fans,
      'offline': instance.offline,
      'library': instance.library,
      'type': _$AlbumTypeEnumMap[instance.type],
      'releaseDate': instance.releaseDate,
      'favoriteDate': instance.favoriteDate,
    };

T _$enumDecode<T>(
  Map<T, dynamic> enumValues,
  dynamic source, {
  T unknownValue,
}) {
  if (source == null) {
    throw ArgumentError('A value must be provided. Supported values: '
        '${enumValues.values.join(', ')}');
  }

  final value = enumValues.entries
      .singleWhere((e) => e.value == source, orElse: () => null)
      ?.key;

  if (value == null && unknownValue == null) {
    throw ArgumentError('`$source` is not one of the supported values: '
        '${enumValues.values.join(', ')}');
  }
  return value ?? unknownValue;
}

T _$enumDecodeNullable<T>(
  Map<T, dynamic> enumValues,
  dynamic source, {
  T unknownValue,
}) {
  if (source == null) {
    return null;
  }
  return _$enumDecode<T>(enumValues, source, unknownValue: unknownValue);
}

const _$AlbumTypeEnumMap = {
  AlbumType.ALBUM: 'ALBUM',
  AlbumType.SINGLE: 'SINGLE',
  AlbumType.FEATURED: 'FEATURED',
};

ArtistHighlight _$ArtistHighlightFromJson(Map<String, dynamic> json) {
  return ArtistHighlight(
    data: json['data'],
    type: _$enumDecodeNullable(_$ArtistHighlightTypeEnumMap, json['type']),
    title: json['title'] as String,
  );
}

Map<String, dynamic> _$ArtistHighlightToJson(ArtistHighlight instance) =>
    <String, dynamic>{
      'data': instance.data,
      'type': _$ArtistHighlightTypeEnumMap[instance.type],
      'title': instance.title,
    };

const _$ArtistHighlightTypeEnumMap = {
  ArtistHighlightType.ALBUM: 'ALBUM',
};

Artist _$ArtistFromJson(Map<String, dynamic> json) {
  return Artist(
    id: json['id'] as String,
    name: json['name'] as String,
    albums: (json['albums'] as List)
        ?.map(
            (e) => e == null ? null : Album.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    albumCount: json['albumCount'] as int,
    topTracks: (json['topTracks'] as List)
        ?.map(
            (e) => e == null ? null : Track.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    picture: json['picture'] == null
        ? null
        : ImageDetails.fromJson(json['picture'] as Map<String, dynamic>),
    fans: json['fans'] as int,
    offline: json['offline'] as bool,
    library: json['library'] as bool,
    radio: json['radio'] as bool,
    favoriteDate: json['favoriteDate'] as String,
    highlight: json['highlight'] == null
        ? null
        : ArtistHighlight.fromJson(json['highlight'] as Map<String, dynamic>),
  );
}

Map<String, dynamic> _$ArtistToJson(Artist instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'albums': instance.albums,
      'albumCount': instance.albumCount,
      'topTracks': instance.topTracks,
      'picture': instance.picture,
      'fans': instance.fans,
      'offline': instance.offline,
      'library': instance.library,
      'radio': instance.radio,
      'favoriteDate': instance.favoriteDate,
      'highlight': instance.highlight,
    };

Playlist _$PlaylistFromJson(Map<String, dynamic> json) {
  return Playlist(
    id: json['id'] as String,
    title: json['title'] as String,
    tracks: (json['tracks'] as List)
        ?.map(
            (e) => e == null ? null : Track.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    image: json['image'] == null
        ? null
        : ImageDetails.fromJson(json['image'] as Map<String, dynamic>),
    trackCount: json['trackCount'] as int,
    duration: json['duration'] == null
        ? null
        : Duration(microseconds: json['duration'] as int),
    user: json['user'] == null
        ? null
        : User.fromJson(json['user'] as Map<String, dynamic>),
    fans: json['fans'] as int,
    library: json['library'] as bool,
    description: json['description'] as String,
  );
}

Map<String, dynamic> _$PlaylistToJson(Playlist instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'tracks': instance.tracks,
      'image': instance.image,
      'duration': instance.duration?.inMicroseconds,
      'trackCount': instance.trackCount,
      'user': instance.user,
      'fans': instance.fans,
      'library': instance.library,
      'description': instance.description,
    };

User _$UserFromJson(Map<String, dynamic> json) {
  return User(
    id: json['id'] as String,
    name: json['name'] as String,
    picture: json['picture'] == null
        ? null
        : ImageDetails.fromJson(json['picture'] as Map<String, dynamic>),
  );
}

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'picture': instance.picture,
    };

ImageDetails _$ImageDetailsFromJson(Map<String, dynamic> json) {
  return ImageDetails(
    fullUrl: json['fullUrl'] as String,
    thumbUrl: json['thumbUrl'] as String,
  );
}

Map<String, dynamic> _$ImageDetailsToJson(ImageDetails instance) =>
    <String, dynamic>{
      'fullUrl': instance.fullUrl,
      'thumbUrl': instance.thumbUrl,
    };

Lyrics _$LyricsFromJson(Map<String, dynamic> json) {
  return Lyrics(
    id: json['id'] as String,
    writers: json['writers'] as String,
    lyrics: (json['lyrics'] as List)
        ?.map(
            (e) => e == null ? null : Lyric.fromJson(e as Map<String, dynamic>))
        ?.toList(),
  );
}

Map<String, dynamic> _$LyricsToJson(Lyrics instance) => <String, dynamic>{
      'id': instance.id,
      'writers': instance.writers,
      'lyrics': instance.lyrics,
    };

Lyric _$LyricFromJson(Map<String, dynamic> json) {
  return Lyric(
    offset: json['offset'] == null
        ? null
        : Duration(microseconds: json['offset'] as int),
    text: json['text'] as String,
    lrcTimestamp: json['lrcTimestamp'] as String,
  );
}

Map<String, dynamic> _$LyricToJson(Lyric instance) => <String, dynamic>{
      'offset': instance.offset?.inMicroseconds,
      'text': instance.text,
      'lrcTimestamp': instance.lrcTimestamp,
    };

QueueSource _$QueueSourceFromJson(Map<String, dynamic> json) {
  return QueueSource(
    id: json['id'] as String,
    text: json['text'] as String,
    source: json['source'] as String,
  );
}

Map<String, dynamic> _$QueueSourceToJson(QueueSource instance) =>
    <String, dynamic>{
      'id': instance.id,
      'text': instance.text,
      'source': instance.source,
    };

SmartTrackList _$SmartTrackListFromJson(Map<String, dynamic> json) {
  return SmartTrackList(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    trackCount: json['trackCount'] as int,
    tracks: (json['tracks'] as List)
        ?.map(
            (e) => e == null ? null : Track.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    cover: json['cover'] == null
        ? null
        : ImageDetails.fromJson(json['cover'] as Map<String, dynamic>),
    subtitle: json['subtitle'] as String,
  );
}

Map<String, dynamic> _$SmartTrackListToJson(SmartTrackList instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'subtitle': instance.subtitle,
      'description': instance.description,
      'trackCount': instance.trackCount,
      'tracks': instance.tracks,
      'cover': instance.cover,
    };

HomePage _$HomePageFromJson(Map<String, dynamic> json) {
  return HomePage(
    sections: (json['sections'] as List)
        ?.map((e) => e == null
            ? null
            : HomePageSection.fromJson(e as Map<String, dynamic>))
        ?.toList(),
  );
}

Map<String, dynamic> _$HomePageToJson(HomePage instance) => <String, dynamic>{
      'sections': instance.sections,
    };

HomePageSection _$HomePageSectionFromJson(Map<String, dynamic> json) {
  return HomePageSection(
    layout:
        _$enumDecodeNullable(_$HomePageSectionLayoutEnumMap, json['layout']),
    items: HomePageSection._homePageItemFromJson(json['items']),
    title: json['title'] as String,
    pagePath: json['pagePath'] as String,
    hasMore: json['hasMore'] as bool,
  );
}

Map<String, dynamic> _$HomePageSectionToJson(HomePageSection instance) =>
    <String, dynamic>{
      'title': instance.title,
      'layout': _$HomePageSectionLayoutEnumMap[instance.layout],
      'pagePath': instance.pagePath,
      'hasMore': instance.hasMore,
      'items': HomePageSection._homePageItemToJson(instance.items),
    };

const _$HomePageSectionLayoutEnumMap = {
  HomePageSectionLayout.ROW: 'ROW',
  HomePageSectionLayout.GRID: 'GRID',
};

DeezerChannel _$DeezerChannelFromJson(Map<String, dynamic> json) {
  return DeezerChannel(
    id: json['id'] as String,
    title: json['title'] as String,
    backgroundColor:
        DeezerChannel._colorFromJson(json['backgroundColor'] as int),
    target: json['target'] as String,
  );
}

Map<String, dynamic> _$DeezerChannelToJson(DeezerChannel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'target': instance.target,
      'title': instance.title,
      'backgroundColor': DeezerChannel._colorToJson(instance.backgroundColor),
    };

Sorting _$SortingFromJson(Map<String, dynamic> json) {
  return Sorting(
    type: _$enumDecodeNullable(_$SortTypeEnumMap, json['type']),
    reverse: json['reverse'] as bool,
    id: json['id'] as String,
    sourceType:
        _$enumDecodeNullable(_$SortSourceTypesEnumMap, json['sourceType']),
  );
}

Map<String, dynamic> _$SortingToJson(Sorting instance) => <String, dynamic>{
      'type': _$SortTypeEnumMap[instance.type],
      'reverse': instance.reverse,
      'id': instance.id,
      'sourceType': _$SortSourceTypesEnumMap[instance.sourceType],
    };

const _$SortTypeEnumMap = {
  SortType.DEFAULT: 'DEFAULT',
  SortType.ALPHABETIC: 'ALPHABETIC',
  SortType.ARTIST: 'ARTIST',
  SortType.ALBUM: 'ALBUM',
  SortType.RELEASE_DATE: 'RELEASE_DATE',
  SortType.POPULARITY: 'POPULARITY',
  SortType.USER: 'USER',
  SortType.TRACK_COUNT: 'TRACK_COUNT',
  SortType.DATE_ADDED: 'DATE_ADDED',
};

const _$SortSourceTypesEnumMap = {
  SortSourceTypes.TRACKS: 'TRACKS',
  SortSourceTypes.PLAYLISTS: 'PLAYLISTS',
  SortSourceTypes.ALBUMS: 'ALBUMS',
  SortSourceTypes.ARTISTS: 'ARTISTS',
  SortSourceTypes.PLAYLIST: 'PLAYLIST',
};

Show _$ShowFromJson(Map<String, dynamic> json) {
  return Show(
    name: json['name'] as String,
    description: json['description'] as String,
    art: json['art'] == null
        ? null
        : ImageDetails.fromJson(json['art'] as Map<String, dynamic>),
    id: json['id'] as String,
  );
}

Map<String, dynamic> _$ShowToJson(Show instance) => <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'art': instance.art,
      'id': instance.id,
    };

ShowEpisode _$ShowEpisodeFromJson(Map<String, dynamic> json) {
  return ShowEpisode(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    url: json['url'] as String,
    duration: json['duration'] == null
        ? null
        : Duration(microseconds: json['duration'] as int),
    publishedDate: json['publishedDate'] as String,
    show: json['show'] == null
        ? null
        : Show.fromJson(json['show'] as Map<String, dynamic>),
  );
}

Map<String, dynamic> _$ShowEpisodeToJson(ShowEpisode instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'url': instance.url,
      'duration': instance.duration?.inMicroseconds,
      'publishedDate': instance.publishedDate,
      'show': instance.show,
    };
