// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cache.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Cache _$CacheFromJson(Map<String, dynamic> json) {
  return Cache(
    libraryTracks:
        (json['libraryTracks'] as List)?.map((e) => e as String)?.toList(),
  )
    ..history = (json['history'] as List)
            ?.map((e) =>
                e == null ? null : Track.fromJson(e as Map<String, dynamic>))
            ?.toList() ??
        []
    ..sorts = (json['sorts'] as List)
            ?.map((e) =>
                e == null ? null : Sorting.fromJson(e as Map<String, dynamic>))
            ?.toList() ??
        []
    ..searchHistory =
        Cache._searchHistoryFromJson(json['searchHistory2'] as List)
    ..threadsWarning = json['threadsWarning'] as bool ?? false
    ..lastUpdateCheck = json['lastUpdateCheck'] as int ?? 0;
}

Map<String, dynamic> _$CacheToJson(Cache instance) => <String, dynamic>{
      'libraryTracks': instance.libraryTracks,
      'history': instance.history,
      'sorts': instance.sorts,
      'searchHistory2': Cache._searchHistoryToJson(instance.searchHistory),
      'threadsWarning': instance.threadsWarning,
      'lastUpdateCheck': instance.lastUpdateCheck,
    };

SearchHistoryItem _$SearchHistoryItemFromJson(Map<String, dynamic> json) {
  return SearchHistoryItem(
    json['data'],
    _$enumDecodeNullable(_$SearchHistoryItemTypeEnumMap, json['type']),
  );
}

Map<String, dynamic> _$SearchHistoryItemToJson(SearchHistoryItem instance) =>
    <String, dynamic>{
      'data': instance.data,
      'type': _$SearchHistoryItemTypeEnumMap[instance.type],
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

const _$SearchHistoryItemTypeEnumMap = {
  SearchHistoryItemType.TRACK: 'TRACK',
  SearchHistoryItemType.ALBUM: 'ALBUM',
  SearchHistoryItemType.ARTIST: 'ARTIST',
  SearchHistoryItemType.PLAYLIST: 'PLAYLIST',
};
