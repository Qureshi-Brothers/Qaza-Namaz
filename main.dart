import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'notify.dart';
import 'screens.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (supabaseConfigured) {
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      cloudReady = true;
    } catch (_) {
      cloudReady = false;
    }
  }

  try {
    await Notifier.init();
  } catch (_) {}

  final state = AppState();
  await state.load();
  runApp(QazaApp(state));
  unawaited(state.afterLogin());
}

class QazaApp extends StatelessWidget {
  final AppState state;
  const QazaApp(this.state, {super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qaza Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: Root(state),
    );
  }
}
