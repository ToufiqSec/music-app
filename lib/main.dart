import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/audio_handler.dart';
import 'providers/audio_provider.dart';
import 'providers/auth_provider.dart';
import 'features/listen_together/providers/room_provider.dart';
import 'core/services/supabase_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/mood_recommendation_engine.dart';
import 'core/services/home_section_cache_store.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';

void main() {
  // 1. Ensure Flutter binding is initialized first
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[Startup] WidgetsFlutterBinding initialized.');

  // Truly Edge-to-Edge display (transparent system bars, no black strips)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // 2. Global release mode error presentation to prevent blank/black screens
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[Startup Error] Uncaught Flutter Error: ${details.exceptionAsString()}');
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: AppColors.swarvaBgDark,
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
  RoomProvider? _roomProvider;

  @override
  void initState() {
    super.initState();
    debugPrint('[Startup] MusicAppBootstrap initState()');
    _initServices();
  }

  Future<void> _initServices() async {
    // 0. Initialize Firebase Core for Native Auth & Messaging
    try {
      debugPrint('[Startup] Initializing Firebase Core...');
      await Firebase.initializeApp();
      debugPrint('[Startup] Firebase Core initialized.');
    } catch (e, stack) {
      debugPrint('[Startup] Firebase Core initialization: $e\n$stack');
    }

    // 1. Initialize Supabase for backend Cloud sync
    try {
      debugPrint('[Startup] Initializing Supabase...');
      await SupabaseService.initialize();
      debugPrint('[Startup] Supabase initialized.');
    } catch (e, stack) {
      debugPrint('[Startup] Supabase initialization failed: $e\n$stack');
    }

    // 2. Initialize Firebase Cloud Messaging & Notifications
    try {
      debugPrint('[Startup] Initializing NotificationService...');
      await NotificationService.instance.initialize();
      debugPrint('[Startup] NotificationService initialized.');
    } catch (e, stack) {
      debugPrint('[Startup] NotificationService initialization failed: $e\n$stack');
    }

    // 3. Initialize AI Services & persistent settings
    try {
      await MoodRecommendationEngine.initApiKey();
    } catch (_) {}

    // 4. Preserve persistent home section & image caches across launches for instant cold start

    // 5. Initialize native AudioService
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
      final audio = AudioProvider(handler);
      final room = RoomProvider();
      room.attachAudioProvider(audio);
      setState(() {
        _audioProvider = audio;
        _authProvider = AuthProvider();
        _roomProvider = room;
      });
      debugPrint('[Startup] Providers mounted, rendering HomeScreen.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // If not ready yet on frame 1, show official animated Swarva splash
    if (_audioProvider == null) {
      return MaterialApp(
        title: 'Swarva',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const SwarvaSplashScreen(),
      );
    }

    // Top-level provider injection guarantees all pushed routes and sheets inherit providers
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _audioProvider!),
        ChangeNotifierProvider.value(value: _authProvider ?? AuthProvider()),
        ChangeNotifierProvider.value(value: _roomProvider ?? RoomProvider()),
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
      title: 'Swarva',
      navigatorKey: NotificationService.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
