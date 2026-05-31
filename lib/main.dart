import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/app_state.dart';
import 'theme/acro_theme.dart';
import 'screens/onboarding_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const AcroApp(),
    ),
  );
}

class AcroApp extends StatelessWidget {
  const AcroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Acro — The Agora of Ideas',
      theme: AcroTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const OnboardingScreen(),
    );
  }
}
