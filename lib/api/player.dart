import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:equalizer/equalizer.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:Saturn/api/cache.dart';
import 'package:Saturn/api/deezer.dart';
import 'package:Saturn/ui/android_auto.dart';
import 'package:just_audio/just_audio.dart';
import 'package:connectivity/connectivity.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:Saturn/translations.i18n.dart';
import 'package:scrobblenaut/scrobblenaut.dart';
import 'package:extended_math/extended_math.dart';

import 'definitions.dart';
import '../settings.dart';

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math';



PlayerHelper playerHelper = PlayerHelper();

class PlayerHelper {

  StreamSubscription _customEventSubscription;
  StreamSubscription _mediaItemSubscription;
  StreamSubscription _playbackStateStreamSubscription;
  QueueSource queueSource;
  LoopMode repeatType = LoopMode.off;
  Timer _timer;
  int audioSession;
  int _prevAudioSession;
  bool equalizerOpen = false;

  //Visualizer
  StreamController _visualizerController = StreamController.broadcast();
  Stream get visualizerStream => _visualizerController.stream;

  //Find queue index by id
  int get queueIndex => AudioService.queue == null ? 0 : AudioService.queue.indexWhere((mi) => mi.id == AudioService.currentMediaItem?.id??'Random string so it returns -1');

  Future start() async {
     //Subscribe to custom events
    _customEventSubscription = AudioService.customEventStream.listen((event) async {
      if (!(event is Map)) return;
      switch (event['action']) {
        case 'onLoad':
          //After audio_service is loaded, load queue, set quality
          await settings.updateAudioServiceQuality();
          await AudioService.customAction('load');
          await authorizeLastFM();
          break;
        case 'onRestore':
          //Load queueSource from isolate
          this.queueSource = QueueSource.fromJson(event['queueSource']);
          repeatType = LoopMode.values[event['loopMode']];
          break;
        case 'queueEnd':
          //If last song is played, load more queue
          this.queueSource = QueueSource.fromJson(event['queueSource']);
//          onQueueEnd();
          break;
        case 'screenAndroidAuto':
          AndroidAuto androidAuto = AndroidAuto();
          List<MediaItem> data = await androidAuto.getScreen(event['id']);
          await AudioService.customAction('screenAndroidAuto', jsonEncode(data));
          break;
        case 'tracksAndroidAuto':
          AndroidAuto androidAuto = AndroidAuto();
          await androidAuto.playItem(event['id']);
          break;
        case 'audioSession':
          if (!settings.enableEqualizer) break;
          //Save
          _prevAudioSession = audioSession;
          audioSession = event['id'];
          if (audioSession == null)
            break;
          //Open EQ
          if (!equalizerOpen) {
            Equalizer.open(event['id']);
            equalizerOpen = true;
            break;
          }
          //Change session id
          if (_prevAudioSession != audioSession) {
            if (_prevAudioSession != null) Equalizer.removeAudioSessionId(_prevAudioSession);
            Equalizer.setAudioSessionId(audioSession);
          }
          break;
        //Visualizer data
        case 'visualizer':
          _visualizerController.add(event['data']);
          break;
      }

    });
    _mediaItemSubscription = AudioService.currentMediaItemStream.listen((event) {
      if (event == null) return;
      //Load more flow if index-1 song
      if (queueIndex == AudioService.queue.length-1)
        onQueueEnd();

      //Save queue
      AudioService.customAction('saveQueue');
      //Add to history
      if (cache.history == null) cache.history = [];
      if (cache.history.length > 0 && cache.history.last.id == event.id) return;
      cache.history.add(Track.fromMediaItem(event));
      cache.save();
    });

    //Logging listen timer
    _timer = Timer.periodic(Duration(seconds: 2), (timer) async {
      if (AudioService.currentMediaItem == null || !AudioService.playbackState.playing) return;
      if (AudioService.playbackState.currentPosition.inSeconds > (AudioService.currentMediaItem.duration.inSeconds * 0.75)) {
        if (cache.loggedTrackId == AudioService.currentMediaItem.id) return;
        cache.loggedTrackId = AudioService.currentMediaItem.id;
        await cache.save();

        //Log to Deezer
        if (settings.logListen) {
          deezerAPI.logListen(AudioService.currentMediaItem.id);
        }
      }

    });

    //Start audio_service
    await startService();
  }

  Future startService() async {
    if (AudioService.running && AudioService.connected) return;
    if (!AudioService.connected)
      await AudioService.connect();
    if (!AudioService.running)
      await AudioService.start(
        backgroundTaskEntrypoint: backgroundTaskEntrypoint,
        androidEnableQueue: true,
        androidStopForegroundOnPause: false,
        androidNotificationOngoing: false,
        androidNotificationClickStartsActivity: true,
        androidNotificationChannelDescription: 'freezer',
        androidNotificationChannelName: 'freezer',
        androidNotificationIcon: 'drawable/ic_logo',
        params: {'ignoreInterruptions': settings.ignoreInterruptions}
      );
  }

  Future authorizeLastFM() async {
    if (settings.lastFMUsername == null || settings.lastFMPassword == null || settings.lastFMAPIKey == null || settings.lastFMAPISecret == null) return;
    await AudioService.customAction("authorizeLastFM", [settings.lastFMUsername, settings.lastFMPassword, settings.lastFMAPIKey, settings.lastFMAPISecret]);
  }

  Future toggleShuffle() async {
    await AudioService.customAction('shuffle');
  }
  
  //Repeat toggle
  Future changeRepeat() async {
    //Change to next repeat type
    switch (repeatType) {
      case LoopMode.one:
        repeatType = LoopMode.off; break;
      case LoopMode.all:
        repeatType = LoopMode.one; break;
      default:
        repeatType = LoopMode.all; break;
    }
    //Set repeat type
    await AudioService.customAction("repeatType", LoopMode.values.indexOf(repeatType));
  }

  //Executed before exit
  Future onExit() async {
    _customEventSubscription.cancel();
    _playbackStateStreamSubscription.cancel();
    _mediaItemSubscription.cancel();
  }

  //Replace queue, play specified track id
  Future _loadQueuePlay(List<MediaItem> queue, String trackId) async {
    await startService();
    await settings.updateAudioServiceQuality();
    await AudioService.customAction('setIndex', queue.indexWhere((m) => m.id == trackId));
    await AudioService.updateQueue(queue);
//    if (queue[0].id != trackId)
//      await AudioService.skipToQueueItem(trackId);
    if (!AudioService.playbackState.playing)
      AudioService.play();
  }

  //Called when queue ends to load more tracks
  Future onQueueEnd() async {
    //Flow
    if (queueSource == null) return;

    List<Track> tracks = [];
    switch(queueSource.source) {
      case 'flow':
        tracks = await deezerAPI.flow();
        break;
      //SmartRadio/Artist radio
      case 'smartradio':
        tracks = await deezerAPI.smartRadio(queueSource.id);
        break;
      //Library shuffle
      case 'libraryshuffle':
        tracks = await deezerAPI.libraryShuffle(start: AudioService.queue.length);
        break;
      case 'mix':
        tracks = await deezerAPI.playMix(queueSource.id);
        // Deduplicate tracks with the same id
        List<String> queueIds = AudioService.queue.map((e) => e.id).toList();
        tracks.removeWhere((track) => queueIds.contains(track.id));
        break;
      default:
        // print(queueSource.toJson());
        break;
    }

    List<MediaItem> mi = tracks.map<MediaItem>((t) => t.toMediaItem()).toList();
    await AudioService.addQueueItems(mi);
//    AudioService.skipToNext();
  }

  //Play track from album
  Future playFromAlbum(Album album, String trackId) async {
    await playFromTrackList(album.tracks, trackId, QueueSource(
      id: album.id,
      text: album.title,
      source: 'album'
    ));
  }

  //Play mix by track
  Future playMix(String trackId, String trackTitle) async {
    List<Track> tracks = await deezerAPI.playMix(trackId);
    playFromTrackList(tracks, tracks[0].id, QueueSource(
        id: trackId,
        text: 'Mix based on'.i18n + ' $trackTitle',
        source: 'mix'
    ));
  }
  //Play from artist top tracks
  Future playFromTopTracks(List<Track> tracks, String trackId, Artist artist) async {
    await playFromTrackList(tracks, trackId, QueueSource(
      id: artist.id,
      text: 'Top ${artist.name}',
      source: 'topTracks'
    ));
  }
  Future playFromPlaylist(Playlist playlist, String trackId) async {
    await playFromTrackList(playlist.tracks, trackId, QueueSource(
      id: playlist.id,
      text: playlist.title,
      source: 'playlist'
    ));
  }

  //Play episode from show, load whole show as queue
  Future playShowEpisode(Show show, List<ShowEpisode> episodes, {int index = 0}) async {
    QueueSource queueSource = QueueSource(
      id: show.id,
      text: show.name,
      source: 'show'
    );
    //Generate media items
    List<MediaItem> queue = episodes.map<MediaItem>((e) => e.toMediaItem(show)).toList();

    //Load and play
    await startService();
    await settings.updateAudioServiceQuality();
    await setQueueSource(queueSource);
    await AudioService.customAction('setIndex', index);
    await AudioService.updateQueue(queue);
    if (!AudioService.playbackState.playing)
      AudioService.play();
  }

  //Load tracks as queue, play track id, set queue source
  Future playFromTrackList(List<Track> tracks, String trackId, QueueSource queueSource) async {
    await startService();

    List<MediaItem> queue = tracks.map<MediaItem>((track) => track.toMediaItem()).toList();
    await setQueueSource(queueSource);
    await _loadQueuePlay(queue, trackId);
  }

  //Load smart track list as queue, start from beginning
  Future playFromSmartTrackList2(FlowHandler stl) async {
    //Load from API if no tracks
    if (stl.tracks == null || stl.tracks.length == 0) {
      if (settings.offlineMode) {
        Fluttertoast.showToast(
          msg: "Offline mode, can't play flow.".i18n,
          gravity: ToastGravity.BOTTOM,
          toastLength: Toast.LENGTH_SHORT
        );
        return;
      }

      stl.tracks = await deezerAPI.flow();

    }
    QueueSource queueSource = QueueSource(
      id: stl.id,
      source: stl.id,
      text: stl.title??('Flow'.i18n)
    );
    await playFromTrackList(stl.tracks, stl.tracks[0].id, queueSource);
  }

  //Load smart track list as queue, start from beginning
  Future playFromSmartTrackList(SmartTrackList stl) async {
    String qwe;
    //Load from API if no tracks
    if (stl.tracks == null || stl.tracks.length == 0) {
      if (settings.offlineMode) {
        Fluttertoast.showToast(
          msg: "Offline mode, can't play flow or smart track lists.".i18n,
          gravity: ToastGravity.BOTTOM,
          toastLength: Toast.LENGTH_SHORT
        );
        return;
      }

      //Flow songs cannot be accessed by smart track list call
      if (stl.id == 'flow' || stl.title == stl.description) {
        qwe = 'flow';
        stl.tracks = await deezerAPI.flow();
      } else {
        stl = await deezerAPI.smartTrackList(stl.id);
      }
    }
    QueueSource queueSource = QueueSource(
      id: stl.id,
      source: (qwe == 'flow')?'flow':'smarttracklist',
      text: stl.title??((qwe == 'flow') ? 'Flow'.i18n : 'Smart track list'.i18n)
    );
    await playFromTrackList(stl.tracks, stl.tracks[0].id, queueSource);
  }
  
  Future setQueueSource(QueueSource queueSource) async {
    await startService();

    this.queueSource = queueSource;
    await AudioService.customAction('queueSource', queueSource.toJson());
  }

  //Reorder tracks in queue
  Future reorder(int oldIndex, int newIndex) async {
    await AudioService.customAction('reorder', [oldIndex, newIndex]);
  }

  //Start visualizer
  Future startVisualizer() async {
    await AudioService.customAction('startVisualizer');
  }
  //Stop visualizer
  Future stopVisualizer() async {
    await AudioService.customAction('stopVisualizer');
  }

}

void backgroundTaskEntrypoint() async {
  AudioServiceBackground.run(() => AudioPlayerTask());
}

class AudioPlayerTask extends BackgroundAudioTask {
  AudioPlayer _player;

  //Queue
  List<MediaItem> _queue = <MediaItem>[];
  List<MediaItem> _originalQueue;
  bool _shuffle = false;
  int _queueIndex = 0;
  ConcatenatingAudioSource _audioSource;

  AudioProcessingState _skipState;
  Seeker _seeker;

  //Stream subscriptions
  StreamSubscription _eventSub;
  StreamSubscription _audioSessionSub;
  StreamSubscription _visualizerSubscription;

  //Loaded from file/frontend
  int mobileQuality;
  int wifiQuality;
  QueueSource queueSource;
  Duration _lastPosition;
  LoopMode _loopMode = LoopMode.off;

  Completer _androidAutoCallback;
  Scrobblenaut _scrobblenaut;
  bool _scrobblenautReady = false;
  // Last logged track id
  String _loggedTrackId;

  MediaItem get mediaItem => _queue[_queueIndex];

  @override
  Future onStart(Map<String, dynamic> params) async {

    final session = await AudioSession.instance;
    session.configure(AudioSessionConfiguration.music());

    if (params['ignoreInterruptions'] == true) {
      _player = AudioPlayer(handleInterruptions: false);
      session.interruptionEventStream.listen((_) {});
      session.becomingNoisyEventStream.listen((_) {});
    } else
      _player = AudioPlayer();

    //Update track index
    _player.currentIndexStream.listen((index) {
      if (index != null) {
        _queueIndex = index;
        AudioServiceBackground.setMediaItem(mediaItem);
      }
    });
    //Update state on all clients on change
    _eventSub = _player.playbackEventStream.listen((event) {
      //Quality string
      if (_queueIndex != -1 && _queueIndex < _queue.length) {
        Map extras = mediaItem.extras;
        extras['qualityString'] = '';
        _queue[_queueIndex] = mediaItem.copyWith(extras: extras);
      }
      //Update
      _broadcastState();
    });
    _player.processingStateStream.listen((state) {
        switch(state) {
          case ProcessingState.completed:
            //Player ended, get more songs
            if (_queueIndex == _queue.length - 1)
              AudioServiceBackground.sendCustomEvent({
                'action': 'queueEnd',
                'queueSource': (queueSource??QueueSource()).toJson()
              });
            break;
          case ProcessingState.ready:
            //Ready to play
            _skipState = null;
            break;
          default:
            break;
        }
    });

    //Audio session
    _audioSessionSub = _player.androidAudioSessionIdStream.listen((event) {
      AudioServiceBackground.sendCustomEvent({"action": 'audioSession', "id": event});
    });

    //Load queue
    AudioServiceBackground.setQueue(_queue);
    AudioServiceBackground.sendCustomEvent({'action': 'onLoad'});
  }

  @override
  Future onSkipToQueueItem(String mediaId) async {
    _lastPosition = null;

    //Calculate new index
    final newIndex = _queue.indexWhere((i) => i.id == mediaId);
    if (newIndex == -1) return;
    //Update buffering state
    _skipState = newIndex > _queueIndex
      ? AudioProcessingState.skippingToNext
      : AudioProcessingState.skippingToPrevious;

    //Skip in player
    await _player.seek(Duration.zero, index: newIndex);
    _queueIndex = newIndex;
    _skipState = null;
    onPlay();
  }

  @override
  Future onPlay() async {
    _player.play();
    //Restore position on play
    if (_lastPosition != null) {
      onSeekTo(_lastPosition);
      _lastPosition = null;
    }

    //LastFM
    if (_scrobblenautReady && mediaItem.id != _loggedTrackId) {
      _loggedTrackId = mediaItem.id;
      await _scrobblenaut.track.scrobble(
        track: mediaItem.title,
        artist: mediaItem.artist,
        album: mediaItem.album,
      );
    }
  }

  @override
  Future onPause() => _player.pause();

  @override
  Future onSeekTo(Duration pos) => _player.seek(pos);

  @override
  Future<void> onFastForward() => _seekRelative(fastForwardInterval);

  @override
  Future<void> onRewind() => _seekRelative(-rewindInterval);

  @override
  Future<void> onSeekForward(bool begin) async => _seekContinuously(begin, 1);

  @override
  Future<void> onSeekBackward(bool begin) async => _seekContinuously(begin, -1);

  //Remove item from queue
  @override
  Future<void> onRemoveQueueItem(MediaItem mediaItem) async {
    int index = _queue.indexWhere((m) => m.id == mediaItem.id);
    _queue.removeAt(index);
    if (index <= _queueIndex) {
      _queueIndex--;
    }
    _audioSource.removeAt(index);

    AudioServiceBackground.setQueue(_queue);
  }

  @override
  Future<void> onSkipToNext() async {
    _lastPosition = null;
    if (_queueIndex == _queue.length-1) return;
    //Update buffering state
    _skipState = AudioProcessingState.skippingToNext;
    _queueIndex++;
    await _player.seekToNext();
    _skipState = null;
    await _broadcastState();
  }

  @override
  Future<void> onSkipToPrevious() async {
    if (_queueIndex == 0) return;
    //Update buffering state
    _skipState = AudioProcessingState.skippingToPrevious;
    //Normal skip to previous
    _queueIndex--;
    await _player.seekToPrevious();
    _skipState = null;
  }

  @override
  Future<List<MediaItem>> onLoadChildren(String parentMediaId) async {
    AudioServiceBackground.sendCustomEvent({
      'action': 'screenAndroidAuto',
      'id': parentMediaId
    });

    //Wait for data from main thread
    _androidAutoCallback = Completer();
    List<MediaItem> data = (await _androidAutoCallback.future) as List<MediaItem>;
    _androidAutoCallback = null;
    return data;
  }

  //While seeking, jump 10s every 1s
  void _seekContinuously(bool begin, int direction) {
    _seeker?.stop();
    if (begin) {
      _seeker = Seeker(_player, Duration(seconds: 10 * direction), Duration(seconds: 1), mediaItem)..start();
    }
  }

  //Relative seek
  Future _seekRelative(Duration offset) async {
    Duration newPos = _player.position + offset;
    //Out of bounds check
    if (newPos < Duration.zero) newPos = Duration.zero;
    if (newPos > mediaItem.duration) newPos = mediaItem.duration;

    await _player.seek(newPos);
  }

  //Update state on all clients
  Future _broadcastState() async {
    await AudioServiceBackground.setState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        //Stop
        MediaControl(
            androidIcon: 'drawable/ic_action_stop',
            label: 'stop',
            action: MediaAction.stop
        ),
      ],
      systemActions: [
        MediaAction.seekTo,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.stop
      ],
      processingState: _getProcessingState(),
      playing: _player.playing,
      position: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed
    );
  }

  //just_audio state -> audio_service state. If skipping, use _skipState
  AudioProcessingState _getProcessingState() {
    if (_skipState != null) return _skipState;
    //SRC: audio_service example
    switch (_player.processingState) {
      case ProcessingState.idle:
        return AudioProcessingState.stopped;
      case ProcessingState.loading:
        return AudioProcessingState.connecting;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
      default:
        throw Exception("Invalid state: ${_player.processingState}");
    }
  }

  //Replace current queue
  @override
  Future onUpdateQueue(List<MediaItem> q) async {
    _lastPosition = null;
    //just_audio
    _shuffle = false;
    _originalQueue = null;
    _player.stop();
    if (_audioSource != null) _audioSource.clear();
    //Filter duplicate IDs
    List<MediaItem> queue = [];
    for (MediaItem mi in q) {
      if (queue.indexWhere((m) => mi.id == m.id) == -1)
        queue.add(mi);
    }
    this._queue = queue;
    AudioServiceBackground.setQueue(queue);
    //Load
    await _loadQueue();
    //await _player.seek(Duration.zero, index: 0);
  }

  //Load queue to just_audio
  Future _loadQueue() async {
    //Don't reset queue index by starting player
    int qi = _queueIndex;

    List<AudioSource> sources = [];
    for(int i=0; i<_queue.length; i++) {
      AudioSource s = await _mediaItemToAudioSource(_queue[i]);
      if (s != null)
        sources.add(s);
    }

    _audioSource = ConcatenatingAudioSource(children: sources);
    //Load in just_audio
    try {
      await _player.setAudioSource(_audioSource, initialIndex: qi, initialPosition: Duration.zero);
    } catch (e) {
      //Error loading tracks
    }
    _queueIndex = qi;
    AudioServiceBackground.setMediaItem(mediaItem);
  }

  Future<AudioSource> _mediaItemToAudioSource(MediaItem mi) async {
    String url = await _getTrackUrl(mi);
    if (url == null) return null;
    if (url.startsWith('http')) return ProgressiveAudioSource(Uri.parse(url));
    return AudioSource.uri(Uri.parse(url), tag: mi.id);
  }

  Future _getTrackUrl(MediaItem mediaItem, {int quality}) async {
    //Check if offline
    String _offlinePath = p.join((await getExternalStorageDirectory()).path, 'offline/');
    File f = File(p.join(_offlinePath, mediaItem.id));
    if (await f.exists()) {
      //return f.path;
      //Stream server URL
      return 'http://localhost:36958/?id=${mediaItem.id}';
    }

    //Show episode direct link
    if (mediaItem.extras['showUrl'] != null)
      return mediaItem.extras['showUrl'];

    //Due to current limitations of just_audio, quality fallback moved to DeezerDataSource in ExoPlayer
    //This just returns fake url that contains metadata
    List playbackDetails = jsonDecode(mediaItem.extras['playbackDetails']);
    //Quality
    ConnectivityResult conn = await Connectivity().checkConnectivity();
    quality = mobileQuality;
    if (conn == ConnectivityResult.wifi) quality = wifiQuality;

    if ((playbackDetails??[]).length < 2) return null;
    //String url = 'https://dzcdn.net/?md5=${playbackDetails[0]}&mv=${playbackDetails[1]}&q=${quality.toString()}#${mediaItem.id}';
    String url = 'http://localhost:36958/?q=$quality&mv=${playbackDetails[1]}&md5origin=${playbackDetails[0]}&id=${mediaItem.id}';
    return url;
  }

  //Custom actions
  @override
  Future onCustomAction(String name, dynamic args) async {
    switch (name) {
      case 'updateQuality':
        //Pass wifi & mobile quality by custom action
        //Isolate can't access globals
        this.wifiQuality = args['wifiQuality'];
        this.mobileQuality = args['mobileQuality'];
        break;
      //Update queue source
      case 'queueSource':
        this.queueSource = QueueSource.fromJson(Map<String, dynamic>.from(args));
        break;
      //Looping
      case 'repeatType':
        _loopMode = LoopMode.values[args];
        _player.setLoopMode(_loopMode);
        break;
      //Save queue
      case 'saveQueue':
        await this._saveQueue();
        break;
      //Load queue after some initialization in frontend
      case 'load':
        await this._loadQueueFile();
        break;
      case 'shuffle':
        String originalId = mediaItem.id;
        if (!_shuffle) {
          _shuffle = true;
          _originalQueue = List.from(_queue);
          _queue.shuffle();

        } else {
          _shuffle = false;
          _queue = _originalQueue;
          _originalQueue = null;
        }

        //Broken
//      _queueIndex = _queue.indexWhere((mi) => mi.id == originalId);
        _queueIndex = 0;
        AudioServiceBackground.setQueue(_queue);
        AudioServiceBackground.setMediaItem(mediaItem);
        await _player.stop();
        await _loadQueue();
        await _player.play();
        break;

      //Android audio callback
      case 'screenAndroidAuto':
        if (_androidAutoCallback != null)
          _androidAutoCallback.complete(jsonDecode(args).map<MediaItem>((m) => MediaItem.fromJson(m)).toList());
        break;
      //Reorder tracks, args = [old, new]
      case 'reorder':
        await _audioSource.move(args[0], args[1]);
        //Switch in queue
        List<MediaItem> newQueue = List.from(_queue);
        newQueue.removeAt(args[0]);
        newQueue.insert(args[1], _queue[args[0]]);
        _queue = newQueue;
        //Update UI
        AudioServiceBackground.setQueue(_queue);
        _broadcastState();
        break;
      //Set index without affecting playback for loading
      case 'setIndex':
        this._queueIndex = args;
        break;
      //Start visualizer
      case 'startVisualizer':
        if (_visualizerSubscription != null) break;

        _player.startVisualizer(
          enableWaveform: false,
          enableFft: true,
          captureRate: 15000,
          captureSize: 128
        );
        _visualizerSubscription = _player.visualizerFftStream.listen((event) {
          //Calculate actual values
          List<double> out = [];
          for (int i=0; i<event.length/2; i++) {
            int rfk = event[i*2].toSigned(8);
            int ifk = event[i*2+1].toSigned(8);
            out.add(log(hypot(rfk, ifk) + 1) / 5.2);
          }
          AudioServiceBackground.sendCustomEvent({"action": "visualizer", "data": out});
        });
        break;
      //Stop visualizer
      case 'stopVisualizer':
        if (_visualizerSubscription != null) {
          _visualizerSubscription.cancel();
          _visualizerSubscription = null;
        }
        break;
      //Authorize lastfm
      case 'authorizeLastFM':
        String username = args[0];
        String password = args[1];
        String apiKey = args[2];
        String apiSecret = args[3];

        try {
          LastFM lastFM = await LastFM.authenticateWithPasswordHash(
              apiKey: apiKey,
              apiSecret: apiSecret,
              username: username,
              passwordHash: password
          );
          _scrobblenaut = Scrobblenaut(lastFM: lastFM);
          _scrobblenautReady = true;
        } catch (e) { print(e); }
        break;
      case 'disableLastFM':
        _scrobblenaut = null;
        _scrobblenautReady = false;
        break;
    }

    return true;
  }

  @override
  Future onTaskRemoved() async {
    await onStop();
  }

  @override
  Future onClose() async {
    print('onClose');
    await onStop();
  }

  Future onStop() async {
    await _saveQueue();
    _player.stop();
    if (_eventSub != null) _eventSub.cancel();
    if (_audioSessionSub != null) _audioSessionSub.cancel();

    await super.onStop();
  }

  //Get queue save file path
  Future<String> _getQueuePath() async {
    Directory dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'playback.json');
  }

  //Export queue to JSON
  Future _saveQueue() async {
    if (_queueIndex == 0 && _queue.length == 0) return;

    String path = await _getQueuePath();
    File f = File(path);
    //Create if doesn't exist
    if (! await File(path).exists()) {
      f = await f.create();
    }
    Map data = {
      'index': _queueIndex,
      'queue': _queue.map<Map<String, dynamic>>((mi) => mi.toJson()).toList(),
      'position': _player.position.inMilliseconds,
      'queueSource': (queueSource??QueueSource()).toJson(),
      'loopMode': LoopMode.values.indexOf(_loopMode??LoopMode.off)
    };
    await f.writeAsString(jsonEncode(data));
  }

  //Restore queue & playback info from path
  Future _loadQueueFile() async {
    File f = File(await _getQueuePath());
    if (await f.exists()) {
      Map<String, dynamic> json = jsonDecode(await f.readAsString());
      this._queue = (json['queue']??[]).map<MediaItem>((mi) => MediaItem.fromJson(mi)).toList();
      this._queueIndex = json['index'] ?? 0;
      this._lastPosition = Duration(milliseconds: json['position']??0);
      this.queueSource = QueueSource.fromJson(json['queueSource']??{});
      this._loopMode = LoopMode.values[(json['loopMode']??0)];
      //Restore queue
      if (_queue != null) {
        await AudioServiceBackground.setQueue(_queue);
        await _loadQueue();
        await AudioServiceBackground.setMediaItem(mediaItem);
      }
    }
    //Send restored queue source to ui
    AudioServiceBackground.sendCustomEvent({
      'action': 'onRestore',
      'queueSource': (queueSource??QueueSource()).toJson(),
      'loopMode': LoopMode.values.indexOf(_loopMode)
    });
    return true;
  }

  @override
  Future onAddQueueItemAt(MediaItem mi, int index) async {
    //-1 == play next
    if (index == -1) index = _queueIndex + 1;

    _queue.insert(index, mi);
    await AudioServiceBackground.setQueue(_queue);
    AudioSource _newSource =  await _mediaItemToAudioSource(mi);
    if (_newSource != null)
      await _audioSource.insert(index,_newSource);

    _saveQueue();
  }

  //Add at end of queue
  @override
  Future onAddQueueItem(MediaItem mi) async {
    if (_queue.indexWhere((m) => m.id == mi.id) != -1)
      return;

    _queue.add(mi);
    await AudioServiceBackground.setQueue(_queue);
    AudioSource _newSource =  await _mediaItemToAudioSource(mi);
    if (_newSource != null)
      await _audioSource.add(_newSource);
    _saveQueue();
  }

  @override
  Future onPlayFromMediaId(String mediaId) async {

    //Android auto load tracks
    if (mediaId.startsWith(AndroidAuto.prefix)) {
      AudioServiceBackground.sendCustomEvent({
        'action': 'tracksAndroidAuto',
        'id': mediaId.replaceFirst(AndroidAuto.prefix, '')
      });
      return;
    }

    //Does the same thing
    await this.onSkipToQueueItem(mediaId);
  }

}

//Seeker from audio_service example (why reinvent the wheel?)
//While holding seek button, will continuously seek
class Seeker {
  final AudioPlayer player;
  final Duration positionInterval;
  final Duration stepInterval;
  final MediaItem mediaItem;
  bool _running = false;

  Seeker(this.player, this.positionInterval, this.stepInterval, this.mediaItem);

  Future start() async {
    _running = true;
    while (_running) {
      Duration newPosition = player.position + positionInterval;
      if (newPosition < Duration.zero) newPosition = Duration.zero;
      if (newPosition > mediaItem.duration) newPosition = mediaItem.duration;
      player.seek(newPosition);
      await Future.delayed(stepInterval);
    }
  }

  void stop() {
    _running = false;
  }
}