// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hiperespectrales/main.dart';

void main() {
  testWidgets('Verificar carga de la interfaz hiperespectral', (WidgetTester tester) async {
    // Levantamos la aplicación utilizando el nuevo nombre de clase HyperspectralApp
    await tester.pumpWidget(const HyperspectralApp());

    // Verificamos que el título principal de la herramienta esté presente en pantalla
    expect(find.text('Análisis de Imágenes Hiperespectrales'), findsOneWidget);
    
    // Verificamos que el botón de análisis se muestre correctamente en la interfaz
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}