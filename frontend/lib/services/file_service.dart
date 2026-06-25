import 'dart:convert';
// ignore: deprecated_member_use, avoid_web_libraries_in_file
import 'dart:html' as html; 
import 'package:file_picker/file_picker.dart';

class FileService {
  
  /// Exporta el mapa clasificado actual a un archivo .json descargable en el navegador
  static void downloadSession({
    required String datasetId,
    required List<List<int>> predictionMap,
  }) {
    // Estructuramos el objeto de guardado
    final sessionData = {
      'export_version': '1.0',
      'dataset_id': datasetId,
      'timestamp': DateTime.now().toIso8601String(),
      'prediction_map': predictionMap,
    };

    // Convertimos el JSON a texto binario comprimido en UTF-8
    final jsonString = jsonEncode(sessionData);
    final bytes = utf8.encode(jsonString);
    final blob = html.Blob([bytes], 'application/json');
    
    // Simulamos un enlace web invisible <a> y forzamos su clic para disparar la descarga nativa
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "tfg_sesion_${datasetId}_${DateTime.now().millisecondsSinceEpoch}.json")
      ..click();
      
    // Limpiamos la memoria del navegador
    html.Url.revokeObjectUrl(url);
  }

  /// Abre el explorador de archivos para importar un JSON guardado previamente
  static Future<Map<String, dynamic>?> uploadSession() async {
    // Abrir ventana nativa de selección de archivos en la web
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null && result.files.first.bytes != null) {
      // Decodificamos los bytes leídos del archivo
      final fileBytes = result.files.first.bytes!;
      final jsonString = utf8.decode(fileBytes);
      final Map<String, dynamic> sessionData = jsonDecode(jsonString);
      
      return sessionData;
    }
    return null; // El usuario canceló la selección
  }
}