import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SodfaSettings extends ChangeNotifier {
  static final SodfaSettings instance = SodfaSettings._();
  SodfaSettings._();

  Locale locale = const Locale('ar');
  Color seedColor = const Color(0xFF7667F5);
  Brightness brightness = Brightness.dark;
  bool ready = false;

  static const languages = <String, String>{
    'ar': 'العربية',
    'en': 'English',
    'ku': 'کوردی',
    'tr': 'Türkçe',
    'fa': 'فارسی',
    'ur': 'اردو',
    'hi': 'हिन्दी',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
    'pt': 'Português',
    'id': 'Bahasa Indonesia',
    'ja': '日本語',
    'ko': '한국어',
    'zh': '简体中文',
    'ru': 'Русский',
    'it': 'Italiano',
  };

  static const colors = <String, Color>{
    'Violet': Color(0xFF7667F5),
    'Blue': Color(0xFF3B82F6),
    'Cyan': Color(0xFF06B6D4),
    'Green': Color(0xFF10B981),
    'Orange': Color(0xFFF97316),
    'Pink': Color(0xFFEC4899),
    'Red': Color(0xFFEF4444),
    'Gold': Color(0xFFEAB308),
    'Indigo': Color(0xFF6366F1),
    'Teal': Color(0xFF14B8A6),
  };

  Future<void> load() async {
    if (ready) return;
    try {
      final p = await SharedPreferences.getInstance();
      locale = Locale(p.getString('locale') ?? 'ar');
      seedColor = Color(p.getInt('seedColor') ?? 0xFF7667F5);
      brightness = (p.getBool('lightMode') ?? false) ? Brightness.light : Brightness.dark;
    } catch (_) {
      // Keep safe defaults in widget tests or if local storage is unavailable.
    } finally {
      ready = true;
      notifyListeners();
    }
  }

  Future<void> setLanguage(String code) async {
    locale = Locale(code);
    final p = await SharedPreferences.getInstance();
    await p.setString('locale', code);
    notifyListeners();
  }

  Future<void> setColor(Color color) async {
    seedColor = color;
    final p = await SharedPreferences.getInstance();
    await p.setInt('seedColor', color.toARGB32());
    notifyListeners();
  }

  Future<void> setBrightness(Brightness value) async {
    brightness = value;
    final p = await SharedPreferences.getInstance();
    await p.setBool('lightMode', value == Brightness.light);
    notifyListeners();
  }
}

class SodfaStrings {
  static const _data = <String, Map<String, String>>{
    'ar': {'home':'الرئيسية','chats':'الدردشة','video':'الفيديو','notifications':'الإشعارات','profile':'حسابي','settings':'الإعدادات','language':'اللغة','theme':'المظهر','colors':'لون التطبيق','dark':'داكن','light':'فاتح','update':'تحديث التطبيق','check':'تحقق من التحديثات','about':'حول صدفة','current':'الإصدار الحالي','conversations':'المحادثات','stories':'القصص','all':'عرض الكل','posts':'آخر المنشورات'},
    'en': {'home':'Home','chats':'Chats','video':'Videos','notifications':'Notifications','profile':'Profile','settings':'Settings','language':'Language','theme':'Theme','colors':'App color','dark':'Dark','light':'Light','update':'App update','check':'Check for updates','about':'About SODFA','current':'Current version','conversations':'Conversations','stories':'Stories','all':'See all','posts':'Latest posts'},
    'ku': {'home':'سەرەکی','chats':'گفتوگۆ','video':'ڤیدیۆ','notifications':'ئاگادارکردنەوەکان','profile':'هەژمار','settings':'ڕێکخستنەکان','language':'زمان','theme':'ڕووکار','colors':'ڕەنگی ئەپ','dark':'تاریک','light':'ڕووناک','update':'نوێکردنەوەی ئەپ','check':'پشکنینی نوێکردنەوە','about':'دەربارەی سەدفە','current':'وەشانی ئێستا','conversations':'گفتوگۆکان','stories':'چیرۆکەکان','all':'هەمووی ببینە','posts':'نوێترین بڵاوکراوەکان'},
    'tr': {'home':'Ana Sayfa','chats':'Sohbetler','video':'Videolar','notifications':'Bildirimler','profile':'Profil','settings':'Ayarlar','language':'Dil','theme':'Tema','colors':'Uygulama rengi','dark':'Koyu','light':'Açık','update':'Uygulama güncellemesi','check':'Güncellemeleri kontrol et','about':'SODFA hakkında','current':'Mevcut sürüm','conversations':'Sohbetler','stories':'Hikâyeler','all':'Tümünü gör','posts':'Son gönderiler'},
    'fa': {'home':'خانه','chats':'گفتگو','video':'ویدیوها','notifications':'اعلان‌ها','profile':'حساب من','settings':'تنظیمات','language':'زبان','theme':'ظاهر','colors':'رنگ برنامه','dark':'تیره','light':'روشن','update':'به‌روزرسانی برنامه','check':'بررسی به‌روزرسانی','about':'درباره صدفة','current':'نسخه فعلی','conversations':'گفتگوها','stories':'داستان‌ها','all':'مشاهده همه','posts':'آخرین پست‌ها'},
    'ur': {'home':'ہوم','chats':'چیٹس','video':'ویڈیوز','notifications':'اطلاعات','profile':'پروفائل','settings':'ترتیبات','language':'زبان','theme':'تھیم','colors':'ایپ کا رنگ','dark':'ڈارک','light':'لائٹ','update':'ایپ اپ ڈیٹ','check':'اپ ڈیٹس چیک کریں','about':'صدفة کے بارے میں','current':'موجودہ ورژن','conversations':'گفتگو','stories':'کہانیاں','all':'سب دیکھیں','posts':'تازہ پوسٹس'},
    'es': {'home':'Inicio','chats':'Chats','video':'Vídeos','notifications':'Notificaciones','profile':'Perfil','settings':'Ajustes','language':'Idioma','theme':'Tema','colors':'Color de la app','dark':'Oscuro','light':'Claro','update':'Actualización','check':'Buscar actualizaciones','about':'Acerca de SODFA','current':'Versión actual','conversations':'Conversaciones','stories':'Historias','all':'Ver todo','posts':'Últimas publicaciones'},
    'fr': {'home':'Accueil','chats':'Discussions','video':'Vidéos','notifications':'Notifications','profile':'Profil','settings':'Paramètres','language':'Langue','theme':'Thème','colors':'Couleur de l’application','dark':'Sombre','light':'Clair','update':'Mise à jour','check':'Vérifier les mises à jour','about':'À propos de SODFA','current':'Version actuelle','conversations':'Conversations','stories':'Stories','all':'Tout voir','posts':'Dernières publications'},
    'de': {'home':'Startseite','chats':'Chats','video':'Videos','notifications':'Benachrichtigungen','profile':'Profil','settings':'Einstellungen','language':'Sprache','theme':'Design','colors':'App-Farbe','dark':'Dunkel','light':'Hell','update':'App-Update','check':'Nach Updates suchen','about':'Über SODFA','current':'Aktuelle Version','conversations':'Unterhaltungen','stories':'Stories','all':'Alle anzeigen','posts':'Neueste Beiträge'},
    'pt': {'home':'Início','chats':'Conversas','video':'Vídeos','notifications':'Notificações','profile':'Perfil','settings':'Configurações','language':'Idioma','theme':'Tema','colors':'Cor do app','dark':'Escuro','light':'Claro','update':'Atualização do app','check':'Verificar atualizações','about':'Sobre o SODFA','current':'Versão atual','conversations':'Conversas','stories':'Stories','all':'Ver tudo','posts':'Publicações recentes'},
    'id': {'home':'Beranda','chats':'Obrolan','video':'Video','notifications':'Notifikasi','profile':'Profil','settings':'Pengaturan','language':'Bahasa','theme':'Tema','colors':'Warna aplikasi','dark':'Gelap','light':'Terang','update':'Pembaruan aplikasi','check':'Periksa pembaruan','about':'Tentang SODFA','current':'Versi saat ini','conversations':'Percakapan','stories':'Cerita','all':'Lihat semua','posts':'Postingan terbaru'},
    'ja': {'home':'ホーム','chats':'チャット','video':'動画','notifications':'通知','profile':'プロフィール','settings':'設定','language':'言語','theme':'テーマ','colors':'アプリの色','dark':'ダーク','light':'ライト','update':'アプリ更新','check':'更新を確認','about':'SODFAについて','current':'現在のバージョン','conversations':'チャット','stories':'ストーリー','all':'すべて見る','posts':'最新の投稿'},
    'ko': {'home':'홈','chats':'채팅','video':'동영상','notifications':'알림','profile':'프로필','settings':'설정','language':'언어','theme':'테마','colors':'앱 색상','dark':'다크','light':'라이트','update':'앱 업데이트','check':'업데이트 확인','about':'SODFA 정보','current':'현재 버전','conversations':'대화','stories':'스토리','all':'모두 보기','posts':'최신 게시물'},
    'zh': {'home':'首页','chats':'聊天','video':'视频','notifications':'通知','profile':'我的','settings':'设置','language':'语言','theme':'主题','colors':'应用颜色','dark':'深色','light':'浅色','update':'应用更新','check':'检查更新','about':'关于 SODFA','current':'当前版本','conversations':'聊天','stories':'故事','all':'查看全部','posts':'最新动态'},
    'ru': {'home':'Главная','chats':'Чаты','video':'Видео','notifications':'Уведомления','profile':'Профиль','settings':'Настройки','language':'Язык','theme':'Тема','colors':'Цвет приложения','dark':'Тёмная','light':'Светлая','update':'Обновление','check':'Проверить обновления','about':'О SODFA','current':'Текущая версия','conversations':'Чаты','stories':'Истории','all':'Показать все','posts':'Последние публикации'},
    'it': {'home':'Home','chats':'Chat','video':'Video','notifications':'Notifiche','profile':'Profilo','settings':'Impostazioni','language':'Lingua','theme':'Tema','colors':'Colore app','dark':'Scuro','light':'Chiaro','update':'Aggiornamento app','check':'Controlla aggiornamenti','about':'Informazioni su SODFA','current':'Versione attuale','conversations':'Conversazioni','stories':'Storie','all':'Vedi tutto','posts':'Ultimi post'},
  };
  static String get(String key, String locale) => _data[locale]?[key] ?? _data['en']![key] ?? key;
}
