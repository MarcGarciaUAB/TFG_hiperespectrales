import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_state.dart';

class ControlPanel extends StatelessWidget {
  const ControlPanel({super.key});

  @override
  Widget build(BuildContext context) {
    // Escuchamos el estado global de la aplicación
    final appState = Provider.of<AppState>(context);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CONFIGURACIÓN',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Colors.tealAccent,
            ),
          ),
          const SizedBox(height: 24),

          // 1. SELECTOR DE DATASET
          const Text('Dataset Hiperespectral:', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: appState.selectedDataset,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'salinas', child: Text('Salinas (Completo)')),
              DropdownMenuItem(value: 'indian_pines', child: Text('Indian Pines')),
              DropdownMenuItem(value: 'pavia_university', child: Text('Pavia University')),
            ],
            onChanged: appState.isLoading ? null : (value) {
              if (value != null) appState.setDataset(value);
            },
          ),
          const SizedBox(height: 20),

          // 2. SELECTOR DE PREPROCESAMIENTO QUIMIOMÉTRICO
          const Text('Preprocesamiento (Filtro):', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: appState.selectedPreprocessing,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'none', child: Text('Sin Preprocesamiento')),
              DropdownMenuItem(value: 'minmax', child: Text('Normalización Min-Max')),
              DropdownMenuItem(value: 'snv', child: Text('Standard Normal Variate (SNV)')),
              DropdownMenuItem(value: 'derivative', child: Text('Primera Derivada')),
            ],
            onChanged: appState.isLoading ? null : (value) {
              if (value != null) appState.setPreprocessing(value);
            },
          ),
          const SizedBox(height: 20),

          // 3. SELECTOR DE ALGORITMO MACHINE LEARNING
          const Text('Modelo de Clasificación:', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: appState.selectedAlgorithm,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'Random_Forest', child: Text('Random Forest 🌲')),
              DropdownMenuItem(value: 'SVM_RBF', child: Text('SVM (Kernel RBF) 🧠')),
              DropdownMenuItem(value: 'PLS-DA', child: Text('PLS-DA (Lineal) 📏')),
              DropdownMenuItem(value: 'k-NN', child: Text('k-Nearest Neighbors 📐')),
            ],
            onChanged: appState.isLoading ? null : (value) {
              if (value != null) appState.setAlgorithm(value);
            },
          ),
          const Spacer(), // Empuja el botón hacia la parte inferior de la pantalla

          // Indicador de estado del Servidor Flask
          Row(
            children: [
              Icon(
                Icons.circle,
                size: 12,
                color: appState.isBackendOnline ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                appState.isBackendOnline ? 'Servidor Python: Conectado' : 'Servidor Python: Desconectado',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // BOTÓN PRINCIPAL DE EJECUCIÓN
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: appState.isLoading 
                  ? const SizedBox(
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)
                    )
                  : const Icon(Icons.analytics),
              label: Text(
                appState.isLoading ? 'PROCESANDO...' : 'EJECUTAR ANÁLISIS',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.grey[800],
              ),
              // Si está cargando o el backend está caído, deshabilitamos el botón
              onPressed: (appState.isLoading || !appState.isBackendOnline)
                  ? null 
                  : () => appState.runClassification(),
            ),
          ),
        ],
      ),
    );
  }
}