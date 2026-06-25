import 'dart:math' as math;
import 'package:flutter/material.dart';

// ==========================================================================
// 1. MODELOS Y SIMULADOR HIPERESPECTRAL
// ==========================================================================

class CropClass {
  final String name;
  final Color color;
  final List<double> baseCurve;

  const CropClass({
    required this.name,
    required this.color,
    required this.baseCurve,
  });
}

class SpectralSimulator {
  static const int defaultBands = 30;

  static final List<CropClass> classes = [
    CropClass(
      name: 'Trigo',
      color: Colors.amber,
      baseCurve: List.generate(defaultBands, (i) => 0.1 + 0.6 * math.sin(i / 10) + 0.1 * math.cos(i / 3)),
    ),
    CropClass(
      name: 'Maíz',
      color: Colors.green,
      baseCurve: List.generate(defaultBands, (i) => 0.05 + 0.7 * math.sin(i / 8) + 0.05 * math.sin(i / 2)),
    ),
    CropClass(
      name: 'Suelo Desnudo',
      color: Colors.brown,
      baseCurve: List.generate(defaultBands, (i) => 0.1 + 0.3 * (i / defaultBands)),
    ),
    CropClass(
      name: 'Agua / Humedal',
      color: Colors.blue,
      baseCurve: List.generate(defaultBands, (i) => 0.4 * math.exp(-i / 5)),
    ),
  ];

  static CropClass getClassAt(int x, int y, int totalWidth, int totalHeight) {
    if (totalWidth <= 0 || totalHeight <= 0) return classes[0];
    double nx = x / totalWidth;
    double ny = y / totalHeight;
    int index = ((nx * 2.2).floor() + (ny * 1.8).floor()) % classes.length;
    return classes[index];
  }
}

// ==========================================================================
// 2. WIDGET PRINCIPAL: HYPERSPECTRALDASHBOARD (CON MENÚ Y BARRA SUPERIOR)
// ==========================================================================

class HyperspectralDashboard extends StatefulWidget {
  const HyperspectralDashboard({Key? key}) : super(key: key);

  @override
  State<HyperspectralDashboard> createState() => _HyperspectralDashboardState();
}

class _HyperspectralDashboardState extends State<HyperspectralDashboard> {
  // Control de Navegación del Menú Lateral Left
  int _selectedMenuIndex = 0;

  // Variables de control de Imagen
  String? _loadedFileName = "escena_satelital_proc.dat";
  bool _isImageLoaded = true;
  final int _imageWidth = 128;
  final int _imageHeight = 128;
  final int _totalBands = SpectralSimulator.defaultBands;

  // Estados de visualización y herramientas
  bool _isRGBComposite = false;
  String _activeLUT = 'Grayscale';
  String _activePreprocessing = 'Ninguno';
  bool _hasClassificationResults = false; // Cambia a true al presionar "Clasificar"
  String? _highlightedClass;

  // Índices de bandas seleccionadas
  int _singleBandIndex = 5;
  int _rBandIndex = 20;
  int _gBandIndex = 12;
  int _bBandIndex = 4;

  // Parámetros radiométricos
  double _brightness = 1.0;
  double _contrast = 1.0;
  bool _thresholdEnabled = false;
  double _thresholdValue = 0.5;

  // Selección en Lienzo
  Offset? _selectedPixel = const Offset(64, 64);
  Rect? _selectedROI;
  Map<String, double>? _roiMeasurements;

  // Controladores para sincronizar Sliders con Campos de Texto
  final TextEditingController _singleBandController = TextEditingController();
  final TextEditingController _rBandController = TextEditingController();
  final TextEditingController _gBandController = TextEditingController();
  final TextEditingController _bBandController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _updateControllers();
    _calculatePixelMeasurement();
  }

  @override
  void dispose() {
    _singleBandController.dispose();
    _rBandController.dispose();
    _gBandController.dispose();
    _bBandController.dispose();
    super.dispose();
  }

  void _updateControllers() {
    _singleBandController.text = _singleBandIndex.toString();
    _rBandController.text = _rBandIndex.toString();
    _gBandController.text = _gBandIndex.toString();
    _bBandController.text = _bBandIndex.toString();
  }

  double _bandToWavelength(int band) {
    return 400.0 + (band * (2100.0 / (_totalBands - 1)));
  }

  void _calculatePixelMeasurement() {
    if (_selectedPixel == null) return;
    setState(() {
      _roiMeasurements = {
        'Reflectancia Media': 0.4251,
        'Índice NDVI Estimado': 0.7412,
        'Área Seleccionada (px)': 1.0,
        'Desviación Estándar': 0.0834,
      };
    });
  }

  List<double> _applyPreprocessing(List<double> curve) {
    if (_activePreprocessing == 'Derivada 1ª') {
      List<double> deriv = [];
      for (int i = 0; i < curve.length - 1; i++) {
        deriv.add(curve[i + 1] - curve[i]);
      }
      if (deriv.isNotEmpty) deriv.add(deriv.last);
      return deriv;
    }
    return curve;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      body: Row(
        children: [
          // ------------------------------------------------------------------
          // A. MENÚ LATERAL DE NAVEGACIÓN (LEFT MENU)
          // ------------------------------------------------------------------
          Container(
            width: 70,
            decoration: BoxDecoration(
            color: const Color(0xFF1E293B), // Slate 800
            border: const Border(right: BorderSide(color: Color(0xFF334155), width: 1)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Icon(Icons.layers, color: Color(0xFF0EA5E9), size: 28), // Logo ficticio
                const Divider(height: 40, color: Color(0xFF334155)),
                _buildMenuIcon(0, Icons.remove_red_eye_outlined, 'Visor'),
                _buildMenuIcon(1, Icons.analytics_outlined, 'Filtros'),
                _buildMenuIcon(2, Icons.map_outlined, 'Mapas'),
                const Spacer(),
                _buildMenuIcon(3, Icons.settings, 'Config'),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // ------------------------------------------------------------------
          // B. CONTENIDO PRINCIPAL (BARRA SUPERIOR + LIENZOS + ANALÍTICAS)
          // ------------------------------------------------------------------
          Expanded(
            child: Column(
              children: [
                // 1. BARRA SUPERIOR DE HERRAMIENTAS (TOP BAR)
                _buildTopHeaderBar(),

                // 2. ESPACIO DE TRABAJO (DIVIDIDO EN LIENZO Y PANEL ANALÍTICO)
                Expanded(
                  child: Row(
                    children: [
                      // Centro: Visor y Sliders de bandas
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            Expanded(
                              child: Center(
                                child: SingleChildScrollView(
                                  child: _selectedMenuIndex == 2 
                                      ? _buildClassificationMapTab() // Si elige el menú de mapas, dibuja clasificación
                                      : _buildMainViewerTab(),       // Si no, dibuja el lienzo principal
                                ),
                              ),
                            ),
                            _buildActiveSliceSlider(),
                          ],
                        ),
                      ),
                      // Derecha: Gráfica y Mediciones
                      Expanded(
                        flex: 2,
                        child: _buildRightAnalyticalPanel(),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // COMPONENTES ESTRUCTURALES ADICIONADOS
  // ==========================================================================

  Widget _buildMenuIcon(int index, IconData icon, String tooltip) {
    bool isSelected = _selectedMenuIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: IconButton(
        icon: Icon(icon, color: isSelected ? const Color(0xFF0EA5E9) : Colors.blueGrey[400]),
        tooltip: tooltip,
        onPressed: () {
          setState(() {
            _selectedMenuIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildTopHeaderBar() {
    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 1)),
      ),
      child: Row(
        children: [
          Text(
            _loadedFileName ?? "Sin archivo cargado",
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
          ),
          const SizedBox(width: 8),
          if (_isImageLoaded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.lightGreen.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
              child: const Text("DAT loaded", style: TextStyle(color: Colors.lightGreen, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          const Spacer(),
          // Botones de acción solicitados
          TextButton.icon(
            icon: const Icon(Icons.folder_open, size: 16, color: Colors.blueGrey),
            label: const Text("Cargar DAT", style: TextStyle(color: Colors.white, fontSize: 11)),
            onPressed: () {
              setState(() {
                _loadedFileName = "escena_satelital_proc.dat";
                _isImageLoaded = true;
              });
            },
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            icon: const Icon(Icons.straighten, size: 16, color: Colors.white),
            label: const Text("Medir ROI", style: TextStyle(color: Colors.white, fontSize: 11)),
            onPressed: () {
              _calculatePixelMeasurement();
            },
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF0EA5E9))),
            icon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF0EA5E9)),
            label: const Text("Clasificar", style: TextStyle(color: Color(0xFF0EA5E9), fontSize: 11)),
            onPressed: () {
              setState(() {
                _hasClassificationResults = true;
                _selectedMenuIndex = 2; // Salta automáticamente a la pestaña de mapas para ver los cultivos
              });
            },
          ),
          const SizedBox(width: 8),
          // Toggle rápido de RGB / Monocanal
          IconButton(
            icon: Icon(_isRGBComposite ? Icons.gradient : Icons.filter_hdr, color: Colors.white),
            tooltip: _isRGBComposite ? "Cambiar a Monocanal" : "Cambiar a Compuesto RGB",
            onPressed: () {
              setState(() {
                _isRGBComposite = !_isRGBComposite;
                _updateControllers();
              });
            },
          )
        ],
      ),
    );
  }

  Widget _buildMainViewerTab() {
    return GestureDetector(
      onTapUp: (details) {
        // Corrección de posición local sobre un lienzo de 380x380 px
        double localX = (details.localPosition.dx / 380) * _imageWidth;
        double localY = (details.localPosition.dy / 380) * _imageHeight;

        setState(() {
          _selectedPixel = Offset(
            localX.clamp(0.0, _imageWidth.toDouble() - 1),
            localY.clamp(0.0, _imageHeight.toDouble() - 1),
          );
          _selectedROI = null;
        });
        _calculatePixelMeasurement();
      },
      child: InteractiveViewer(
        child: Container(
          width: 380,
          height: 380,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.blueGrey[800]!),
          ),
          child: CustomPaint(
            painter: HyperspectralPainter(
              loadedFileName: _loadedFileName!,
              width: _imageWidth,
              height: _imageHeight,
              isRGBMode: _isRGBComposite,
              singleBand: _singleBandIndex,
              activeLUT: _activeLUT,
              brightness: _brightness,
              contrast: _contrast,
              thresholdEnabled: _thresholdEnabled,
              thresholdValue: _thresholdValue,
              rBand: _rBandIndex,
              gBand: _gBandIndex,
              bBand: _bBandIndex,
              selectedPixel: _selectedPixel,
              selectedROI: _selectedROI,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumericSelector({
    required double value,
    required double min,
    required double max,
    required TextEditingController controller,
    required bool isInteger,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: const Color(0xFF0EA5E9),
            inactiveColor: Colors.blueGrey[800],
            onChanged: (val) {
              setState(() {
                onChanged(val);
                controller.text = isInteger ? val.toInt().toString() : val.toStringAsFixed(2);
              });
            },
          ),
        ),
        SizedBox(
          width: 45,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 11, color: Colors.white, fontFamily: 'monospace'),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (text) {
              double? parsed = double.tryParse(text);
              if (parsed != null) {
                setState(() {
                  double finalVal = parsed.clamp(min, max);
                  onChanged(finalVal);
                  controller.text = isInteger ? finalVal.toInt().toString() : finalVal.toStringAsFixed(2);
                });
              }
            },
          ),
        )
      ],
    );
  }

  // ==========================================================================
  // METODOS ENCAPSULADOS PROPIOS DE TU LAYOUT ORIGINAL
  // ==========================================================================

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
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)
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
          ]
        ],
      ),
    );
  }

  Widget _buildClassificationMapTab() {
    if (!_hasClassificationResults) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bubble_chart, size: 48, color: Colors.blueGrey[600]),
              const SizedBox(height: 12),
              const Text('Mapa de clasificación vacío.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              const Text(
                'Ejecute el clasificador automático desde la barra superior para mapear los cultivos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.blueGrey, fontSize: 10),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Center(
            child: InteractiveViewer(
              child: Container(
                width: 380,
                height: 380,
                decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(4)),
                child: CustomPaint(
                  painter: ClassificationPainter(
                    width: _imageWidth,
                    height: _imageHeight,
                    highlightedClass: _highlightedClass,
                    selectedPixel: _selectedPixel,
                    selectedROI: _selectedROI,
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(
          height: 140,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B), 
            border: Border(top: BorderSide(color: Colors.blueGrey[700]!))
          ),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 3.2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 6,
            ),
            itemCount: SpectralSimulator.classes.length,
            itemBuilder: (context, idx) {
              CropClass crop = SpectralSimulator.classes[idx];
              bool isHighlighted = _highlightedClass == crop.name;
              return InkWell(
                onTap: () {
                  setState(() {
                    _highlightedClass = isHighlighted ? null : crop.name;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isHighlighted ? crop.color.withOpacity(0.2) : Colors.transparent,
                    border: Border.all(
                      color: isHighlighted ? crop.color : Colors.blueGrey[800]!,
                      width: isHighlighted ? 2.0 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: crop.color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          crop.name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                            color: isHighlighted ? Colors.white : Colors.blueGrey[200],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
            const Text('Firma Espectral de Reflectancia', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
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
            const Divider(height: 24, color: Colors.blueGrey),
            const Text('Resultados de Medición ("Measure")', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
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

  Widget _buildSpectralChart() {
    int px = _selectedPixel != null ? _selectedPixel!.dx.toInt() : 72;
    int py = _selectedPixel != null ? _selectedPixel!.dy.toInt() : 72;
    CropClass activeClass = SpectralSimulator.getClassAt(px, py, _imageWidth, _imageHeight);
    List<double> rawCurve = activeClass.baseCurve;
    List<double> processedCurve = _applyPreprocessing(rawCurve);

    double minWavelength = _bandToWavelength(0);
    double maxWavelength = _bandToWavelength(rawCurve.length - 1);

    return Column(
      children: [
        Expanded(
          child: Card(
            elevation: 0,
            color: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Colors.blueGrey[700]!),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: CustomPaint(
                size: Size.infinite,
                painter: SpectralChartPainter(
                  curve: processedCurve,
                  lineColor: activeClass.color,
                  preprocessingMode: _activePreprocessing,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${minWavelength.toStringAsFixed(0)}nm (VIS)', style: TextStyle(fontSize: 9, color: Colors.blueGrey[400])),
            Text('Espectro Infrarrojo', style: TextStyle(fontSize: 9, color: Colors.blueGrey[400])),
            Text('${maxWavelength.toStringAsFixed(0)}nm (SWIR)', style: TextStyle(fontSize: 9, color: Colors.blueGrey[400])),
          ],
        ),
      ],
    );
  }
}

// ==========================================================================
// 3. PAINTERS PERSONALIZADOS
// ==========================================================================

class HyperspectralPainter extends CustomPainter {
  final String loadedFileName;
  final int width;
  final int height;
  final bool isRGBMode;
  final int singleBand;
  final String activeLUT;
  final double brightness;
  final double contrast;
  final bool thresholdEnabled;
  final double thresholdValue;
  final int rBand;
  final int gBand;
  final int bBand;
  final Offset? selectedPixel;
  final Rect? selectedROI;

  HyperspectralPainter({
    required this.loadedFileName,
    required this.width,
    required this.height,
    required this.isRGBMode,
    required this.singleBand,
    required this.activeLUT,
    required this.brightness,
    required this.contrast,
    required this.thresholdEnabled,
    required this.thresholdValue,
    required this.rBand,
    required this.gBand,
    required this.bBand,
    required this.selectedPixel,
    required this.selectedROI,
  });

  Color _applyLUT(double val) {
    double adjusted = ((val - 0.5) * contrast + 0.5) * brightness;
    adjusted = adjusted.clamp(0.0, 1.0);

    if (thresholdEnabled) {
      return (adjusted >= thresholdValue) ? Colors.red : Colors.black;
    }

    if (activeLUT == 'Thermal') {
      if (adjusted < 0.25) {
        return Color.fromARGB(255, 0, 0, (adjusted * 4 * 255).toInt());
      } else if (adjusted < 0.5) {
        return Color.fromARGB(255, ((adjusted - 0.25) * 4 * 255).toInt(), 0, 255);
      } else if (adjusted < 0.75) {
        return Color.fromARGB(255, 255, 0, (255 - (adjusted - 0.5) * 4 * 255).toInt());
      } else {
        return Color.fromARGB(255, 255, ((adjusted - 0.75) * 4 * 255).toInt(), 0);
      }
    } else if (activeLUT == 'Rainbow') {
      int hue = ((1.0 - adjusted) * 280).toInt();
      return HSVColor.fromAHSV(1.0, hue.toDouble(), 1.0, 1.0).toColor();
    } else if (activeLUT == 'Ice') {
      return Color.fromARGB(255, (adjusted * 255).toInt(), (adjusted * 255).toInt(), 255);
    } else {
      int intensity = (adjusted * 255).toInt().clamp(0, 255);
      return Color.fromARGB(255, intensity, intensity, intensity);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    Paint pixelPaint = Paint()..style = PaintingStyle.fill;
    double cellWidth = size.width / width;
    double cellHeight = size.height / height;

    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        CropClass crop = SpectralSimulator.getClassAt(x, y, width, height);
        double bandVal = crop.baseCurve[(singleBand % crop.baseCurve.length)];

        if (!isRGBMode) {
          pixelPaint.color = _applyLUT(bandVal);
        } else {
          double valR = crop.baseCurve[(rBand % crop.baseCurve.length)] * brightness;
          double valG = crop.baseCurve[(gBand % crop.baseCurve.length)] * brightness;
          double valB = crop.baseCurve[(bBand % crop.baseCurve.length)] * brightness;

          pixelPaint.color = Color.fromARGB(
            255,
            (valR * 255).toInt().clamp(0, 255),
            (valG * 255).toInt().clamp(0, 255),
            (valB * 255).toInt().clamp(0, 255),
          );
        }

        canvas.drawRect(
          Rect.fromLTWH(x * cellWidth, y * cellHeight, cellWidth + 0.5, cellHeight + 0.5),
          pixelPaint,
        );
      }
    }

    if (selectedPixel != null) {
      double px = selectedPixel!.dx * cellWidth;
      double py = selectedPixel!.dy * cellHeight;

      Paint glowPaint = Paint()
        ..color = Colors.black.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5;

      canvas.drawRect(Rect.fromCenter(center: Offset(px, py), width: 22, height: 22), glowPaint);
      canvas.drawLine(Offset(px - 26, py), Offset(px + 26, py), glowPaint);
      canvas.drawLine(Offset(px, py - 26), Offset(px, py + 26), glowPaint);

      Paint selectionPaint = Paint()
        ..color = Colors.yellowAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawRect(Rect.fromCenter(center: Offset(px, py), width: 20, height: 20), selectionPaint);
      canvas.drawLine(Offset(px - 24, py), Offset(px + 24, py), selectionPaint);
      canvas.drawLine(Offset(px, py - 24), Offset(px, py + 24), selectionPaint);
      
      canvas.drawCircle(Offset(px, py), 10, selectionPaint..strokeWidth = 1.2);
    }

    if (selectedROI != null) {
      Paint roiPaint = Paint()
        ..color = Colors.cyanAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawRect(selectedROI!, roiPaint);
      canvas.drawRect(
        selectedROI!,
        Paint()
          ..color = Colors.cyanAccent.withOpacity(0.12)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant HyperspectralPainter oldDelegate) {
    return oldDelegate.singleBand != singleBand ||
        oldDelegate.activeLUT != activeLUT ||
        oldDelegate.isRGBMode != isRGBMode ||
        oldDelegate.brightness != brightness ||
        oldDelegate.contrast != contrast ||
        oldDelegate.thresholdEnabled != thresholdEnabled ||
        oldDelegate.thresholdValue != thresholdValue ||
        oldDelegate.rBand != rBand ||
        oldDelegate.gBand != gBand ||
        oldDelegate.bBand != bBand ||
        oldDelegate.selectedPixel != selectedPixel ||
        oldDelegate.selectedROI != selectedROI;
  }
}

class ClassificationPainter extends CustomPainter {
  final int width;
  final int height;
  final String? highlightedClass;
  final Offset? selectedPixel;
  final Rect? selectedROI;

  ClassificationPainter({
    required this.width,
    required this.height,
    required this.highlightedClass,
    required this.selectedPixel,
    required this.selectedROI,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Paint pixelPaint = Paint()..style = PaintingStyle.fill;
    double cellWidth = size.width / width;
    double cellHeight = size.height / height;

    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        CropClass cropClass = SpectralSimulator.getClassAt(x, y, width, height);
        Color targetColor = cropClass.color;

        if (highlightedClass != null && cropClass.name != highlightedClass) {
          targetColor = targetColor.withOpacity(0.12);
        }

        pixelPaint.color = targetColor;
        canvas.drawRect(
          Rect.fromLTWH(x * cellWidth, y * cellHeight, cellWidth + 0.5, cellHeight + 0.5),
          pixelPaint,
        );
      }
    }

    if (selectedPixel != null) {
      double px = selectedPixel!.dx * cellWidth;
      double py = selectedPixel!.dy * cellHeight;

      Paint glowPaint = Paint()
        ..color = Colors.black.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5;

      canvas.drawRect(Rect.fromCenter(center: Offset(px, py), width: 22, height: 22), glowPaint);
      canvas.drawLine(Offset(px - 26, py), Offset(px + 26, py), glowPaint);
      canvas.drawLine(Offset(px, py - 26), Offset(px, py + 26), glowPaint);

      Paint selectionPaint = Paint()
        ..color = Colors.yellowAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawRect(Rect.fromCenter(center: Offset(px, py), width: 20, height: 20), selectionPaint);
      canvas.drawLine(Offset(px - 24, py), Offset(px + 24, py), selectionPaint);
      canvas.drawLine(Offset(px, py - 24), Offset(px, py + 24), selectionPaint);
      canvas.drawCircle(Offset(px, py), 10, selectionPaint..strokeWidth = 1.2);
    }

    if (selectedROI != null) {
      Paint roiPaint = Paint()
        ..color = Colors.cyanAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawRect(selectedROI!, roiPaint);
      canvas.drawRect(
        selectedROI!,
        Paint()
          ..color = Colors.cyanAccent.withOpacity(0.12)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ClassificationPainter oldDelegate) {
    return oldDelegate.highlightedClass != highlightedClass ||
        oldDelegate.selectedPixel != selectedPixel ||
        oldDelegate.selectedROI != selectedROI;
  }
}

class SpectralChartPainter extends CustomPainter {
  final List<double> curve;
  final Color lineColor;
  final String preprocessingMode;

  SpectralChartPainter({required this.curve, required this.lineColor, required this.preprocessingMode});

  @override
  void paint(Canvas canvas, Size size) {
    if (curve.isEmpty) return;

    Paint linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    Paint gridPaint = Paint()
      ..color = Colors.blueGrey[700]!
      ..strokeWidth = 1.0;

    int gridLines = 5;
    for (int i = 0; i <= gridLines; i++) {
      double yVal = (size.height / gridLines) * i;
      canvas.drawLine(Offset(0, yVal), Offset(size.width, yVal), gridPaint);
    }

    double maxVal = curve.reduce(math.max);
    double minVal = curve.reduce(math.min);
    double deltaY = (maxVal - minVal == 0) ? 1.0 : (maxVal - minVal);

    Path curvePath = Path();
    double stepX = size.width / (curve.length - 1);

    for (int i = 0; i < curve.length; i++) {
      double px = i * stepX;
      double normVal = (curve[i] - minVal) / deltaY;
      double py = size.height - (normVal * size.height);

      if (i == 0) {
        curvePath.moveTo(px, py);
      } else {
        curvePath.lineTo(px, py);
      }
    }

    canvas.drawPath(curvePath, linePaint);

    TextSpan span = TextSpan(
      style: TextStyle(color: Colors.blueGrey[400], fontSize: 9, fontFamily: 'monospace'),
      text: "Filtro: $preprocessingMode",
    );
    TextPainter tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, const Offset(10, 10));
  }

  @override
  bool shouldRepaint(covariant SpectralChartPainter oldDelegate) {
    return oldDelegate.curve != curve || oldDelegate.lineColor != lineColor || oldDelegate.preprocessingMode != preprocessingMode;
  }
}