import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/azkar.dart';
import '../services/azkar_service.dart';
import '../utils/app_constants.dart';

class AzkarDetailScreen extends StatefulWidget {
  final AzkarCategory category;

  const AzkarDetailScreen({super.key, required this.category});

  @override
  State<AzkarDetailScreen> createState() => _AzkarDetailScreenState();
}

class _AzkarDetailScreenState extends State<AzkarDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  double _fontSize = 18.0;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _loadSettings();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _fontSize = prefs.getDouble('azkar_font_size') ?? 18.0;
      });
    } catch (e) {
      debugPrint('❌ Error loading Azkar settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('azkar_font_size', _fontSize);
    } catch (e) {
      debugPrint('❌ Error saving Azkar settings: $e');
    }
  }

  void _incrementZikr(Azkar azkar) {
    if (azkar.isCompleted) return;

    HapticFeedback.lightImpact();

    setState(() {
      final categoryIndex = widget.category.azkar.indexWhere(
        (a) => a.id == azkar.id,
      );
      if (categoryIndex != -1) {
        widget.category.azkar[categoryIndex] = azkar.incrementCount();
      }
    });

    AzkarService.instance.incrementAzkarCount(widget.category.id, azkar.id);

    _progressController.forward().then((_) => _progressController.reverse());

    final updatedAzkar = widget.category.azkar.firstWhere(
      (a) => a.id == azkar.id,
    );
    if (updatedAzkar.isCompleted) {
      HapticFeedback.heavyImpact();
    }
  }

  void _copyZikr(String text) {
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم نسخ الذكر بنجاح',
          textAlign: TextAlign.center,
          style: GoogleFonts.tajawal(fontSize: 14, color: Colors.white),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _resetCounters() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'إعادة تعيين العدادات',
            style: GoogleFonts.tajawal(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'هل تريد تصفير جميع العدادات في ${widget.category.title}؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'إلغاء',
                style: GoogleFonts.tajawal(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                AzkarService.instance.resetCategoryCounters(widget.category.id);
                setState(() {
                  for (int i = 0; i < widget.category.azkar.length; i++) {
                    widget.category.azkar[i] = Azkar(
                      id: widget.category.azkar[i].id,
                      text: widget.category.azkar[i].text,
                      target: widget.category.azkar[i].target,
                      category: widget.category.azkar[i].category,
                      currentCount: 0,
                    );
                  }
                });
                Navigator.of(context).pop();
              },
              child: Text(
                'تأكيد',
                style: GoogleFonts.tajawal(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'تغيير حجم الخط',
            style: GoogleFonts.tajawal(fontWeight: FontWeight.w600),
          ),
          content: StatefulBuilder(
            builder: (context, dialogSetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_fontSize.toInt()}',
                    style: GoogleFonts.tajawal(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Slider(
                    value: _fontSize,
                    min: 16.0,
                    max: 34.0,
                    divisions: 18,
                    activeColor: Theme.of(context).primaryColor,
                    onChanged: (value) {
                      dialogSetState(() => _fontSize = value);
                      setState(() => _fontSize = value);
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                _saveSettings();
                Navigator.of(context).pop();
              },
              child: Text(
                'حفظ',
                style: GoogleFonts.tajawal(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            widget.category.title,
            style: GoogleFonts.tajawal(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              onPressed: _resetCounters,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              onPressed: _showFontSizeDialog,
              icon: const Icon(Icons.text_fields),
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      AppConstants.darkBackgroundColor,
                      AppConstants.darkSurfaceColor,
                    ]
                  : [AppConstants.backgroundColor, AppConstants.surfaceColor],
            ),
          ),
          child: Column(
            children: [
              // كارت التقدم الإجمالي
              Container(
                margin: const EdgeInsets.all(16.0),
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: StreamBuilder<List<AzkarCategory>>(
                  stream: AzkarService.instance.categoriesStream,
                  builder: (context, snapshot) {
                    AzkarCategory currentCategory =
                        (snapshot.hasData && snapshot.data!.isNotEmpty)
                        ? snapshot.data!.firstWhere(
                            (cat) => cat.id == widget.category.id,
                            orElse: () => widget.category,
                          )
                        : widget.category;

                    return Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'التقدم في الأذكار',
                              style: GoogleFonts.tajawal(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${currentCategory.totalCompleted} من أصل ${currentCategory.totalCount}',
                              style: GoogleFonts.tajawal(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: currentCategory.overallProgress,
                            minHeight: 10,
                            backgroundColor: isDark
                                ? Colors.white10
                                : Colors.black12,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              // قائمة الأذكار
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: widget.category.azkar.length,
                  itemBuilder: (context, index) =>
                      _buildAzkarCard(widget.category.azkar[index]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAzkarCard(Azkar azkar) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: azkar.isCompleted
            ? (isDark
                  ? Colors.green.withOpacity(0.15)
                  : Colors.green.withOpacity(0.05))
            : Theme.of(context).cardColor,
        border: Border.all(
          color: azkar.isCompleted
              ? Colors.green.withOpacity(0.5)
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _incrementZikr(azkar),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                azkar.text,
                style: GoogleFonts.amiri(
                  fontSize: _fontSize,
                  height: 2.0,
                  fontWeight: FontWeight.w600,
                  color: azkar.isCompleted
                      ? (isDark ? Colors.greenAccent : Colors.green.shade900)
                      : Theme.of(context).textTheme.bodyLarge?.color,
                ),
                textAlign: TextAlign.right, // جعل النص يتوسط الكارت للأذكار
              textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  // عداد الضغط (الدائرة)
                  GestureDetector(
                    onTap: () => _incrementZikr(azkar),
                    child: AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 + (_progressAnimation.value * 0.15),
                          child: Container(
                            width: 65,
                            height: 65,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: azkar.isCompleted
                                  ? LinearGradient(
                                      colors: [
                                        Colors.green.shade400,
                                        Colors.green.shade700,
                                      ],
                                    )
                                  : AppConstants.primaryGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: azkar.isCompleted
                                      ? Colors.green.withOpacity(0.3)
                                      : Theme.of(
                                          context,
                                        ).primaryColor.withOpacity(0.3),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                '${azkar.currentCount}',
                                style: GoogleFonts.tajawal(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 20),
                  // معلومات التقدم
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              azkar.isCompleted ? 'تمت القراءة' : 'قيد التكرار',
                              style: GoogleFonts.tajawal(
                                fontSize: 13,
                                color: azkar.isCompleted
                                    ? Colors.green
                                    : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${azkar.target} / ${azkar.currentCount}',
                              style: GoogleFonts.tajawal(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: azkar.progress,
                            minHeight: 7,
                            backgroundColor: isDark
                                ? Colors.white10
                                : Colors.black12,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              azkar.isCompleted
                                  ? Colors.green
                                  : Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // زر النسخ
                  IconButton(
                    onPressed: () => _copyZikr(azkar.text),
                    icon: Icon(
                      Icons.copy_rounded,
                      size: 22,
                      color: Colors.grey.shade500,
                    ),
                    tooltip: 'نسخ الذكر',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
