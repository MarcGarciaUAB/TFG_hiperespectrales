import os
import sys
import joblib
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.cross_decomposition import PLSRegression
from sklearn.ensemble import RandomForestClassifier
from sklearn.svm import SVC
from sklearn.neighbors import KNeighborsClassifier
from sklearn.preprocessing import OneHotEncoder
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from backend.core.data_loader import load_dataset
from backend.core.preprocessing import flatten_cube, apply_preprocessing
from sklearn.metrics import accuracy_score, precision_recall_fscore_support

# --- IMPLEMENTACIÓN DE PLS-DA PARA CLASIFICACIÓN ---
class PLSDAClassifier:
    """ Envoltorio (Wrapper) para adaptar PLSRegression a un problema de clasificación multiclase """

    def __init__(self, n_components=20):
        self.n_components = n_components
        self.pls = PLSRegression(n_components=n_components)
        self.ohe = OneHotEncoder(sparse_output=False)

    def fit(self, X, y):
        # Convertir las etiquetas de clase a matriz One-Hot (Ej: Clase 3 -> [0, 0, 1, 0...])
        y_onehot = self.ohe.fit_transform(y.reshape(-1, 1))
        self.pls.fit(X, y_onehot)
        return self

    def predict(self, X):
        # La predicción devuelve valores continuos, tomamos el valor máximo (argmax)
        preds_continuous = self.pls.predict(X)
        return self.ohe.inverse_transform(preds_continuous).ravel()


def run_experiment():
    datasets = ['salinas', 'pavia_university', 'indian_pines']
    # 'none' es nuestro grupo de control (baseline)
    preprocessing_methods = ['none', 'minmax', 'snv', 'derivative']

    results_list = []

    for ds in datasets:
        print(f"\n{'=' * 20} PROCESANDO DATASET: {ds.upper()} {'=' * 20}")

        # 1. Carga y preprocesado básico (una vez por dataset)
        X_cube, Y_gt = load_dataset(ds)
        X_flat, Y_flat, _ = flatten_cube(X_cube, Y_gt)
        labeled_indices = np.where(Y_flat > 0)[0]
        X_sampled = X_flat[labeled_indices]
        Y_sampled = Y_flat[labeled_indices]

        for method in preprocessing_methods:
            print(f" > Método de Preprocesado: {method}")

            # 2. Aplicar el preprocesado actual
            X_proc = apply_preprocessing(X_sampled, method=method)

            # 3. Split
            X_train, X_test, y_train, y_test = train_test_split(
                X_proc, Y_sampled, test_size=0.30, random_state=42, stratify=Y_sampled
            )

            # 4. Modelos
            models = {
                'PLS-DA': PLSDAClassifier(n_components=15),
                'RF': RandomForestClassifier(n_estimators=100, n_jobs=-1, random_state=42),
                'SVM': SVC(kernel='rbf', C=10, gamma='scale'),
                'k-NN': KNeighborsClassifier(n_neighbors=5, n_jobs=-1)
            }

            for name, model in models.items():
                model.fit(X_train, y_train)
                y_pred = model.predict(X_test)

                # Calculamos todas las métricas a la vez
                # Usamos average='weighted' para que tenga en cuenta el desbalanceo de clases
                precision, recall, f1, _ = precision_recall_fscore_support(
                    y_test, y_pred, average='weighted', zero_division=0
                )
                acc = accuracy_score(y_test, y_pred)

                # Guardar resultado en la lista
                results_list.append({
                    'Dataset': ds,
                    'Preprocesado': method,
                    'Modelo': name,
                    'Accuracy': round(acc * 100, 2),
                    'Precision': round(precision * 100, 2),
                    'Recall': round(recall * 100, 2),
                    'F1-Score': round(f1 * 100, 2)
                })

    # 5. Crear tabla resumen final
    df_results = pd.DataFrame(results_list)
    print("\n\n" + "=" * 50)
    print(" TABLA COMPARATIVA DE RESULTADOS")
    print("=" * 50)
    print(df_results.pivot(index=['Dataset', 'Preprocesado'], columns='Modelo', values='Accuracy'))

    # Exportar a CSV para pegarlo en tu informe o LaTeX
    df_results.to_csv("resultados_tfg.csv", index=False)


if __name__ == "__main__":
    run_experiment()
