import 'package:cookidea/features/dashboard/presentation/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('workspace renders on desktop', (tester) async {
    await tester.view.setPhysicalSize(const Size(1440, 1000));
    await tester.view.setDevicePixelRatio(1);
    await tester.pumpWidget(const MaterialApp(home: DashboardPage(supabaseEnabled: false)));
    await tester.pumpAndSettle();
    expect(find.text('Bonjour 👋'), findsOneWidget);
    expect(find.text('Vos projets'), findsOneWidget);
    expect(find.text('Créer ma première idée'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.view.resetPhysicalSize();
    await tester.view.resetDevicePixelRatio();
  });

  testWidgets('workspace adapts to a narrow mobile viewport', (tester) async {
    await tester.view.setPhysicalSize(const Size(360, 800));
    await tester.view.setDevicePixelRatio(1);
    await tester.pumpWidget(const MaterialApp(home: DashboardPage(supabaseEnabled: false)));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(find.text('Bonjour 👋'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.view.resetPhysicalSize();
    await tester.view.resetDevicePixelRatio();
  });
}
