import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/barang_provider.dart';
import 'providers/transaksi_provider.dart';
import 'providers/pembukuan_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  // 1. Inisialisasi binding Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inisialisasi format tanggal Indonesia
  await initializeDateFormatting('id_ID', null);

  // 3. LOCK PORTRAIT: Menghemat resource agar HP tidak re-layout saat diputar
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // 4. FLAT UI: Mematikan transparansi status bar untuk performa GPU
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.blue, 
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // 5. Jalankan aplikasi
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiProvider digabung di sini agar semua screen bisa akses data
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // BarangProvider HARUS ADA dan kita matikan lazy-nya dulu biar dia standby
        ChangeNotifierProvider(create: (_) => BarangProvider(), lazy: false),
        ChangeNotifierProvider(create: (_) => TransaksiProvider()),
        ChangeNotifierProvider(create: (_) => PembukuanProvider()),
      ],
      child: MaterialApp(
        title: 'POS UMKM',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          splashFactory: NoSplash.splashFactory, 
          visualDensity: VisualDensity.compact,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: NoAnimationPageTransitionsBuilder(),
              TargetPlatform.iOS: NoAnimationPageTransitionsBuilder(),
            },
          ),
        ),
        // Home menggunakan Consumer untuk cek status login
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            return auth.isLoggedIn ? const HomeScreen() : const LoginScreen();
          },
        ),
      ),
    );
  }
}

// Custom Class untuk mematikan total animasi perpindahan halaman (Sangat Ringan)
class NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoAnimationPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}