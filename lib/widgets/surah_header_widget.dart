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

    // ألوان تحاكي ورق المصحف القديم والتذهيب
    final Color goldColor = isDarkMode ? const Color(0xFFFFD700).withOpacity(0.5) : const Color(0xFFC5A059);
    final Color decorationColor = isDarkMode ? Colors.white24 : Colors.white54;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [const Color(0xFF1A1A1A), const Color(0xFF2D2D2D)]
              : [const Color(0xFF8B7355), const Color(0xFF6B5B45)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        // إطار خارجي مزدوج بسيط
        border: Border.all(color: goldColor.withOpacity(0.3), width: 1.5),
      ),
      child: Stack(
        children: [
          // رسم الزخارف الخلفية (الإطار الإسلامي)
          Positioned.fill(
            child: CustomPaint(
              painter: MushafFramePainter(
                isDarkMode: isDarkMode,
                accentColor: goldColor,
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoTag(
                      surah.revelationType == 'Meccan' ? 'مكية' : 'مدنية',
                      isDarkMode,
                    ),
                    
                    // اسم السورة في المنتصف مع خط أندلسي/كوفي
                    Expanded(
                      child: Text(
                        surah.name,
                        style: GoogleFonts.amiriQuran(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : const Color(0xFFFEF8F0),
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    _buildInfoTag('${surah.ayahCount} آية', isDarkMode),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  'ترتيبها: ${surah.number}',
                  style: GoogleFonts.tajawal(
                    fontSize: 10,
                    color: isDarkMode ? Colors.white38 : Colors.white60,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTag(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.black12,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.white24,
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.tajawal(
          fontSize: 11,
          color: isDark ? Colors.white70 : Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// الرسام الخاص بإطار المصحف الواقعي
class MushafFramePainter extends CustomPainter {
  final bool isDarkMode;
  final Color accentColor;

  MushafFramePainter({required this.isDarkMode, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accentColor.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final double w = size.width;
    final double h = size.height;
    final double padding = 10.0;

    // 1. رسم الإطار الداخلي المنحني (بوابة)
    Path framePath = Path();
    
    // الزوايا المزخرفة
    double cornerSize = 25.0;
    
    // أعلى يسار
    framePath.moveTo(padding + cornerSize, padding);
    framePath.lineTo(w - padding - cornerSize, padding);
    
    // قوس علوي يمين
    framePath.quadraticBezierTo(w - padding, padding, w - padding, padding + cornerSize);
    framePath.lineTo(w - padding, h - padding - cornerSize);
    
    // قوس سفلي يمين
    framePath.quadraticBezierTo(w - padding, h - padding, w - padding - cornerSize, h - padding);
    framePath.lineTo(padding + cornerSize, h - padding);
    
    // قوس سفلي يسار
    framePath.quadraticBezierTo(padding, h - padding, padding, h - padding - cornerSize);
    framePath.lineTo(padding, padding + cornerSize);
    
    // قوس علوي يسار
    framePath.quadraticBezierTo(padding, padding, padding + cornerSize, padding);

    canvas.drawPath(framePath, paint);

    // 2. رسم ثمانيات الأضلاع في الأركان (Islamic Star Corner)
    _drawCornerStar(canvas, Offset(padding, padding), paint);
    _drawCornerStar(canvas, Offset(w - padding, padding), paint);
    _drawCornerStar(canvas, Offset(padding, h - padding), paint);
    _drawCornerStar(canvas, Offset(w - padding, h - padding), paint);
    
    // 3. إضافة نقاط تزيينية صغيرة على الأطراف
    final dotPaint = Paint()..color = accentColor.withOpacity(0.3)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w/2, padding), 2, dotPaint);
    canvas.drawCircle(Offset(w/2, h - padding), 2, dotPaint);
  }

  void _drawCornerStar(Canvas canvas, Offset center, Paint paint) {
    double size = 6.0;
    Path star = Path();
    for (int i = 0; i < 8; i++) {
      double angle = (i * 45) * math.pi / 180;
      double r = i % 2 == 0 ? size : size / 2;
      double x = center.dx + r * math.cos(angle);
      double y = center.dy + r * math.sin(angle);
      if (i == 0) star.moveTo(x, y); else star.lineTo(x, y);
    }
    star.close();
    canvas.drawPath(star, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}