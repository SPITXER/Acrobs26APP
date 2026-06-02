import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/app_state.dart';
import 'theme/acro_theme.dart';
import 'screens/acropolis_map_screen.dart';
import 'screens/room_screen.dart';

final _navigatorKey  = GlobalKey<NavigatorState>();
final _messengerKey  = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(
        navigatorKey: _navigatorKey,
        messengerKey: _messengerKey,
      ),
      child: AcroApp(navigatorKey: _navigatorKey, messengerKey: _messengerKey),
    ),
  );
}

class AcroApp extends StatelessWidget {
  final GlobalKey<NavigatorState>       navigatorKey;
  final GlobalKey<ScaffoldMessengerState> messengerKey;
  const AcroApp({super.key, required this.navigatorKey, required this.messengerKey});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey:        navigatorKey,
      scaffoldMessengerKey: messengerKey,
      title: 'Acro — The Agora of Ideas',
      theme: AcroTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const AcropolisMapScreen(),
      routes: {
        '/room': (_) => const RoomScreen(),
      },
    );
  }
}
