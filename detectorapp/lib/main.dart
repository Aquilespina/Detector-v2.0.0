import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// Importar los servicios de IA y el nuevo Painter
import 'services/pose_detector.dart';
import 'services/feature_calculator.dart';
import 'services/classifier.dart';
import 'widgets/pose_painter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anatomic AI',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _imageFile;
  String _statusMessage = 'Selecciona una imagen para analizar tu postura.';
  bool _isAnalyzing = false;

  final PoseDetector _poseDetector = PoseDetector();
  final PostureClassifier _classifier = PostureClassifier();

  ClassificationResult? _classificationResult;
  
  // --- NUEVO: Estado para el Painter ---
  ui.Image? _image;
  List<PoseLandmark> _landmarks = [];

  @override
  void initState() {
    super.initState();
    _classifier.initialize();
    _poseDetector.initialize();
  }

  @override
  void dispose() {
    _poseDetector.dispose();
    _classifier.dispose();
    super.dispose();
  }

  // --- NUEVO: Función para cargar la imagen en el formato correcto para el Painter ---
  Future<ui.Image> _loadImage(File file) async {
    final data = await file.readAsBytes();
    return await decodeImageFromList(data);
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: source, maxWidth: 1024);

      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        final image = await _loadImage(imageFile);

        setState(() {
          _imageFile = imageFile;
          _image = image;
          _statusMessage = 'Analizando imagen...';
          _isAnalyzing = true;
          _classificationResult = null;
          _landmarks = []; // Limpiar landmarks antiguos
        });

        await _analyzeImage(imageFile);
      }
    } catch (e) {
      _showError('Error al obtener la imagen: $e');
    }
  }

  Future<void> _analyzeImage(File imageFile) async {
    print("--- INICIANDO ANÁLISIS CON NUEVO MODELO ---");

    try {
      final landmarks = await _poseDetector.detectPose(imageFile);

      if (landmarks.isEmpty) {
        _showError('No se detectó ninguna persona en la imagen.');
        return;
      }

      final requiredLandmarkIds = {5, 6, 11, 12};
      final detectedIds = landmarks.map((l) => l.id).toSet();

      if (!detectedIds.containsAll(requiredLandmarkIds)) {
        _showError('Análisis fallido: Asegúrate de que hombros y caderas sean visibles.');
        return;
      }

      final features = FeatureCalculator.calculatePostureFeatures(landmarks);
      final result = _classifier.classify(features);

      setState(() {
        _statusMessage = 'Análisis completado.';
        _classificationResult = result;
        _landmarks = landmarks; // --- NUEVO: Guardar los landmarks para el Painter ---
        _isAnalyzing = false;
      });
    } catch (e) {
      _showError('Error durante el análisis: $e');
    }
  }

  void _showError(String message) {
    setState(() {
      _statusMessage = message;
      _isAnalyzing = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _reset() {
    setState(() {
      _imageFile = null;
      _image = null;
      _landmarks = [];
      _statusMessage = 'Selecciona una imagen para analizar tu postura.';
      _isAnalyzing = false;
      _classificationResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Anatomic AI: Detector Postural')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 350,
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50),
              // --- NUEVO: Usar CustomPaint para dibujar el esqueleto ---
              child: (_image != null)
                  ? CustomPaint(
                      painter: PosePainter(_image!, _landmarks),
                      size: Size.infinite,
                    )
                  : const Center(
                      child: Icon(Icons.image, size: 80, color: Colors.grey)),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: ElevatedButton.icon(onPressed: _isAnalyzing ? null : () => _pickImage(ImageSource.camera), icon: const Icon(Icons.camera_alt), label: const Text('Cámara'))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton.icon(onPressed: _isAnalyzing ? null : () => _pickImage(ImageSource.gallery), icon: const Icon(Icons.photo_library), label: const Text('Galería'))),
              ],
            ),
            const SizedBox(height: 20),
            if (_isAnalyzing) const Center(child: CircularProgressIndicator()),
            if (!_isAnalyzing) Text(_statusMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            if (_classificationResult != null) _buildResultCard(_classificationResult!),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(ClassificationResult result) {
    final cardColor = result.label == 'Saludable' ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 20.0),
      color: cardColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cardColor, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result.label.toUpperCase(), style: TextStyle(color: cardColor, fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 8),
            Text('Confianza: ${(result.confidence * 100).toStringAsFixed(1)}%'),
            const Divider(),
            Text(result.description, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
