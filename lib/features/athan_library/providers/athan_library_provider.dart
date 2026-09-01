import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/datasources/athan_remote_datasource.dart';
import '../data/models/athan_model.dart';

/// حالات تحميل الملف
enum DownloadStatus { idle, downloading, done, error }

/// Provider لإدارة مكتبة الأذان (جلب البيانات، التشغيل، التحميل، الحفظ)
class AthanLibraryProvider with ChangeNotifier {
  // ─── مفاتيح SharedPreferences ──────────────────────────────────────────────
  static const String _keyDefaultAthan = 'athan_library_default_path';
  static const String _keyDefaultFajr = 'athan_library_default_fajr_path';
  static const String _keyDefaultAthanId = 'athan_library_default_id';
  static const String _keyDefaultFajrId = 'athan_library_default_fajr_id';
  static const String _keyDefaultAthanName = 'athan_library_default_name';
  static const String _keyDefaultFajrName = 'athan_library_default_fajr_name';

  // ─── بادئة اسم الملف المحمَّل (ثابتة وفريدة لكل أذان) ────────────────────
  static const String _filePrefix = 'downloaded_athan_';

  // ─── Data source ──────────────────────────────────────────────────────────
  final AthanRemoteDataSource _remoteDataSource;

  AthanLibraryProvider({AthanRemoteDataSource? remoteDataSource})
      : _remoteDataSource =
            remoteDataSource ?? AthanRemoteDataSourceImpl() {
    _init();
  }

  // ─── State ────────────────────────────────────────────────────────────────
  List<AthanModel> _allAthans = [];
  bool _isLoading = false;
  String? _errorMessage;

  /// الأذان الذي يُعاد تشغيله حاليًا (null = لا يوجد)
  String? _playingId;

  /// حالة تحميل كل أذان (key = id)
  final Map<String, DownloadStatus> _downloadStatus = {};

  /// نسبة التحميل (0.0 → 1.0) لكل أذان
  final Map<String, double> _downloadProgress = {};

  /// الأذانات المحفوظة محلياً (key = id, value = مسار الملف على القرص)
  final Map<String, String> _localPaths = {};

  /// ID الأذان العادي المختار كافتراضي
  String? _defaultAthanId;

  /// ID أذان الفجر المختار كافتراضي
  String? _defaultFajrId;

  /// اسم الأذان العادي الافتراضي (للعرض في شاشة الإعدادات)
  String? _defaultAthanName;

  /// اسم أذان الفجر الافتراضي (للعرض في شاشة الإعدادات)
  String? _defaultFajrName;

  // ─── Getters ──────────────────────────────────────────────────────────────
  List<AthanModel> get normalAthans =>
      _allAthans.where((a) => !a.isFajr).toList();
  List<AthanModel> get fajrAthans =>
      _allAthans.where((a) => a.isFajr).toList();
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get playingId => _playingId;
  String? get defaultAthanId => _defaultAthanId;
  String? get defaultFajrId => _defaultFajrId;

  /// اسم الأذان العادي الافتراضي للعرض (null = لم يُختَر أذان من المكتبة)
  String? get defaultAthanName => _defaultAthanName;

  /// اسم أذان الفجر الافتراضي للعرض (null = لم يُختَر أذان من المكتبة)
  String? get defaultFajrName => _defaultFajrName;

  /// هل يوجد أذان عادي مُعيَّن من المكتبة السحابية؟
  bool get hasCloudAthan => _defaultAthanId != null && _defaultAthanName != null;

  /// هل يوجد أذان فجر مُعيَّن من المكتبة السحابية؟
  bool get hasCloudFajr => _defaultFajrId != null && _defaultFajrName != null;

  DownloadStatus downloadStatusOf(String id) =>
      _downloadStatus[id] ?? DownloadStatus.idle;
  double downloadProgressOf(String id) => _downloadProgress[id] ?? 0.0;

  /// هل الملف موجود على القرص؟ يتحقق من الذاكرة أولاً ثم القرص
  bool isDownloaded(String id) {
    // التحقق من الـ cache أولاً
    if (_downloadStatus[id] == DownloadStatus.done &&
        _localPaths.containsKey(id)) {
      return true;
    }
    // التحقق من القرص مباشرةً (يغطي حالة إعادة تشغيل التطبيق)
    final cachedPath = _localPaths[id];
    if (cachedPath != null) {
      return File(cachedPath).existsSync();
    }
    return false;
  }

  // ─── Init ─────────────────────────────────────────────────────────────────
  Future<void> _init() async {
    await _loadSavedDefaults();
    await _scanLocalFiles(); // ✅ استعادة الملفات المحمّلة مسبقاً عند إعادة التشغيل
    await fetchAthans();
  }

  /// يفحص مجلد Documents ويستعيد أي ملفات سبق تحميلها بالبادئة الثابتة
  Future<void> _scanLocalFiles() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File) {
          final fileName = entity.path.split('/').last.split('\\').last;
          if (fileName.startsWith(_filePrefix) && fileName.endsWith('.mp3')) {
            // استخراج الـ id من اسم الملف: downloaded_athan_{id}.mp3
            final id = fileName
                .replaceFirst(_filePrefix, '')
                .replaceFirst('.mp3', '');
            if (id.isNotEmpty && await entity.exists()) {
              _localPaths[id] = entity.path;
              _downloadStatus[id] = DownloadStatus.done;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[AthanLibrary] _scanLocalFiles error: $e');
    }
  }

  Future<void> _loadSavedDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    _defaultAthanId = prefs.getString(_keyDefaultAthanId);
    _defaultFajrId = prefs.getString(_keyDefaultFajrId);
    _defaultAthanName = prefs.getString(_keyDefaultAthanName);
    _defaultFajrName = prefs.getString(_keyDefaultFajrName);
    notifyListeners();
  }

  /// يُعيد تحميل الإعدادات من SharedPreferences — يُستدعى بعد العودة من شاشة المكتبة
  Future<void> syncFromPrefs() async {
    await _loadSavedDefaults();
  }

  /// مسح الأذان الافتراضي من المكتبة السحابية والعودة للأذان المحلي.
  /// ملاحظة: لا يحذف الملف من القرص — يبقى "محمّل" ويمكن تعيينه مرة أخرى بدون إعادة تحميل.
  Future<void> clearDefault({required bool isFajr}) async {
    final prefs = await SharedPreferences.getInstance();
    if (isFajr) {
      _defaultFajrId = null;
      _defaultFajrName = null;
      await prefs.remove(_keyDefaultFajrId);
      await prefs.remove(_keyDefaultFajrName);
      await prefs.remove(_keyDefaultFajr);
    } else {
      _defaultAthanId = null;
      _defaultAthanName = null;
      await prefs.remove(_keyDefaultAthanId);
      await prefs.remove(_keyDefaultAthanName);
      await prefs.remove(_keyDefaultAthan);
    }
    notifyListeners();
  }

  // ─── Fetch ────────────────────────────────────────────────────────────────
  Future<void> fetchAthans() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allAthans = await _remoteDataSource.fetchAthans();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Preview playback ─────────────────────────────────────────────────────
  void setPlayingId(String? id) {
    _playingId = id;
    notifyListeners();
  }

  // ─── Download & Set ───────────────────────────────────────────────────────
  Future<String?> downloadAndSet(AthanModel athan) async {
    final dir = await getApplicationDocumentsDirectory();
    // ✅ اسم فريد ثابت لكل أذان بناءً على ID — لا يتغير بين الجلسات
    final fileName = '$_filePrefix${athan.id}.mp3';
    final filePath = '${dir.path}/$fileName';

    // ─── تحقق 1: هل الملف موجود في الذاكرة (نفس الجلسة)؟ ─────────────────
    if (_localPaths.containsKey(athan.id)) {
      debugPrint('[AthanLibrary] ✅ Cache hit for ${athan.id}, setting as default');
      await _saveAsDefault(athan, localPath: _localPaths[athan.id]!);
      return _localPaths[athan.id];
    }

    // ─── تحقق 2: هل الملف موجود على القرص (جلسة سابقة)؟ ──────────────────
    final file = File(filePath);
    if (await file.exists()) {
      debugPrint('[AthanLibrary] 💾 Disk hit for ${athan.id}, skipping download');
      _localPaths[athan.id] = filePath;
      _downloadStatus[athan.id] = DownloadStatus.done;
      _downloadProgress[athan.id] = 1.0;
      await _saveAsDefault(athan, localPath: filePath);
      notifyListeners();
      return filePath;
    }

    // ─── لا يوجد: تحميل من الإنترنت ────────────────────────────────────────
    debugPrint('[AthanLibrary] ⬇️ Downloading ${athan.name} (${athan.id})...');
    _downloadStatus[athan.id] = DownloadStatus.downloading;
    _downloadProgress[athan.id] = 0.0;
    notifyListeners();

    try {
      final request = http.Request('GET', Uri.parse(athan.url));
      final response = await http.Client().send(request);

      final contentLength = response.contentLength ?? 0;
      int received = 0;
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          _downloadProgress[athan.id] = received / contentLength;
          notifyListeners();
        }
      }
      await sink.close();

      _localPaths[athan.id] = filePath;
      _downloadStatus[athan.id] = DownloadStatus.done;
      _downloadProgress[athan.id] = 1.0;
      await _saveAsDefault(athan, localPath: filePath);
      debugPrint('[AthanLibrary] ✅ Downloaded: $filePath');
      notifyListeners();
      return filePath;
    } catch (e) {
      _downloadStatus[athan.id] = DownloadStatus.error;
      notifyListeners();
      debugPrint('[AthanLibrary] ❌ Download error: $e');
      return null;
    }
  }

  Future<void> _saveAsDefault(AthanModel athan, {String? localPath}) async {
    final prefs = await SharedPreferences.getInstance();
    final path = localPath ?? _localPaths[athan.id] ?? '';

    if (athan.isFajr) {
      _defaultFajrId = athan.id;
      _defaultFajrName = athan.name;
      await prefs.setString(_keyDefaultFajrId, athan.id);
      await prefs.setString(_keyDefaultFajrName, athan.name);
      if (path.isNotEmpty) await prefs.setString(_keyDefaultFajr, path);
    } else {
      _defaultAthanId = athan.id;
      _defaultAthanName = athan.name;
      await prefs.setString(_keyDefaultAthanId, athan.id);
      await prefs.setString(_keyDefaultAthanName, athan.name);
      if (path.isNotEmpty) await prefs.setString(_keyDefaultAthan, path);
    }
    notifyListeners();
  }

  /// يُرجع المسار المحفوظ للأذان العادي الافتراضي
  static Future<String?> getDefaultAthanPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDefaultAthan);
  }

  /// يُرجع المسار المحفوظ لأذان الفجر الافتراضي
  static Future<String?> getDefaultFajrPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDefaultFajr);
  }
}
