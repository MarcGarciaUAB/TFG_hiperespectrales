import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'dart:convert';

// Importa tus modelos y servicios
import 'models/app_state.dart';
import 'services/file_service.dart';
import 'services/api_service.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..checkServerStatus(),
      child: const HyperspectralApp(),
    ),
  );
}

class HyperspectralApp extends StatelessWidget {
  const HyperspectralApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Analizador de Imágenes Hiperespectrales',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFF0EA5E9),
          background: Color(0xFF0F172A),
          surface: Color(0xFF1E293B),
          onBackground: Color(0xFFF1F5F9),
          onSurface: Color(0xFFE2E8F0),
        ),
        useMaterial3: true,
        fontFamily: 'RobotoMono',
      ),
      home: const HyperspectralWorkspace(),
    );
  }
}

class CropClass {
  final String name;
  final Color color;
  CropClass(this.name, this.color);
}

class DatasetClasses {
    static final Map<String, List<String>> _labelsMap = {
    'salinas': [
      'Fondo', 'Brocoli_green_weeds_1', 'Brocoli_green_weeds_2', 'Fallow', 'Fallow_rough_plow',
      'Fallow_smooth', 'Stubble', 'Celery', 'Grapes_untrained', 'Soil_vinyard_develop',
      'Corn_senesced_green_weeds', 'Lettuce_romaine_4wk', 'Lettuce_romaine_5wk', 'Lettuce_romaine_6wk',
      'Lettuce_romaine_7wk', 'Vinyard_untrained', 'Vinyard_vertical_trellis'
    ],
    'pavia_university': [
      'Fondo', 'Asfalto', 'Prados', 'Grava', 'Pintura metálica', 'Chapas', 'Sombras', 'Self-Blocking Bricks', 'Césped', 'Árboles'
    ],
    'indian_pines': [
      'Fondo', 'Alfalfa', 'Corn (no-till)', 'Corn (min-till)', 'Grass-pasture', 'Hay-windrowed', 'Soybean (no-till)', 'Soybean (min-till)', 'Wheat', 'Woods'
    ],
    
};
static final List<Color> _colors = [
    Colors.transparent, Colors.red, Colors.green, Colors.blue, Colors.yellow, 
    Colors.purple, Colors.orange, Colors.cyan, Colors.pink, Colors.brown, 
    Colors.teal, Colors.indigo, Colors.lime, Colors.amber, Colors.grey, Colors.blueGrey
  ];
  static String getName(String datasetId, int index) {
    final labels = _labelsMap[datasetId] ?? ['Desconocido'];
    return (index >= 0 && index < labels.length) ? labels[index] : 'Clase $index';
  }
  static Color getColor(int index) {
    return (index >= 0 && index < _colors.length) ? _colors[index] : Colors.black;
  }
  static int getCount(String datasetId) {
    return _labelsMap[datasetId]?.length ?? 0;
  }
}
class HyperspectralWorkspace extends StatefulWidget {
  const HyperspectralWorkspace({super.key});

  @override
  State<HyperspectralWorkspace> createState() => _HyperspectralWorkspaceState();
}

class _HyperspectralWorkspaceState extends State<HyperspectralWorkspace> {
  // Image properties & Stacks
  int? _highlightedClassIndex;
  String? _loadedFileName;
  int _imageWidth = 145;
  int _imageHeight = 145;
  int _totalBands = 220;
  String? _selectedFormat;
  bool _isImageLoaded = false;

  // Render & Color LUT modes
  bool _isRGBComposite = false;
  String _activeLUT = 'Grayscale'; 
  int _singleBandIndex = 29;
  int _rBandIndex = 50;
  int _gBandIndex = 110;
  int _bBandIndex = 170;

  // Toolbar & Selection variables
  String _activeTool = 'Point'; 
  Offset? _selectedPixel;
  Rect? _selectedROI;
  Offset? _roiStartPoint;

  // Contrast & Threshold tools
  double _brightness = 1.0;
  double _contrast = 1.0;
  bool _thresholdEnabled = false;
  double _thresholdValue = 0.5;

  // Processing & Analytical options
  String _activePreprocessing = 'None'; 
  String _activeAlgorithm = 'Random_Forest';
  bool _isClassifying = false;
  bool _hasClassificationResults = false;
  String? _highlightedClass;
  String? _errorMessage;

  // ImageJ Measure Window simulated data
  Map<String, double>? _roiMeasurements;

  // Manual inputs controllers
  late TextEditingController _brightnessController;
  late TextEditingController _contrastController;
  late TextEditingController _thresholdController;
  late TextEditingController _singleBandController;
  late TextEditingController _rBandController;
  late TextEditingController _gBandController;
  late TextEditingController _bBandController;

  @override
  void initState() {
    super.initState();
    _brightnessController = TextEditingController(text: _brightness.toStringAsFixed(2));
    _contrastController = TextEditingController(text: _contrast.toStringAsFixed(2));
    _thresholdController = TextEditingController(text: _thresholdValue.toStringAsFixed(2));
    _singleBandController = TextEditingController(text: _singleBandIndex.toString());
    _rBandController = TextEditingController(text: _rBandIndex.toString());
    _gBandController = TextEditingController(text: _gBandIndex.toString());
    _bBandController = TextEditingController(text: _bBandIndex.toString());
  }

  @override
  void dispose() {
    _brightnessController.dispose();
    _contrastController.dispose();
    _thresholdController.dispose();
    _singleBandController.dispose();
    _rBandController.dispose();
    _gBandController.dispose();
    _bBandController.dispose();
    super.dispose();
  }

  double _bandToWavelength(int bandIndex) {
    if (_loadedFileName == 'pavia_university.mat') {
      return 430.0 + (bandIndex * (430.0 / 102.0));
    } else {
      int maxBand = _totalBands > 1 ? _totalBands - 1 : 1;
      return 400.0 + (bandIndex * (2100.0 / maxBand));
    }
  }

  void _openDataset(String filename, String format) {
    setState(() {
      _errorMessage = null;
      _loadedFileName = filename;
      _selectedFormat = format;
      _imageWidth = (filename == "indian_pines.mat") ? 145 : 256;
      _imageHeight = (filename == "indian_pines.mat") ? 145 : 256;
      _totalBands = (filename == "indian_pines.mat") ? 220 : 103;
      _isImageLoaded = true;
      _selectedPixel = const Offset(72, 72);
      _selectedROI = null;
      _roiMeasurements = null;
      _hasClassificationResults = false;

      // Sync limits to manual controllers
      _singleBandIndex = 29;
      _singleBandController.text = '29';
      _rBandIndex = 50;
      _rBandController.text = '50';
      _gBandIndex = 110;
      _gBandController.text = '110';
      _bBandIndex = 170;
      _bBandController.text = '170';

      _calculatePixelMeasurement();
    });

    // Mapear al string esperado por backend y actualizar AppState
    String dsId = 'salinas';
    if (filename == "indian_pines.mat") dsId = 'indian_pines';
    if (filename == "pavia_university.mat") dsId = 'pavia_university';
    final appState = context.read<AppState>();
    appState.setDataset(dsId);
    context.read<AppState>().setDataset(dsId);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Dataset "$filename" abierto correctamente.'),
        backgroundColor: Colors.cyan[900],
      ),
    );
  }

  void _resetWorkspace() {
    setState(() {
      _loadedFileName = null;
      _isImageLoaded = false;
      _selectedPixel = null;
      _selectedROI = null;
      _activePreprocessing = 'None';
      _hasClassificationResults = false;
      _isClassifying = false;
      _highlightedClass = null;
      _errorMessage = null;
      _roiMeasurements = null;
      _brightness = 1.0;
      _contrast = 1.0;
      _thresholdEnabled = false;

      _brightnessController.text = '1.00';
      _contrastController.text = '1.00';
      _thresholdController.text = '0.50';
    });
  }

  void _importSession() async {
    final data = await FileService.uploadSession();
    if (data != null) {
      final datasetId = data['dataset_id'];
      final mapDynamic = data['prediction_map'] as List<dynamic>;
      final predictionMap = mapDynamic.map((row) => List<int>.from(row as List)).toList();
      
      context.read<AppState>().loadExternalSession(datasetId, predictionMap);
      
      String filename = 'indian_pines.mat';
      if (datasetId == 'pavia_university') filename = 'pavia_university.mat';
      if (datasetId == 'salinas') filename = 'salinas_agricultural.hdr';
      
      _openDataset(filename, (filename.endsWith('.mat') ? '.mat' : '.hdr'));
      
      setState(() {
        _hasClassificationResults = true;
      });
    }
  }

  void _exportSession() {
    final appState = context.read<AppState>();
    if (appState.predictionMap != null) {
      FileService.downloadSession(
        datasetId: appState.selectedDataset,
        predictionMap: appState.predictionMap!,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay mapa de clasificación para exportar.')),
      );
    }
  }

  void _calculatePixelMeasurement() {
  if (_selectedPixel == null) return;
  
  final appState = context.read<AppState>();
  List<double> rawCurve = appState.currentSignature; // Leemos la curva real del servidor
  
  if (rawCurve.isEmpty) return;

  List<double> processedCurve = _applyPreprocessing(rawCurve);

  double sum = processedCurve.reduce((a, b) => a + b);
  double mean = sum / processedCurve.length;
  double min = processedCurve.reduce(math.min);
  double max = processedCurve.reduce(math.max);
  double variance = processedCurve.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) / processedCurve.length;
  double stdDev = math.sqrt(variance);

  setState(() {
    _roiMeasurements = {
      'Área (px)': 1.0,
      'Reflectancia Media': mean,
      'Desv. Estándar': stdDev,
      'Mínimo Espectral': min,
      'Máximo Espectral': max,
    };
  });
}

Future<void> _calculateROIMeasurements() async {
  if (_selectedROI == null) return;

  final appState = context.read<AppState>();

  int xStart = ((_selectedROI!.left / 380) * _imageWidth).toInt();
  int xEnd   = ((_selectedROI!.right / 380) * _imageWidth).toInt();
  int yStart = ((_selectedROI!.top / 380) * _imageHeight).toInt();
  int yEnd   = ((_selectedROI!.bottom / 380) * _imageHeight).toInt();

  final result = await ApiService().fetchROIStats(
    datasetId: appState.selectedDataset,
    xStart: xStart,
    yStart: yStart,
    xEnd: xEnd,
    yEnd: yEnd,
  );

  if (result == null) return;

  final meanCurve = List<double>.from(result['mean_curve']);

  final processed = _applyPreprocessing(meanCurve);

  double mean = processed.reduce((a, b) => a + b) / processed.length;

  setState(() {
    _roiMeasurements = {
      'Área (px)': ((xEnd - xStart) * (yEnd - yStart)).toDouble(),
      'Reflectancia Media': mean,
      'Mínimo Espectral': result['min'],
      'Máximo Espectral': result['max'],
    };
  });
}

  List<double> _applyPreprocessing(List<double> originalCurve) {
    if (_activePreprocessing == 'Normalize') {
      double max = originalCurve.reduce(math.max);
      double min = originalCurve.reduce(math.min);
      return originalCurve.map((v) => (max - min > 0) ? (v - min) / (max - min) : v).toList();
    } else if (_activePreprocessing == 'SNV') {
      double sum = originalCurve.reduce((a, b) => a + b);
      double mean = sum / originalCurve.length;
      double variance = originalCurve.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) / originalCurve.length;
      double stdDev = math.sqrt(variance);
      return originalCurve.map((v) => (stdDev > 0) ? (v - mean) / stdDev : 0.0).toList();
    } else if (_activePreprocessing == '1st Derivative') {
      List<double> derivative = [];
      for (int i = 0; i < originalCurve.length - 1; i++) {
        derivative.add((originalCurve[i + 1] - originalCurve[i]) * 5);
      }
      derivative.add(0.0);
      return derivative;
    }
    return originalCurve;
  }

  Future<void> _runModelClassification() async {
    setState(() {
      _isClassifying = true;
      _errorMessage = null;
    });

    final appState = context.read<AppState>();
    await appState.runClassification();

    setState(() {
      _isClassifying = false;
      if (appState.errorMessage != null) {
        _errorMessage = appState.errorMessage;
        _hasClassificationResults = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error del servidor: $_errorMessage'),
            backgroundColor: Colors.redAccent,
          ),
        );
      } else {
        _hasClassificationResults = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clasificación completada con éxito.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

void _exportSpectralCSV() {
  if (_selectedPixel == null) return;

  final appState = context.read<AppState>();
  final curve = _applyPreprocessing(appState.currentSignature);

  if (curve.isEmpty) return;

  int x = _selectedPixel!.dx.toInt();
  int y = _selectedPixel!.dy.toInt();

  String csvContent = "Band,Wavelength_nm,Reflectance\n";

  for (int i = 0; i < curve.length; i++) {
    double wl = _bandToWavelength(i);
    csvContent += "$i,${wl.toStringAsFixed(1)},${curve[i].toStringAsFixed(6)}\n";
  }

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Exportar Firma Espectral'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Referencia Píxel: X:$x, Y:$y'),
          const SizedBox(height: 12),
          Container(
            height: 150,
            width: 400,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(4),
            ),
            child: SingleChildScrollView(
              child: Text(
                csvContent,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('CSV generado correctamente.')),
            );
          },
          icon: const Icon(Icons.download),
          label: const Text('Guardar CSV'),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Column(
        children: [
          _buildMenuBar(),
          _buildToolbar(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: _buildLeftControlPanel()),
                Expanded(flex: 5, child: _buildMainViewerPanel()),
                Expanded(flex: 4, child: _buildRightAnalyticalPanel()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuBar() {
    return Container(
      color: const Color(0xFF020617),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.science_rounded, color: Color(0xFF38BDF8), size: 18),
          const SizedBox(width: 8),
          const Text('Analizador de Imágenes Hiperespectrales', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
          const SizedBox(width: 24),
          _buildMenuDropdown('Archivo', [
            _buildMenuItem('Abrir Indian Pines (.mat)', () => _openDataset('indian_pines.mat', '.mat')),
            _buildMenuItem('Abrir Pavia University (.mat)', () => _openDataset('pavia_university.mat', '.mat')),
            _buildMenuItem('Abrir Salinas (.hdr)', () => _openDataset('salinas_agricultural.hdr', '.hdr')),
            const PopupMenuDivider(),
            _buildMenuItem('Importar Sesión (.json)', _importSession),
            _buildMenuItem('Exportar Sesión (.json)', _exportSession),
            const PopupMenuDivider(),
            _buildMenuItem('Reiniciar Análisis', _resetWorkspace),
          ]),
          _buildMenuDropdown('Editar', [
            _buildMenuItem('Limpiar ROI Seleccionada', () {
              setState(() {
                _selectedROI = null;
                _roiMeasurements = null;
              });
            }),
          ]),
          _buildMenuDropdown('Imagen', [
            _buildMenuItem('Modo Banda Única', () => setState(() => _isRGBComposite = false)),
            _buildMenuItem('Modo Combinación RGB', () => setState(() => _isRGBComposite = true)),
            const PopupMenuDivider(),
            _buildMenuItem('LUT: Escala de Grises', () => setState(() => _activeLUT = 'Grayscale')),
            _buildMenuItem('LUT: Térmico (Fuego)', () => setState(() => _activeLUT = 'Thermal')),
            _buildMenuItem('LUT: Jet (Arcoíris)', () => setState(() => _activeLUT = 'Rainbow')),
            _buildMenuItem('LUT: Hielo/Frío', () => setState(() => _activeLUT = 'Ice')),
          ]),
          _buildMenuDropdown('Algoritmo', [
            _buildMenuItem('k-NN', () { setState(() => _activeAlgorithm = 'k-NN'); context.read<AppState>().setAlgorithm('k-NN'); }),
            _buildMenuItem('PLS-DA', () { setState(() => _activeAlgorithm = 'PLS-DA'); context.read<AppState>().setAlgorithm('PLS-DA'); }),
            _buildMenuItem('Random Forest', () { setState(() => _activeAlgorithm = 'Random_Forest'); context.read<AppState>().setAlgorithm('Random_Forest'); }),
            _buildMenuItem('SVM (RBF)', () { setState(() => _activeAlgorithm = 'SVM_RBF'); context.read<AppState>().setAlgorithm('SVM_RBF'); }),
          ]),
          _buildMenuDropdown('Procesar', [
            _buildMenuItem('Aplicar Normalización', () {
              setState(() => _activePreprocessing = 'Normalize');
              context.read<AppState>().setPreprocessing('normalización');
            }),
            _buildMenuItem('Aplicar SNV (Standard Normal Variate)', () {
              setState(() => _activePreprocessing = 'SNV');
              context.read<AppState>().setPreprocessing('snv');
            }),
            _buildMenuItem('Aplicar Primera Derivada', () {
              setState(() => _activePreprocessing = '1st Derivative');
              context.read<AppState>().setPreprocessing('primera derivada');
            }),
            _buildMenuItem('Restablecer Filtros', () {
              setState(() => _activePreprocessing = 'None');
              context.read<AppState>().setPreprocessing('ninguno');
            }),
          ]),
          _buildMenuDropdown('Analizar', [
            _buildMenuItem('Medir Selección ("Measure")', () {
              if (_activeTool == 'Rectangle') {
                _calculateROIMeasurements();
              } else {
                _calculatePixelMeasurement();
              }
            }),
            _buildMenuItem('Graficar Firma Espectral', _exportSpectralCSV),
          ]),
        ],
      ),
    );
  }

  Widget _buildMenuDropdown(String title, List<PopupMenuEntry> items) {
    return PopupMenuButton(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          title,
          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
        ),
      ),
      itemBuilder: (context) => items,
    );
  }

  PopupMenuItem _buildMenuItem(String title, VoidCallback action) {
    return PopupMenuItem(
      onTap: action,
      height: 32,
      child: Text(title, style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _buildToolbar() {
    return Container(
      color: const Color(0xFF1E293B),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _buildToolButton('Point', Icons.adjust, 'Selección de Píxel (Firma Unitaria)'),
          _buildToolButton('Rectangle', Icons.crop_square, 'Definición de ROI (Estadísticas Integradas)'),
          _buildToolButton('Pan', Icons.pan_tool_outlined, 'Navegación libre por Lienzo'),
          _buildToolButton('Zoom', Icons.zoom_in, 'Zoom dinámico'),
          const VerticalDivider(color: Colors.white24, width: 24),
          IconButton(
            icon: _isClassifying 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2))
                : const Icon(Icons.flash_on, size: 16, color: Colors.amber),
            tooltip: 'Ejecutar Clasificador ($_activeAlgorithm)',
            onPressed: _isImageLoaded && !_isClassifying ? _runModelClassification : null,
          ),
          IconButton(
            icon: const Icon(Icons.table_chart_outlined, size: 16, color: Colors.greenAccent),
            tooltip: 'Medir región seleccionada',
            onPressed: _isImageLoaded
                ? () {
                    if (_activeTool == 'Rectangle' && _selectedROI != null) {
                      _calculateROIMeasurements();
                    } else {
                      _calculatePixelMeasurement();
                    }
                  }
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.transform, size: 16, color: Colors.purpleAccent),
            tooltip: 'Alternar Umbralización (Threshold)',
            onPressed: _isImageLoaded ? () => setState(() => _thresholdEnabled = !_thresholdEnabled) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton(String toolName, IconData icon, String tooltip) {
    bool isSelected = _activeTool == toolName;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          setState(() {
            _activeTool = toolName;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(6),
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0EA5E9) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.white70),
        ),
      ),
    );
  }

  Widget _buildLeftControlPanel() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(right: BorderSide(color: Colors.blueGrey[700]!, width: 1)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Propiedades de la Imagen', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            _buildMetadataPanel(),
            const Divider(height: 24),
            const Text('Lookup Table (LUT)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            _buildLUTSelector(),
            const Divider(height: 24),
            const Text('Preprocesamiento', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            _buildPreprocessingSelector(),
            const Divider(height: 24),
            const Text('Ajustes de Contraste y Brillo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            _buildContrastControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataPanel() {
    if (!_isImageLoaded) {
      return Container(
        padding: const EdgeInsets.all(12),
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.blueGrey[900], borderRadius: BorderRadius.circular(6)),
        child: const Text('Cargue un dataset desde el menú "Archivo".', style: TextStyle(fontSize: 10, color: Colors.white54)),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.blueGrey[900], borderRadius: BorderRadius.circular(6)),
      child: Column(
        children: [
          _buildMetaRow('Nombre Archivo', _loadedFileName ?? ''),
          _buildMetaRow('Dimensiones', '${_imageWidth}x$_imageHeight px'),
          _buildMetaRow('Bandas de Stack', '$_totalBands bandas'),
          _buildMetaRow('Rango Espectral', '400 nm - 2500 nm'),
          _buildMetaRow('Formato', _selectedFormat ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String key, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: const TextStyle(fontSize: 10, color: Colors.white60)),
          Text(val, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
        ],
      ),
    );
  }

  Widget _buildLUTSelector() {
    return Column(
      children: ['Grayscale', 'Thermal', 'Rainbow', 'Ice'].map((lut) {
        return RadioListTile<String>(
          title: Text(lut, style: const TextStyle(fontSize: 11)),
          value: lut,
          dense: true,
          contentPadding: EdgeInsets.zero,
          groupValue: _activeLUT,
          onChanged: (val) {
            if (val != null) setState(() => _activeLUT = val);
          },
        );
      }).toList(),
    );
  }

  Widget _buildPreprocessingSelector() {
    return Column(
      children: ['None', 'Normalize', 'SNV', '1st Derivative'].map((method) {
        return RadioListTile<String>(
          title: Text(method, style: const TextStyle(fontSize: 11)),
          value: method,
          dense: true,
          contentPadding: EdgeInsets.zero,
          groupValue: _activePreprocessing,
          onChanged: (val) {
            if (val != null) {
              setState(() => _activePreprocessing = val);
              
              String backendPrep = 'ninguno';
              if (val == 'Normalize') backendPrep = 'normalización';
              if (val == 'SNV') backendPrep = 'snv';
              if (val == '1st Derivative') backendPrep = 'primera derivada';
              context.read<AppState>().setPreprocessing(backendPrep);
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildNumericSelector({
    required double value,
    required double min,
    required double max,
    required TextEditingController controller,
    required ValueChanged<double> onChanged,
    bool isInteger = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: _isImageLoaded ? (val) {
              setState(() {
                onChanged(val);
                controller.text = isInteger ? val.toInt().toString() : val.toStringAsFixed(2);
              });
            } : null,
          ),
        ),
        SizedBox(
          width: 55,
          height: 28,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: !isInteger),
            style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.white),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Colors.white24, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
              ),
            ),
            onSubmitted: (text) {
              double? parsed = double.tryParse(text);
              if (parsed != null) {
                double clamped = parsed.clamp(min, max);
                if (isInteger) {
                  clamped = clamped.roundToDouble();
                }
                setState(() {
                  onChanged(clamped);
                  controller.text = isInteger ? clamped.toInt().toString() : clamped.toStringAsFixed(2);
                });
              } else {
                controller.text = isInteger ? value.toInt().toString() : value.toStringAsFixed(2);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContrastControls() {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Brillo', style: TextStyle(fontSize: 10)),
          ],
        ),
        _buildNumericSelector(
          value: _brightness,
          min: 0.5,
          max: 2.0,
          controller: _brightnessController,
          onChanged: (val) => _brightness = val,
        ),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Contraste', style: TextStyle(fontSize: 10)),
          ],
        ),
        _buildNumericSelector(
          value: _contrast,
          min: 0.5,
          max: 2.0,
          controller: _contrastController,
          onChanged: (val) => _contrast = val,
        ),
        if (_thresholdEnabled) ...[
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Umbral (Threshold)', style: TextStyle(fontSize: 10, color: Colors.redAccent)),
            ],
          ),
          _buildNumericSelector(
            value: _thresholdValue,
            min: 0.0,
            max: 1.0,
            controller: _thresholdController,
            onChanged: (val) => _thresholdValue = val,
          ),
        ]
      ],
    );
  }

  Widget _buildMainViewerPanel() {
    return DefaultTabController(
      length: 2,
      child: Container(
        color: const Color(0xFF0F172A),
        child: Column(
          children: [
            TabBar(
              labelColor: const Color(0xFF38BDF8),
              unselectedLabelColor: Colors.blueGrey[400],
              indicatorColor: const Color(0xFF38BDF8),
              tabs: const [
                Tab(icon: Icon(Icons.photo_size_select_actual_outlined, size: 16), text: 'Visor de Stack'),
                Tab(icon: Icon(Icons.analytics_outlined, size: 16), text: 'Mapa de Clasificación'),
              ],
            ),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildHyperstackViewerTab(),
                  _buildClassificationMapTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHyperstackViewerTab() {
    if (!_isImageLoaded) {
      return const Center(child: Text('Cargue un dataset para ver el stack hiperespectral.', style: TextStyle(color: Colors.white30, fontSize: 11)));
    }
  
    return Column(
      children: [
        _buildActiveSliceSlider(),
        
        Expanded(
          
  child: Padding(
    padding: const EdgeInsets.all(16.0),
    child: Center(
      child: Container(
        width: 380,
        height: 380,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.blueGrey[700]!),
        ),
        clipBehavior: Clip.antiAlias,
        child: Consumer<AppState>(
          builder: (context, appState, child) {
            // Si no hay imagen en el estado, mostramos cargando
            if (appState.currentImageBase64 == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return InteractiveViewer(
              scaleEnabled: _activeTool == 'Zoom',
              panEnabled: _activeTool == 'Pan',
              minScale: 0.5,
              maxScale: 6.0,
              child: GestureDetector(
                onPanStart: (details) { if (_activeTool == 'Rectangle') {
                        setState(() {
                          _roiStartPoint = details.localPosition;
                          _selectedROI = null;
                        });
                      }
 },
                onPanUpdate: (details) {
                      if (_activeTool == 'Rectangle' && _roiStartPoint != null) {
                        setState(() {
                          _selectedROI = Rect.fromPoints(_roiStartPoint!, details.localPosition);
                        });
                      }
},
                onPanEnd: (_) {
                      if (_activeTool == 'Rectangle' && _selectedROI != null) {
                        _calculateROIMeasurements();
                      }
},
                onTapDown: (details) async {
                  if (_activeTool == 'Point') {
                    double localX = (details.localPosition.dx / 380) * _imageWidth;
                    double localY = (details.localPosition.dy / 380) * _imageHeight;
                    setState(() {
                      _selectedPixel = Offset(
                        localX.clamp(0.0, _imageWidth.toDouble() - 1),
                        localY.clamp(0.0, _imageHeight.toDouble() - 1),
                      );
                      _selectedROI = null;
                    });
                    
                    // 1. Pedimos la firma real a Flask
                    await appState.updatePixelSignature(_selectedPixel!.dx.toInt(), _selectedPixel!.dy.toInt());
                    // 2. Calculamos la estadística
                    _calculatePixelMeasurement();
                  }
                },
                // Aquí viene el cambio clave: CustomPaint dibuja POR ENCIMA de la imagen nativa
                child: CustomPaint(
                  foregroundPainter: SelectionPainter( // Hemos cambiado el nombre del Painter
                    width: _imageWidth,
                    height: _imageHeight,
                    selectedPixel: _selectedPixel,
                    selectedROI: _selectedROI,
                  ),
                  child: Image.memory(
                    base64Decode(appState.currentImageBase64!),
                    width: 380,
                    height: 380,
                    fit: BoxFit.fill,
                    gaplessPlayback: true, // Evita parpadeos al cambiar de banda
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  ),
),
      ],
    );
  }

  Widget _buildActiveSliceSlider() {
    return Container(
      color: const Color(0xFF1E293B),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          if (!_isRGBComposite) ...[
            Row(
              children: [
                SizedBox(
                  width: 140, 
                  child: Text(
                    'Slice (Banda):\n(${_bandToWavelength(_singleBandIndex).toStringAsFixed(1)} nm)', 
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)
                  ),
                ),
                Expanded(
                  child: _buildNumericSelector(
                    value: _singleBandIndex.toDouble(),
                    min: 0,
                    max: (_totalBands - 1).toDouble(),
                    controller: _singleBandController,
                    isInteger: true,
                    onChanged: (val) => _singleBandIndex = val.toInt(),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                SizedBox(
                  width: 120, 
                  child: Text(
                    'Canal Rojo:\n(${_bandToWavelength(_rBandIndex).toStringAsFixed(1)} nm)', 
                    style: const TextStyle(fontSize: 9, color: Colors.redAccent)
                  )
                ),
                Expanded(
                  child: _buildNumericSelector(
                    value: _rBandIndex.toDouble(),
                    min: 0,
                    max: (_totalBands - 1).toDouble(),
                    controller: _rBandController,
                    isInteger: true,
                    onChanged: (val) => _rBandIndex = val.toInt(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                SizedBox(
                  width: 120, 
                  child: Text(
                    'Canal Verde:\n(${_bandToWavelength(_gBandIndex).toStringAsFixed(1)} nm)', 
                    style: const TextStyle(fontSize: 9, color: Colors.greenAccent)
                  )
                ),
                Expanded(
                  child: _buildNumericSelector(
                    value: _gBandIndex.toDouble(),
                    min: 0,
                    max: (_totalBands - 1).toDouble(),
                    controller: _gBandController,
                    isInteger: true,
                    onChanged: (val) => _gBandIndex = val.toInt(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                SizedBox(
                  width: 120, 
                  child: Text(
                    'Canal Azul:\n(${_bandToWavelength(_bBandIndex).toStringAsFixed(1)} nm)', 
                    style: const TextStyle(fontSize: 9, color: Colors.blueAccent)
                  )
                ),
                Expanded(
                  child: _buildNumericSelector(
                    value: _bBandIndex.toDouble(),
                    min: 0,
                    max: (_totalBands - 1).toDouble(),
                    controller: _bBandController,
                    isInteger: true,
                    onChanged: (val) => _bBandIndex = val.toInt(),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12), // Espacio entre sliders y botón
        SizedBox(
          width: double.infinity, // Hace que el botón ocupe todo el ancho
          child: ElevatedButton.icon(
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text("Actualizar Visualización"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              // Esta es la lógica que "dispara" la petición al backend
              final appState = context.read<AppState>();
              
              List<int> bands;
              if (_isRGBComposite) {
                bands = [_rBandIndex, _gBandIndex, _bBandIndex];
                print("DEBUG: Enviando bandas RGB: $bands"); // DEBE imprimir 3 números
              } else {
                bands = [_singleBandIndex];
                print("DEBUG: Enviando banda única: $bands");
              }
              
              appState.updateRenderedImage(bands);
            },
          ),
        ),
        ],
      ),
    );
  }

Widget _buildClassificationLegend() {
  final appState = context.read<AppState>();
  final String dsId = appState.selectedDataset;
  final int totalClasses = DatasetClasses.getCount(dsId);

  return Container(
    padding: const EdgeInsets.all(8),
    height: 120, // Altura ajustada
    child: SingleChildScrollView(
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: List.generate(totalClasses, (index) {
          final label = DatasetClasses.getName(dsId, index);
          final color = DatasetClasses.getColor(index);
          final isSelected = _highlightedClassIndex == index;

          return InkWell(
            onTap: () {
              setState(() {
                // Alternar selección: si ya estaba seleccionado, limpiar filtro
                _highlightedClassIndex = (isSelected) ? null : index;
              });
            },
            child: Chip(
              backgroundColor: isSelected ? Colors.white : Colors.blueGrey[800],
              avatar: CircleAvatar(backgroundColor: color, radius: 8),
              label: Text(
                label,
                style: TextStyle(
                  fontSize: 10, 
                  color: isSelected ? Colors.black : Colors.white
                ),
              ),
            ),
          );
        }),
      ),
    ),
  );
}

Widget _buildClassificationMapTab() {
  return Consumer<AppState>(
    builder: (context, appState, child) {
      if (appState.predictionMap == null) return const Center(child: Text("Sin mapa"));

      return Column( // Envolvemos en columna para añadir la leyenda debajo
        children: [
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              return GestureDetector(
                onTapDown: (details) {
            // Calcular el índice (x, y) basado en el toque
            final RenderBox box = context.findRenderObject() as RenderBox;
            final localPos = box.globalToLocal(details.globalPosition);
            print("Clic detectado en: ${localPos.dx}, ${localPos.dy}");
            final cols = appState.predictionMap![0].length;
            final rows = appState.predictionMap!.length;
            final cellWidth = constraints.maxWidth / cols;
            final cellHeight = constraints.maxHeight / rows;

            int x = (localPos.dx / cellWidth).floor();
            int y = (localPos.dy / cellHeight).floor();

            if (x >= 0 && x < cols && y >= 0 && y < rows) {
              appState.selectPixel(x, y);
            }
          },
                child: Stack(
                  children: [
                    RepaintBoundary(
                      child: CustomPaint(
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                        // Pasamos el nuevo parámetro al painter
                        painter: ClassificationPainter(
                          appState.predictionMap!, 
                          appState.selectedDataset,
                          highlightedClass: _highlightedClassIndex,
                        ),
                      ),
                    ),
                    CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: SelectionPainter(
                        width: appState.predictionMap![0].length,
                        height: appState.predictionMap!.length,
                        selectedPixel: appState.selectedPixel,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          _buildClassificationLegend(), // Aquí insertamos la leyenda
        ],
      );
    },
  );
}



  Widget _buildRightAnalyticalPanel() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(left: BorderSide(color: Colors.blueGrey[700]!, width: 1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Firma Espectral de Reflectancia', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: _isImageLoaded
                  ? _buildSpectralChart()
                  : Center(
                      child: Text(
                        'Firma vacía.\nSeleccione puntos sobre el lienzo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.blueGrey[500], fontSize: 10),
                      ),
                    ),
            ),
            const Divider(height: 24),
            const Text('Resultados de Medición ("Measure")', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildMeasurementsTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurementsTable() {
    if (_roiMeasurements == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.blueGrey[900], borderRadius: BorderRadius.circular(4)),
        child: const Text('No hay mediciones activas.\nUse la herramienta de selección e imprima en Medir.', style: TextStyle(fontSize: 9, color: Colors.blueGrey)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.blueGrey[900], borderRadius: BorderRadius.circular(4)),
      child: Column(
        children: _roiMeasurements!.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(entry.key, style: const TextStyle(fontSize: 10, color: Colors.white60)),
                Text(
                  entry.value.toStringAsFixed(entry.key.contains('Área') ? 0 : 5),
                  style: const TextStyle(fontSize: 10, color: Color(0xFF0EA5E9), fontFamily: 'monospace', fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

 
}



class SelectionPainter extends CustomPainter {
  final int width;
  final int height;
  final Offset? selectedPixel;
  final Rect? selectedROI;

  SelectionPainter({required this.width, required this.height, this.selectedPixel, this.selectedROI});

  @override
  void paint(Canvas canvas, Size size) {
    double cellWidth = size.width / width;
    double cellHeight = size.height / height;

    if (selectedPixel != null) {
      double px = selectedPixel!.dx * cellWidth;
      double py = selectedPixel!.dy * cellHeight;

      // Brillo oscuro de fondo
      Paint glowPaint = Paint()..color = Colors.black.withOpacity(0.7)..style = PaintingStyle.stroke..strokeWidth = 3.5;
      canvas.drawRect(Rect.fromCenter(center: Offset(px, py), width: 22, height: 22), glowPaint);
      canvas.drawLine(Offset(px - 26, py), Offset(px + 26, py), glowPaint);
      canvas.drawLine(Offset(px, py - 26), Offset(px, py + 26), glowPaint);

      // Indicador amarillo brillante
      Paint selectionPaint = Paint()..color = Colors.yellowAccent..style = PaintingStyle.stroke..strokeWidth = 2.0;
      canvas.drawRect(Rect.fromCenter(center: Offset(px, py), width: 20, height: 20), selectionPaint);
      canvas.drawLine(Offset(px - 24, py), Offset(px + 24, py), selectionPaint);
      canvas.drawLine(Offset(px, py - 24), Offset(px, py + 24), selectionPaint);
      canvas.drawCircle(Offset(px, py), 10, selectionPaint..strokeWidth = 1.2);
    }

    if (selectedROI != null) {
      Paint roiPaint = Paint()..color = Colors.cyanAccent..style = PaintingStyle.stroke..strokeWidth = 2.0;
      canvas.drawRect(selectedROI!, roiPaint);
      canvas.drawRect(selectedROI!, Paint()..color = Colors.cyanAccent.withOpacity(0.12)..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(covariant SelectionPainter oldDelegate) {
    return oldDelegate.selectedPixel != selectedPixel || oldDelegate.selectedROI != selectedROI;
  }
}

class ClassificationPainter extends CustomPainter {
  final List<List<int>> map;
  final String datasetId;
  final int? highlightedClass; // Nuevo parámetro

  ClassificationPainter(this.map, this.datasetId, {this.highlightedClass});

  @override
  void paint(Canvas canvas, Size size) {
    if (map.isEmpty) return;

    final rows = map.length;
    final cols = map[0].length;
    final cellWidth = size.width / cols;
    final cellHeight = size.height / rows;

    final paint = Paint()..style = PaintingStyle.fill;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final classId = map[r][c];
        Color color = DatasetClasses.getColor(classId);

        // Lógica de resaltado: si hay una clase seleccionada y no es esta, aplicar transparencia
        if (highlightedClass != null && highlightedClass != classId) {
          color = color.withOpacity(0.1); 
        }

        paint.color = color;
        canvas.drawRect(
          Rect.fromLTWH(c * cellWidth, r * cellHeight, cellWidth, cellHeight),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant ClassificationPainter oldDelegate) {
    return oldDelegate.map != map || oldDelegate.highlightedClass != highlightedClass;
  }
}


// Clase para pintar la curva espectral
class SpectralPainter extends CustomPainter {
  final List<double> curve;
  SpectralPainter(this.curve);

  @override
  void paint(Canvas canvas, Size size) {
    if (curve.isEmpty) return;

    // Márgenes para dejar espacio a los ejes y números
    final double paddingLeft = 40.0;
    final double paddingBottom = 25.0;
    
    // Área disponible para dibujar la línea
    final double graphWidth = size.width - paddingLeft - 10;
    final double graphHeight = size.height - paddingBottom - 10;

    final paint = Paint()
      ..color = Colors.blue[300]!
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final double maxVal = curve.reduce(math.max);
    final double minVal = curve.reduce(math.min);
    final double range = (maxVal - minVal) == 0 ? 1 : (maxVal - minVal);

    // 1. Dibujar la línea
    final path = Path();
    for (int i = 0; i < curve.length; i++) {
      final x = paddingLeft + (i / (curve.length - 1)) * graphWidth;
      final y = size.height - paddingBottom - ((curve[i] - minVal) / range) * graphHeight;
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);

    // 2. Dibujar etiquetas de los ejes
    final textStyle = const TextStyle(color: Colors.white70, fontSize: 9);

    // Eje Y (4 divisiones)
    for (int i = 0; i <= 4; i++) {
      double val = minVal + (range * (i / 4));
      double y = size.height - paddingBottom - ((val - minVal) / range) * graphHeight;
      
      _drawText(canvas, val.toStringAsFixed(1), 5, y - 5, textStyle);
      
      // Línea guía opcional
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width, y), Paint()..color = Colors.white10..strokeWidth = 0.5);
    }

    // Eje X (4 divisiones)
    for (int i = 0; i <= 4; i++) {
      int index = (i * (curve.length - 1) ~/ 4);
      double x = paddingLeft + (i / 4) * graphWidth;
      
      _drawText(canvas, index.toString(), x - 5, size.height - 15, textStyle);
    }
  }

  void _drawText(Canvas canvas, String text, double x, double y, TextStyle style) {
    final textSpan = TextSpan(text: text, style: style);
    final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    textPainter.layout();
    textPainter.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant SpectralPainter oldDelegate) => true;
}
Widget _buildSpectralChart() {
  return Consumer<AppState>(
    builder: (context, appState, child) {
      if (appState.currentSignature.isEmpty) {
        return const Center(child: Text("Selecciona un píxel"));
      }

      return Container(
        height: 250, 
        width: double.infinity, 
        color: Colors.black54, 
        child: CustomPaint(
          painter: SpectralPainter(appState.currentSignature),
        ),
      );
    },
  );
}