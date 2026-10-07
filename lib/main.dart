import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Color(0xFF0F0F11),
  ));
  runApp(const DarkFreeApp());
}

class DarkFreeApp extends StatelessWidget {
  const DarkFreeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DarkFree',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF111113),
        fontFamily: 'sans-serif',
      ),
      home: const SplashScreen(),
    );
  }
}

// ==================== 1. SPLASH SCREEN ====================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double progress = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startSteppedProgress();
  }

  void _startSteppedProgress() {
    // 2 секунды с неравномерной анимацией
    final steps = [
      Future.delayed(const Duration(milliseconds: 300), () => setState(() => progress = 0.25)),
      Future.delayed(const Duration(milliseconds: 700), () => setState(() => progress = 0.55)),
      Future.delayed(const Duration(milliseconds: 1400), () => setState(() => progress = 0.85)),
      Future.delayed(const Duration(milliseconds: 2000), () => setState(() => progress = 1.0)),
    ];

    Future.wait(steps).then((_) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 600),
            pageBuilder: (_, __, ___) => const MainNavigationShell(),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101012),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Иконка шпиона (силуэт)
            Icon(Icons.security, size: 75, color: Colors.grey.shade800),
            const SizedBox(height: 28),
            // Прогресс-бар не шире иконки
            SizedBox(
              width: 75,
              height: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: const Color(0xFF2B2B30),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE50914)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== NAVIGATION SHELL ====================
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 1; // 0: Support, 1: Home, 2: Settings
  String userId = "#000000";
  String serverUrl = "http://192.168.0.104:5000";

  @override
  void initState() {
    super.initState();
    _initUserId();
  }

  Future<void> _initUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('user_id');
    if (id == null) {
      final random = Random();
      final num = 100000 + random.nextInt(900000);
      id = "#$num";
      await prefs.setString('user_id', id);
    }
    String? savedUrl = prefs.getString('server_url');
    setState(() {
      userId = id!;
      if (savedUrl != null && savedUrl.isNotEmpty) serverUrl = savedUrl;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      SupportScreen(onCopyId: () {}),
      HomeScreen(userId: userId, serverUrl: serverUrl),
      SettingsScreen(
        userId: userId,
        serverUrl: serverUrl,
        onUrlChanged: (newUrl) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('server_url', newUrl);
          setState(() => serverUrl = newUrl);
        },
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF101012),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Логотип DarkFree вверху
            RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                children: [
                  TextSpan(text: 'Dark', style: TextStyle(color: Color(0xFFE50914))),
                  TextSpan(text: 'Free', style: TextStyle(color: Color(0xFF6C6C75))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: screens[_currentIndex],
              ),
            ),
            // Нижняя панель навигации
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _navItem(icon: Icons.headset_mic_rounded, index: 0),
          _navItem(icon: Icons.home_rounded, index: 1),
          _navItem(icon: Icons.settings_rounded, index: 2),
        ],
      ),
    );
  }

  Widget _navItem({required IconData icon, required int index}) {
    final isCenterSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          size: isCenterSelected ? 38 : 28,
          color: isCenterSelected ? const Color(0xFFD6D6DD) : const Color(0xFF484850),
        ),
      ),
    );
  }
}

// ==================== 2. HOME SCREEN ====================
class ServerItem {
  final String id;
  final String name;
  final String host;
  final String config;
  int? ping;

  ServerItem({required this.id, required this.name, required this.host, required this.config, this.ping});
}

class HomeScreen extends StatefulWidget {
  final String userId;
  final String serverUrl;

  const HomeScreen({super.key, required this.userId, required this.serverUrl});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String tier = "Free Edition";
  List<ServerItem> servers = [];
  int selectedIndex = -1;
  bool isConnected = false;
  bool isConnecting = false;
  int connectingDots = 1;
  Timer? _dotTimer;
  Timer? _sessionTimer;
  int connectedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _fetchServers();
  }

  Future<void> _fetchServers() async {
    try {
      final res = await http.get(Uri.parse('${widget.serverUrl}/api/servers?user_id=${widget.userId}')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          tier = data['tier'] ?? "Free Edition";
          servers = (data['servers'] as List).map((s) => ServerItem(
            id: s['id'],
            name: s['name'],
            host: s['host'],
            config: s['config'],
          )).toList();
        });
        _measurePingLocally();
      }
    } catch (_) {
      // Сервер не ответил — список пуст
    }
  }

  Future<void> _measurePingLocally() async {
    for (var s in servers) {
      final sw = Stopwatch()..start();
      try {
        final socket = await Socket.connect(s.host, 443, timeout: const Duration(milliseconds: 1500));
        socket.destroy();
        sw.stop();
        setState(() => s.ping = sw.elapsedMilliseconds);
      } catch (_) {
        sw.stop();
        setState(() => s.ping = 999);
      }
    }
  }

  void _toggleConnection() {
    if (selectedIndex == -1) return;

    if (isConnected) {
      _sessionTimer?.cancel();
      setState(() {
        isConnected = false;
        connectedSeconds = 0;
      });
      return;
    }

    if (isConnecting) return;

    setState(() => isConnecting = true);
    _dotTimer = Timer.periodic(const Duration(milliseconds: 400), (t) {
      setState(() => connectingDots = (connectingDots % 3) + 1);
    });

    Future.delayed(const Duration(seconds: 2), () {
      _dotTimer?.cancel();
      setState(() {
        isConnecting = false;
        isConnected = true;
      });
      _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => connectedSeconds++);
      });
    });
  }

  String _formatDuration(int seconds) {
    final h = (seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    return "$h:$m";
  }

  @override
  void dispose() {
    _dotTimer?.cancel();
    _sessionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // Карточка уровня и серверов
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1F24),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(tier, style: const TextStyle(color: Color(0xFFE50914), fontWeight: FontWeight.bold, fontSize: 16)),
                      GestureDetector(
                        onTap: _fetchServers,
                        child: const Icon(Icons.refresh_rounded, color: Color(0xFF484850), size: 24),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: servers.isEmpty
                      ? const Center(child: Text("No servers available", style: TextStyle(color: Color(0xFF484850), fontSize: 13)))
                      : ListView.builder(
                          itemCount: servers.length,
                          itemBuilder: (ctx, idx) {
                            final s = servers[idx];
                            final isSel = selectedIndex == idx;
                            return GestureDetector(
                              onTap: () => setState(() => selectedIndex = idx),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isSel ? const Color(0xFFE50914) : Colors.transparent, width: 1.5),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(s.name, style: const TextStyle(color: Color(0xFFE50914), fontWeight: FontWeight.w600)),
                                    Text(s.ping != null ? "${s.ping} ms" : "-- ms", style: const TextStyle(color: Color(0xFF6C6C75))),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Кнопка подключения Connect
          GestureDetector(
            onTap: _toggleConnection,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1F24),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isConnected ? const Color(0xFFE50914) : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  isConnecting ? "Connecting${'.' * connectingDots}" : (isConnected ? "Connected" : "Connect"),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isConnected ? const Color(0xFFE50914) : Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Таймер подключения
          SizedBox(
            height: 24,
            child: isConnected
                ? Text(_formatDuration(connectedSeconds), style: const TextStyle(color: Color(0xFF8A8A93), fontSize: 14))
                : null,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

// ==================== 3. SETTINGS SCREEN ====================
class SettingsScreen extends StatefulWidget {
  final String userId;
  final String serverUrl;
  final ValueChanged<String> onUrlChanged;

  const SettingsScreen({super.key, required this.userId, required this.serverUrl, required this.onUrlChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool killSwitch = false;
  bool autoConnect = false;
  bool devMode = false;
  late TextEditingController _urlCtrl;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: widget.serverUrl);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          const Center(
            child: Text("Connection", style: TextStyle(color: Color(0xFFE50914), fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 16),
          _buildToggleOption("Kill Switch", killSwitch, (v) => setState(() => killSwitch = v)),
          const SizedBox(height: 10),
          _buildToggleOption("Auto Connect", autoConnect, (v) => setState(() => autoConnect = v)),
          const SizedBox(height: 10),
          _buildToggleOption("Developer Mode", devMode, (v) => setState(() => devMode = v)),
          if (devMode) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFF1E1F24), borderRadius: BorderRadius.circular(12)),
              child: TextField(
                controller: _urlCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  labelText: "API URL",
                  labelStyle: const TextStyle(color: Color(0xFFE50914)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check, color: Color(0xFFE50914)),
                    onPressed: () {
                      widget.onUrlChanged(_urlCtrl.text.trim());
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("URL Updated"), duration: Duration(seconds: 1)));
                    },
                  ),
                ),
              ),
            ),
          ],
          const Spacer(),
          // ID пользователя справа внизу над таббаром
          Align(
            alignment: Alignment.bottomRight,
            child: Text(widget.userId, style: const TextStyle(color: Color(0xFF5E5E66), fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildToggleOption(String title, bool val, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1F24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFFE50914), fontWeight: FontWeight.bold, fontSize: 14)),
          Switch(
            value: val,
            activeColor: const Color(0xFFE50914),
            activeTrackColor: const Color(0xFF5A1015),
            inactiveThumbColor: const Color(0xFF484850),
            inactiveTrackColor: const Color(0xFF161618),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ==================== 4. SUPPORT SCREEN ====================
class SupportScreen extends StatelessWidget {
  final VoidCallback onCopyId;

  const SupportScreen({super.key, required this.onCopyId});

  @override
  Widget build(BuildContext context) {
    const botTag = "@DarkFreeVPN_bot";
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1F24),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Support", style: TextStyle(color: Color(0xFFE50914), fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text("Telegram:", style: TextStyle(color: Color(0xFF6C6C75), fontSize: 14)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                Clipboard.setData(const ClipboardData(text: botTag));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF2B2B30),
                    content: const Text("Copied to clipboard", style: TextStyle(color: Colors.white)),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF272930),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  botTag,
                  style: TextStyle(color: Color(0xFFE50914), fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
