import '../../bible/references.dart';

/// A licensed audio recording of one translation.
class AudioSourceInfo {
  const AudioSourceInfo({
    required this.translationId,
    required this.name,
    required this.license,
    required this.chapterUrl,
  });

  final String translationId;
  final String name;
  final String license;

  /// URL of the recording for a chapter.
  final Uri Function(ChapterRef chapter) chapterUrl;
}

/// Audio sources the app may play. Only recordings whose licence is
/// confirmed for use in this app belong here; none are confirmed yet, so
/// the audio player is shown disabled.
const List<AudioSourceInfo> licensedAudioSources = [];

AudioSourceInfo? audioSourceFor(String translationId) {
  for (final s in licensedAudioSources) {
    if (s.translationId == translationId) return s;
  }
  return null;
}
