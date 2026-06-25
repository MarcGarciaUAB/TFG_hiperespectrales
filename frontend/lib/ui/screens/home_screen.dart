import 'package:flutter/material.dart';
import '../widgets/control_panel.dart';
import '../widgets/canvas_viewer.dart';
import '../widgets/results_panel.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Analizador de Imágenes Hiperespectrales'),
        actions: [
          IconButton(
            icon: Icon(Icons.upload_file),
            tooltip: 'Cargar sesión previa',
            onPressed: () {
              // Lógica del file_service para cargar un JSON
            },
          ),
          IconButton(
            icon: Icon(Icons.save),
            tooltip: 'Descargar resultados',
            onPressed: () {
              // Lógica del file_service para guardar el mapa actual
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // Panel Izquierdo (Controles) - 20% del ancho
          Expanded(
            flex: 2, 
            child: ControlPanel(),
          ),
          // Visor Central (Imagen) - 60% del ancho
          Expanded(
            flex: 6,
            child: CanvasViewer(),
          ),
          // Panel Derecho (Estadísticas) - 20% del ancho
          Expanded(
            flex: 2,
            child: ResultsPanel(),
          ),
        ],
      ),
    );
  }
}