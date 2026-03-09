import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:imsakia/screens/calendar_page.dart';
import 'package:imsakia/services/bukhari_database_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:flutter_svg/flutter_svg.dart'; // أضفنا مكتبة الـ SVG
import '../providers/settings_provider.dart';
import '../services/hijri_date_service.dart';
import 'bukhari_library_page.dart';
import 'allah_names_page.dart'; // استيراد صفحة أسماء الله الحسنى
import 'radio_page.dart'; // استيراد صفحة الراديو
import '../features/quran_madinah/ui/index_screen.dart'; // استيراد صفحة الفهرس مباشرة بدلاً من صفحة الاختيار
import '../features/audio/screens/audio_reciters_screen.dart'; // Audio module
import '../widgets/neumorphic_box.dart';

/// صفحة بسيطة للأقسام التي تحت التطوير
class UnderDevelopmentPage extends StatelessWidget {
  const UnderDevelopmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDarkMode
            ? const Color(0xFF121212)
            : const Color(0xFFF5F5F0),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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

    final Color primaryTextColor = isDarkMode
        ? Colors.white
        : Colors.brown[900]!;
    final Color secondaryTextColor = isDarkMode
        ? Colors.white70
        : Colors.brown[400]!;


    // القائمة المحدثة مع الصور الجديدة
    final List<Map<String, dynamic>> menuItems = [
      {
        'title': 'صوتيات',
        'icon': Icons.library_music,
        'isAsset': false,
        'color': Colors.blueAccent,
      },
      {
        'title': 'مكتبة الحديث',
        'asset': 'assets/images/muhammed.png', // الصورة المطلوبة
        'isAsset': true,
        'color': Colors.tealAccent,
      },
      {
        'title': 'الراديو',
        'icon': Icons.radio,
        'isAsset': false,
        'color': Colors.greenAccent,
      },
      {
        'title': 'القبلة',
        'icon': Icons.explore,
        'isAsset': false,
        'color': Colors.orangeAccent,
      },
      {
        'title': 'أسماء الله الحسنى',
        'asset': 'assets/images/names.svg', // صورة الـ SVG المطلوبة
        'isAsset': true,
        'isSvg': true,
        'color': Colors.amberAccent,
      },
      {
        'title': 'الاشعارات',
        'icon': Icons.notifications_active,
        'isAsset': false,
        'color': Colors.orange,
      },
      {
        'title': 'التقويم الهجري',
        'icon': Icons.event_note,
        'isAsset': false,
        'color': Colors.lightBlueAccent,
      },
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDarkMode
            ? const Color(0xFF121212)
            : const Color(0xFFF5F5F0),
        appBar: AppBar(
          backgroundColor: isDarkMode ? Colors.transparent : Colors.blue,
          elevation: 0,
          iconTheme: IconThemeData(
            color: isDarkMode ? Colors.white : Colors.white,
          ),
          title: Text(
            'تبيان',
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? primaryTextColor : Colors.white,
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
                        color: isDarkMode
                            ? Colors.amber[200]
                            : Colors.brown[700],
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

            // زر القرآن الكريم بالصورة الجديدة quraan.png
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: NeumorphicBox(
                  borderRadius: 20,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const IndexScreen(),
                        ),
                      );
                    },
                    child: SizedBox(
                      height: 115,
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
                          Hero(
                            tag: 'quran_logo_hero',
                            child: Image.asset(
                              'assets/images/quranlogo.png', // Changed to match destination for smooth Hero animation
                              height: 70,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // شبكة الأيقونات
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
                  return NeumorphicBox(
                    borderRadius: 15,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: () {
                        if (item['title'] == 'مكتبة الحديث') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const BukhariLibraryPage(),
                            ),
                          );
                        } else if (item['title'] == 'أسماء الله الحسنى') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AllahNamesPage(),
                            ), // الانتقال لصفحة الأسماء
                          );
                        } else if (item['title'] == 'صوتيات') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AudioRecitersScreen(),
                            ),
                          );
                        } else if (item['title'] == 'الراديو') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RadioPage(),
                            ), // الانتقال لصفحة الراديو
                          );
                        } else if (item['title'] == 'التقويم الهجري') {
                          // التعديل هنا
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CalendarPage(),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UnderDevelopmentPage(),
                            ),
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // منطق عرض الأيقونة أو الصورة (SVG أو PNG)
                            if (item['isAsset'] == true)
                              item['isSvg'] == true
                                  ? SvgPicture.asset(
                                      item['asset'],
                                      height: 35,
                                      width: 35,
                                      colorFilter: ColorFilter.mode(
                                        item['color'],
                                        BlendMode.srcIn,
                                      ),
                                    )
                                  : Image.asset(
                                      item['asset'],
                                      height: 35,
                                      width: 35,
                                    )
                            else
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
                    ),
                  );
                }, childCount: menuItems.length),
              ),
            ),
            // أضف هذا الجزء في الـ CustomScrollView بعد SliverPadding الخاص بالشبكة
            // داخل قائمة الـ Widgets في صفحة تبيان
            SliverToBoxAdapter(
              child: FutureBuilder<Map<String, dynamic>?>(
                future: BukhariDatabaseService.getDailyHadith(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  // إذا لم توجد بيانات أو حدث خطأ
                  if (!snapshot.hasData || snapshot.data == null) {
                    return const SizedBox.shrink();
                  }

                  final String hadithText =
                      snapshot.data!['text'] ?? "لا يوجد نص متاح";
                  final bool isDarkMode =
                      Theme.of(context).brightness == Brightness.dark;

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                    child: NeumorphicBox(
                      borderRadius: 25,
                      child: InkWell(
                        onTap: () => _showHadithDetails(context, hadithText),
                        borderRadius: BorderRadius.circular(25),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.auto_awesome,
                                    color: Colors.amber,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'حديث اليوم',
                                    style: GoogleFonts.tajawal(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                      color: Colors.amber[800],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 15),
                              Text(
                                hadithText,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.amiri(
                                  fontSize: 18,
                                  height: 1.6,
                                  color: isDarkMode
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 15),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    'إضغط للتفاصيل',
                                    style: GoogleFonts.tajawal(
                                      fontSize: 13,
                                      color: Colors.blueAccent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_right_alt,
                                    color: Colors.blueAccent,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHadithDetails(BuildContext context, String text) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Text(
                      'الحديث الشريف',
                      style: GoogleFonts.tajawal(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 30),
                    Text(
                      text,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.amiri(
                        fontSize: 22,
                        height: 1.8,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'إغلاق',
                  style: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
