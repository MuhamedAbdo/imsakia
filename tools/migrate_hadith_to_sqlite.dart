// ============================================================
// سكربت التحويل: JSON → SQLite
// التشغيل: dart run tools/migrate_hadith_to_sqlite.dart
// ============================================================
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:convert';
import 'package:sqlite3/sqlite3.dart';

/// خريطة: اسم الملف (بدون امتداد) → book_key المستخدم في DB
const Map<String, String> kBookFiles = {
  'bukhari'  : 'bukhari',
  'muslim'   : 'muslim',
  'abi_daud' : 'abi_daud',
  'ahmed'    : 'ahmed',
  'darimi'   : 'darimi',
  'ibn_maja' : 'ibn_maja',
  'malik'    : 'malik',
  'nasai'    : 'nasai',
  'trmizi'   : 'trmizi',
};

void main() async {
  final stopwatch = Stopwatch()..start();

  final dbPath = 'assets/hadith_database.db';
  final dbFile = File(dbPath);
  if (dbFile.existsSync()) {
    print('⚠️  ملف DB موجود مسبقاً — سيتم حذفه وإعادة الإنشاء');
    dbFile.deleteSync();
  }

  print('📦 إنشاء قاعدة البيانات: $dbPath');
  final db = sqlite3.open(dbPath);

  // ── إعدادات الأداء ─────────────────────────────────────────
  db.execute('PRAGMA journal_mode = WAL;');
  db.execute('PRAGMA synchronous  = NORMAL;');
  db.execute('PRAGMA page_size    = 4096;');
  db.execute('PRAGMA cache_size   = 10000;');

  // ── إنشاء الجدول ───────────────────────────────────────────
  // ملاحظة: حذفنا search_term لأنه لا يُعرض في الواجهة،
  // والبحث يعمل على hadith + description بشكل كافٍ.
  db.execute('''
    CREATE TABLE hadiths (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      book_key    TEXT    NOT NULL,
      number      INTEGER NOT NULL,
      hadith      TEXT    NOT NULL,
      description TEXT    NOT NULL DEFAULT ''
    );
  ''');

  // ── إدراج البيانات ──────────────────────────────────────────
  int totalInserted = 0;

  for (final entry in kBookFiles.entries) {
    final fileName = entry.key;
    final bookKey  = entry.value;
    final filePath = 'assets/data/$fileName.json';
    final file     = File(filePath);

    if (!file.existsSync()) {
      print('⛔  الملف غير موجود: $filePath — تخطّي');
      continue;
    }

    print('📖 تحميل $fileName.json ...');
    final jsonString = file.readAsStringSync();
    final List<dynamic> records = json.decode(jsonString) as List<dynamic>;
    print('   → ${records.length} سجل — جارٍ الإدراج ...');

    // نستخدم Transaction لتسريع الإدراج بشكل كبير
    final stmt = db.prepare('''
      INSERT INTO hadiths (book_key, number, hadith, description)
      VALUES (?, ?, ?, ?);
    ''');

    db.execute('BEGIN;');
    for (final raw in records) {
      final map = raw as Map<String, dynamic>;
      stmt.execute([
        bookKey,
        (map['number'] as num?)?.toInt() ?? 0,
        (map['hadith']      as String?) ?? '',
        (map['description'] as String?) ?? '',
      ]);
    }
    db.execute('COMMIT;');
    stmt.dispose();

    totalInserted += records.length;
    print('   ✅ تم إدراج ${records.length} حديث من $fileName');
  }

  // ── إنشاء الفهارس بعد الإدراج (أسرع) ──────────────────────
  print('\n🔍 إنشاء الفهارس ...');
  db.execute('CREATE INDEX idx_hadiths_book     ON hadiths (book_key);');
  db.execute('CREATE INDEX idx_hadiths_book_num ON hadiths (book_key, number);');
  db.execute('CREATE INDEX idx_hadiths_num      ON hadiths (number);');

  // ── VACUUM لضغط الـ DB وتقليل الحجم ────────────────────────
  print('🗜️  VACUUM لتقليل الحجم ...');
  db.execute('VACUUM;');

  db.dispose();

  // ── ضغط قاعدة البيانات إلى GZip لتقليل حجم التطبيق وتجاوز حدود GitHub ──
  print('\n📦 جارٍ ضغط قاعدة البيانات باستخدام GZip ...');
  final uncompressedBytes = dbFile.readAsBytesSync();
  final gzBytes = gzip.encode(uncompressedBytes);
  final gzPath = 'assets/hadith_database.db.gz';
  final gzFile = File(gzPath);
  gzFile.writeAsBytesSync(gzBytes, flush: true);

  // حذف الملف الأصلي غير المضغوط (198 MB) حتى لا يزيد حجم التطبيق ولا يفشل git push
  if (dbFile.existsSync()) {
    dbFile.deleteSync();
  }

  stopwatch.stop();
  final originalMB = (uncompressedBytes.length / 1024 / 1024).toStringAsFixed(2);
  final gzSizeMB   = (gzFile.lengthSync() / 1024 / 1024).toStringAsFixed(2);

  print('\n══════════════════════════════════════════');
  print('✅  اكتملت عملية التحويل والضغط بنجاح!');
  print('   إجمالي الأحاديث المُدرجة : $totalInserted');
  print('   الحجم الأصلي (SQLite)     : $originalMB MB');
  print('   الحجم المضغوط (GZip)      : $gzSizeMB MB (توفير ممتاز!)');
  print('   الوقت المستغرق            : ${stopwatch.elapsed}');
  print('   الموقع                    : $gzPath');
  print('══════════════════════════════════════════');
  print('\nالخطوة التالية:');
  print('  1. تأكد من إضافة assets/hadith_database.db.gz في pubspec.yaml');
  print('  2. احذف ملفات الـ JSON التسعة من pubspec.yaml');
}

