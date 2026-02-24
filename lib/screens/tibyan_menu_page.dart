import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../providers/settings_provider.dart';
import '../services/hijri_date_service.dart';
import 'quran_home_new.dart';
import 'bukhari_library_page.dart';

/// صفحة بسيطة للأقسام التي تحت التطوير
class UnderDevelopmentPage extends StatelessWidget {
  const UnderDevelopmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl, // لضمان ظهور زر الرجوع على اليمين
      child: Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F0),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          // Flutter سيتكفل بوضع السهم على اليمين تلقائياً بسبب Directionality
          iconTheme: IconThemeData(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // أيقونة لطيفة تعبر عن العمل الجاري
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.construction_rounded,
                  size: 80,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'سيتم تطويره قريباً',
                style: GoogleFonts.tajawal(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'نحن نعمل على إضافة هذا القسم المميّز',
                style: GoogleFonts.tajawal(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class TibyanMenuPage extends StatelessWidget {
  const TibyanMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final DateTime now = DateTime.now();
    final String formattedGregorian = DateFormat(
      'EEEE، d MMMM yyyy',
      'ar',
    ).format(now);

    final hijriDateMap = HijriDateService.getHijriDate(
      now,
      settings.hijriAdjustment,
    );
    final String formattedHijri = hijriDateMap['formatted'];

    final Color primaryTextColor = isDarkMode ? Colors.white : Colors.brown[900]!;
    final Color secondaryTextColor = isDarkMode ? Colors.white70 : Colors.brown[400]!;
    final Color cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    // تم حذف السبحة والأذكار والأدعية من القائمة
    final List<Map<String, dynamic>> menuItems = [
      {'title': 'صوتيات', 'icon': Icons.library_music, 'color': Colors.blueAccent},
      {'title': 'مكتبة الحديث', 'icon': Icons.collections_bookmark, 'color': Colors.tealAccent},
      {'title': 'الراديو', 'icon': Icons.radio, 'color': Colors.greenAccent},
      {'title': 'القبلة', 'icon': Icons.explore, 'color': Colors.orangeAccent},
      {'title': 'أسماء الله الحسنى', 'icon': Icons.wb_sunny, 'color': Colors.amberAccent},
      {'title': 'الاشعارات', 'icon': Icons.notifications_active, 'color': Colors.orange},
      {'title': 'التقويم الهجري', 'icon': Icons.event_note, 'color': Colors.lightBlueAccent},
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F0),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'تبيان',
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
          centerTitle: true,
        ),
        body: CustomScrollView(
          slivers: [
            // قسم التاريخ
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Column(
                  children: [
                    Text(
                      formattedHijri,
                      style: GoogleFonts.tajawal(
                        fontSize: 22,
                        color: isDarkMode ? Colors.amber[200] : Colors.brown[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedGregorian,
                      style: GoogleFonts.tajawal(
                        fontSize: 16,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // زر القرآن الكريم
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const QuranHomeNew()),
                    );
                  },
                  child: Container(
                    height: 115,
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDarkMode ? 0.4 : 0.05),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text(
                          'القرآن الكريم',
                          style: GoogleFonts.tajawal(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                        Icon(
                          Icons.menu_book_rounded,
                          size: 60,
                          color: isDarkMode ? Colors.orangeAccent : Colors.orange[300],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // شبكة الأيقونات المحدثة
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.88,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = menuItems[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () {
                      if (item['title'] == 'مكتبة الحديث') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const BukhariLibraryPage()),
                        );
                      } else {
                        // أي زر آخر يفتح صفحة "سيتم تطويره قريباً"
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const UnderDevelopmentPage()),
                        );
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(15),
                        border: isDarkMode ? Border.all(color: Colors.white12) : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            item['icon'] as IconData,
                            size: 32,
                            color: item['color'] as Color,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item['title'] as String,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.tajawal(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: primaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }, childCount: menuItems.length),
              ),
            ),
          ],
        ),
      ),
    );
  }
}