import 'package:cookidea/features/dashboard/presentation/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dashboard shows the first-project empty state', (tester) async {
    await tester.view.setPhysicalSize(const Size(1440, 1000));
    await tester.view.setDevicePixelRatio(1);

    await tester.pumpWidget(
      const MaterialApp(home: DashboardPage()),
    );

    expect(find.text('Bonjour 👋'), findsOneWidget);
    expect(find.text('Vos projets'), findsOneWidget);
    expect(find.text('Créer ma première idée'), findsOneWidget);

    await tester.view.resetPhysicalSize();
    await tester.view.resetDevicePixelRatio();
  });
}
