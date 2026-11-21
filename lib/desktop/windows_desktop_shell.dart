import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';

import '../features/athan/services/athan_manager.dart';
import '../features/audio/services/audio_handler.dart';
import '../providers/settings_provider.dart';
import '../screens/azkar_screen.dart';
import '../screens/allah_names_page.dart';
import '../screens/radio_page.dart';
import '../screens/calendar_page.dart';
import '../screens/hadith_library_page.dart';
import '../screens/fiqh_library_page.dart';
import '../screens/encyclopedia_screen.dart';
import '../features/quran_madinah/ui/index_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/tasbih_screen.dart';
import '../features/audio/screens/audio_reciters_screen.dart';
import 'windows_desktop_home.dart';

/// Navigation item model for Windows Desktop Sidebar.
class _DesktopNavItem {
  final String title;
  final IconData icon;
  final IconData activeIcon;

  const _DesktopNavItem({
    required this.title,
    required this.icon,
    required this.activeIcon,
  });
}

/// Navigator observer to track nested detail route push/pop events in desktop shell.
class _ShellNavigatorObserver extends NavigatorObserver {
  final VoidCallback onNavigationChanged;
  _ShellNavigatorObserver({required this.onNavigationChanged});

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) => onNavigationChanged());
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) => onNavigationChanged());
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) => onNavigationChanged());
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) => onNavigationChanged());
  }
}

/// The Main Application Shell for Windows Desktop.
/// Features a native RTL right-hand sidebar, clean header bar with Zaad identity,
/// responsive layout adapting to any desktop window size, and zero mobile navigation artifacts.
class WindowsDesktopShell extends StatefulWidget {
  const WindowsDesktopShell({super.key});

  @override
  State<WindowsDesktopShell> createState() => _WindowsDesktopShellState();
}

class _WindowsDesktopShellState extends State<WindowsDesktopShell> {
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;

  final GlobalKey<NavigatorState> _contentNavKey = GlobalKey<NavigatorState>();
  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(0);
  final List<int> _history = [];
  late final _ShellNavigatorObserver _navigatorObserver;

  late final List<Widget> _destinations;

  static const List<_DesktopNavItem> _navItems = [
    _DesktopNavItem(
      title: 'الرئيسية والمواقيت',
      icon: Icons.mosque_outlined,
      activeIcon: Icons.mosque_rounded,
    ),
    _DesktopNavItem(
      title: 'القرآن الكريم',
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book_rounded,
    ),
    _DesktopNavItem(
      title: 'الأذكار',
      icon: Icons.auto_stories_outlined,
      activeIcon: Icons.auto_stories_rounded,
    ),
    _DesktopNavItem(
      title: 'مكتبة الحديث',
      icon: Icons.format_quote_outlined,
      activeIcon: Icons.format_quote_rounded,
    ),
    _DesktopNavItem(
      title: 'الفقه الإسلامي',
      icon: Icons.gavel_outlined,
      activeIcon: Icons.gavel_rounded,
    ),
    _DesktopNavItem(
      title: 'الموسوعة الإسلامية',
      icon: Icons.history_edu_outlined,
      activeIcon: Icons.history_edu_rounded,
    ),
    _DesktopNavItem(
      title: 'التقويم والمناسبات',
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month_rounded,
    ),
    _DesktopNavItem(
      title: 'المسبحة الإلكترونية',
      icon: Icons.fingerprint_outlined,
      activeIcon: Icons.fingerprint_rounded,
    ),
    _DesktopNavItem(
      title: 'الصوتيات والقراء',
      icon: Icons.library_music_outlined,
      activeIcon: Icons.library_music_rounded,
    ),
    _DesktopNavItem(
      title: 'إذاعة القرآن',
      icon: Icons.radio_outlined,
      activeIcon: Icons.radio_rounded,
    ),
    _DesktopNavItem(
      title: 'أسماء الله الحسنى',
      icon: Icons.auto_awesome_outlined,
      activeIcon: Icons.auto_awesome_rounded,
    ),
    _DesktopNavItem(
      title: 'الإعدادات',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _navigatorObserver = _ShellNavigatorObserver(
      onNavigationChanged: () {
        if (mounted) {
          setState(() {});
        }
      },
    );

    _destinations = [
      WindowsDesktopHome(
        onNavigateToSection: _navigateToSection,
      ),
      const IndexScreen(),
      const AzkarScreenWidget(),
      const HadithLibraryPage(),
      const FiqhLibraryPage(),
      const EncyclopediaScreen(),
      const CalendarPage(),
      const TasbihScreen(),
      const AudioRecitersScreen(),
      const RadioPage(),
      const AllahNamesPage(),
      SettingsScreen(
        onSettingsSaved: () {
          if (mounted) {
            _navigateToSection(0);
          }
        },
      ),
    ];
  }

  @override
  void dispose() {
    _selectedIndexNotifier.dispose();
    super.dispose();
  }

  bool get _canGoBack {
    final bool canPopNested = _contentNavKey.currentState?.canPop() ?? false;
    return canPopNested || _history.isNotEmpty || _selectedIndex != 0;
  }

  void _handleBack() {
    if (!_canGoBack) return;

    // 1. Nested navigation first (detail screens / pushed routes)
    if (_contentNavKey.currentState?.canPop() ?? false) {
      _contentNavKey.currentState?.pop();
      return;
    }

    // 2. Main page history
    if (_history.isNotEmpty) {
      final prevIndex = _history.removeLast();
      _selectedIndexNotifier.value = prevIndex;
      setState(() {
        _selectedIndex = prevIndex;
      });
      return;
    }

    // 3. Fallback: if not on Dashboard, return to Dashboard (Rule 5)
    if (_selectedIndex != 0) {
      _selectedIndexNotifier.value = 0;
      setState(() {
        _selectedIndex = 0;
      });
      return;
    }

    // 4. On Dashboard with no history: do nothing, never close the app (Rules 6 & 7)
  }

  void _navigateToSection(int index) {
    if (!mounted || index < 0 || index >= _navItems.length) return;
    if (_selectedIndex == index) {
      // Pop any nested routes back to root of current section
      if (_contentNavKey.currentState?.canPop() ?? false) {
        _contentNavKey.currentState?.popUntil((route) => route.isFirst);
      }
      return;
    }

    // Pop any open detail screen before switching section
    if (_contentNavKey.currentState?.canPop() ?? false) {
      _contentNavKey.currentState?.popUntil((route) => route.isFirst);
    }

    setState(() {
      // Avoid loops: remove any existing occurrence of target section
      _history.removeWhere((item) => item == index);
      // Record current section into history
      _history.add(_selectedIndex);
      _selectedIndex = index;
    });
    _selectedIndexNotifier.value = index;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () {
          if (_canGoBack) _handleBack();
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): () {
          if (_canGoBack) _handleBack();
        },
        const SingleActivator(LogicalKeyboardKey.browserBack): () {
          if (_canGoBack) _handleBack();
        },
      },
      child: Focus(
        autofocus: true,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              if (_canGoBack) {
                _handleBack();
              }
            },
            child: Scaffold(
              backgroundColor: isDark
                  ? const Color(0xFF121212)
                  : const Color(0xFFF4F6F9),
              body: LayoutBuilder(
                builder: (context, constraints) {
                  final autoCollapse = constraints.maxWidth < 950;
                  final isCollapsed = _isSidebarCollapsed || autoCollapse;

                  return Row(
                    children: [
                      // 1. Right-side RTL Navigation Sidebar
                      _buildSidebar(context, isDark, primaryColor, isCollapsed, autoCollapse),

                      // 2. Main Content Area filling remaining width
                      Expanded(
                        child: Column(
                          children: [
                            // Desktop Header Bar with Zaad identity & current page title
                            _buildDesktopHeader(context, isDark),

                            // Main Content Area with nested Navigator support
                            Expanded(
                              child: Navigator(
                                key: _contentNavKey,
                                observers: [_navigatorObserver],
                                onGenerateRoute: (settings) {
                                  return MaterialPageRoute(
                                    builder: (context) {
                                      return ValueListenableBuilder<int>(
                                        valueListenable: _selectedIndexNotifier,
                                        builder: (context, selectedIndex, _) {
                                          return IndexedStack(
                                            index: selectedIndex,
                                            children: _destinations,
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              // Emergency Athan Alert if playing
              floatingActionButton: StreamBuilder<MediaItem?>(
                stream: audioHandler?.mediaItem,
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data?.id == 'athan_alert') {
                    return FloatingActionButton.extended(
                      onPressed: () => AthanManager.stopAthan(),
                      backgroundColor: Colors.redAccent,
                      icon: const Icon(
                        Icons.stop_circle_outlined,
                        color: Colors.white,
                      ),
                      label: Text(
                        'إيقاف الأذان',
                        style: GoogleFonts.tajawal(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sidebar Implementation
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSidebar(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    bool isCollapsed,
    bool autoCollapse,
  ) {
    final sidebarWidth = isCollapsed ? 76.0 : 250.0;
    const accentGold = Color(0xFFD4AF37);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181B1E) : Colors.white,
        border: Border(
          left: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Sidebar Brand Header
          _buildBrandHeader(isDark, isCollapsed),

          const Divider(height: 1, thickness: 0.8),

          // 2. Navigation Items List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                final item = _navItems[index];
                final isSelected = _selectedIndex == index;

                return _buildNavItemTile(
                  item: item,
                  isSelected: isSelected,
                  isCollapsed: isCollapsed,
                  isDark: isDark,
                  accentGold: accentGold,
                  onTap: () => _navigateToSection(index),
                );
              },
            ),
          ),

          const Divider(height: 1, thickness: 0.8),

          // 3. Sidebar Footer: Theme Mode & Collapse toggle
          _buildSidebarFooter(context, isDark, isCollapsed, autoCollapse),
        ],
      ),
    );
  }

  Widget _buildBrandHeader(bool isDark, bool isCollapsed) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 12 : 18,
        vertical: 8,
      ),
      alignment: Alignment.center,
      child: isCollapsed
          ? Tooltip(
              message: 'زاد • المرجع الإسلامي الشامل',
              child: Image.asset(
                'assets/images/app_icon.png',
                height: 38,
                fit: BoxFit.contain,
              ),
            )
          : Row(
              children: [
                Image.asset(
                  'assets/images/app_icon.png',
                  height: 38,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'زاد',
                        style: GoogleFonts.tajawal(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFD4AF37),
                          letterSpacing: 0.5,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'المواقيت والقرآن الكريم',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.tajawal(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : const Color(0xFF546E7A),
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildNavItemTile({
    required _DesktopNavItem item,
    required bool isSelected,
    required bool isCollapsed,
    required bool isDark,
    required Color accentGold,
    required VoidCallback onTap,
  }) {
    final activeBg = isDark
        ? accentGold.withValues(alpha: 0.18)
        : const Color(0xFFFFF8E1);

    final activeColor = isDark ? accentGold : const Color(0xFFB8860B);
    final inactiveColor = isDark ? Colors.white70 : const Color(0xFF546E7A);

    final content = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: EdgeInsets.symmetric(
            horizontal: isCollapsed ? 10 : 14,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(
                    color: accentGold.withValues(alpha: 0.4),
                    width: 0.8,
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment:
                isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(
                isSelected ? item.activeIcon : item.icon,
                size: 22,
                color: isSelected ? activeColor : inactiveColor,
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.tajawal(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected
                          ? (isDark ? Colors.white : const Color(0xFF1E2428))
                          : inactiveColor,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 5,
                    height: 18,
                    decoration: BoxDecoration(
                      color: accentGold,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );

    if (isCollapsed) {
      return Tooltip(
        message: item.title,
        preferBelow: false,
        child: content,
      );
    }
    return content;
  }

  Widget _buildSidebarFooter(
    BuildContext context,
    bool isDark,
    bool isCollapsed,
    bool autoCollapse,
  ) {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 8 : 12,
        vertical: 8,
      ),
      child: isCollapsed
          ? Column(
              children: [
                IconButton(
                  icon: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    color: isDark ? const Color(0xFFD4AF37) : Colors.black87,
                    size: 20,
                  ),
                  tooltip: isDark ? 'الوضع الفاتح' : 'الوضع الداكن',
                  onPressed: () {
                    settingsProvider.setThemeMode(
                      isDark ? AppThemeMode.light : AppThemeMode.dark,
                    );
                  },
                ),
                if (!autoCollapse)
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                    ),
                    tooltip: 'توسيع القائمة',
                    onPressed: () {
                      setState(() => _isSidebarCollapsed = false);
                    },
                  ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      settingsProvider.setThemeMode(
                        isDark ? AppThemeMode.light : AppThemeMode.dark,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isDark
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                            color: isDark
                                ? const Color(0xFFD4AF37)
                                : Colors.black87,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isDark ? 'الوضع الفاتح' : 'الوضع الداكن',
                              style: GoogleFonts.tajawal(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!autoCollapse)
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                    ),
                    tooltip: 'طي القائمة',
                    onPressed: () {
                      setState(() => _isSidebarCollapsed = true);
                    },
                  ),
              ],
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Desktop Header Implementation
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDesktopHeader(BuildContext context, bool isDark) {
    final currentTitle = _navItems[_selectedIndex].title;
    final currentIcon = _navItems[_selectedIndex].activeIcon;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181B1E) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // 1. Global Back Button
          _buildBackButton(context, isDark),

          const SizedBox(width: 14),

          // 2. Section Icon & Title
          Icon(
            currentIcon,
            color: const Color(0xFFD4AF37),
            size: 22,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              currentTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.tajawal(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF263238),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Spacer(),
          // App title branding indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.desktop_windows_rounded,
                  size: 14,
                  color: Color(0xFFD4AF37),
                ),
                const SizedBox(width: 6),
                Text(
                  'زاد • نسخة سطح المكتب',
                  style: GoogleFonts.tajawal(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFD4AF37),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Global Back Button Implementation
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBackButton(BuildContext context, bool isDark) {
    final canGoBack = _canGoBack;
    const accentGold = Color(0xFFD4AF37);

    final Color iconColor = canGoBack
        ? (isDark ? Colors.white : const Color(0xFF263238))
        : (isDark
            ? Colors.white.withValues(alpha: 0.22)
            : Colors.black.withValues(alpha: 0.22));

    final Color borderColor = canGoBack
        ? (isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.12))
        : (isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.04));

    final Color bgColor = canGoBack
        ? (isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03))
        : Colors.transparent;

    // Directional arrow: in RTL (Arabic), back points right (->)
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final IconData backIcon = isRtl
        ? Icons.arrow_forward_rounded
        : Icons.arrow_back_rounded;

    return Semantics(
      label: 'رجوع للصفحة السابقة',
      button: true,
      enabled: canGoBack,
      child: Tooltip(
        message: canGoBack ? 'رجوع' : 'لا يوجد صفحة سابقة',
        preferBelow: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: canGoBack ? _handleBack : null,
            hoverColor: canGoBack
                ? accentGold.withValues(alpha: isDark ? 0.15 : 0.08)
                : Colors.transparent,
            splashColor: canGoBack
                ? accentGold.withValues(alpha: 0.25)
                : Colors.transparent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: borderColor,
                  width: 1,
                ),
              ),
              child: Center(
                child: Icon(
                  backIcon,
                  size: 20,
                  color: iconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
