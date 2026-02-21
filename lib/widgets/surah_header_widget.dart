import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SurahHeaderWidget extends StatelessWidget {
  final Map<String, dynamic> surah;

  const SurahHeaderWidget({super.key, required this.surah});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color goldColor = isDarkMode ? const Color(0xFFFFD700).withOpacity(0.5) : const Color(0xFFC5A059);

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
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 5))],
        border: Border.all(color: goldColor.withOpacity(0.3), width: 1.5),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: MushafFramePainter(isDarkMode: isDarkMode, accentColor: goldColor))),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoTag(surah['revelation_type'] == 'Meccan' ? 'مكية' : 'مدنية', isDarkMode),
                    Expanded(
                      child: Text(surah['name_ar'] ?? '',
                        style: GoogleFonts.amiriQuran(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                        textAlign: TextAlign.center),
                    ),
                    _buildInfoTag('${surah['ayah_count'] ?? 0} آية', isDarkMode),
                  ],
                ),
                const SizedBox(height: 5),
                Text('ترتيبها: ${surah['id']}', 
                  style: GoogleFonts.tajawal(fontSize: 10, color: Colors.white70)),
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
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: GoogleFonts.tajawal(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
    );
  }
}

class MushafFramePainter extends CustomPainter {
  final bool isDarkMode;
  final Color accentColor;
  MushafFramePainter({required this.isDarkMode, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = accentColor.withOpacity(0.4)..style = PaintingStyle.stroke..strokeWidth = 1.0;
    final double w = size.width;
    final double h = size.height;
    final double p = 10.0;
    double cs = 25.0;

    Path path = Path();
    path.moveTo(p + cs, p);
    path.lineTo(w - p - cs, p);
    path.quadraticBezierTo(w - p, p, w - p, p + cs);
    path.lineTo(w - p, h - p - cs);
    path.quadraticBezierTo(w - p, h - p, w - p - cs, h - p);
    path.lineTo(p + cs, h - p);
    path.quadraticBezierTo(p, h - p, p, h - p - cs);
    path.lineTo(p, p + cs);
    path.quadraticBezierTo(p, p, p + cs, p);
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}