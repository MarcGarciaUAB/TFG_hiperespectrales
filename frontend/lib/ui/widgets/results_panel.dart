import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_state.dart';

class ResultsPanel extends StatelessWidget {
  const ResultsPanel({super.key});

  /// Mismo generador de colores que el Canvas para mantener la consistencia visual
  Color _getClassColor(int classId) {
    if (classId == 0) return Colors.black;
    final List<Color> palette = [
      Colors.red, Colors.green, Colors.blue, Colors.yellow,
      Colors.purple, Colors.orange, Colors.cyan, Colors.pinkAccent,
      Colors.lime, Colors.pink, Colors.teal, Colors.indigo,
      Colors.brown, Colors.amber, Colors.lightGreen, Colors.deepPurple
    ];
    return palette[(classId - 1) % palette.length];
  }

  /// Traduce el ID de la clase a un nombre legible en base al dataset (Aporte académico)
  String _getClassName(String dataset, int classId) {
    if (classId == 0) return 'Fondo (No clasificado)';
    
    // Nombres reales de los datasets para que tu TFG quede súper profesional
    if (dataset == 'salinas') {
      final names = [
        'Brócoli green_weed_1', 'Brócoli green_weed_2', 'Fallow', 'Fallow rough plow',
        'Fallow smooth', 'Stubble', 'Celery', 'Grapes untrained',
        'Soil vinyard develop', 'Corn senesced_green_weed', 'Lettuce romaine 4wk',
        'Lettuce romaine 5wk', 'Lettuce romaine 6wk', 'Lettuce romaine 7wk',
        'Vinyard untrained', 'Vinyard vertical trellis'
      ];
      return classId <= names.length ? names[classId - 1] : 'Clase $classId';
    } else if (dataset == 'indian_pines') {
      final names = [
        'Alfalfa', 'Corn-notill', 'Corn-mintill', 'Corn', 'Grass-pasture',
        'Grass-trees', 'Grass-pasture-mowed', 'Hay-windrowed', 'Oats',
        'Soybean-notill', 'Soybean-mintill', 'Soybean-clean', 'Wheat',
        'Woods', 'Buildings-Grass-Drives', 'Stone-Steel-Towers'
      ];
      return classId <= names.length ? names[classId - 1] : 'Clase $classId';
    }
    
    return 'Material / Clase $classId';
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final matrix = appState.predictionMap;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          left: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MÉTRICAS Y RESULTADOS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Colors.tealAccent,
            ),
          ),
          const SizedBox(height: 24),

          // Si no hay datos, mostramos un mensaje de espera sutil
          if (matrix == null)
            const Expanded(
              child: Center(
                child: Text(
                  'Esperando datos de análisis...',
                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ),
            )
          else ...[
            // Si hay datos, calculamos el histograma en tiempo real
            _buildStatisticsList(context, appState, matrix),
          ],
        ],
      ),
    );
  }

  Widget _buildStatisticsList(BuildContext context, AppState appState, List<List<int>> matrix) {
    // 1. Algoritmo de conteo (Histograma)
    final Map<int, int> histogram = {};
    int totalPixels = 0;

    for (var row in matrix) {
      for (var pixel in row) {
        histogram[pixel] = (histogram[pixel] ?? 0) + 1;
        totalPixels++;
      }
    }

    // Ordenamos las clases numéricamente para que la lista no salga desordenada
    final sortedClasses = histogram.keys.toList()..sort();

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Píxeles Evaluados: $totalPixels',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const Divider(height: 24, color: Colors.grey),
          
          // Lista scrollable con el desglose de cada elemento quimiométrico detectado
          Expanded(
            child: ListView.builder(
              itemCount: sortedClasses.length,
              itemBuilder: (context, index) {
                final classId = sortedClasses[index];
                final count = histogram[classId]!;
                final percentage = (count / totalPixels) * 100;
                final className = _getClassName(appState.selectedDataset, classId);
                final classColor = _getClassColor(classId);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      // Pequeño indicador de color cuadrado (Leyenda mapeada con la GPU)
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: classColor,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: Colors.white24, width: 0.5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Nombre de la clase / material detectado
                      Expanded(
                        child: Text(
                          className,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      
                      // Datos numéricos cuantitativos (Píxeles y % de área ocupada)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${percentage.toStringAsFixed(2)}%',
                            style: const TextStyle(
                              fontSize: 13, 
                              fontWeight: FontWeight.bold,
                              color: Colors.tealAccent
                            ),
                          ),
                          Text(
                            '$count px',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}