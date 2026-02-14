import 'dart:io';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart' as mlkit;

class PoseLandmark {
  final int id;
  final double x;
  final double y;
  final double confidence;

  PoseLandmark({
    required this.id,
    required this.x,
    required this.y,
    required this.confidence,
  });
}

class PoseDetector {
  mlkit.PoseDetector? _poseDetector;
  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized) return;
    
    final options = mlkit.PoseDetectorOptions(
      mode: mlkit.PoseDetectionMode.single,
      model: mlkit.PoseDetectionModel.base,
    );
    _poseDetector = mlkit.PoseDetector(options: options);
    _isInitialized = true;
    print('✅ Pose Detector de ML Kit inicializado');
  }

  Future<List<PoseLandmark>> detectPose(File imageFile) async {
    if (!_isInitialized) initialize();

    try {
      final inputImage = mlkit.InputImage.fromFile(imageFile);
      final List<mlkit.Pose> poses = await _poseDetector!.processImage(inputImage);

      if (poses.isEmpty) return [];

      final pose = poses.first;
      List<PoseLandmark> landmarks = [];

      // Mapeo unificado para coincidir con FeatureCalculator (IDs de MoveNet)
      // 5:L Shoulder, 6:R Shoulder, 7:L Elbow, 8:R Elbow, 9:L Wrist, 10:R Wrist, 11:L Hip, 12:R Hip
      
      _addLandmark(landmarks, pose, mlkit.PoseLandmarkType.leftShoulder, 5);
      _addLandmark(landmarks, pose, mlkit.PoseLandmarkType.rightShoulder, 6);
      _addLandmark(landmarks, pose, mlkit.PoseLandmarkType.leftElbow, 7);
      _addLandmark(landmarks, pose, mlkit.PoseLandmarkType.rightElbow, 8);
      _addLandmark(landmarks, pose, mlkit.PoseLandmarkType.leftWrist, 9);
      _addLandmark(landmarks, pose, mlkit.PoseLandmarkType.rightWrist, 10);
      _addLandmark(landmarks, pose, mlkit.PoseLandmarkType.leftHip, 11);
      _addLandmark(landmarks, pose, mlkit.PoseLandmarkType.rightHip, 12);

      return landmarks;
    } catch (e) {
      print('❌ Error en detección de pose: $e');
      return [];
    }
  }

  void _addLandmark(List<PoseLandmark> list, mlkit.Pose pose, mlkit.PoseLandmarkType type, int targetId) {
    final landmark = pose.landmarks[type];
    if (landmark != null) {
      list.add(PoseLandmark(
        id: targetId,
        x: landmark.x,
        y: landmark.y,
        confidence: landmark.likelihood,
      ));
    }
  }

  void dispose() {
    if (_isInitialized) {
      _poseDetector?.close();
      _isInitialized = false;
    }
  }
}
