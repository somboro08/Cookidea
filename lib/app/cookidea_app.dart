import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../features/auth/presentation/auth_gate.dart';

class CookideaApp extends StatelessWidget {
  const CookideaApp({super.key, required this.supabaseEnabled});
  final bool supabaseEnabled;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cookidea',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: context.pal.bg,
            systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: AuthGate(supabaseEnabled: supabaseEnabled),
    );
  }
}
