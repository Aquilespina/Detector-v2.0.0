import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// Importar los servicios de IA actualizados
import 'services/pose_detector.dart';
import 'services/feature_calculator.dart';
import 'services/classifier.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anatomic AI',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
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

  @override
  void initState() {
    super.initState();
    _poseDetector.initialize();
    _classifier.initialize(); // Inicializa el nuevo clasificador
  }

  @override
  void dispose() {
    _poseDetector.dispose();
    _classifier.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: source, maxWidth: 1024);

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _statusMessage = 'Analizando imagen...';
          _isAnalyzing = true;
          _classificationResult = null;
        });
        await _analyzeImage(_imageFile!);
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
      
      // --- LLAMADA AL NUEVO CLASIFICADOR (SIN ASYNC/AWAIT) ---
      final result = _classifier.classify(features);

      setState(() {
        _statusMessage = 'Análisis completado.';
        _classificationResult = result;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _reset() {
    setState(() {
      _imageFile = null;
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
              child: _imageFile != null
                  ? Image.file(_imageFile!, fit: BoxFit.contain)
                  : const Center(child: Icon(Icons.image, size: 80, color: Colors.grey)),
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

  // --- TARJETA DE RESULTADOS SIMPLIFICADA ---
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
            Text(
              result.label.toUpperCase(),
              style: TextStyle(color: cardColor, fontWeight: FontWeight.bold, fontSize: 20),
            ),
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
