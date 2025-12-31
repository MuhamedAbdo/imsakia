import 'package:flutter/material.dart';
import '../utils/app_constants.dart';

class Azkar {
  final String id;
  final String category;
  final String text;
  final int target;
  final int? currentCount;
  final bool isCompleted;

  Azkar({
    required this.id,
    required this.category,
    required this.text,
    required this.target,
    this.currentCount = 0,
    this.isCompleted = false,
  });

  factory Azkar.fromJson(Map<String, dynamic> json) {
    return Azkar(
      id: json['id'] as String,
      category: json['category'] as String,
      text: json['text'] as String,
      target: json['target'] as int,
      currentCount: json['currentCount'] as int? ?? 0,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'text': text,
      'target': target,
      'currentCount': currentCount,
      'isCompleted': isCompleted,
    };
  }

  Azkar copyWith({
    String? id,
    String? category,
    String? text,
    int? target,
    int? currentCount,
    bool? isCompleted,
  }) {
    return Azkar(
      id: id ?? this.id,
      category: category ?? this.category,
      text: text ?? this.text,
      target: target ?? this.target,
      currentCount: currentCount ?? this.currentCount,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Azkar incrementCount() {
    final newCount = (currentCount ?? 0) + 1;
    return copyWith(
      currentCount: newCount,
      isCompleted: newCount >= target,
    );
  }

  Azkar resetCount() {
    return copyWith(
      currentCount: 0,
      isCompleted: false,
    );
  }

  double get progress {
    if (target <= 0) return 0.0;
    return (currentCount ?? 0) / target;
  }

  int get remaining => target - (currentCount ?? 0);
}

class AzkarCategory {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final LinearGradient gradient;
  final List<Azkar> azkar;

  AzkarCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.gradient,
    required this.azkar,
  });

  factory AzkarCategory.fromJson(Map<String, dynamic> json) {
    return AzkarCategory(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      icon: _getIconFromString(json['icon'] as String),
      color: Color(int.parse(json['color'] as String)),
      gradient: _getGradientFromString(json['gradient'] as String),
      azkar: (json['azkar'] as List)
          .map((azkarJson) => Azkar.fromJson(azkarJson as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'icon': icon.codePoint.toString(),
      'color': color.value.toString(),
      'gradient': _gradientToString(gradient),
      'azkar': azkar.map((azkar) => azkar.toJson()).toList(),
    };
  }

  static IconData _getIconFromString(String iconString) {
    switch (iconString) {
      case 'Icons.wb_sunny':
        return Icons.wb_sunny;
      case 'Icons.nightlight_round':
        return Icons.nightlight_round;
      case 'Icons.mosque':
        return Icons.mosque;
      case 'Icons.bedtime':
        return Icons.bedtime;
      case 'Icons.favorite':
        return Icons.favorite;
      default:
        return Icons.auto_stories;
    }
  }

  static LinearGradient _getGradientFromString(String gradientString) {
    // Simple gradient parsing - in real app, you'd want more robust parsing
    return AppConstants.primaryGradient;
  }

  static String _gradientToString(LinearGradient gradient) {
    // Simple gradient serialization - in real app, you'd want more robust serialization
    return 'primaryGradient';
  }

  AzkarCategory updateAzkarCount(String azkarId, int newCount) {
    return copyWith(
      azkar: azkar.map((azkar) {
        if (azkar.id == azkarId) {
          return azkar.copyWith(
            currentCount: newCount,
            isCompleted: newCount >= azkar.target,
          );
        }
        return azkar;
      }).toList(),
    );
  }

  AzkarCategory resetAllCounters() {
    return copyWith(
      azkar: azkar.map((azkar) => azkar.resetCount()).toList(),
    );
  }

  int get totalCompleted => azkar.where((azkar) => azkar.isCompleted).length;
  int get totalCount => azkar.length;
  double get overallProgress => totalCount > 0 ? totalCompleted / totalCount : 0.0;

  AzkarCategory copyWith({
    String? id,
    String? title,
    String? description,
    IconData? icon,
    Color? color,
    LinearGradient? gradient,
    List<Azkar>? azkar,
  }) {
    return AzkarCategory(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      gradient: gradient ?? this.gradient,
      azkar: azkar ?? this.azkar,
    );
  }
}
