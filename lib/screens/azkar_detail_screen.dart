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
    
    print('🔄 AzkarDetailScreen: initState for category: ${widget.category.title}');
    print('📊 Category data: ${widget.category.azkar.length} azkar');
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
      print('❌ Error loading Azkar settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('azkar_font_size', _fontSize);
    } catch (e) {
      print('❌ Error saving Azkar settings: $e');
    }
  }

  void _incrementZikr(Azkar azkar) {
    if (azkar.isCompleted) return;
    
    HapticFeedback.lightImpact();
    
    // Update local state immediately for instant UI feedback
    setState(() {
      // Find and update the azkar in the current category
      final categoryIndex = widget.category.azkar.indexWhere((a) => a.id == azkar.id);
      if (categoryIndex != -1) {
        widget.category.azkar[categoryIndex] = azkar.incrementCount();
      }
    });
    
    // Also update the service for persistence
    AzkarService.instance.incrementAzkarCount(widget.category.id, azkar.id);
    
    // Check if target reached
    final updatedAzkar = widget.category.azkar.firstWhere((a) => a.id == azkar.id);
    if (updatedAzkar.isCompleted) {
      HapticFeedback.heavyImpact();
    }
    
    // Animate progress
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
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black
                : Colors.white,
          ),
        ),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFE0E0E0)
            : Theme.of(context).primaryColor,
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
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFFE0E0E0)
                : null,
          ),
        ),
        backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? const Color(0xFF2A2A2A)
            : null,
        content: Text(
          'هل أنت متأكد من أنك تريد إعادة تعيين جميع العدادات في ${widget.category.title}؟',
          style: GoogleFonts.tajawal(
            color: Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFFBDBDBD)
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'إلغاء',
              style: GoogleFonts.tajawal(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF64B5F6)
                    : Theme.of(context).primaryColor,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              AzkarService.instance.resetCategoryCounters(widget.category.id);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E88E5)
                  : Theme.of(context).primaryColor,
            ),
            child: Text(
              'إعادة تعيين',
              style: GoogleFonts.tajawal(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'حجم الخط',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.w600,
          ),
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
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? const Color(0xFFE0E0E0)
                        : null,
                  ),
                ),
                const SizedBox(height: 20),
                Slider(
                  value: _fontSize,
                  min: 12.0,
                  max: 28.0,
                  divisions: 16,
                  activeColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF64B5F6)
                      : Theme.of(context).primaryColor,
                  inactiveColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF424242)
                      : null,
                  thumbColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF64B5F6)
                      : Theme.of(context).primaryColor,
                  onChanged: (value) {
                    dialogSetState(() {
                      _fontSize = value;
                    });
                    // Update the main page state
                    setState(() {
                      _fontSize = value;
                    });
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'إلغاء',
              style: GoogleFonts.tajawal(
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _saveSettings();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
            ),
            child: Text(
              'حفظ',
              style: GoogleFonts.tajawal(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.category.title,
          style: GoogleFonts.tajawal(
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(),
        actions: [
          IconButton(
            onPressed: _resetCounters,
            icon: const Icon(Icons.refresh),
            tooltip: 'إعادة تعيين العدادات',
          ),
          IconButton(
            onPressed: _showFontSizeDialog,
            icon: const Icon(Icons.text_fields),
            tooltip: 'حجم الخط',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: Theme.of(context).brightness == Brightness.dark
                ? [AppConstants.darkBackgroundColor, AppConstants.darkSurfaceColor]
                : [AppConstants.backgroundColor, AppConstants.surfaceColor],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Progress overview
              Container(
                margin: const EdgeInsets.all(16.0),
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: StreamBuilder<List<AzkarCategory>>(
                  stream: AzkarService.instance.categoriesStream,
                  builder: (context, snapshot) {
                    // Get current category from service data
                    AzkarCategory currentCategory;
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      currentCategory = snapshot.data!.firstWhere(
                        (cat) => cat.id == widget.category.id,
                        orElse: () => widget.category,
                      );
                    } else {
                      // Fallback to widget category if stream has no data
                      currentCategory = widget.category;
                    }
                    
                    return Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'التقدم الإجمالي',
                              style: GoogleFonts.tajawal(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${currentCategory.totalCompleted} / ${currentCategory.totalCount}',
                              style: GoogleFonts.tajawal(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: currentCategory.overallProgress,
                          backgroundColor: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Theme.of(context).primaryColor,
                          ),
                          minHeight: 8,
                        ),
                      ],
                    );
                  },
                ),
              ),
              
              // Azkar list
              Expanded(
                child: _buildSimpleAzkarList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAzkarList() {
    // Try StreamBuilder first, but fallback to direct data if needed
    return StreamBuilder<List<AzkarCategory>>(
      stream: AzkarService.instance.categoriesStream,
      builder: (context, snapshot) {
        print('🔄 AzkarDetailScreen _buildAzkarList StreamBuilder state: hasData=${snapshot.hasData}');
        
        // If Stream has data, use it
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final categories = snapshot.data!;
          final currentCategory = categories.firstWhere(
            (cat) => cat.id == widget.category.id,
            orElse: () => widget.category,
          );
          
          print('📊 Using Stream data: Category "${currentCategory.title}" has ${currentCategory.azkar.length} azkar');
          
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: currentCategory.azkar.length,
            itemBuilder: (context, index) {
              final azkar = currentCategory.azkar[index];
              return _buildAzkarCard(azkar, index);
            },
          );
        }
        
        // Fallback to direct widget data
        print('⚠️ StreamBuilder fallback: Using widget.category directly');
        print('📊 Using fallback data: Category "${widget.category.title}" has ${widget.category.azkar.length} azkar');
        
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          itemCount: widget.category.azkar.length,
          itemBuilder: (context, index) {
            final azkar = widget.category.azkar[index];
            return _buildAzkarCard(azkar, index);
          },
        );
      },
    );
  }
  
  // Fallback simple list view for testing
  Widget _buildSimpleAzkarList() {
    print('🔄 AzkarDetailScreen: Building simple list with ${widget.category.azkar.length} items');
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: widget.category.azkar.length,
      itemBuilder: (context, index) {
        final azkar = widget.category.azkar[index];
        return _buildAzkarCard(azkar, index);
      },
    );
  }

  Widget _buildAzkarCard(Azkar azkar, int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: azkar.isCompleted 
            ? Colors.green.withOpacity(0.1)
            : Theme.of(context).cardColor,
        border: Border.all(
          color: azkar.isCompleted 
              ? Colors.green.withOpacity(0.3)
              : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: azkar.isCompleted
                ? Colors.green.withOpacity(0.2)
                : Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: 10,
            sigmaY: 10,
          ),
          child: Container(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Azkar text
                Text(
                  azkar.text,
                  style: GoogleFonts.amiri(
                    fontSize: _fontSize,
                    height: 1.8,
                    fontWeight: FontWeight.w600,
                    color: azkar.isCompleted 
                        ? Colors.green.shade700
                        : Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  textAlign: TextAlign.right,
                ),
                
                const SizedBox(height: 20),
                
                // Progress and controls
                Row(
                  children: [
                    // Progress indicator
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'التقدم',
                            style: GoogleFonts.tajawal(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: azkar.progress,
                            backgroundColor: Colors.grey.withOpacity(0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              azkar.isCompleted ? Colors.green : Theme.of(context).primaryColor,
                            ),
                            minHeight: 6,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${azkar.currentCount ?? 0} / ${azkar.target}',
                            style: GoogleFonts.tajawal(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: azkar.isCompleted ? Colors.green : Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Counter button
                    GestureDetector(
                      onTap: () => _incrementZikr(azkar),
                      child: AnimatedBuilder(
                        animation: _progressAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1.0 + (_progressAnimation.value * 0.1),
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: azkar.isCompleted
                                    ? LinearGradient(
                                        colors: [Colors.green.shade400, Colors.green.shade600],
                                      )
                                    : AppConstants.primaryGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: azkar.isCompleted
                                        ? Colors.green.withOpacity(0.4)
                                        : Theme.of(context).primaryColor.withOpacity(0.4),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Text(
                                      '${azkar.currentCount ?? 0}',
                                      style: GoogleFonts.tajawal(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  if (azkar.isCompleted)
                                    const Positioned(
                                      top: 2,
                                      right: 2,
                                      child: Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Action buttons
                    Column(
                      children: [
                        IconButton(
                          onPressed: () => _copyZikr(azkar.text),
                          icon: const Icon(Icons.copy),
                          tooltip: 'نسخ',
                          iconSize: 20,
                        ),
                      ],
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
