import os
import scipy.io as sio
import numpy as np

# Rutas base donde guardaremos los archivos descargados
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATASETS_DIR = os.path.join(BASE_DIR, 'datasets')

# Diccionario de configuración: mapea el nombre del dataset con sus archivos reales
DATASET_CONFIG = {
    'indian_pines': {
        'data_path': 'Indian_pines_corrected.mat',
        'data_key': 'indian_pines_corrected',
        'gt_path': 'Indian_pines_gt.mat',
        'gt_key': 'indian_pines_gt'
    },
    'pavia_university': {
        'data_path': 'PaviaU.mat',
        'data_key': 'paviaU',
        'gt_path': 'PaviaU_gt.mat',
        'gt_key': 'paviaU_gt'
    },
    'salinas': {
        'data_path': 'Salinas_corrected.mat',
        'data_key': 'salinas_corrected',
        'gt_path': 'Salinas_gt.mat',
        'gt_key': 'salinas_gt'
    }
}


def load_dataset(dataset_name):
    """
    Carga dinámicamente un dataset hiperespectral basándose en su nombre.
    Retorna el cubo de datos (X) y sus etiquetas espaciales (Y).
    """
    if dataset_name not in DATASET_CONFIG:
        raise ValueError(f"El dataset '{dataset_name}' no está soportado. Opciones: {list(DATASET_CONFIG.keys())}")

    config = DATASET_CONFIG[dataset_name]

    # Construir rutas absolutas
    data_file = os.path.join(DATASETS_DIR, config['data_path'])
    gt_file = os.path.join(DATASETS_DIR, config['gt_path'])

    # Cargar matrices usando SciPy
    try:
        data_mat = sio.loadmat(data_file)
        gt_mat = sio.loadmat(gt_file)
    except FileNotFoundError as e:
        raise FileNotFoundError(
            f"Falta un archivo del dataset. Asegúrate de haber descargado '{config['data_path']}' en '{DATASETS_DIR}'.")

    # Extraer los arrays de NumPy usando las keys correctas
    X = data_mat[config['data_key']]
    Y = gt_mat[config['gt_key']]

    print(f"  {dataset_name} cargado correctamente.")
    print(f"   Dimensión del Cubo: {X.shape}")
    print(f"   Dimensión de Etiquetas: {Y.shape}")

    return X, Y


# Bloque de prueba (solo se ejecuta si corres este script directamente)
if __name__ == "__main__":
    # Prueba a cargar el más pequeño para verificar que todo funciona
    cubo, etiquetas = load_dataset('salinas')