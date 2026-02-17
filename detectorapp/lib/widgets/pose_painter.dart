import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/pose_detector.dart';

class PosePainter extends CustomPainter {
  final ui.Image image;
  final List<PoseLandmark> landmarks;

  PosePainter(this.image, this.landmarks);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.lightGreen
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    // --- LÓGICA DE DIBUJO CORREGIDA Y ROBUSTA ---

    // 1. Define los tamaños de la imagen y del contenedor donde se va a dibujar.
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final canvasSize = size;

    // 2. Calcula cómo se debe ajustar la imagen para que quepa en el contenedor (BoxFit.contain).
    final fittedSizes = applyBoxFit(BoxFit.contain, imageSize, canvasSize);
    final sourceSize = fittedSizes.source;
    final destinationSize = fittedSizes.destination;

    // 3. Calcula el rectángulo de origen (toda la imagen) y el de destino (centrado en el canvas).
    final sourceRect = Rect.fromLTWH(0, 0, sourceSize.width, sourceSize.height);
    final double dx = (canvasSize.width - destinationSize.width) / 2.0;
    final double dy = (canvasSize.height - destinationSize.height) / 2.0;
    final destinationRect = Rect.fromLTWH(dx, dy, destinationSize.width, destinationSize.height);

    // 4. Dibuja la imagen de fondo.
    canvas.drawImageRect(image, sourceRect, destinationRect, Paint());

    if (landmarks.isEmpty) return;

    // 5. Escala y dibuja los puntos usando el `destinationRect` como referencia precisa.
    final Map<int, Offset> landmarkOffsets = {};
    for (final landmark in landmarks) {
      // Escala las coordenadas desde el tamaño original de la imagen al tamaño y posición en que fue dibujada.
      final double scaledDx = (landmark.x / image.width) * destinationRect.width + destinationRect.left;
      final double scaledDy = (landmark.y / image.height) * destinationRect.height + destinationRect.top;
      landmarkOffsets[landmark.id] = Offset(scaledDx, scaledDy);
    }
    
    // 6. Dibuja las conexiones y los puntos.
    final connections = [
      [5, 6], [11, 12], [5, 11], [6, 12], [5, 7], [7, 9], [6, 8], [8, 10],
    ];

    for (final connection in connections) {
      if (landmarkOffsets.containsKey(connection[0]) && landmarkOffsets.containsKey(connection[1])) {
        canvas.drawLine(landmarkOffsets[connection[0]]!, landmarkOffsets[connection[1]]!, linePaint);
      }
    }

    for (final offset in landmarkOffsets.values) {
      canvas.drawPoints(ui.PointMode.points, [offset], dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.landmarks != landmarks;
  }
}
