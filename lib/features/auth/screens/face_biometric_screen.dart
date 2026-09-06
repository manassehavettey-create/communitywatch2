import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:ui';
import 'dart:async';
import '../../../core/widgets/three_d_grid_background.dart';

class FaceBiometricScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Function(Map<String, dynamic>) onComplete;

  const FaceBiometricScreen({
    super.key, 
    required this.userData, 
    required this.onComplete
  });

  @override
  State<FaceBiometricScreen> createState() => _FaceBiometricScreenState();
}

class _FaceBiometricScreenState extends State<FaceBiometricScreen> with TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  
  int _currentStep = 0;
  final List<String> _steps = [
    'CENTER_FACE',
    'LOOK_UP',
    'LOOK_DOWN',
    'LOOK_LEFT',
    'LOOK_RIGHT',
    'SCANNING_IDENTITY'
  ];

  late AnimationController _pulseController;
  late AnimationController _scanController;
  double _progress = 0.0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _scanController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        // Select front camera
        final front = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras![0],
        );
        
        _controller = CameraController(front, ResolutionPreset.high, enableAudio: false);
        await _controller!.initialize();
        if (mounted) setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
        _progress = (_currentStep / (_steps.length - 1));
      });
      
      if (_currentStep == _steps.length - 1) {
        _finalizeScan();
      }
    }
  }

  Future<void> _finalizeScan() async {
    setState(() => _isProcessing = true);
    _scanController.forward();
    
    // Simulate deep AI scanning
    await Future.delayed(const Duration(seconds: 4));
    
    if (mounted) {
      final updatedData = Map<String, dynamic>.from(widget.userData);
      updatedData['biometric_verified'] = 1;
      widget.onComplete(updatedData);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _pulseController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Stack(
        children: [
          const ThreeDGridBackground(),
          
          // CAMERA PREVIEW
          if (_isInitialized && _controller != null)
            Center(
              child: ClipOval(
                child: SizedBox(
                  width: 280,
                  height: 350,
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: CameraPreview(_controller!),
                  ),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Color(0xFF0A5CFF))),

          // SCANNER OVERLAY
          Center(
            child: Container(
              width: 290,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF0A5CFF).withOpacity(0.5),
                  width: 2,
                ),
              ),
            ),
          ),

          // SCAN LINE
          AnimatedBuilder(
            animation: _scanController,
            builder: (context, child) {
              return Positioned(
                top: MediaQuery.of(context).size.height * 0.3 + (350 * _scanController.value),
                left: MediaQuery.of(context).size.width * 0.5 - 140,
                child: Opacity(
                  opacity: _isProcessing ? 1.0 : 0.0,
                  child: Container(
                    width: 280,
                    height: 2,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0A5CFF),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ],
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          const Color(0xFF0A5CFF),
                          Colors.transparent,
                        ]
                      )
                    ),
                  ),
                ),
              );
            },
          ),

          // UI INTERFACE
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  _buildHeader(),
                  const Spacer(),
                  _buildInstructionCard(),
                  const SizedBox(height: 40),
                  _buildProgressIndicator(),
                  const SizedBox(height: 20),
                  if (!_isProcessing)
                    _buildStepButton(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Text(
          'BIOMETRIC_SYNC',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 4.0),
        ),
        Text(
          'FACIAL_SURVEILLANCE_ENROLLMENT',
          style: TextStyle(fontSize: 10, color: const Color(0xFF0A5CFF).withOpacity(0.8), fontWeight: FontWeight.bold, letterSpacing: 2.0),
        ),
      ],
    );
  }

  Widget _buildInstructionCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Text(
                _steps[_currentStep],
                style: const TextStyle(color: Color(0xFF0A5CFF), fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2),
              ),
              const SizedBox(height: 12),
              Text(
                _getInstructionText(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInstructionText() {
    switch(_steps[_currentStep]) {
      case 'CENTER_FACE': return 'POSITION YOUR FACE WITHIN THE CIRCULAR VIEWPORT';
      case 'LOOK_UP': return 'SLOWLY TILT YOUR HEAD UPWARDS';
      case 'LOOK_DOWN': return 'SLOWLY TILT YOUR HEAD DOWNWARDS';
      case 'LOOK_LEFT': return 'ROTATE YOUR HEAD TO THE LEFT';
      case 'LOOK_RIGHT': return 'ROTATE YOUR HEAD TO THE RIGHT';
      case 'SCANNING_IDENTITY': return 'HOLD STEADY. ANALYZING LIVENESS PATTERNS...';
      default: return '';
    }
  }

  Widget _buildProgressIndicator() {
    return Container(
      width: double.infinity,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: _progress,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A5CFF),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(color: const Color(0xFF0A5CFF).withOpacity(0.5), blurRadius: 10)
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _nextStep,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0A5CFF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: const Text('CAPTURE_POSITION', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2.0)),
      ),
    );
  }
}
