import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AppState extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  // Variables de configuración de la sesión actual
  String _selectedDataset = 'salinas';
  String _selectedAlgorithm = 'Random_Forest';
  String _selectedPreprocessing = 'snv';
  String? _currentImageBase64;
  List<double> _currentSignature = [];

  // Estados de control de la UI
  bool _isLoading = false;
  String? _errorMessage;
  bool _isBackendOnline = false;

  // El resultado: la matriz bidimensional de píxeles clasificados
  List<List<int>>? _predictionMap;

  // Getters para que la UI pueda leer las variables de forma segura (Read-Only)
  String? get currentImageBase64 => _currentImageBase64;
  List<double> get currentSignature => _currentSignature;
  String get selectedDataset => _selectedDataset;
  String get selectedAlgorithm => _selectedAlgorithm;
  String get selectedPreprocessing => _selectedPreprocessing;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isBackendOnline => _isBackendOnline;
  List<List<int>>? get predictionMap => _predictionMap;
  Offset? _selectedPixel;
  Offset? get selectedPixel => _selectedPixel;

  // Setters que actualizan el estado y avisan a los widgets
  void setDataset(String dataset) {
    _selectedDataset = dataset;
    notifyListeners();
  }

  void setAlgorithm(String algo) {
    _selectedAlgorithm = algo;
    notifyListeners();
  }

  void setPreprocessing(String prep) {
    _selectedPreprocessing = prep;
    notifyListeners();
  }

  /// Actualiza la imagen del visor (llámalo cuando el usuario mueva el slider de bandas)
  Future<void> updateRenderedImage(List<int> bands) async {
    _currentImageBase64 = await _apiService.fetchRenderedBand(
      datasetId: _selectedDataset, 
      bands: bands
    );
    notifyListeners(); // Avisa a main.dart para que redibuje la imagen
  }

  /// Actualiza la gráfica (llámalo cuando el usuario haga clic en la imagen)
  Future<void> updatePixelSignature(int x, int y) async {
    print("Consultando API para firma...");
    final sig = await _apiService.fetchPixelSignature(
      datasetId: _selectedDataset, 
      x: x, 
      y: y
    );
    
    if (sig != null) {
      _currentSignature = sig;
      print("Firma recibida: ${sig.length} puntos");
      notifyListeners(); // Avisa al gráfico para que se redibuje
    }else {
    print("Error: La API devolvió null");
  }
  }

  /// Inicializa la app verificando si Python está corriendo
  Future<void> checkServerStatus() async {
    _isBackendOnline = await _apiService.checkHealth();
    notifyListeners();
  }

  /// Dispara el flujo analítico: llama al servicio web y gestiona la carga/errores
  Future<void> runClassification() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners(); // Muestra el spinner de carga en la web

    try {
      _predictionMap = await _apiService.predict(
        datasetId: _selectedDataset,
        algorithm: _selectedAlgorithm,
        preprocessing: _selectedPreprocessing,
      );
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _predictionMap = null;
    } finally {
      _isLoading = false;
      notifyListeners(); // Oculta el spinner y dibuja el mapa o el error
    }
  }

  /// Permite inyectar directamente una matriz (útil para cuando carguemos sesiones guardadas)
  void loadExternalSession(String dataset, List<List<int>> map) {
    _selectedDataset = dataset;
    _predictionMap = map;
    _errorMessage = null;
    notifyListeners();
  }

  void selectPixel(int x, int y) {
  _selectedPixel = Offset(x.toDouble(), y.toDouble());
  print("AppState: Píxel seleccionado $x, $y");
  notifyListeners(); // Esto redibuja el mapa y el gráfico
  
  // Cargar la firma espectral automáticamente al seleccionar
  updatePixelSignature(x, y); 
}
}