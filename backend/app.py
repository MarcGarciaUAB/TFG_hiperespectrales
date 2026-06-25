import os
import joblib
import base64
import io
import numpy as np
from PIL import Image
from flask import Flask, request, jsonify
from flask_cors import CORS
from core.data_loader import load_dataset
from core.preprocessing import flatten_cube, apply_preprocessing

app = Flask(__name__)
# Habilitamos CORS para que Flutter (que corre en el navegador) pueda hacer peticiones sin bloqueos de seguridad
CORS(app)

CACHE = {
    "dataset_name": None,
    "cube": None,
    "gt": None
}

MODELS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'models', 'saved_models')

def get_or_load_cube(dataset_name):
    """Carga el cubo hiperespectral solo si no está ya en memoria."""
    if CACHE["dataset_name"] != dataset_name:
        print(f" Cargando dataset '{dataset_name}' en memoria...")
        cube, gt = load_dataset(dataset_name)
        CACHE["dataset_name"] = dataset_name
        CACHE["cube"] = cube
        CACHE["gt"] = gt
    return CACHE["cube"]


@app.route('/roi_stats', methods=['POST'])
def get_roi_stats():
    data = request.json
    dataset_name = data.get('dataset_id', 'salinas')
    x1, y1 = data['xStart'], data['yStart']
    x2, y2 = data['xEnd'], data['yEnd']

    cube = get_or_load_cube(dataset_name)

    # Extraer el bloque (ROI)
    # Nota: +1 para incluir el último índice
    roi = cube[y1:y2 + 1, x1:x2 + 1, :]

    # Calcular estadísticas sobre todo el bloque
    # Axis=(0,1) promedia sobre el alto y ancho, dejando el eje de bandas (spectral)
    mean_curve = np.mean(roi, axis=(0, 1))
    min_val = np.min(roi)
    max_val = np.max(roi)

    return jsonify({
        "mean_curve": mean_curve.tolist(),
        "min": float(min_val),
        "max": float(max_val)
    }), 200

@app.route('/pixel_signature', methods=['POST'])
def get_pixel_signature():
    """Devuelve la firma espectral (array 1D) de un píxel específico."""
    data = request.json
    dataset_name = data.get('dataset_id', 'salinas')
    x = data.get('x', 0)
    y = data.get('y', 0)

    try:
        cube = get_or_load_cube(dataset_name)

        # Validar que las coordenadas no se salgan de la imagen
        if y < 0 or y >= cube.shape[0] or x < 0 or x >= cube.shape[1]:
            return jsonify({"error": "Coordenadas fuera de límite"}), 400

        # Extraer la curva en la coordenada (Y, X) y convertir el array de NumPy a lista estándar de Python
        signature = cube[y, x, :].tolist()

        return jsonify({"curve": signature}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/get_band_image', methods=['POST'])
def get_band_image():
    data = request.json
    dataset_id = data.get('dataset_id', 'salinas')
    bands = data.get('bands', [0])

    try:
        cube = get_or_load_cube(dataset_id)

        if len(bands) == 1:
            img_data = cube[:, :, bands[0]]
            # Normalización simple para 1 banda
            img_min, img_max = img_data.min(), img_data.max()
            if img_max - img_min == 0:
                img_norm = np.zeros(img_data.shape, dtype=np.uint8)
            else:
                img_norm = ((img_data - img_min) / (img_max - img_min) * 255).astype(np.uint8)
            img = Image.fromarray(img_norm, mode='L')

        elif len(bands) == 3:
            # Extraer y normalizar por canal (R, G, B)
            channels = []
            for b_idx in bands:
                channel = cube[:, :, b_idx].astype(np.float32)
                # Normalización independiente por canal
                c_min, c_max = channel.min(), channel.max()
                if c_max - c_min == 0:
                    channel_norm = np.zeros(channel.shape, dtype=np.uint8)
                else:
                    channel_norm = ((channel - c_min) / (c_max - c_min) * 255).astype(np.uint8)
                channels.append(channel_norm)

            # Apilar los canales normalizados
            rgb_data = np.dstack(channels)
            img = Image.fromarray(rgb_data, mode='RGB')

        else:
            return jsonify({"error": "Número de bandas inválido"}), 400

        # Convertir a base64
        buffered = io.BytesIO()
        img.save(buffered, format="PNG")
        img_str = base64.b64encode(buffered.getvalue()).decode('utf-8')
        return jsonify({"image_base64": img_str}), 200

    except Exception as e:
        print(f"DEBUG ERROR: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/render_band', methods=['POST'])
def render_band():
    """Corta 1 o 3 bandas del cubo, normaliza y devuelve un PNG en Base64."""
    data = request.json
    dataset_name = data.get('dataset_id', 'salinas')
    bands = data.get('bands', [0])  # Esperamos una lista: [10] para gris, o [29, 15, 9] para RGB

    try:
        cube = get_or_load_cube(dataset_name)

        # 1. Extraer los datos brutos del cubo
        if len(bands) == 1:
            # Escala de grises (1 sola banda)
            img_data = cube[:, :, bands[0]]
        elif len(bands) == 3:
            # Color RGB (3 bandas)
            img_data = cube[:, :, bands]
        else:
            return jsonify({"error": "Se requieren exactamente 1 o 3 bandas"}), 400

        # 2. Normalizar matemáticamente los valores para que entren entre 0 y 255
        img_min = img_data.min()
        img_max = img_data.max()

        if img_max > img_min:
            img_normalized = (img_data - img_min) / (img_max - img_min) * 255.0
        else:
            img_normalized = img_data * 0  # Prevención de división por cero si la banda es plana

        img_uint8 = img_normalized.astype(np.uint8)

        # 3. Crear el lienzo de imagen
        if len(bands) == 1:
            pil_img = Image.fromarray(img_uint8, mode='L')  # L = Luminance (Escala de grises)
        else:
            pil_img = Image.fromarray(img_uint8, mode='RGB')

        # 4. Convertir la imagen a un string Base64 directamente en memoria RAM
        buffered = io.BytesIO()
        pil_img.save(buffered, format="PNG")
        img_base64_str = base64.b64encode(buffered.getvalue()).decode('utf-8')

        return jsonify({"image_base64": img_base64_str}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/health', methods=['GET'])
def health_check():
    """Endpoint de diagnóstico para comprobar que el backend está vivo."""
    return jsonify({
        "status": "ok",
        "message": "Motor de clasificación hiperespectral activo."
    }), 200


@app.route('/predict', methods=['POST'])
def predict():
    """
    Endpoint transaccional principal.
    Espera un JSON con: dataset_id, algorithm y preprocessing.
    """
    try:
        # 1. Leer los parámetros enviados por Flutter
        data = request.json
        dataset_id = data.get('dataset_id', 'salinas')
        algorithm = data.get('algorithm', 'Random_Forest')
        preprocessing = data.get('preprocessing', 'snv')

        print(f" Petición recibida -> Dataset: {dataset_id} | Filtro: {preprocessing} | Modelo: {algorithm}")

        # 2. Cargar la imagen hiperespectral pura
        X_cube, Y_gt = load_dataset(dataset_id)

        # 3. Aplanar el cubo completo (esta vez sin submuestrear, queremos pintar toda la imagen)
        X_flat, _, original_shape = flatten_cube(X_cube, Y_gt)

        # 4. Aplicar el mismo preprocesamiento que usamos en el entrenamiento
        X_processed = apply_preprocessing(X_flat, method=preprocessing)

        # 5. Cargar dinámicamente el modelo binario correcto
        model_filename = f"{dataset_id}_{preprocessing}_{algorithm}.joblib"
        model_path = os.path.join(MODELS_DIR, model_filename)

        if not os.path.exists(model_path):
            return jsonify({
                "error": f"El modelo {model_filename} no existe. Por favor, entrénalo primero en el servidor."
            }), 404

        print(f" Cargando modelo: {model_filename}...")
        model = joblib.load(model_path)

        # 6. Realizar la inferencia masiva sobre todos los píxeles
        print("⚙️ Procesando inferencia espacial...")
        y_pred_flat = model.predict(X_processed)

        # 7. Reconstruir la matriz espacial 2D (H, W)
        prediction_map = y_pred_flat.reshape(original_shape)

        # 8. Devolver el mapa al frontend como una lista de listas JSON
        return jsonify({
            "status": "success",
            "dataset": dataset_id,
            "shape": original_shape,
            "prediction_map": prediction_map.tolist()  # Convertimos el tensor NumPy a formato web compatible
        }), 200

    except Exception as e:
        print(f" Error interno: {str(e)}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    print(" Iniciando servidor Flask en http://127.0.0.1:5000")
    app.run(host='127.0.0.1', port=5000, debug=True)