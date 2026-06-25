import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:5000';

  /// Comprueba si el backend de Python está encendido
  Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'ok';
      }
      return false;
    } catch (_) {
      return false;
    }
  }

/// Pide al servidor la firma espectral real de un píxel
Future<List<double>?> fetchPixelSignature({
    required String datasetId,
    required int x,
    required int y,
  }) async {
    final url = Uri.parse('$baseUrl/pixel_signature');
    final body = jsonEncode({'dataset_id': datasetId, 'x': x, 'y': y});

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Se convierte la lista dinámica a una lista estricta de doubles
        return List<double>.from(data['curve'].map((val) => val.toDouble()));
      }
    } catch (e) {
      print("Error obteniendo firma espectral: $e");
    }
    return null; // Retorna null si hay error
  }

Future<Map<String, dynamic>?> fetchROIStats({
  required String datasetId,
  required int xStart, required int yStart,
  required int xEnd, required int yEnd,
}) async {
  final url = Uri.parse('$baseUrl/roi_stats');
  final body = jsonEncode({
    'dataset_id': datasetId,
    'xStart': xStart, 'yStart': yStart,
    'xEnd': xEnd, 'yEnd': yEnd
  });

  final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: body);
  
  if (response.statusCode == 200) {
    return jsonDecode(response.body); // Devuelve {mean_curve, min, max}
  }
  return null;
}

Future<String?> fetchBandImage({
    required String datasetId,
    required List<int> bands,
  }) async {
    print("DEBUG FLUTTER: Intentando conectar a ${baseUrl}/get_band_image");
    final url = Uri.parse('$baseUrl/get_band_image');
    final body = jsonEncode({'dataset_id': datasetId, 'bands': bands});

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("DEBUG: Imagen recibida, longitud: ${data['image_base64'].length}"); 
        return data['image_base64']; 
      }else {
    print("DEBUG: Error del servidor: ${response.statusCode}"); 
}
    } catch (e) {
      print("Error al cargar la imagen: $e");
    }
    return null;
  }

/// Pide al servidor la imagen renderizada (1 o 3 bandas) en Base64
  Future<String?> fetchRenderedBand({
    required String datasetId,
    required List<int> bands,
  }) async {
    final url = Uri.parse('$baseUrl/render_band');
    final body = jsonEncode({'dataset_id': datasetId, 'bands': bands});

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['image_base64'];
      }
    } catch (e) {
      print("Error obteniendo la imagen de la banda: $e");
    }
    return null;
  }

  /// Envía la petición de clasificación y devuelve la matriz bidimensional
  Future<List<List<int>>> predict({
    required String datasetId,
    required String algorithm,
    required String preprocessing,
  }) async {
    final url = Uri.parse('$baseUrl/predict');
    
    final body = jsonEncode({
      'dataset_id': datasetId,
      'algorithm': algorithm,
      'preprocessing': preprocessing,
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      
      // Se castea la respuesta dinámica a una estructura rígida de Dart: List<List<int>>
      List<dynamic> rawMap = responseData['prediction_map'];
      List<List<int>> predictionMap = rawMap
          .map((row) => List<int>.from(row as List))
          .toList();
          
      return predictionMap;
    } else {
      // Si el servidor responde con error, extraemos el mensaje
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['error'] ?? 'Error desconocido en el servidor.');
    }
  }
}