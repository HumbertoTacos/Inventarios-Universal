// Test básico de humo para la app de inventario.

import 'package:flutter_test/flutter_test.dart';
import 'package:blancos_gina/main.dart';

void main() {
  testWidgets('La app se renderiza correctamente', (WidgetTester tester) async {
    await tester.pumpWidget(const MiInventarioApp());

    // Verifica que el título de la app aparezca
    expect(find.text('Inventario'), findsOneWidget);
  });
}
