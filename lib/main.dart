// Flutter 3.50 currently reports the Material library import as deprecated.
// Keep the stable Material widgets until the replacement API is production-ready.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'services/sodfa_update_dialog.dart';
import 'services/sodfa_update_service.dart';
import 'services/sodfa_settings.dart';
import 'services/sodfa_changelog_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SodfaApp());
}

const ink = Color(0xFF101426);
const panel = Color(0xFF1B2239);
const violet = Color(0xFF7667F5);
const muted = Color(0xFF9CA4BD);

class SodfaApp extends StatefulWidget {
  const SodfaApp({super.key});

  @override
  State<SodfaApp> createState() => _SodfaAppState();
}

class _SodfaAppState extends State<SodfaApp> {
  @override
  void initState() {
    super.initState();
    SodfaSettings.instance.load();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: SodfaSettings.instance,
        builder: (context, _) {
          final settings = SodfaSettings.instance;
          final isLight = settings.brightness == Brightness.light;
          final scheme = ColorScheme.fromSeed(
            seedColor: settings.seedColor,
            brightness: settings.brightness,
          );
          final rtl = const {'ar', 'ku', 'fa', 'ur'}.contains(settings.locale.languageCode);
          return MaterialApp(
            title: 'صدفة',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              brightness: settings.brightness,
              scaffoldBackgroundColor: isLight ? const Color(0xFFF6F7FB) : ink,
              colorScheme: scheme.copyWith(surface: isLight ? Colors.white : panel),
              appBarTheme: AppBarTheme(
                backgroundColor: isLight ? const Color(0xFFF6F7FB) : ink,
                foregroundColor: isLight ? const Color(0xFF151827) : Colors.white,
                elevation: 0,
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: isLight ? Colors.white : panel,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            locale: settings.locale,
            home: Directionality(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: const SodfaShell(),
            ),
          );
        },
      );
}

class SodfaShell extends StatefulWidget {
  const SodfaShell({super.key});

  @override
  State<SodfaShell> createState() => _SodfaShellState();
}

class _SodfaShellState extends State<SodfaShell> with WidgetsBindingObserver {
  bool _checkingUpdate = false;
  bool _updateDialogVisible = false;
  DateTime? _lastUpdateCheck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdates(force: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkForUpdates();
  }

  Future<void> _checkForUpdates({bool force = false}) async {
    if (!mounted || _checkingUpdate || _updateDialogVisible) return;
    final now = DateTime.now();
    if (!force && _lastUpdateCheck != null &&
        now.difference(_lastUpdateCheck!) < const Duration(hours: 6)) {
      return;
    }
    _checkingUpdate = true;
    _lastUpdateCheck = now;
    try {
      final release = await SodfaUpdateService.check();
      if (!mounted || release == null) return;
      _updateDialogVisible = true;
      await showSodfaUpdateDialog(context, release);
    } catch (_) {
      // Retry on the next resume when the network or release service is unavailable.
      _lastUpdateCheck = null;
    } finally {
      _updateDialogVisible = false;
      _checkingUpdate = false;
    }
  }
  int index = 0;
  final pages = const [
    FeedPage(),
    ChatsPage(),
    ReelsPage(),
    NotificationsPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final language = SodfaSettings.instance.locale.languageCode;
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF171D31),
        indicatorColor: const Color(0xFF393568),
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: SodfaStrings.get('home', language),
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: const Icon(Icons.chat_bubble_rounded),
            label: SodfaStrings.get('chats', language),
          ),
          NavigationDestination(
            icon: const Icon(Icons.play_circle_outline_rounded),
            selectedIcon: const Icon(Icons.play_circle_fill_rounded),
            label: SodfaStrings.get('video', language),
          ),
          NavigationDestination(
            icon: const Icon(Icons.notifications_none_rounded),
            selectedIcon: const Icon(Icons.notifications_rounded),
            label: SodfaStrings.get('notifications', language),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: SodfaStrings.get('profile', language),
          ),
        ],
      ),
    );
  }
}

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final liked = <int>{};

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.forum_rounded, color: Color(0xFF9185FF), size: 27),
              SizedBox(width: 9),
              Text('صدفة', style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'بحث',
              onPressed: () {},
              icon: const Icon(Icons.search_rounded),
            ),
            IconButton(
              tooltip: 'إنشاء منشور',
              onPressed: () => _showCompose(context),
              icon: const Icon(Icons.add_box_outlined),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 20),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6257D9), Color(0xFF393A82)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('كل تواصلك بمكان واحد',
                              style: TextStyle(
                                  fontSize: 19, fontWeight: FontWeight.bold)),
                          SizedBox(height: 5),
                          Text('شارك لحظاتك وتواصل بأمان',
                              style: TextStyle(
                                  color: Color(0xFFE0DEFF), fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.shield_rounded,
                        size: 35, color: Color(0xFFE5E2FF)),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('القصص',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  Text('عرض الكل', style: TextStyle(color: violet)),
                ],
              ),
            ),
            SizedBox(
              height: 112,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                children: const [
                  StoryTile(name: 'قصتك', color: violet, add: true),
                  StoryTile(name: 'أحمد', color: Color(0xFF4D8FE8)),
                  StoryTile(name: 'محمد', color: Color(0xFF8B68D8)),
                  StoryTile(name: 'سارة', color: Color(0xFFD17A9B)),
                  StoryTile(name: 'مصطفى', color: Color(0xFF35A88A)),
                  StoryTile(name: 'حسين', color: Color(0xFFB28B50)),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 8, 18, 10),
              child: Text('آخر المنشورات',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
            PostCard(
              name: 'أحمد علي',
              handle: '@ahmed',
              time: 'قبل ١٥ دقيقة',
              text: 'أهلاً بأصدقائنا في صدفة ❤️ مساحة تجمعنا وتخلّي التواصل أسهل.',
              color: const Color(0xFF4D8FE8),
              liked: liked.contains(1),
              onLike: () => setState(() {
                liked.contains(1) ? liked.remove(1) : liked.add(1);
              }),
            ),
            PostCard(
              name: 'سارة محمد',
              handle: '@sara',
              time: 'قبل ساعة',
              text: 'شنو أكثر ميزة تتمنون تشوفوها بالتطبيق؟ شاركونا آراءكم 🌟',
              color: const Color(0xFFD17A9B),
              liked: liked.contains(2),
              onLike: () => setState(() {
                liked.contains(2) ? liked.remove(2) : liked.add(2);
              }),
            ),
          ],
        ),
      );

  void _showCompose(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: panel,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('منشور جديد',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(hintText: 'شنو ببالك؟'),
            ),
            const SizedBox(height: 12),
            const Text('النشر التجريبي محلي حالياً، وسيُربط بالخادم لاحقاً.',
                style: TextStyle(color: muted, fontSize: 11)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حفظ المسودة'),
            ),
          ],
        ),
      ),
    );
  }
}

class StoryTile extends StatelessWidget {
  const StoryTile(
      {super.key, required this.name, required this.color, this.add = false});
  final String name;
  final Color color;
  final bool add;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: CircleAvatar(
                radius: 27,
                backgroundColor: color.withValues(alpha: .2),
                child: Icon(add ? Icons.add : Icons.person_rounded,
                    color: color, size: 25),
              ),
            ),
            const SizedBox(height: 5),
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11)),
          ],
        ),
      );
}

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.name,
    required this.handle,
    required this.time,
    required this.text,
    required this.color,
    required this.liked,
    required this.onLike,
  });
  final String name, handle, time, text;
  final Color color;
  final bool liked;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) => Card(
        color: panel,
        margin: const EdgeInsets.fromLTRB(12, 5, 12, 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: .2),
                    child: Icon(Icons.person, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text('$handle • $time',
                            style: const TextStyle(color: muted, fontSize: 10)),
                      ],
                    ),
                  ),
                  const Icon(Icons.more_horiz, color: muted),
                ],
              ),
              const SizedBox(height: 13),
              Text(text, style: const TextStyle(height: 1.6)),
              const SizedBox(height: 12),
              Container(
                height: 118,
                decoration: BoxDecoration(
                  color: const Color(0xFF252D49),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Icon(Icons.image_outlined, size: 38, color: muted),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: onLike,
                    icon: Icon(
                      liked ? Icons.favorite : Icons.favorite_border,
                      color: liked ? Colors.pinkAccent : muted,
                    ),
                  ),
                  const Text('إعجاب', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 18),
                  const Icon(Icons.mode_comment_outlined, color: muted),
                  const SizedBox(width: 6),
                  const Text('تعليق', style: TextStyle(fontSize: 12)),
                  const Spacer(),
                  const Icon(Icons.share_outlined, color: muted),
                  const SizedBox(width: 6),
                  const Text('مشاركة', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      );
}

class ChatsPage extends StatelessWidget {
  const ChatsPage({super.key});
  static const people = [
    ('أحمد علي', 'وصلت للبيت؟', 'الآن', Color(0xFF4D8FE8)),
    ('مجموعة الأصدقاء', 'محمد: نشوفكم باچر', '٧:٤٢ م', Color(0xFF8B68D8)),
    ('مصطفى كريم', 'تسلم حبيبي 🌹', '٦:١٨ م', Color(0xFF35A88A)),
    ('سارة محمد', 'أرسلت صورة', '٥:٥٠ م', Color(0xFFD17A9B)),
    ('حسين', 'تمام، اتفقنا', 'أمس', Color(0xFFB28B50)),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('المحادثات',
              style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
            IconButton(onPressed: () {}, icon: const Icon(Icons.group_add)),
          ],
        ),
        body: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: people.length,
          separatorBuilder: (_, __) => const Divider(color: Color(0xFF282E45)),
          itemBuilder: (context, index) {
            final p = people[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: p.$4.withValues(alpha: .2),
                child: Icon(Icons.person, color: p.$4),
              ),
              title: Text(p.$1,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(p.$2,
                  style: const TextStyle(color: muted, fontSize: 12)),
              trailing: Text(p.$3,
                  style: const TextStyle(color: muted, fontSize: 10)),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ConversationPage(name: p.$1, color: p.$4),
                ),
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: violet,
          onPressed: () {},
          child: const Icon(Icons.edit_rounded),
        ),
      );
}

class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key, required this.name, required this.color});
  final String name;
  final Color color;

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final controller = TextEditingController();
  final messages = <String>[
    'هلا حبيبي، شلونك؟',
    'الحمد لله تمام، إنت شخبارك؟',
    'كلشي تمام، مشتاقين 🌹',
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void send() {
    final value = controller.text.trim();
    if (value.isEmpty) return;
    setState(() {
      messages.add(value);
      controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: widget.color.withValues(alpha: .2),
                child: Icon(Icons.person, color: widget.color),
              ),
              const SizedBox(width: 10),
              Text(widget.name, style: const TextStyle(fontSize: 15)),
            ],
          ),
          actions: const [
            Icon(Icons.call_outlined),
            SizedBox(width: 18),
            Icon(Icons.videocam_outlined),
            SizedBox(width: 12),
          ],
        ),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(10),
              child: Text('محادثة تجريبية محلية — غير متصلة بالخادم',
                  style: TextStyle(color: muted, fontSize: 11)),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) => Align(
                  alignment: index.isEven
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 290),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: index.isEven
                          ? const Color(0xFF5148A8)
                          : const Color(0xFF222A42),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(messages[index]),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.add_circle_outline, color: violet),
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: 4,
                        onSubmitted: (_) => send(),
                        decoration:
                            const InputDecoration(hintText: 'اكتب رسالتك...'),
                      ),
                    ),
                    const SizedBox(width: 7),
                    IconButton(
                      onPressed: send,
                      style: IconButton.styleFrom(
                          backgroundColor: violet, foregroundColor: Colors.white),
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class ReelsPage extends StatelessWidget {
  const ReelsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('الفيديوهات القصيرة')),
        body: PageView(
          scrollDirection: Axis.vertical,
          children: const [
            ReelPlaceholder(title: 'اكتشف مقاطع جديدة', creator: '@sodfa'),
            ReelPlaceholder(title: 'مساحتك لمشاركة اللحظات', creator: '@community'),
          ],
        ),
      );
}

class ReelPlaceholder extends StatelessWidget {
  const ReelPlaceholder({super.key, required this.title, required this.creator});
  final String title, creator;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF242B4A), Color(0xFF39336C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            const Center(
                child: Icon(Icons.play_circle_outline,
                    size: 76, color: Colors.white70)),
            Positioned(
              right: 20,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(creator, style: const TextStyle(color: muted)),
                ],
              ),
            ),
            const Positioned(
              left: 18,
              bottom: 28,
              child: Column(
                children: [
                  Icon(Icons.favorite_border, size: 28),
                  SizedBox(height: 20),
                  Icon(Icons.mode_comment_outlined, size: 27),
                  SizedBox(height: 20),
                  Icon(Icons.share_outlined, size: 27),
                ],
              ),
            ),
          ],
        ),
      );
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('الإشعارات')),
        body: ListView(
          children: const [
            NotificationTile(
                icon: Icons.favorite,
                color: Colors.pinkAccent,
                title: 'أحمد أعجب بمنشورك',
                subtitle: 'قبل ٥ دقائق'),
            NotificationTile(
                icon: Icons.person_add_alt_1,
                color: Colors.lightBlue,
                title: 'لديك متابع جديد',
                subtitle: 'قبل ٢٠ دقيقة'),
            NotificationTile(
                icon: Icons.mode_comment,
                color: Colors.amber,
                title: 'سارة علّقت على منشورك',
                subtitle: 'قبل ساعة'),
          ],
        ),
      );
}

class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final Color color;
  final String title, subtitle;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .15),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(color: muted)),
      );
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('الملف الشخصي'),
          actions: [
            IconButton(
              tooltip: 'الإعدادات',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              ),
              icon: const Icon(Icons.settings_outlined),
            )
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const SizedBox(height: 18),
            const CircleAvatar(
              radius: 48,
              backgroundColor: Color(0xFF393568),
              child: Icon(Icons.person, size: 52, color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text('مستخدم صدفة',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            const Center(
                child: Text('@sodfa_user',
                    style: TextStyle(color: muted))),
            const SizedBox(height: 20),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ProfileStat(value: '0', label: 'منشور'),
                ProfileStat(value: '0', label: 'متابع'),
                ProfileStat(value: '0', label: 'يتابع'),
              ],
            ),
            const SizedBox(height: 24),
            const Text('هذا ملف تجريبي. ستتم إضافة تعديل الملف وإعدادات الحساب بعد بناء خدمة التسجيل.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, height: 1.6)),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.edit_outlined),
              label: const Text('تعديل الملف الشخصي'),
            ),
          ],
        ),
      );
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _version = '...';
  bool _checking = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  String get _lang => SodfaSettings.instance.locale.languageCode;
  String tr(String key) => SodfaStrings.get(key, _lang);

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _version = info.version);
    } catch (_) {
      if (!mounted) return;
      setState(() => _version = 'Unknown');
    }
  }

  Future<void> _checkForUpdates() async {
    if (_checking) return;
    setState(() { _checking = true; _status = tr('check') + '...'; });
    try {
      final release = await SodfaUpdateService.check();
      if (!mounted) return;
      if (release == null) {
        setState(() => _status = '✓ ' + tr('current'));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('current'))));
      } else {
        setState(() => _status = 'New version: ${release.version}');
        await showSodfaUpdateDialog(context, release);
      }
    } catch (_) {
      if (mounted) setState(() => _status = 'Update check failed');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SodfaSettings.instance,
      builder: (context, _) {
        final settings = SodfaSettings.instance;
        return Scaffold(
          appBar: AppBar(title: Text(tr('settings'))),
          body: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: settings.seedColor.withValues(alpha: .18),
                    child: Icon(Icons.language_rounded, color: settings.seedColor),
                  ),
                  title: Text(tr('language')),
                  subtitle: Text(SodfaSettings.languages[settings.locale.languageCode] ?? settings.locale.languageCode),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _chooseLanguage,
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  leading: Icon(Icons.palette_outlined, color: settings.seedColor),
                  title: Text(tr('colors')),
                  subtitle: Text(tr('theme')),
                  trailing: CircleAvatar(radius: 11, backgroundColor: settings.seedColor),
                  onTap: _chooseColor,
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: SwitchListTile(
                  secondary: Icon(settings.brightness == Brightness.dark ? Icons.dark_mode : Icons.light_mode, color: settings.seedColor),
                  title: Text(tr('theme')),
                  subtitle: Text(settings.brightness == Brightness.dark ? tr('dark') : tr('light')),
                  value: settings.brightness == Brightness.light,
                  onChanged: (v) => settings.setBrightness(v ? Brightness.light : Brightness.dark),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: settings.seedColor,
                        child: const Icon(Icons.system_update_alt_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('update'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('${tr('current')}: $_version', style: const TextStyle(color: muted, fontSize: 12)),
                        ],
                      )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _checking ? null : _checkForUpdates,
                icon: _checking ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh_rounded),
                label: Text(_checking ? '...' : tr('check')),
                style: FilledButton.styleFrom(backgroundColor: settings.seedColor, minimumSize: const Size.fromHeight(52)),
              ),
              const SizedBox(height: 8),
              Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 12)),
              const SizedBox(height: 20),
              const Divider(),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: settings.seedColor.withValues(alpha: .16),
                    child: Icon(Icons.history_rounded, color: settings.seedColor),
                  ),
                  title: const Text('سجل التغييرات'),
                  subtitle: const Text('تفاصيل الإضافات والإصلاحات في كل إصدار'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SodfaChangelogPage(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: settings.seedColor.withValues(alpha: .16),
                    child: Icon(Icons.info_outline_rounded, color: settings.seedColor),
                  ),
                  title: Text(tr('about')),
                  subtitle: const Text('صدفة — تواصل يجمعنا في مكان واحد'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AboutSodfaPage(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _chooseLanguage() async {
    final current = SodfaSettings.instance.locale.languageCode;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: SodfaSettings.languages.entries.map((e) => RadioListTile<String>(
          value: e.key,
          groupValue: current,
          title: Text(e.value),
          secondary: Text(e.key.toUpperCase()),
          onChanged: (v) => Navigator.pop(context, v),
        )).toList(),
      ),
    );
    if (selected != null) await SodfaSettings.instance.setLanguage(selected);
  }

  Future<void> _chooseColor() async {
    final selected = await showModalBottomSheet<Color>(
      context: context,
      showDragHandle: true,
      builder: (context) => GridView.count(
        crossAxisCount: 5,
        shrinkWrap: true,
        padding: const EdgeInsets.all(24),
        children: SodfaSettings.colors.values.map((color) => IconButton(
          tooltip: color.toARGB32().toRadixString(16),
          onPressed: () => Navigator.pop(context, color),
          icon: CircleAvatar(backgroundColor: color, child: color == SodfaSettings.instance.seedColor ? const Icon(Icons.check, color: Colors.white) : null),
        )).toList(),
      ),
    );
    if (selected != null) await SodfaSettings.instance.setColor(selected);
  }
}


class AboutSodfaPage extends StatefulWidget {
  const AboutSodfaPage({super.key});

  @override
  State<AboutSodfaPage> createState() => _AboutSodfaPageState();
}

class _AboutSodfaPageState extends State<AboutSodfaPage> {
  String _version = '...';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = info.version);
    } catch (_) {
      if (mounted) setState(() => _version = 'غير متاح');
    }
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 22, 4, 10),
        child: Text(title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      );

  Widget _featureTile(IconData icon, String title, String subtitle,
          {bool planned = false}) =>
      Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: planned
                ? Colors.orange.withValues(alpha: .14)
                : Theme.of(context).colorScheme.primary.withValues(alpha: .14),
            child: Icon(icon,
                color: planned
                    ? Colors.orangeAccent
                    : Theme.of(context).colorScheme.primary),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle),
          trailing: planned
              ? const Text('قيد التطوير',
                  style: TextStyle(fontSize: 10, color: Colors.orangeAccent))
              : const Icon(Icons.check_circle_rounded,
                  color: Colors.green, size: 19),
          isThreeLine: subtitle.length > 48,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('حول صدفة')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [scheme.primary, scheme.tertiary],
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.forum_rounded,
                      color: Colors.white, size: 46),
                ),
                const SizedBox(height: 14),
                const Text('صدفة',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 29,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                const Text('تواصل يجمعنا',
                    style: TextStyle(color: Colors.white70, fontSize: 15)),
                const SizedBox(height: 13),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text('الإصدار ' + _version,
                      style: const TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          _sectionTitle('ما هي صدفة؟'),
          const Text(
            'صدفة مشروع منصة تواصل اجتماعي تطمح إلى جمع المحادثات الخاصة والجماعية، '
            'القصص، المنشورات، الفيديوهات القصيرة، الغرف الصوتية والمكالمات، '
            'واكتشاف أشخاص واهتمامات جديدة ضمن تجربة واحدة سهلة وآمنة.',
            style: TextStyle(height: 1.75),
          ),
          _sectionTitle('الموجود في هذه النسخة'),
          _featureTile(Icons.translate_rounded, 'واجهة متعددة اللغات',
              'تغيير لغة الواجهة مع دعم اتجاه الكتابة من اليمين إلى اليسار.'),
          _featureTile(Icons.palette_outlined, 'تخصيص المظهر',
              'اختيار الألوان والتبديل بين الوضع الداكن والفاتح مع حفظ الإعدادات.'),
          _featureTile(Icons.system_update_alt_rounded, 'تحديثات داخل التطبيق',
              'فحص التحديث عند تشغيل التطبيق والعودة إليه، مع تنزيل الملف والتحقق من سلامته قبل فتح مُثبّت Android.'),
          _featureTile(Icons.history_rounded, 'سجل تغييرات التحديثات',
              'عرض الإصدارات السابقة وتفاصيل الإضافات والإصلاحات لكل تحديث.'),
          _featureTile(Icons.dashboard_customize_outlined, 'واجهات اجتماعية أولية',
              'نماذج محلية للمنشورات والقصص والمحادثات والملف الشخصي؛ ليست متصلة بعد بخدمة مستخدمين حقيقية.'),
          _sectionTitle('المزايا التي نعمل على بنائها'),
          _featureTile(Icons.person_add_alt_1_rounded, 'الحسابات والملفات الشخصية',
              'تسجيل آمن، توثيق الحساب، تعديل الملف وإدارة الجلسات.',
              planned: true),
          _featureTile(Icons.forum_outlined, 'مراسلة مباشرة متقدمة',
              'رسائل فورية، مجموعات، قنوات، رسائل صوتية، مشاركة ملفات والبحث داخل المحادثات.',
              planned: true),
          _featureTile(Icons.call_rounded, 'المكالمات والغرف الصوتية',
              'مكالمات صوتية ومرئية، غرف عامة وخاصة ومشاركة أثناء المكالمة.',
              planned: true),
          _featureTile(Icons.video_library_outlined, 'القصص والفيديو والبث',
              'قصص مؤقتة، مقاطع قصيرة، بث مباشر وأدوات تفاعل وإدارة المحتوى.',
              planned: true),
          _featureTile(Icons.explore_outlined, 'الاكتشاف والأشخاص القريبون',
              'بحث واكتشاف حسب الاهتمامات، مع تحكم واضح بإظهار الموقع أو إخفائه.',
              planned: true),
          _featureTile(Icons.shuffle_rounded, 'دردشة عشوائية صوتية ومرئية',
              'اختيار صوت أو فيديو والاتصال بأشخاص متاحين حسب اللغة والاهتمامات، مع التالي والإنهاء والحظر والإبلاغ. الفيديو العشوائي للبالغين فقط وبعد التحقق من العمر وموافقة الكاميرا.',
              planned: true),
          _featureTile(Icons.shield_outlined, 'الخصوصية والحماية',
              'حظر وإبلاغ، مكافحة الإزعاج، تحكم بالخصوصية، وحماية للمحادثات بتقنيات موثوقة.',
              planned: true),
          _sectionTitle('تنبيه مهم'),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              'صدفة ما زالت في مرحلة البناء. بعض الأقسام الحالية تجريبية وتعمل ببيانات محلية، '
              'والمراسلة الحقيقية والمكالمات والحسابات والإشعارات السحابية تحتاج إلى ربط خوادمها '
              'وتجربتها أمنياً قبل إطلاقها. لا تستخدم هذه النسخة لإرسال معلومات أو محادثات خاصة.',
              style: TextStyle(height: 1.7),
            ),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text('صدفة — خطوة بخطوة نحو مساحة تواصل أفضل',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class SodfaChangelogPage extends StatefulWidget {
  const SodfaChangelogPage({super.key});

  @override
  State<SodfaChangelogPage> createState() => _SodfaChangelogPageState();
}

class _SodfaChangelogPageState extends State<SodfaChangelogPage> {
  late Future<List<SodfaChangelogEntry>> _entries;

  @override
  void initState() {
    super.initState();
    _entries = SodfaChangelogService.load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('سجل تغييرات صدفة')),
        body: FutureBuilder<List<SodfaChangelogEntry>>(
          future: _entries,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 40),
                      const SizedBox(height: 10),
                      const Text('تعذر تحميل سجل التغييرات.'),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => setState(
                          () => _entries = SodfaChangelogService.load(),
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final entries = snapshot.data ?? const <SodfaChangelogEntry>[];
            if (entries.isEmpty) {
              return const Center(child: Text('لا توجد تغييرات مسجلة حالياً.'));
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final color = Theme.of(context).colorScheme;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: color.primaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'الإصدار ${entry.version}',
                                style: TextStyle(
                                  color: color.onPrimaryContainer,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (entry.date.isNotEmpty)
                              Text(
                                entry.date,
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          entry.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...entry.changes.map(
                          (change) => Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 18,
                                  color: color.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    change,
                                    style: const TextStyle(height: 1.55),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
}

class ProfileStat extends StatelessWidget {
  const ProfileStat({super.key, required this.value, required this.label});
  final String value, label;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style:
                  const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: muted, fontSize: 12)),
        ],
      );
}
