import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class VoiceCommunicationService extends ChangeNotifier {
  static final VoiceCommunicationService instance = VoiceCommunicationService._init();
  VoiceCommunicationService._init();

  // IMPORTANT: GET YOUR APP ID FROM https://console.agora.io/
  static const String _appId = "YOUR_AGORA_APP_ID_HERE";

  RtcEngine? _engine;
  bool _isJoined = false;
  bool _isMuted = false;
  int? _remoteUid;

  bool get isJoined => _isJoined;
  bool get isMuted => _isMuted;
  int? get remoteUid => _remoteUid;

  /// Initializes the Agora Engine with High-Fidelity Voice Settings
  Future<void> initialize() async {
    // 1. Request Microphone Permissions
    await [Permission.microphone].request();

    // 2. Create the engine
    _engine = createAgoraRtcEngine();
    
    // 3. Initialize the engine
    await _engine!.initialize(const RtcEngineContext(
      appId: _appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    // 4. Register Event Handlers for Tactical Feedback
    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("✅ [VOICE_LINK] Local user joined: ${connection.channelId}");
          _isJoined = true;
          notifyListeners();
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("📡 [VOICE_LINK] Remote unit connected: $remoteUid");
          _remoteUid = remoteUid;
          notifyListeners();
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint("🚫 [VOICE_LINK] Remote unit disconnected: $remoteUid");
          _remoteUid = null;
          notifyListeners();
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          debugPrint("🚪 [VOICE_LINK] Left channel");
          _isJoined = false;
          _remoteUid = null;
          notifyListeners();
        },
      ),
    );

    // 5. Enable Audio Volume Indication for UI feedback
    await _engine!.enableAudioVolumeIndication(interval: 200, smooth: 3, reportVad: true);
  }

  /// Connects the Unit to a specific Tactical Channel
  Future<void> joinChannel(String channelName, {String? token}) async {
    if (_engine == null) await initialize();

    await _engine!.joinChannel(
      token: token ?? "", // Use "" if no token security is enabled in console
      channelId: channelName,
      uid: 0, // 0 allows Agora to assign a random UID
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
      ),
    );
  }

  /// Terminates the Voice Link
  Future<void> leaveChannel() async {
    await _engine?.leaveChannel();
  }

  /// Toggles Microphone Encryption (Mute)
  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    await _engine?.muteLocalAudioStream(_isMuted);
    notifyListeners();
  }

  /// Switches between Earpiece and Speaker
  Future<void> toggleSpeaker(bool useSpeaker) async {
    await _engine?.setEnableSpeakerphone(useSpeaker);
  }

  @override
  void dispose() {
    _engine?.release();
    super.dispose();
  }
}
