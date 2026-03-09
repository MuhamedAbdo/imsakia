import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;
  var dbPath = r'd:\projects\imsakia\assets\quran.db';

  debugPrint('Size before: ${File(dbPath).lengthSync()} bytes');

  var db = await databaseFactory.openDatabase(dbPath);

  // Drop unused tables
  await db.execute("DROP TABLE IF EXISTS surahs");
  await db.execute("DROP TABLE IF EXISTS ayahs");
  await db.execute("DROP TABLE IF EXISTS hizbs");
  await db.execute("DROP TABLE IF EXISTS juzs");
  await db.execute(
    "DROP TABLE IF EXISTS migrations",
  ); // Usually okay to drop in external static databases
  await db.execute("DROP TABLE IF EXISTS editions");

  // Vacuum to reclaim space
  await db.execute("VACUUM");

  await db.close();

  debugPrint('Size after: ${File(dbPath).lengthSync()} bytes');
}
