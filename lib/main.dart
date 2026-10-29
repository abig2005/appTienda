import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'controllers/carrito_controller.dart';
import 'controllers/sesion_controller.dart';
import 'repository/database_helper.dart';
import 'services/notification_service.dart';
import 'services/preferencias_service.dart';
import 'theme/app_theme.dart';
import 'views/login_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint(AppConfig.resumen);

  Intl.defaultLocale = 'es_MX';
  await initializeDateFormatting('es_MX');
  await PreferenciasService.instance.inicializar();

  try {
    await DatabaseHelper.instance.database;
    await DatabaseHelper.instance.sincronizarUsuariosDemo();
  } catch (e) {
    debugPrint('Error al preparar la base de datos: $e');
  }
  await NotificationService.instance.inicializar();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TemaController()),
        ChangeNotifierProvider(create: (_) => SesionController()),
        ChangeNotifierProvider(create: (_) => CarritoController()),
      ],
      child: const AppTiendaApp(),
    ),
  );
}

class AppTiendaApp extends StatelessWidget {
  const AppTiendaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = context.watch<TemaController>();
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: kDebugMode,
      theme: AppTheme.tema(Brightness.light),
      darkTheme: AppTheme.tema(Brightness.dark),
      themeMode: tema.modo,
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX'), Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(tema.escalaTexto)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const LoginView(),
    );
  }
}
