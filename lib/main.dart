import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'services/audio_handler.dart';
import 'providers/audio_provider.dart';
import 'providers/auth_provider.dart';
import 'core/services/supabase_service.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  // 1. Ensure Flutter binding is initialized first
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[Startup] WidgetsFlutterBinding initialized.');

  // 2. Global release mode error presentation to prevent blank/black screens
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[Startup Error] Uncaught Flutter Error: ${details.exceptionAsString()}');
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF182838),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFFF8FA3), size: 48),
              const SizedBox(height: 16),
              const Text(
                'Initialization Issue',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  };

  // 3. Immediately invoke runApp with a lightweight bootstrap widget to guarantee first-frame rendering
  debugPrint('[Startup] runApp() dispatched immediately.');
  runApp(const MusicAppBootstrap());
}

/// Lightweight App Bootstrap that guarantees immediate first-frame rendering
/// and manages background audio service initialization without freezing the UI.
class MusicAppBootstrap extends StatefulWidget {
  const MusicAppBootstrap({super.key});

  @override
  State<MusicAppBootstrap> createState() => _MusicAppBootstrapState();
}

class _MusicAppBootstrapState extends State<MusicAppBootstrap> {
  AudioProvider? _audioProvider;
  AuthProvider? _authProvider;

  @override
  void initState() {
    super.initState();
    debugPrint('[Startup] MusicAppBootstrap initState()');
    _initServices();
  }

  Future<void> _initServices() async {
    // 1. Initialize Supabase first for backend Auth & Cloud sync
    try {
      debugPrint('[Startup] Initializing Supabase...');
      await SupabaseService.initialize();
      debugPrint('[Startup] Supabase initialized.');
    } catch (e, stack) {
      debugPrint('[Startup] Supabase initialization failed: $e\n$stack');
    }

    // 2. Initialize native AudioService
    MyAudioHandler handler;
    try {
      debugPrint('[Startup] Initializing native AudioService...');
      handler = await AudioService.init(
        builder: () => MyAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.musicapp.channel.audio',
          androidNotificationChannelName: 'Music Playback',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          androidNotificationIcon: 'mipmap/ic_launcher',
        ),
      );
      debugPrint('[Startup] AudioService successfully initialized.');
    } catch (e, stack) {
      debugPrint('[Startup] AudioService.init failed, falling back to local player: $e\n$stack');
      // Graceful fallback to standalone handler so playback is never completely blocked
      handler = MyAudioHandler();
    }

    if (mounted) {
      setState(() {
        _audioProvider = AudioProvider(handler);
        _authProvider = AuthProvider();
      });
      debugPrint('[Startup] Providers mounted, rendering HomeScreen.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // If not ready yet on frame 1, show a fast lightweight native-matched splash container
    if (_audioProvider == null) {
      return MaterialApp(
        title: 'Music App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: Scaffold(
          backgroundColor: const Color(0xFF182838),
          body: Center(
            child: Image.asset(
              'assets/icon/splash_icon.png',
              width: 140,
              height: 140,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.music_note_rounded,
                size: 80,
                color: Colors.white70,
              ),
            ),
          ),
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _audioProvider!),
        ChangeNotifierProvider.value(value: _authProvider ?? AuthProvider()),
      ],
      child: const MusicApp(),
    );
  }
}

class MusicApp extends StatelessWidget {
  const MusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
