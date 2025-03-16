import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';
import 'screens/news_page.dart'; 
import 'screens/radio_page.dart';
import 'screens/tv_page.dart';
import 'screens/settings_page.dart';
import 'services/notification_service.dart';
import 'services/rss_service.dart';

// Global navigation key to use for navigation from outside of widgets
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Stel de statusbalkkleur en icoontjes in
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent, // Transparante achtergrond
    statusBarIconBrightness: Brightness.dark, // Donkere icoontjes (voor een lichte achtergrond)
    systemNavigationBarColor: Colors.white, // Optioneel: pas de navigatiebalk aan
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // Initialize notifications first
  await NotificationService.initialize();
  
  // Then initialize workmanager
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true,
  );
  
  runApp(const MyApp());
}

// Handle deep links from notifications
void handleDeepLink(String? url) {
  if (url != null && url.isNotEmpty) {
    debugPrint('Opening deep link: $url');
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => NewsArticleScreen(articleUrl: url),
      ),
    );
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == 'checkRSSFeed') {
      await RSSService.checkForNewContent();
    }
    return true;
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Set the navigator key
      title: 'Samen1',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFA6401),
          primary: const Color(0xFFFA6401),
          secondary: const Color(0xFFB94B01),
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final _pages = const [
    NewsPage(),
    RadioPage(),
    TVPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFFFA6401),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.newspaper), label: 'Nieuws'),
          BottomNavigationBarItem(icon: Icon(Icons.radio), label: 'Radio'),
          BottomNavigationBarItem(icon: Icon(Icons.tv), label: 'TV'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Instellingen'),
        ],
      ),
    );
  }
}
