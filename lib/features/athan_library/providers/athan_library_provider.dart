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
  // ─── مفاتيح SharedPreferences للصلوات ──────────────────────────────────────
  static String _keyIdFor(String prayerKey) => 'athan_library_id_$prayerKey';
  static String _keyNameFor(String prayerKey) => 'athan_library_name_$prayerKey';
  // Note: we save the absolute path directly to the key that Native Android uses.
  static String _keyPathFor(String prayerKey) => 'athan_path_$prayerKey';

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

  /// المعرفات المحفوظة لكل صلاة (key: prayerKey, value: id)
  final Map<String, String> _assignedIds = {};

  /// الأسماء المحفوظة لكل صلاة (key: prayerKey, value: name)
  final Map<String, String> _assignedNames = {};

  // ─── Getters ──────────────────────────────────────────────────────────────
  List<AthanModel> get normalAthans =>
      _allAthans.where((a) => !a.isFajr).toList();
  List<AthanModel> get fajrAthans =>
      _allAthans.where((a) => a.isFajr).toList();
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get playingId => _playingId;

  /// إرجاع اسم الأذان السحابي المعين لصلاة معينة، أو null إذا لم يكن هناك واحد.
  String? getAssignedNameFor(String prayerKey) => _assignedNames[prayerKey];

  /// إرجاع ID الأذان السحابي المعين لصلاة معينة، أو null إذا لم يكن هناك واحد.
  String? getAssignedIdFor(String prayerKey) => _assignedIds[prayerKey];

  /// هل الصلاة المعينة لها أذان سحابي؟
  bool hasCloudAthanFor(String prayerKey) => _assignedIds.containsKey(prayerKey) && _assignedNames.containsKey(prayerKey);

  /// هل هذا الأذان معين لأي صلاة؟
  bool isAssigned(String id) => _assignedIds.containsValue(id);

  /// إرجاع قائمة بالصلوات التي تم تعيين هذا الأذان لها
  List<String> getPrayersAssignedTo(String id) {
    return _assignedIds.entries
        .where((entry) => entry.value == id)
        .map((entry) => entry.key)
        .toList();
  }

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
    final prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
    for (var p in prayers) {
      final id = prefs.getString(_keyIdFor(p));
      final name = prefs.getString(_keyNameFor(p));
      if (id != null) _assignedIds[p] = id;
      if (name != null) _assignedNames[p] = name;
    }
    notifyListeners();
  }

  /// يُعيد تحميل الإعدادات من SharedPreferences — يُستدعى بعد العودة من شاشة المكتبة
  Future<void> syncFromPrefs() async {
    await _loadSavedDefaults();
  }

  /// مسح الأذان الافتراضي من المكتبة السحابية والعودة للأذان المحلي.
  /// ملاحظة: لا يحذف الملف من القرص — يبقى "محمّل" ويمكن تعيينه مرة أخرى بدون إعادة تحميل.
  /// مسح الأذان السحابي لصلاة معينة (أو لكل الصلوات إذا كان prayerKey == 'all').
  Future<void> clearDefault({required String prayerKey}) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (prayerKey == 'all') {
      final normalPrayers = ['dhuhr', 'asr', 'maghrib', 'isha'];
      for (var p in normalPrayers) {
        _assignedIds.remove(p);
        _assignedNames.remove(p);
        await prefs.remove(_keyIdFor(p));
        await prefs.remove(_keyNameFor(p));
        // نُعيد المسار الافتراضي لأذان مكة حتى لا يتعطل الناتيف
        await prefs.setString(_keyPathFor(p), "assets/audio/athan_makkah.mp3");
      }
    } else {
      _assignedIds.remove(prayerKey);
      _assignedNames.remove(prayerKey);
      await prefs.remove(_keyIdFor(prayerKey));
      await prefs.remove(_keyNameFor(prayerKey));
      final fallbackPath = prayerKey == 'fajr' ? "assets/audio/fajr_makkah.mp3" : "assets/audio/athan_makkah.mp3";
      await prefs.setString(_keyPathFor(prayerKey), fallbackPath);
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
  Future<String?> downloadAndSet(AthanModel athan, {required String prayerKey}) async {
    final dir = await getApplicationDocumentsDirectory();
    // ✅ اسم فريد ثابت لكل أذان بناءً على ID — لا يتغير بين الجلسات
    final fileName = '$_filePrefix${athan.id}.mp3';
    final filePath = '${dir.path}/$fileName';

    // ─── تحقق 1: هل الملف موجود في الذاكرة (نفس الجلسة)؟ ─────────────────
    if (_localPaths.containsKey(athan.id)) {
      debugPrint('[AthanLibrary] ✅ Cache hit for ${athan.id}, setting as default for $prayerKey');
      await _saveAsDefault(athan, prayerKey: prayerKey, localPath: _localPaths[athan.id]!);
      return _localPaths[athan.id];
    }

    // ─── تحقق 2: هل الملف موجود على القرص (جلسة سابقة)؟ ──────────────────
    final file = File(filePath);
    if (await file.exists()) {
      debugPrint('[AthanLibrary] 💾 Disk hit for ${athan.id}, skipping download');
      _localPaths[athan.id] = filePath;
      _downloadStatus[athan.id] = DownloadStatus.done;
      _downloadProgress[athan.id] = 1.0;
      await _saveAsDefault(athan, prayerKey: prayerKey, localPath: filePath);
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
      await _saveAsDefault(athan, prayerKey: prayerKey, localPath: filePath);
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

  Future<void> _saveAsDefault(AthanModel athan, {required String prayerKey, String? localPath}) async {
    final prefs = await SharedPreferences.getInstance();
    final path = localPath ?? _localPaths[athan.id] ?? '';

    if (prayerKey == 'all') {
      final normalPrayers = ['dhuhr', 'asr', 'maghrib', 'isha'];
      for (var p in normalPrayers) {
        _assignedIds[p] = athan.id;
        _assignedNames[p] = athan.name;
        await prefs.setString(_keyIdFor(p), athan.id);
        await prefs.setString(_keyNameFor(p), athan.name);
        if (path.isNotEmpty) await prefs.setString(_keyPathFor(p), path);
      }
    } else {
      _assignedIds[prayerKey] = athan.id;
      _assignedNames[prayerKey] = athan.name;
      await prefs.setString(_keyIdFor(prayerKey), athan.id);
      await prefs.setString(_keyNameFor(prayerKey), athan.name);
      if (path.isNotEmpty) await prefs.setString(_keyPathFor(prayerKey), path);
    }
    
    notifyListeners();
  }

  // 🛡️ ملاحظة: الدالة getDefaultAthanPath لم تعد مستخدمة عالمياً بنفس الطريقة،
  // لأن مسار الأذان يتم حفظه الآن مباشرة في مفتاح "athan_path_$prayerKey" الذي يعتمد عليه
  // التطبيق ونظام الأندرويد الأصلي (Native). تم التخلص من الدالة لعدم الحاجة إليها.
}
