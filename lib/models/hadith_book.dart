import 'package:flutter/material.dart';

class HadithBook {
  final String title;
  /// مفتاح فريد يُستخدم للاستعلام من قاعدة البيانات
  /// مثال: 'bukhari', 'muslim', 'abi_daud', ...
  final String bookKey;
  final Color coverColor;
  final String author;

  const HadithBook({
    required this.title,
    required this.bookKey,
    required this.coverColor,
    required this.author,
  });
}
