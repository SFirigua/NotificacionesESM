import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/app_bootstrap.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Sin trabajo pesado antes de `runApp`: el splash nativo y el de Flutter se
  // muestran de inmediato y la inicialización corre en `AppBootstrap`.
  runApp(const BirthdayReminderApp());
}

class BirthdayReminderApp extends StatelessWidget {
  const BirthdayReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recordatorio de cumpleaños',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD81B60)),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es'), Locale('en')],
      locale: const Locale('es'),
      home: const AppBootstrap(),
    );
  }
}
