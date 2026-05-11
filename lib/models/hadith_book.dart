import 'package:flutter/material.dart';

class HadithBook {
  final String title;
  final String jsonPath;
  final Color coverColor;
  final String author;

  const HadithBook({
    required this.title,
    required this.jsonPath,
    required this.coverColor,
    required this.author,
  });
}
