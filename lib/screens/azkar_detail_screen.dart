import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;
import '../models/azkar.dart';
import '../services/azkar_service.dart';
import '../utils/app_constants.dart';

class AzkarDetailScreen extends StatefulWidget {
  final AzkarCategory category;

  const AzkarDetailScreen({
    super.key,
    required this.category,
  });

  @override
  State<AzkarDetailScreen> createState() => _AzkarDetailScreenState();
}

class _AzkarDetailScreenState extends State<AzkarDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _progressController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _progressAnimation;
  double _fontSize = 18.0;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _loadSettings();
  }
  
  @override
  void dispose() {
    _slideController.dispose();
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
      final categoryIndex = widget.category.azkar.indexWhere((a) => a.id == azkar.id);
      if (categoryIndex != -1) {
        widget.category.azkar[categoryIndex] = azkar.incrementCount();
      }
    });
    
    AzkarService.instance.incrementAzkarCount(widget.category.id, azkar.id);
    
    final updatedAzkar = widget.category.azkar.firstWhere((a) => a.id == azkar.id);
    if (updatedAzkar.isCompleted) {
      HapticFeedback.heavyImpact();
    }
    
    _progressController.forward().then((_) {
      _progressController.reverse();
    });
  }

  void _copyZikr(String text) {
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم نسخ الذكر',
          style: GoogleFonts.tajawal(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
          ),
        ),
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFE3F2FD) : Theme.of(context).primaryColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _resetCounters() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'إعادة تعيين العدادات',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.w600),
        ),
        content: Text('هل تريد إعادة تعيين جميع العدادات في ${widget.category.title}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('إلغاء', style: GoogleFonts.tajawal()),
          ),
          ElevatedButton(
            onPressed: () {
              AzkarService.instance.resetCategoryCounters(widget.category.id);
              Navigator.of(context).pop();
            },
            child: Text('إعادة تعيين', style: GoogleFonts.tajawal(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حجم الخط', style: GoogleFonts.tajawal(fontWeight: FontWeight.w600)),
        content: StatefulBuilder(
          builder: (context, dialogSetState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${_fontSize.toInt()}', style: GoogleFonts.tajawal(fontSize: 24)),
                Slider(
                  value: _fontSize,
                  min: 12.0,
                  max: 28.0,
                  divisions: 16,
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
            onPressed: () {
              _saveSettings();
              Navigator.of(context).pop();
            },
            child: Text('حفظ', style: GoogleFonts.tajawal(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.category.title,
          style: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(onPressed: _resetCounters, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _showFontSizeDialog, icon: const Icon(Icons.text_fields)),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppConstants.darkBackgroundColor, AppConstants.darkSurfaceColor]
                : [AppConstants.backgroundColor, AppConstants.surfaceColor],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // --- Progress Overview (Header) ---
              Container(
                margin: const EdgeInsets.all(16.0),
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                ),
                child: StreamBuilder<List<AzkarCategory>>(
                  stream: AzkarService.instance.categoriesStream,
                  builder: (context, snapshot) {
                    AzkarCategory currentCategory = (snapshot.hasData && snapshot.data!.isNotEmpty)
                        ? snapshot.data!.firstWhere((cat) => cat.id == widget.category.id, orElse: () => widget.category)
                        : widget.category;
                    
                    return Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('التقدم الإجمالي', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w500)),
                            Text(
                              '${currentCategory.totalCompleted} / ${currentCategory.totalCount}',
                              style: GoogleFonts.tajawal(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: isDark ? const Color(0xFF64B5F6) : Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: currentCategory.overallProgress,
                          backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? const Color(0xFF64B5F6) : Theme.of(context).primaryColor,
                          ),
                          minHeight: 8,
                        ),
                      ],
                    );
                  },
                ),
              ),
              Expanded(child: _buildSimpleAzkarList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleAzkarList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: widget.category.azkar.length,
      itemBuilder: (context, index) => _buildAzkarCard(widget.category.azkar[index], index),
    );
  }

  Widget _buildAzkarCard(Azkar azkar, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: azkar.isCompleted 
            ? (isDark ? Colors.green.withOpacity(0.15) : Colors.green.withOpacity(0.1))
            : Theme.of(context).cardColor,
        border: Border.all(
          color: azkar.isCompleted ? (isDark ? Colors.greenAccent.withOpacity(0.5) : Colors.green.withOpacity(0.3)) : Colors.transparent,
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  azkar.text,
                  style: GoogleFonts.amiri(
                    fontSize: _fontSize,
                    height: 1.8,
                    fontWeight: FontWeight.w600,
                    color: azkar.isCompleted 
                        ? (isDark ? Colors.greenAccent : Colors.green.shade700)
                        : Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('التقدم', style: GoogleFonts.tajawal(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: azkar.progress,
                            backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              azkar.isCompleted 
                                  ? (isDark ? Colors.greenAccent : Colors.green)
                                  : (isDark ? const Color(0xFF64B5F6) : Theme.of(context).primaryColor),
                            ),
                            minHeight: 6,
                          ),
                          const SizedBox(height: 6),
                          // --- Improved Visibility for Counter Text ---
                          Text(
                            '${azkar.currentCount ?? 0} / ${azkar.target}',
                            style: GoogleFonts.tajawal(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: azkar.isCompleted 
                                  ? (isDark ? Colors.greenAccent : Colors.green)
                                  : (isDark ? const Color(0xFFE3F2FD) : Theme.of(context).primaryColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => _incrementZikr(azkar),
                      child: AnimatedBuilder(
                        animation: _progressAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1.0 + (_progressAnimation.value * 0.1),
                            child: Container(
                              width: 60, height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: azkar.isCompleted
                                    ? LinearGradient(colors: [Colors.green.shade400, Colors.green.shade600])
                                    : AppConstants.primaryGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: azkar.isCompleted
                                        ? Colors.green.withOpacity(0.4)
                                        : Theme.of(context).primaryColor.withOpacity(0.3),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '${azkar.currentCount ?? 0}',
                                  style: GoogleFonts.tajawal(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _copyZikr(azkar.text),
                      icon: const Icon(Icons.copy, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}