import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';

// حذف المتغيرات القديمة الخاصة بالدومين والسر فقط

// --- نموذج بيانات الموقع ---
class Website {
  final String domain;
  final String secret;
  Website({required this.domain, required this.secret});

  Map<String, dynamic> toJson() => {'domain': domain, 'secret': secret};
  factory Website.fromJson(Map<String, dynamic> json) => Website(
    domain: json['domain'],
    secret: json['secret'],
  );
}

// --- دوال مساعدة للتخزين ---
Future<List<Website>> loadWebsites() async {
  final prefs = await SharedPreferences.getInstance();
  final list = prefs.getStringList('websites') ?? [];
  return list.map((e) => Website.fromJson(jsonDecode(e))).toList();
}

Future<void> saveWebsites(List<Website> websites) async {
  final prefs = await SharedPreferences.getInstance();
  final list = websites.map((w) => jsonEncode(w.toJson())).toList();
  await prefs.setStringList('websites', list);
}

Future<void> addWebsite(Website website) async {
  final websites = await loadWebsites();
  websites.add(website);
  await saveWebsites(websites);
}

Future<void> deleteWebsite(int index) async {
  final websites = await loadWebsites();
  websites.removeAt(index);
  await saveWebsites(websites);
}

// متغير عام لتخزين توكن Firebase
String? fcmToken;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await _getAndPrintFCMToken();
  runApp(const MyApp());
}

Future<void> _getAndPrintFCMToken() async {
  try {
    NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission for notifications');
      fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        print('FCM Token: $fcmToken');
        print('Token length:  [1m${fcmToken!.length} [0m');
      } else {
        print('Failed to get FCM token');
      }
    } else {
      print('User declined or has not accepted permission for notifications');
    }
  } catch (e) {
    print('Error getting FCM token: $e');
  }
}

// --- تعديل MyApp ---
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> _hasAnyWebsite() async {
    final websites = await loadWebsites();
    return websites.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

// --- تعديل شاشة الإدخال لتدعم إعادة الاستخدام ---
class DomainEntryScreen extends StatefulWidget {
  final VoidCallback? onSuccess;
  const DomainEntryScreen({super.key, this.onSuccess});

  @override
  State<DomainEntryScreen> createState() => _DomainEntryScreenState();
}

class _DomainEntryScreenState extends State<DomainEntryScreen> {
  final TextEditingController _domainController = TextEditingController();
  final TextEditingController _secretController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  Future<bool> _verifyCredentials(String domain, String secret) async {
    try {
      print('Attempting to verify credentials for domain: $domain');
      // التحقق من وجود توكن Firebase
      if (fcmToken == null) {
        print('FCM token is null, cannot proceed with verification');
        return false;
      }
      final response = await http.post(
        Uri.parse('https://api.zoudne.com/api/verify-credentials.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'domain': domain,
          'secret': secret,
          'token': fcmToken,
        }),
      ).timeout(const Duration(seconds: 10));
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final success = data['success'] == true;
        print('Verification result: $success');
        if (success) {
          final tokenStored = data['token_stored'] ?? false;
          if (tokenStored) {
            print('Firebase token stored successfully in database');
          } else {
            print('Firebase token already exists in database');
          }
        }
        return success;
      } else {
        print('HTTP Error: ${response.statusCode} - ${response.reasonPhrase}');
        return false;
      }
    } catch (e) {
      print('API connection error: $e');
      return false;
    }
  }

  Future<void> _saveAndContinue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; });
    final domain = _domainController.text.trim();
    final secret = _secretController.text.trim();
    final isValid = await _verifyCredentials(domain, secret);
    if (!isValid) {
      setState(() { _saving = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الدومين أو الرمز السري\nيرجى التحقق من البيانات المدخلة'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }
    // إضافة الموقع الجديد
    await addWebsite(Website(domain: domain, secret: secret));
    setState(() { _saving = false; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم التحقق من البيانات بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
      if (widget.onSuccess != null) {
        widget.onSuccess!();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MyHomePage(title: 'Flutter Demo Home Page')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعداد التطبيق')), // "App Setup" in Arabic
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _domainController,
                  decoration: const InputDecoration(
                    labelText: 'الدومين',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال الدومين' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _secretController,
                  decoration: const InputDecoration(
                    labelText: 'الرمز السري',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال الرمز السري' : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveAndContinue,
                    child: _saving
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('متابعة'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- تعديل الصفحة الرئيسية لعرض المواقع ---
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Website> _websites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWebsites();
    // استقبال إشعارات FCM في foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // تشغيل صوت النظام
      SystemSound.play(SystemSoundType.alert);
      // عرض تنبيه بالنص
      _showNotificationDialog(message);
    });
  }

  void _showNotificationDialog(RemoteMessage message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تنبيه'),
        content: Text(message.notification?.body ?? 'وصل إشعار جديد'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadWebsites() async {
    final sites = await loadWebsites();
    setState(() {
      _websites = sites;
      _loading = false;
    });
  }

  void _addNewWebsite() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DomainEntryScreen(
          onSuccess: () {
            Navigator.of(context).pop();
            _loadWebsites();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Center(
          child: Image.asset(
            'assets/logo.png',
            height: 40,
            fit: BoxFit.contain,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'إضافة موقع',
            onPressed: _addNewWebsite,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _websites.isEmpty
              ? const Center(child: Text('ابدأ بإضافة مواقعك', style: TextStyle(fontSize: 20)))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'لتلقي تنبيه بالنقرات عليك إضافة الكود المخصص في الصفحة المراد تتبع نقراتها',
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _websites.length,
                        itemBuilder: (context, i) {
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.language),
                                    title: Text(_websites[i].domain),
                                    subtitle: const Text('تمت الإضافة'),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () async {
                                        await deleteWebsite(i);
                                        _loadWebsites();
                                      },
                                      tooltip: 'حذف الموقع',
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.copy),
                                        label: const Text('نسخ التعليمات البرمجية'),
                                        onPressed: () async {
                                          const String phpCode = '''<?php
\$domain = \$_SERVER['HTTP_HOST'];

\$response = file_get_contents('https://api.satayr.com/get-website-data.php', false, stream_context_create([
    'http' => [
        'method'  => 'POST',
        'header'  => "Content-Type: application/json\\r\\n",
        'content' => json_encode([
            'domain' => \$domain
        ])
    ]
]));

\$data = json_decode(\$response, true);

if (\$data['success']) {
    echo '<pre>';
    print_r(\$data['data']); // معلومات الموقع من قاعدة البيانات الخاصة بك
    echo '</pre>';
} else {
    echo 'حدث خطأ: ' . \$data['message'];
}
?>''';
                                          await Clipboard.setData(const ClipboardData(text: phpCode));
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('تم نسخ التعليمات البرمجية!'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: null, // لم نعد بحاجة للزر هنا
    );
  }
}
