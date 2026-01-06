import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/quran_models.dart';
import '../providers/theme_provider.dart';

class SurahHeaderWidget extends StatelessWidget {
  final QuranSurah surah;

  const SurahHeaderWidget({
    super.key,
    required this.surah,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [
                  const Color(0xFF2d2d2d),
                  const Color(0xFF1e1e1e),
                ]
              : [
                  const Color(0xFF8B7355),
                  const Color(0xFF6B5B45),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black26 : Colors.black12,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDarkMode ? Colors.white12 : Colors.white24,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Islamic decorative pattern - minimal height
          CustomPaint(
            size: const Size(double.infinity, 20),
            painter: IslamicPatternPainter(isDarkMode: isDarkMode),
          ),
          
          const SizedBox(height: 4),
          
          // Compact horizontal layout for surah info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left side: Revelation type and number
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.white12 : Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        surah.revelationType == 'Meccan' ? 'مكية' : 'مدنية',
                        style: GoogleFonts.tajawal(
                          fontSize: 11,
                          color: isDarkMode ? Colors.white70 : const Color(0xFFfef8f0),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.white12 : Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '#${surah.number}',
                        style: GoogleFonts.tajawal(
                          fontSize: 11,
                          color: isDarkMode ? Colors.white70 : const Color(0xFFfef8f0),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Center: Surah name
                Expanded(
                  child: Text(
                    surah.name,
                    style: GoogleFonts.amiriQuran(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : const Color(0xFFfef8f0),
                      shadows: [
                        Shadow(
                          color: isDarkMode ? Colors.black26 : Colors.black12,
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                // Right side: Ayah count
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white12 : Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${surah.ayahCount} آية',
                    style: GoogleFonts.tajawal(
                      fontSize: 11,
                      color: isDarkMode ? Colors.white70 : const Color(0xFFfef8f0),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 4),
          
          // Bottom decorative pattern - minimal
          CustomPaint(
            size: const Size(double.infinity, 20),
            painter: IslamicPatternPainter(isDarkMode: isDarkMode),
          ),
        ],
      ),
    );
  }
}

class IslamicPatternPainter extends CustomPainter {
  final bool isDarkMode;

  IslamicPatternPainter({required this.isDarkMode});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDarkMode ? Colors.white12 : Colors.white24
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    
    // Create Islamic geometric pattern
    final double width = size.width;
    final double height = size.height;
    
    // Draw interconnected geometric shapes
    for (int i = 0; i < width; i += 40) {
      // Draw diamond shapes
      final centerX = i + 20.0;
      final centerY = height / 2;
      
      path.moveTo(centerX, centerY - 10);
      path.lineTo(centerX + 10, centerY);
      path.lineTo(centerX, centerY + 10);
      path.lineTo(centerX - 10, centerY);
      path.close();
      
      canvas.drawPath(path, paint);
      path.reset();
      
      // Draw connecting lines
      if (i > 0) {
        canvas.drawLine(
          Offset(i - 20, centerY),
          Offset(centerX - 10, centerY),
          paint,
        );
      }
    }
    
    // Draw central decorative element
    final centerOffset = Offset(width / 2, height / 2);
    canvas.drawCircle(centerOffset, 8, paint);
    
    // Draw star pattern in center
    for (int i = 0; i < 8; i++) {
      final angle = (i * 45) * 3.14159 / 180;
      final x = centerOffset.dx + 15 * cos(angle);
      final y = centerOffset.dy + 15 * sin(angle);
      
      canvas.drawLine(centerOffset, Offset(x, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;

  double cos(double angle) => math.cos(angle);
  double sin(double angle) => math.sin(angle);
}

