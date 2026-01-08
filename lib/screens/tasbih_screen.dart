import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TasbihScreen extends StatefulWidget {
  const TasbihScreen({super.key});

  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen>
    with TickerProviderStateMixin {
  int _currentCount = 0;
  int _totalCount = 0;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadCounts();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = 'tasbih_${today.year}_${today.month}_${today.day}';
    setState(() {
      _currentCount = prefs.getInt('tasbih_current') ?? 0;
      _totalCount = prefs.getInt(todayKey) ?? 0;
    });
  }

  Future<void> _saveCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = 'tasbih_${today.year}_${today.month}_${today.day}';
    await prefs.setInt('tasbih_current', _currentCount);
    await prefs.setInt(todayKey, _totalCount);
  }

  void _incrementCount() {
    HapticFeedback.lightImpact();
    setState(() {
      _currentCount++;
      _totalCount++;
    });
    _saveCounts();
    _animationController
        .forward(from: 0)
        .then((_) => _animationController.reverse());
  }

  // رسالة التأكيد عند إعادة الضبط
  void _confirmReset() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Text(
              'تأكيد إعادة الضبط',
              style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'هل أنت متأكد من رغبتك في تصفير العداد الحالي؟',
              style: GoogleFonts.tajawal(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'إلغاء',
                  style: GoogleFonts.tajawal(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() => _currentCount = 0);
                  _saveCounts();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'تصفير',
                  style: GoogleFonts.tajawal(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color textColor = isDark ? Colors.white : Colors.black87;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: GestureDetector(
        onTap: _incrementCount, // الضغط يعمل في أي مكان في الشاشة
        child: Scaffold(
          backgroundColor: isDark
              ? const Color(0xFF121212)
              : const Color(0xFFF8F9FA),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'المسبحة',
              style: GoogleFonts.tajawal(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.refresh, color: textColor.withOpacity(0.7)),
                onPressed: _confirmReset, // استدعاء دالة التأكيد
              ),
            ],
          ),
          body: Column(
            children: [
              const SizedBox(height: 20),
              Text(
                'اذكر الله يذكرك',
                style: GoogleFonts.tajawal(
                  fontSize: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),

              // منطقة العداد المركزية
              Expanded(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) => Transform.scale(
                      scale: _scaleAnimation.value,
                      child: _buildMainCircle(isDark, primaryColor),
                    ),
                  ),
                ),
              ),

              // الحاوية السفلية المحدثة
              _buildTotalCard(isDark, primaryColor),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainCircle(bool isDark, Color primaryColor) {
    return Container(
      width: 180, // حجم متناسق وأنيق
      height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(isDark ? 0.25 : 0.1),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: primaryColor.withOpacity(0.4), width: 3),
      ),
      child: Center(
        child: Text(
          '$_currentCount',
          style: GoogleFonts.tajawal(
            fontSize: 50,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildTotalCard(bool isDark, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 25),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'إجمالي اليوم',
            style: GoogleFonts.tajawal(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          Text(
            '$_totalCount',
            style: GoogleFonts.tajawal(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              // أبيض في المظلم، ولون التطبيق في الفاتح لضمان الوضوح
              color: isDark ? Colors.white : primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
