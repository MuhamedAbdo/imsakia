import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/azkar.dart';
import '../services/azkar_service.dart';
import '../utils/app_constants.dart';
import 'azkar_detail_screen.dart';

class AzkarScreenWidget extends StatefulWidget {
  const AzkarScreenWidget({super.key});

  @override
  State<AzkarScreenWidget> createState() => _AzkarScreenState();
}

class _AzkarScreenState extends State<AzkarScreenWidget> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAzkar();
  }

  Future<void> _initializeAzkar() async {
    try {
      if (AzkarService.instance.isInitialized) {
        setState(() => _isLoading = false);
        return;
      }

      await AzkarService.instance.initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          setState(() => _isLoading = false);
        },
      );

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToDetail(AzkarCategory category) async {
    HapticFeedback.selectionClick();
    // ننتظر العودة من الشاشة
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AzkarDetailScreen(category: category),
      ),
    );
    // بمجرد العودة نحدّث الواجهة لتعكس القيم الجديدة من الـ Service
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color elementsColor = isDark ? Colors.white : Colors.black87;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'الأذكار',
            style: GoogleFonts.tajawal(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: elementsColor,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: const Color(0xFF546E7A)),
          leading: IconButton(
            onPressed: _showResetAllDialog,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تصفير جميع الأذكار',
          ),
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
          child: _isLoading
              ? _buildLoadingState()
              : SafeArea(child: _buildCategoriesGrid()),
        ),
      ),
    );
  }

  void _showResetAllDialog() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'تصفير جميع الأذكار',
            style: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'هل أنت متأكد من تصفير جميع عدادات الأذكار؟ لا يمكن التراجع عن هذه الخطوة.',
            style: GoogleFonts.tajawal(),
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
              onPressed: () async {
                await AzkarService.instance.resetAllCounters();
                if (context.mounted) {
                  Navigator.of(context).pop();
                  setState(() {}); // تحديث الشبكة بعد التصفير
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'تصفير الآن',
                style: GoogleFonts.tajawal(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.auto_stories,
            size: 60,
            color: AppConstants.primaryColor,
          ),
          const SizedBox(height: 20),
          Text(
            'جاري تحميل الأذكار...',
            style: GoogleFonts.tajawal(fontSize: 18),
          ),
          const SizedBox(height: 20),
          const CircularProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildCategoriesGrid() {
    return StreamBuilder<List<AzkarCategory>>(
      stream: AzkarService.instance.categoriesStream,
      builder: (context, snapshot) {
        final categories = snapshot.hasData
            ? snapshot.data!
            : AzkarService.instance.categories;

        if (categories.isEmpty) {
          return _buildEmptyState();
        }

        return GridView.builder(
          padding: const EdgeInsets.all(20.0),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 20.0,
            mainAxisSpacing: 20.0,
            childAspectRatio: 0.95,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) => CategoryCardWidget(
            category: categories[index],
            onTap: () => _navigateToDetail(categories[index]),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 60, color: Colors.grey),
          const SizedBox(height: 20),
          Text('لا توجد أذكار متاحة', style: GoogleFonts.tajawal(fontSize: 18)),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _initializeAzkar,
            child: Text('إعادة المحاولة', style: GoogleFonts.tajawal()),
          ),
        ],
      ),
    );
  }
}

class CategoryCardWidget extends StatefulWidget {
  final AzkarCategory category;
  final VoidCallback onTap;

  const CategoryCardWidget({
    super.key,
    required this.category,
    required this.onTap,
  });

  @override
  State<CategoryCardWidget> createState() => _CategoryCardWidgetState();
}

class _CategoryCardWidgetState extends State<CategoryCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.05,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    final bool isHajjCategory =
        category.id == 'hajj_umrah' || category.title.contains('الحج');
    final bool isDuasCategory =
        category.id == 'daily_duas' || category.title.contains('الدعاء');

    String? assetPath;
    if (isHajjCategory) assetPath = 'assets/images/kaaba.png';
    if (isDuasCategory) assetPath = 'assets/images/duas.png';

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [category.color.withValues(alpha: 0.85), category.color],
            ),
            boxShadow: [
              BoxShadow(
                color: category.color.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.1),
              width: 0.8,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(24),
              splashColor: Colors.white.withValues(alpha: 0.2),
              highlightColor: Colors.white.withValues(alpha: 0.1),
              child: Stack(
                children: [
                  Positioned(
                    left: -10,
                    bottom: -10,
                    child: assetPath != null
                        ? Opacity(
                            opacity: 0.15,
                            child: Image.asset(
                              assetPath,
                              width: 90,
                              height: 90,
                              color: Colors.white,
                              colorBlendMode: BlendMode.srcIn,
                            ),
                          )
                        : Icon(
                            category.icon,
                            size: 80,
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                          child: assetPath != null
                              ? Image.asset(assetPath, width: 30, height: 30)
                              : Icon(
                                  category.icon,
                                  size: 30,
                                  color: Colors.white,
                                ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          category.title,
                          style: GoogleFonts.tajawal(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: category.overallProgress,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            minHeight: 4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${category.totalCompleted} / ${category.totalCount}',
                          style: GoogleFonts.tajawal(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                          textDirection: TextDirection.ltr,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
