import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'news_model.dart';
import 'news_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  if (Platform.isAndroid || Platform.isIOS) {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Android 13 이상: 알림 권한 요청
    await messaging.requestPermission(alert: true, badge: true, sound: true);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZDNet 뉴스 스크래핑',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'ZDNet 뉴스'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  List<News> newsList = [];
  bool isLoading = false;
  bool _fcmReady = false;
  String? _fcmToken;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadNews('');
    _setupFCM().then((_) async {
      final token = await FirebaseMessaging.instance.getToken();
      setState(() {
        _fcmReady = true;
        _fcmToken = token;
      });
    });
  }

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  Future<void> _setupFCM() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'push_channel_id', // ID used in show()
      'Push Channel',
      importance: Importance.max,
    );

    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission();
    print('알림 권한 상태 : ${settings.authorizationStatus}');

    // Initialize flutterLocalNotificationsPlugin
    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInitSettings =
        DarwinInitializationSettings();

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: iosInitSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(initSettings);

    String? token = await messaging.getToken();
    if (token != null) {
      print('토큰 있따 : $token');
    } else {
      print('토큰 업따');
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('포그라운드 메시지 수신!');
      if (message.notification != null) {
        print('알림 제목: ${message.notification!.title}');
        print('알림 내용: ${message.notification!.body}');
        // Create Android notification channel before showing notification

        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(channel);

        // Show local notification when app is in foreground
        flutterLocalNotificationsPlugin.show(
          0,
          message.notification!.title,
          message.notification!.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'push_channel_id',
              'Push Channel',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }
    });
  }

  Future<void> _loadNews(String keyword) async {
    setState(() => isLoading = true);
    try {
      final fetched = await fetchNews(keyword);
      setState(() => newsList = fetched);
    } catch (e) {
      print(e);
    }
    setState(() => isLoading = false);
  }

  void _launchURL(String url) async {
    final cleanUrl = url.startsWith('http') ? url : 'https://$url';

    if (Platform.isAndroid) {
      final intent = AndroidIntent(
        action: 'action_view',
        data: cleanUrl,
        package: 'com.android.chrome',
      );
      try {
        await intent.launch();
      } catch (e) {
        print('크롬 실행 실패: $e');
      }
    } else {
      final uri = Uri.parse(cleanUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        print('링크 열기 실패 (iOS): $uri');
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('링크 열기 실패'),
              content: Text('해당 링크를 열 수 없습니다:\n$uri'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  Future<void> sendPushToServer(String token) async {
    final String baseUrl;

    if (kIsWeb) {
      baseUrl = 'http://localhost:8080'; // 웹 실행 시
    } else if (Platform.isAndroid) {
      baseUrl = 'http://10.0.2.2:8080'; // Android 에뮬레이터
    } else {
      baseUrl = 'http://127.0.0.1:8080'; // iOS, macOS, 기타
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/news/send-push'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'title': 'ZDNet 알림',
        'body': '3초 뒤 푸쉬!!',
      }),
    );

    if (response.statusCode == 200) {
      print(' 서버 푸시 요청 성공');
    } else {
      print(' 서버 푸시 요청 실패: ${response.body}');
    }
  }

  Future<void> sendPushDelayedToServer(String token) async {
    final String baseUrl = kIsWeb
        ? 'http://localhost:8080'
        : Platform.isAndroid
        ? 'http://10.0.2.2:8080'
        : 'http://127.0.0.1:8080';

    final response = await http.post(
      Uri.parse('$baseUrl/api/news/send-push-delayed'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token, 'title': '돌아오세요', 'body': '다시 접속해주세요'}),
    );

    if (response.statusCode == 200) {
      print('돌아와 푸시 예약');
    } else {
      print('돌아와 푸시 예약 실패');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              height: 40,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: '검색어 입력',
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        filled: true,
                        fillColor: Colors.white24,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 12,
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      cursorColor: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      _loadNews(_searchController.text);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: newsList.length,
                    itemBuilder: (context, index) {
                      final news = newsList[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 6.0,
                        ),
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              news.title.isNotEmpty ? news.title : '제목 없음',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                news.link.isNotEmpty ? news.link : '링크 없음',
                                style: const TextStyle(color: Colors.blueGrey),
                              ),
                            ),
                            onTap: news.link.isNotEmpty
                                ? () => _launchURL(news.link)
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: null, // pagination unsupported
                      child: const Text('이전'),
                    ),
                    const Text('페이지 1'),
                    ElevatedButton(
                      onPressed: null, // pagination unsupported
                      child: const Text('다음'),
                    ),
                  ],
                ),
              ],
            ),
      floatingActionButton: (_fcmReady && _fcmToken != null)
          ? FloatingActionButton(
              onPressed: () async {
                if (_fcmToken != null && _fcmToken!.isNotEmpty) {
                  print('서버에 푸시 요청 중...');
                  await sendPushToServer(_fcmToken!);
                } else {
                  print('토큰 준비 안 됨');
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('토큰 없음'),
                        content: const Text('FCM 초기화 중입니다. 잠시 후 다시 시도해주세요.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('확인'),
                          ),
                        ],
                      ),
                    );
                  }
                }
              },
              child: const Icon(Icons.notifications),
            )
          : null,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      // 앱이 백그라운드로 전환될 때 푸시 예약 요청
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        print(' 앱 백그라운드 전환됨 - 푸시 예약 요청');
        await sendPushDelayedToServer(token);
      } else {
        print(' 토큰이 없어 푸시 예약 요청 불가');
      }
    }
  }
}
