import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../../bible/references.dart';
import 'audio_catalog.dart';

/// Plays chapter recordings with background and lock-screen controls.
/// Only created when a licensed source exists (see audio_catalog.dart).
class BibleAudioHandler extends BaseAudioHandler with SeekHandler {
  BibleAudioHandler(this.source) {
    _player.playbackEventStream.listen((_) => _broadcast());
    _player.processingStateStream.listen((s) {
      if (s == ProcessingState.completed) skipToNext();
    });
  }

  final AudioSourceInfo source;
  final _player = AudioPlayer();
  ChapterRef? _chapter;

  static BibleAudioHandler? _instance;

  /// Starts the audio service once and returns the shared handler.
  static Future<BibleAudioHandler> start(AudioSourceInfo source) async {
    return _instance ??= await AudioService.init(
      builder: () => BibleAudioHandler(source),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'app.scripture.bibleapp.audio',
        androidNotificationChannelName: 'Audio Bible',
        androidNotificationOngoing: true,
      ),
    );
  }

  Stream<Duration> get position => _player.positionStream;
  Duration? get duration => _player.duration;
  ChapterRef? get chapter => _chapter;

  Future<void> playChapter(ChapterRef c) async {
    _chapter = c;
    mediaItem.add(
      MediaItem(
        id: c.code,
        title: c.label,
        album: source.name,
        artist: source.license,
      ),
    );
    await _player.setUrl(source.chapterUrl(c).toString());
    await _player.play();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> skipToNext() async {
    final next = _chapter?.next;
    if (next != null) await playChapter(next);
  }

  @override
  Future<void> skipToPrevious() async {
    final prev = _chapter?.previous;
    if (prev != null) await playChapter(prev);
  }

  void _broadcast() {
    final playing = _player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: switch (_player.processingState) {
          ProcessingState.idle => AudioProcessingState.idle,
          ProcessingState.loading => AudioProcessingState.loading,
          ProcessingState.buffering => AudioProcessingState.buffering,
          ProcessingState.ready => AudioProcessingState.ready,
          ProcessingState.completed => AudioProcessingState.completed,
        },
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ),
    );
  }
}
