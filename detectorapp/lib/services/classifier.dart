import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

class ClassificationResult {
  final String label;
  final double confidence;
  final String description;
  final List<double> probabilities;
  final List<double> rawFeatures; // <-- NUEVO: Incluirá los datos de asimetría

  ClassificationResult({
    required this.label,
    required this.confidence,
    required this.description,
    required this.probabilities,
    required this.rawFeatures,
  });

  @override
  String toString() {
    return '$label (${(confidence * 100).toStringAsFixed(1)}%)';
  }
}

class PostureClassifier {
  static const String _modelPath = 'assets/models/classifier_model.tflite';
  static const String _configPath = 'assets/models/config.json';

  late Interpreter _interpreter;
  bool _isInitialized = false;

  // Parámetros cargados desde config.json
  late double _healthyThreshold;
  late double _scoliosisThreshold;
  late double _minDisplayedConfidence;
  late double _maxDisplayedConfidence;
  late double _highRiskMinConfidence;
  late double _asymmetryFuseThreshold;

  static const List<String> _classLabels = ['Saludable', 'Riesgo Leve', 'Posible escoliosis'];
  static const Map<String, String> _classDescriptions = {
    'Saludable': 'Postura dentro de parámetros normales. No se detectan asimetrías clínicamente significativas.',
    'Riesgo Leve': 'Se detectan ligeras asimetrías que podrían no ser clínicamente relevantes. Se recomienda observar la postura y repetir el análisis periódicamente.',
    'Posible escoliosis': 'Se detectan asimetrías que sugieren una posible escoliosis. Se recomienda encarecidamente consultar con un especialista.',
  };

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      print('🧠 Cargando configuración y modelo...');

      final configString = await rootBundle.loadString(_configPath);
      final config = json.decode(configString);

      final thresholds = config['classification_thresholds'];
      _healthyThreshold = thresholds['healthy'];
      _scoliosisThreshold = thresholds['scoliosis'];
      _asymmetryFuseThreshold = thresholds['asymmetry_fuse_threshold'] ?? 0.05;

      final confidenceParams = config['confidence_scaling'];
      _minDisplayedConfidence = confidenceParams['min_displayed'];
      _maxDisplayedConfidence = confidenceParams['max_displayed'];
      _highRiskMinConfidence = confidenceParams['high_risk_min'];

      _interpreter = await Interpreter.fromAsset(_modelPath);
      _isInitialized = true;

      print('✅ Configuración y modelo cargados correctamente.');
    } catch (e) {
      print('❌ Error fatal al inicializar el clasificador: $e');
      rethrow;
    }
  }

  List<double> _normalizeFeatures(List<double> features, Map<String, dynamic> config) {
    final scalerMeans = (config['scaler_means'] as List).map((e) => e as double).toList();
    final scalerScale = (config['scaler_scale'] as List).map((e) => e as double).toList();
    
    List<double> normalized = [];
    for (int i = 0; i < features.length; i++) {
      normalized.add((features[i] - scalerMeans[i]) / scalerScale[i]);
    }
    return normalized;
  }

  Future<ClassificationResult> classifyPosture(List<double> rawFeatures) async {
    if (!_isInitialized) await initialize();
    if (rawFeatures.length != 10) throw ArgumentError('Se esperaban 10 características.');

    try {
      final configString = await rootBundle.loadString(_configPath);
      final config = json.decode(configString);
      final normalizedFeatures = _normalizeFeatures(rawFeatures, config);

      var input = [normalizedFeatures];
      var output = List.filled(1 * 1, 0.0).reshape([1, 1]);
      _interpreter.run(input, output);

      double scoliosisProbability = output[0][0];
      String label;
      double confidence;

      double shoulderYDiff = rawFeatures[0]; 
      double hipYDiff = rawFeatures[1];
      bool isModelOverconfident = scoliosisProbability > _scoliosisThreshold && (shoulderYDiff.abs() < _asymmetryFuseThreshold && hipYDiff.abs() < _asymmetryFuseThreshold);

      if (isModelOverconfident) {
        print('🚨 ¡FUSIBLE ACTIVADO! El modelo predijo escoliosis, pero la asimetría es insignificante. Corrigiendo a Riesgo Leve.');
        label = _classLabels[1];
        confidence = _minDisplayedConfidence;
      } else {
        if (scoliosisProbability < _healthyThreshold) {
          label = _classLabels[0];
          double depth = 1.0 - (scoliosisProbability / _healthyThreshold);
          confidence = _minDisplayedConfidence + depth * (_maxDisplayedConfidence - _minDisplayedConfidence);
        } else if (scoliosisProbability >= _healthyThreshold && scoliosisProbability < _scoliosisThreshold) {
          label = _classLabels[1];
          double midPoint = (_healthyThreshold + _scoliosisThreshold) / 2;
          double range = (_scoliosisThreshold - _healthyThreshold) / 2;
          double depth = 1.0 - ((scoliosisProbability - midPoint).abs() / range);
          confidence = _minDisplayedConfidence + depth * (_maxDisplayedConfidence - _minDisplayedConfidence);
        } else {
          label = _classLabels[2];
          double depth = (scoliosisProbability - _scoliosisThreshold) / (1.0 - _scoliosisThreshold);
          confidence = _highRiskMinConfidence + depth * (_maxDisplayedConfidence - _highRiskMinConfidence);
        }
      }

      confidence = clampDouble(confidence, 0.0, _maxDisplayedConfidence);

      return ClassificationResult(
        label: label,
        confidence: confidence,
        description: _classDescriptions[label] ?? '',
        probabilities: [1.0 - scoliosisProbability, scoliosisProbability],
        rawFeatures: rawFeatures, // <-- NUEVO: Devolvemos los datos de asimetría
      );
    } catch (e) {
      print('❌ Error durante la clasificación: $e');
      return ClassificationResult(label: 'Error', confidence: 0, description: 'No se pudo procesar el análisis.', probabilities: [], rawFeatures: []);
    }
  }

  void dispose() {
    if (_isInitialized) {
      _interpreter.close();
      _isInitialized = false;
      print('🔒 Clasificador liberado.');
    }
  }
}
