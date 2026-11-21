import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'seerah_timeline_screen.dart';
import 'battles_screen.dart';
import 'companions_screen.dart';
import 'history_screen.dart';

class EncyclopediaScreen extends StatelessWidget {
  const EncyclopediaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1.0),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF121212)
            : const Color(0xFFF7F8FA),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'الموسوعة الإسلامية',
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: isDark ? Colors.white : const Color(0xFF263238),
            ),
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: isDark ? Colors.white : const Color(0xFF263238),
              size: 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon Container
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFFD4AF37).withValues(alpha: 0.12)
                        : const Color(0xFFD4AF37).withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withValues(alpha: isDark ? 0.15 : 0.08),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        size: 46,
                        color: Color(0xFFD4AF37),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Availability Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFFD4AF37).withValues(alpha: 0.15)
                        : const Color(0xFFD4AF37).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        size: 15,
                        color: Color(0xFFD4AF37),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'جميع أقسام الموسوعة الإسلامية متاحة الآن',
                          softWrap: true,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.tajawal(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFD4AF37),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Main Title
                Text(
                  'الموسوعة الإسلامية',
                  style: GoogleFonts.tajawal(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF263238),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Short Description
                Text(
                  'السيرة النبوية، الغزوات، الصحابة، والتاريخ الإسلامي',
                  style: GoogleFonts.tajawal(
                    fontSize: 15,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : const Color(0xFF546E7A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Topics Preview Grid / List
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.04),
                        blurRadius: 15,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildTopicRow(
                        icon: Icons.history_edu_rounded,
                        title: 'السيرة النبوية المطهرة',
                        subtitle: 'محطات مضيئة من حياة خير البرية ﷺ',
                        isDark: isDark,
                        isAvailable: true,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SeerahTimelineScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 20, thickness: 0.5),
                      _buildTopicRow(
                        icon: Icons.shield_outlined,
                        title: 'الغزوات والسرايا',
                        subtitle: 'أحداث ودروس المعارك الإسلامية الخالدة',
                        isDark: isDark,
                        isAvailable: true,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const BattlesScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 20, thickness: 0.5),
                      _buildTopicRow(
                        icon: Icons.groups_rounded,
                        title: 'سير الصحابة الكرام',
                        subtitle: 'سير أعلام الهدى ورجال حول الرسول ﷺ',
                        isDark: isDark,
                        isAvailable: true,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const CompanionsScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 20, thickness: 0.5),
                      _buildTopicRow(
                        icon: Icons.auto_stories_outlined,
                        title: 'التاريخ والحضارة الإسلامية',
                        subtitle: 'عصور الإشعاع الحضاري والأحداث التاريخية',
                        isDark: isDark,
                        isAvailable: true,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const HistoryScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Note
                Text(
                  'تم إطلاق جميع أبواب الموسوعة الإسلامية: السيرة النبوية المطهرة، الغزوات والسرايا، سير الصحابة الكرام، والتاريخ والحضارة الإسلامية.',
                  style: GoogleFonts.tajawal(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontWeight: FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildTopicRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    bool isAvailable = false,
    VoidCallback? onTap,
  }) {
    final rowContent = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: const Color(0xFFD4AF37),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        softWrap: true,
                        style: GoogleFonts.tajawal(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF263238),
                        ),
                      ),
                    ),
                    if (isAvailable) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                            width: 0.6,
                          ),
                        ),
                        child: Text(
                          'متاح الآن',
                          style: GoogleFonts.tajawal(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFD4AF37),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.tajawal(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF546E7A),
                  ),
                ),
              ],
            ),
          ),
          if (isAvailable)
            const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 14,
              color: Color(0xFFD4AF37),
            ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: rowContent,
        ),
      );
    }

    return rowContent;
  }
}
