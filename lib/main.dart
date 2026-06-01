import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/app_state.dart';
import 'theme/acro_theme.dart';
import 'screens/acropolis_map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
      home: const AcropolisMapScreen(),
    );
  }
}
