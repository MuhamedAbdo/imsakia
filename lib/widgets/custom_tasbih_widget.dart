import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'neumorphic_box.dart';

class CustomTasbih extends StatefulWidget {
  const CustomTasbih({super.key});

  @override
  State<CustomTasbih> createState() => _CustomTasbihState();
}

class _CustomTasbihState extends State<CustomTasbih> {
  int _count = 0;
  int _dailyCount = 0;
  bool _isMainPressed = false;
  bool _isResetPressed = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    // تجهيز الصوت مسبقاً في الذاكرة (Preloading) لضمان استجابة لحظية بدون تأخير
    _audioPlayer.setSource(AssetSource('audio/click.mp3')).catchError((e) {
      // تم إمساك الاستثناء وتجاهله لتجنب انهيار التطبيق في حال عدم وجود ملف الصوت
      debugPrint("Tasbih: click.mp3 sound asset not found, running silently: $e");
    });
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
    
    _loadCount();
    _loadDailyCount();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadCount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _count = prefs.getInt('custom_tasbih_count') ?? 0;
    });
  }

  Future<void> _saveCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('custom_tasbih_count', _count);
  }

  Future<void> _loadDailyCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = 'daily_count_${today.day}_${today.month}_${today.year}';
    const lastResetKey = 'last_reset_date';

    final lastResetDate = prefs.getString(lastResetKey);
    final todayString = '${today.day}_${today.month}_${today.year}';

    if (lastResetDate != todayString) {
      await prefs.setString(lastResetKey, todayString);
      await prefs.setInt(todayKey, 0);
      _dailyCount = 0;
    } else {
      setState(() {
        _dailyCount = prefs.getInt(todayKey) ?? 0;
      });
    }
  }

  Future<void> _saveDailyCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = 'daily_count_${today.day}_${today.month}_${today.year}';
    await prefs.setInt(todayKey, _dailyCount);
  }

  Future<void> _playClickSound() async {
    try {
      // تصفير مؤشر الصوت وإعادة التشغيل فوراً للتعامل مع التسبيح السريع جداً
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.resume();
    } catch (e) {
      // ignore
    }
  }

  Future<void> _incrementCount() async {
    HapticFeedback.heavyImpact();
    _playClickSound();
    setState(() {
      _count++;
      _dailyCount++;
    });
    _saveCount();
    _saveDailyCount();
  }

  Future<void> _resetCount() async {
    HapticFeedback.mediumImpact();
    _playClickSound();
    setState(() {
      _count = 0;
    });
    _saveCount();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NeumorphicBox(
          borderRadius: 20,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'تسبيحات اليوم',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                    fontFamily: 'Cairo',
                    shadows: [
                      Shadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.3),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_dailyCount',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                    fontFamily: 'Cairo',
                    shadows: [
                      Shadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.3),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 23), // تم تقليل المسافة لرفع جسم المسبحة 2 بكسل
        FittedBox(
          fit: BoxFit
              .scaleDown, // تضمن تصغير المسبحة إذا كانت الشاشة صغيرة مع الحفاظ على التناسب
          child: SizedBox(
            width: 280,
            height:
                378, // تقليل الارتفاع ليصبح التصميم متناسقاً وغير ممطوط عمودياً
            // تم إزالة BoxDecoration لإلغاء البرواز والظل الأسود وجعل الخلفية شفافة
            child: Stack(
              children: [
                // 1. زر التصفير (Reset Button - في الخلف)
                Positioned(
                  bottom:
                      150, // تنزيل الزر للحفاظ على موقعه بعد رفع جسم المسبحة
                  right: 58, // تعديل الموضع لليسار بناء على طلب المستخدم
                  child: GestureDetector(
                    onTapDown: (_) => setState(() => _isResetPressed = true),
                    onTapUp: (_) => setState(() => _isResetPressed = false),
                    onTapCancel: () => setState(() => _isResetPressed = false),
                    onTap: _resetCount,
                    child: AnimatedScale(
                      scale: _isResetPressed ? 0.86 : 1.0, // زيادة تأثير الضغط
                      duration: const Duration(milliseconds: 100),
                      child: Image.asset(
                        'assets/images/reset_button_wooden.png',
                        width: 24,
                        height: 24,
                      ),
                    ),
                  ),
                ),
                // 2. الزر الرئيسي (Main Button - في الخلف)
                Positioned(
                  bottom: 46, // تنزيل الزر للحفاظ على موقعه بعد رفع جسم المسبحة
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTapDown: (_) => setState(() => _isMainPressed = true),
                      onTapUp: (_) => setState(() => _isMainPressed = false),
                      onTapCancel: () => setState(() => _isMainPressed = false),
                      onTap: _incrementCount,
                      child: AnimatedScale(
                        scale: _isMainPressed ? 0.93 : 1.0, // زيادة تأثير الضغط
                        duration: const Duration(milliseconds: 100),
                        child: Image.asset(
                          'assets/images/main_button_wooden.png',
                          width: 97, // تم تكبير الحجم لتصبح 97
                          height: 97,
                        ),
                      ),
                    ),
                  ),
                ),
                // 3. صورة الخشب (توضع لتغطي حواف الأزرار فقط)
                IgnorePointer(
                  child: Container(
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/body_wooden.png'),
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
                ),
                // 4. رقم العداد (بدون خلفية، وبمساحة أكبر ليتوسط الشاشة الرمادية)
                Positioned(
                  top: 75, // رفع الرقم للأعلى بمقدار 2 بكسل
                  left: 40,
                  right: 40,
                  height: 85,
                  child: Center(
                    child: Text(
                      _count.toString(),
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87, // تم تغيير اللون إلى الأسود
                        fontFamily: 'Courier New',
                        letterSpacing: 4,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
