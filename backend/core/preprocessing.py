import numpy as np


def flatten_cube(X, Y):
    """
    Convierte el cubo 3D (H, W, B) en una matriz 2D (N, B) para Machine Learning.
    También aplana la matriz de etiquetas Y de (H, W) a (N, 1).
    """
    # Guardamos las dimensiones originales para poder reconstruir la imagen después
    original_shape = X.shape[:2]

    # -1 le dice a NumPy que calcule automáticamente el número total de píxeles (H * W)
    X_flat = X.reshape(-1, X.shape[2])
    Y_flat = Y.reshape(-1)

    return X_flat, Y_flat, original_shape


def apply_preprocessing(X_flat, method=None):
    """
    Aplica técnicas de preprocesamiento quimiométrico a la matriz 2D.
    method: 'minmax', 'snv', 'derivative' o None.
    """
    if method is None or method == 'none':
        return X_flat

    X_processed = np.copy(X_flat).astype(np.float64)

    if method == 'minmax':
        # Normalización Min-Max por píxel (fila)
        min_vals = X_processed.min(axis=1, keepdims=True)
        max_vals = X_processed.max(axis=1, keepdims=True)
        # Evitar división por cero
        denominator = np.where((max_vals - min_vals) == 0, 1, max_vals - min_vals)
        X_processed = (X_processed - min_vals) / denominator

    elif method == 'snv':
        # Standard Normal Variate: (x - media) / desviación_estándar
        mean_vals = X_processed.mean(axis=1, keepdims=True)
        std_vals = X_processed.std(axis=1, keepdims=True)
        # Evitar división por cero
        std_vals = np.where(std_vals == 0, 1, std_vals)
        X_processed = (X_processed - mean_vals) / std_vals

    elif method == 'derivative':
        # Primera derivada espectral (diferencia a lo largo de las bandas)
        X_processed = np.gradient(X_processed, axis=1)

    else:
        raise ValueError(f"Método de preprocesamiento '{method}' no reconocido.")

    return X_processed


# Bloque de prueba
if __name__ == "__main__":
    from data_loader import load_dataset

    # 1. Cargamos el dataset
    cubo, etiquetas = load_dataset('salinas')

    # 2. Aplanamos
    X_flat, Y_flat, shape = flatten_cube(cubo, etiquetas)
    print(f"Forma original: {shape}")
    print(f"Cubo aplanado: {X_flat.shape}")

    # 3. Probamos el filtro matemático SNV
    X_snv = apply_preprocessing(X_flat, method='snv')
    print(f"Media del primer píxel tras SNV (debería ser ~0): {X_snv[0].mean():.4f}")
    print(f"Desviación estándar del primer píxel tras SNV (debería ser ~1): {X_snv[0].std():.4f}")