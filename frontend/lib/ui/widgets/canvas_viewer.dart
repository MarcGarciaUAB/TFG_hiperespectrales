import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_state.dart';

class CanvasViewer extends StatelessWidget {
  const CanvasViewer({super.key});

  /// Genera un color único y vistoso para cada ID de clase de forma dinámica
  Color _getClassColor(int classId) {
    if (classId == 0) return Colors.black; // El 0 siempre es el fondo/background
    
    // Paleta de colores científicos de alta visibilidad
    final List<Color> palette = [
      Colors.red, Colors.green, Colors.blue, Colors.yellow,
      Colors.purple, Colors.orange, Colors.cyan, Colors.pinkAccent,
      Colors.lime, Colors.pink, Colors.teal, Colors.indigo,
      Colors.brown, Colors.amber, Colors.lightGreen, Colors.deepPurple
    ];
    
    return palette[(classId - 1) % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Container(
      color: const Color(0xFF1E1E1E), // Fondo gris oscuro para resaltar el canvas
      child: Center(
        child: _buildContent(context, appState),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppState appState) {
    // Caso 1: El backend está procesando los datos
    if (appState.isLoading) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.tealAccent),
          SizedBox(height: 16),
          Text(
            'Procesando cubo de datos hiperespectrales...',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      );
    }

    // Caso 2: Ha ocurrido un error en la comunicación o en el script de Python
    if (appState.errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              'Error en el motor analítico:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[300]),
            ),
            const SizedBox(height: 8),
            Text(
              appState.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Caso 3: Estado inicial (No hay datos cargados todavía)
    if (appState.predictionMap == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.layers_outlined, color: Colors.grey[700], size: 64),
          const SizedBox(height: 16),
          Text(
            'Ningún mapa cargado',
            style: TextStyle(fontSize: 16, color: Colors.grey[400], fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Selecciona una configuración a la izquierda y pulsa "Ejecutar Análisis"\no importa una sesión previa desde la barra superior.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      );
    }
// Caso 4: Renderizado exitoso de la matriz mediante CustomPaint
    final matrix = appState.predictionMap!;
    final rows = matrix.length;
    final cols = matrix[0].length;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Mapa de Clasificación: ${appState.selectedDataset.toUpperCase()}',
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
        ),
        Text(
          'Resolución Espacial: $cols x $rows píxeles',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 20),
        
        // CORRECCIÓN: Envolvemos el CustomPaint dentro del widget AspectRatio
        RepaintBoundary(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 500, maxWidth: 500),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[800]!, width: 2),
            ),
            child: AspectRatio(
              aspectRatio: cols / rows, // Ahora sí está en el widget correcto
              child: CustomPaint(
                size: Size.infinite,
                painter: HyperspectralMapPainter(
                  matrix: matrix,
                  colorGenerator: _getClassColor,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Clase encargada del dibujado por hardware de los píxeles clasificados
class HyperspectralMapPainter extends CustomPainter {
  final List<List<int>> matrix;
  final Color Function(int) colorGenerator;

  HyperspectralMapPainter({required this.matrix, required this.colorGenerator});

  @override
  void paint(Canvas canvas, Size size) {
    final int rows = matrix.length;
    final int cols = matrix[0].length;

    // Calculamos cuánto mide un píxel hiperespectral en la pantalla física del navegador
    final double pixelWidth = size.width / cols;
    final double pixelHeight = size.height / rows;

    final Paint paint = Paint()..style = PaintingStyle.fill;

    // Bucle bidimensional que recorre la predicción espacial
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final int classId = matrix[r][c];
        
        // Asignamos el color de la firma quimiométrica
        paint.color = colorGenerator(classId);

        // Definimos el rectángulo geométrico de ese píxel exacto
        final Rect rect = Rect.fromLTWH(
          c * pixelWidth,
          r * pixelHeight,
          pixelWidth + 0.5,  // El +0.5 evita "grietas" de subpíxeles por el redondeo decimal
          pixelHeight + 0.5,
        );

        // Pintamos directamente en la GPU
        canvas.drawRect(rect, paint);
      }
    }
  }

  // Solo se vuelve a ejecutar el bucle si la matriz cambia (ahorra procesador)
  @override
  bool shouldRepaint(covariant HyperspectralMapPainter oldDelegate) {
    return oldDelegate.matrix != matrix;
  }
}