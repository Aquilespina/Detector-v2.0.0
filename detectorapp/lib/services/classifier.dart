import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

// --- NUEVA CLASE DE RESULTADO (MÁS SIMPLE) ---
class ClassificationResult {
  final String label;
  final double confidence;
  final String description;

  ClassificationResult({
    required this.label,
    required this.confidence,
    required this.description,
  });

  @override
  String toString() {
    return '$label (${(confidence * 100).toStringAsFixed(1)}%)';
  }
}

// --- NUEVO CLASIFICADOR (BASADO EN TU CÓDIGO) ---
class PostureClassifier {
  late Interpreter _interpreter;
  late double _umbral;

  Future<void> initialize() async {
    try {
      // Cargar metadatos para obtener el umbral correcto
      final String metadataString = await rootBundle.loadString('assets/models/metadata_flutter.json');
      final metadata = json.decode(metadataString);
      _umbral = metadata['umbral_recomendado'];

      // Cargar el nuevo modelo TFLite
      _interpreter = await Interpreter.fromAsset('assets/models/modelo_escoliosis_final.tflite');

      print('✅ Modelo y metadatos cargados. Umbral de decisión: $_umbral');
    } catch (e) {
      print('❌ Error fatal al inicializar el nuevo clasificador: $e');
      rethrow;
    }
  }

  ClassificationResult classify(List<double> features) {
    var input = [features];
    
    // --- ¡CORRECCIÓN! Ajustar la forma de salida a la que el nuevo modelo espera ---
    var output = List.filled(4, 0.0).reshape([2, 2]);

    try {
      _interpreter.run(input, output);

      // Asumimos que la probabilidad relevante sigue estando en la primera "fila" de la respuesta
      double probEscoliosis = output[0][1];

      if (probEscoliosis > _umbral) {
        return ClassificationResult(
          label: 'Posible escoliosis',
          confidence: probEscoliosis,
          description: 'Se detectaron asimetrías que podrían sugerir una posible escoliosis. Se recomienda consultar con un especialista.',
        );
      } else {
        return ClassificationResult(
          label: 'Saludable',
          confidence: 1 - probEscoliosis,
          description: 'Postura dentro de los parámetros normales. No se detectan indicios claros de escoliosis.',
        );
      }
    } catch (e) {
      print('❌ Error durante la clasificación: $e');
      return ClassificationResult(
          label: 'Error',
          confidence: 0,
          description: 'No se pudo procesar el análisis con el modelo.');
    }
  }

  void dispose() {
    _interpreter.close();
    print('🔒 Clasificador liberado.');
  }
}
