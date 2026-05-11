import 'package:flutter/material.dart';

class FiqhBook {
  final int id;
  final String title;
  final String fileName;
  final String icon;
  final String color;
  late final String jsonPath; // Added for consistency with HadithBook

  FiqhBook({
    required this.id,
    required this.title,
    required this.fileName,
    required this.icon,
    required this.color,
  }) {
    jsonPath = 'assets/data/fiqh/$fileName';
  }

  factory FiqhBook.fromJson(Map<String, dynamic> json) {
    return FiqhBook(
      id: json['id'] as int,
      title: json['title'] as String,
      fileName: json['file_name'] as String,
      icon: json['icon'] as String,
      color: json['color'] as String,
    );
  }

  Color get coverColor {
    // Convert hex color string to Color
    return Color(int.parse(color.replaceFirst('#', '0xFF')));
  }
}

class FiqhBookData {
  final String sectionName;
  final List<FiqhQuestion> data;

  FiqhBookData({required this.sectionName, required this.data});

  factory FiqhBookData.fromJson(Map<String, dynamic> json) {
    final dataList =
        (json['data'] as List?)
            ?.map((item) => FiqhQuestion.fromJson(item))
            .toList() ??
        [];

    return FiqhBookData(
      sectionName: json['section_name'] as String,
      data: dataList,
    );
  }
}

class FiqhQuestion {
  final int id;
  final String question;
  final String answer;
  final String? evidence;
  final List<String> tags;

  FiqhQuestion({
    required this.id,
    required this.question,
    required this.answer,
    this.evidence,
    required this.tags,
  });

  factory FiqhQuestion.fromJson(Map<String, dynamic> json) {
    return FiqhQuestion(
      id: json['id'] as int,
      question: json['question'] as String,
      answer: json['answer'] as String,
      evidence: json['evidence'] as String?,
      tags: List<String>.from(json['tags'] as List? ?? []),
    );
  }
}
