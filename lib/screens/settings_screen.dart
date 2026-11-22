import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/font_settings_provider.dart';
import '../features/athan/providers/athan_provider.dart';
import '../features/athan_library/providers/athan_library_provider.dart';
import '../features/athan_library/ui/athan_library_screen.dart';
import '../services/prayer_times_service.dart';
import '../widgets/neumorphic_box.dart';
import '../features/audio/services/audio_handler.dart';
import '../services/permissions_service.dart';
import '../widgets/custom_localized_picker.dart';
import '../desktop/services/windows_desktop_service.dart';
import '../desktop/services/windows_athan_service.dart';

class SettingsScreen extends StatefulWidget {
  final bool isFirstTimeSetup;
  final VoidCallback? onSettingsSaved;
  const SettingsScreen({
    super.key,
    this.isFirstTimeSetup = false,
    this.onSettingsSaved,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  late SettingsProvider _settingsProvider;
  String? _selectedCountry;
  String? _selectedState;
  int _tempAdjustment = 0; // عداد مؤقت يظهر للمستخدم فقط
  bool _windowsAutoStartEnabled = false;

  // ⏱️ التعديلات اليدوية المؤقتة (Staged Calibration)
  PrayerCalibrationMode _stagedCalibrationMode = PrayerCalibrationMode.global;
  int _stagedGlobalOffset = 0;
  Map<String, int> _stagedPrayerOffsets = {
    'fajr': 0,
    'dhuhr': 0,
    'asr': 0,
    'maghrib': 0,
    'isha': 0,
  };
  // الأقسام المفتوحة افتراضياً في الأكورديون (مغلقة افتراضياً)
  final Set<int> _expandedSections = {};

  Map<String, bool> _permissionStatuses = {};

  final Map<String, String> _calculationMethods = {
    'egyptian': 'الهيئة المصرية العامة للمساحة',
    'turkey': 'رئاسة الشؤون الدينية التركية (Diyanet)',
    'karachi': 'جامعة العلوم الإسلامية بكراتشي',
    'umm_al_qura': 'جامعة أم القرى، مكة المكرمة',
    'muslim_world_league': 'رابطة العالم الإسلامي',
    'north_america': 'الجمعية الإسلامية لأمريكا الشمالية',
    'dubai': 'دبي (الإمارات)',
    'kuwait': 'الكويت',
    'qatar': 'قطر',
  };

  @override
  void initState() {
    super.initState();
    _settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    _loadSavedLocation();
    _stagedCalibrationMode = _settingsProvider.prayerCalibrationMode;
    _stagedGlobalOffset = _settingsProvider.prayerOffsetGlobal;
    _stagedPrayerOffsets = Map<String, int>.from(
      _settingsProvider.prayerIndividualOffsets,
    );

    // 🔥 ضمان مزامنة الـ Switch مع حالة نظام أندرويد من اللحظة الأولى
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final platformBrightness = MediaQuery.platformBrightnessOf(context);
        if (_settingsProvider.themeMode == AppThemeMode.system) {
          final isDark = platformBrightness == Brightness.dark;
          _settingsProvider.setThemeMode(
            isDark ? AppThemeMode.dark : AppThemeMode.light,
          );
        }
      }
    });

    // تحميل المؤذنين (الآن عبر الأصول الثابتة، لا يحتاج انتظار)
    Provider.of<AthanProvider>(context, listen: false);

    WidgetsBinding.instance.addObserver(this);
    _refreshPermissionStatuses();
    if (Platform.isWindows) {
      WindowsDesktopService.instance.isAutoStartEnabled().then((enabled) {
        if (mounted) setState(() => _windowsAutoStartEnabled = enabled);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissionStatuses();
    }
  }

  Future<void> _refreshPermissionStatuses() async {
    final statuses = await PermissionsService.checkAllPermissions();
    if (mounted) {
      setState(() {
        _permissionStatuses = statuses;
      });
    }
  }

  void _loadSavedLocation() {
    final savedLocation = _settingsProvider.selectedCityName;
    if (savedLocation.contains(',')) {
      final parts = savedLocation.split(',');
      if (parts.length >= 2) {
        setState(() {
          _selectedState = parts[0].trim();
          _selectedCountry = parts[1].trim();
        });
      }
    }
  }

  // ignore: unused_element
  void _testPlayAthan(String prayerKey) async {
    if (Platform.isWindows) {
      if (WindowsAthanService.instance.isPlaying) {
        await WindowsAthanService.instance.stopAthan();
      } else {
        await WindowsAthanService.instance.playAthan(
          prayerKey: prayerKey,
          prayerName: 'تجربة',
          isTest: true,
        );
      }
      if (mounted) setState(() {});
      return;
    }

    if (audioHandler == null) {
      try {
        await initAudioService();
      } catch (e) {
        debugPrint("ATHAN TEST: Failed to init audioHandler: $e");
      }
    }

    // ✅ Guard: widget may have been disposed during await
    if (!mounted) return;

    if (audioHandler == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذّر تهيئة مشغل الصوت. أعد تشغيل التطبيق.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // ✅ All context reads are safe — mounted confirmed above
    final provider = Provider.of<AthanProvider>(context, listen: false);
    final state = audioHandler!.playbackState.value;
    final activeKey = audioHandler!.mediaItem.value?.extras?['activeTestKey'];
    final isPlayingThisKey = state.playing && activeKey == prayerKey;

    if (isPlayingThisKey) {
      await audioHandler!.stop();
    } else {
      // ✨ استخدم النسخة Async لتشغيل صوت المكتبة السحابية إن وُجد
      final path = await provider.getPathForPrayerWithCloudFallback(prayerKey);
      if (!mounted) return; // guard after await
      await audioHandler!.customAction('playAthan', {
        'path': path,
        'prayerName': 'تجربة',
        'activeTestKey': prayerKey,
      });
    }
  }

  void _autoSelectMethod(String country) {
    String method = 'muslim_world_league';
    if (country.contains("Egypt")) {
      method = 'egyptian';
    } else if (country.contains("Turkey")) {
      method = 'turkey';
    } else if (country.contains("Saudi Arabia")) {
      method = 'umm_al_qura';
    } else if (country.contains("United Arab Emirates")) {
      method = 'dubai';
    } else if (country.contains("Kuwait")) {
      method = 'kuwait';
    } else if (country.contains("Qatar")) {
      method = 'qatar';
    }
    _settingsProvider.setCalculationMethod(method);
  }

  Future<void> _saveSettings() async {
    if (widget.isFirstTimeSetup &&
        (_selectedState == null || _selectedCountry == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يرجى اختيار الدولة والمحافظة',
            style: GoogleFonts.tajawal(),
          ),
        ),
      );
      return;
    }

    try {
      if (_selectedState != null && _selectedCountry != null) {
        final fullLocation = "$_selectedState, $_selectedCountry";
        await _settingsProvider.setCity(fullLocation);

        try {
          List<Location> locations = await locationFromAddress(fullLocation);
          if (locations.isNotEmpty) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setDouble('last_lat', locations.first.latitude);
            await prefs.setDouble('last_lng', locations.first.longitude);
          }
        } catch (e) {
          debugPrint("Geocoding Error: $e");
        }
      }

      if (_tempAdjustment != 0) {
        await _settingsProvider.updateHijriAdjustment(_tempAdjustment);
        setState(() {
          _tempAdjustment = 0;
        });
      }

      // حفظ التعديلات اليدوية للمواقيت
      await _settingsProvider.savePrayerOffsets(
        mode: _stagedCalibrationMode,
        global: _stagedGlobalOffset,
        individual: _stagedPrayerOffsets,
      );

      if (widget.isFirstTimeSetup) {
        await _settingsProvider.setFirstLaunchComplete();
      }

      await PrayerTimesService.instance.getCurrentPrayerTimes();
      await PrayerTimesService.instance.scheduleAllPrayers();

      if (mounted) {
        if (widget.isFirstTimeSetup) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم ضبط المواقيت بنجاح حسب موقعك',
                style: GoogleFonts.tajawal(),
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/main', (route) => false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم حفظ الإعدادات بنجاح',
                style: GoogleFonts.tajawal(),
              ),
              backgroundColor: Colors.green,
            ),
          );
          if (widget.onSettingsSaved != null) {
            widget.onSettingsSaved!();
          }
        }
      }
    } catch (e) {
      debugPrint("Error saving settings: $e");
    }
  }

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
              : const Color(0xFFF8F9FA),
          appBar: widget.isFirstTimeSetup
              ? null
              : AppBar(
                  title: Text(
                    'إعدادات المواقيت',
                    style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                  ),
                  centerTitle: true,
                ),
          body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: Column(
                children: [
              if (widget.isFirstTimeSetup) _buildHeader(),
              // 1. الموقع الجغرافي
              _buildSection(
                sectionIndex: 0,
                title: 'الموقع الجغرافي',
                icon: Icons.location_on_rounded,
                children: [
                  CustomLocalizedPicker(
                    initialCountry: _selectedCountry,
                    initialState: _selectedState,
                    onSelectionChanged: (country, state) {
                      setState(() {
                        _selectedCountry = country;
                        _selectedState = state;
                        if (country != null) {
                          _autoSelectMethod(country);
                        }
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 15),
              // 2. الحساب الفقهي والوقت
              _buildSection(
                sectionIndex: 1,
                title: 'الحساب الفقهي والوقت',
                icon: Icons.access_time_rounded,
                children: [
                  _buildCalculationMethodSelector(),
                  const SizedBox(height: 15),
                  _buildMadhabSelector(),
                  const Divider(height: 30),
                  _buildDstToggle(),
                ],
              ),
              const SizedBox(height: 15),
              // 3. إعدادات الأذان
              _buildAthanSection(isDark),
              const SizedBox(height: 15),
              // 4. ضبط المواقيت يدوياً
              _buildManualCalibrationSection(isDark),
              const SizedBox(height: 15),
              // 5. الصلاحيات وإعدادات سطح المكتب
              if (Platform.isWindows) ...[
                _buildWindowsDesktopSettings(isDark),
                const SizedBox(height: 15),
              ] else ...[
                _buildPermissionsSection(),
                const SizedBox(height: 15),
              ],
              // 6. التقويم والمظهر
              _buildSection(
                sectionIndex: 5,
                title: 'التقويم والمظهر',
                icon: Icons.palette_outlined,
                children: [
                  _buildHijriAdjustmentControl(),
                  const Divider(height: 30),
                  _buildThemeSelector(isDark),
                ],
              ),
              const SizedBox(height: 15),
              // 7. إعدادات القراءة والخط
              _buildFontSettingsSection(isDark),
              const SizedBox(height: 30),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    ),
  ),
),
);
  }

  Widget _buildHijriAdjustmentControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('معايرة التاريخ الهجري', style: GoogleFonts.tajawal(fontSize: 15)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              onPressed: () => setState(() => _tempAdjustment--),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: _tempAdjustment == 0
                    ? Colors.grey.withValues(alpha: 0.1)
                    : Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _tempAdjustment == 0
                    ? "تلقائي"
                    : (_tempAdjustment > 0
                          ? "+$_tempAdjustment يوم"
                          : "$_tempAdjustment يوم"),
                style: GoogleFonts.tajawal(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: _tempAdjustment == 0 ? Colors.grey : Colors.green,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.green),
              onPressed: () => setState(() => _tempAdjustment++),
            ),
          ],
        ),
        if (_tempAdjustment != 0)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              "* سيتم تطبيق التعديل عند الضغط على حفظ",
              style: GoogleFonts.tajawal(fontSize: 11, color: Colors.orange),
            ),
          ),
      ],
    );
  }

  Widget _buildDstToggle() {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) => SwitchListTile(
        title: Text(
          'التوقيت الصيفي (+1 ساعة)',
          style: GoogleFonts.tajawal(fontSize: 15),
        ),
        subtitle: Text(
          'ملاحظة: فعّل هذا الخيار فقط إذا كانت مواقيت الصلاة متأخرة بساعة في هاتفك. الهواتف الحديثة تضبط الوقت تلقائياً ولا تحتاج لتفعيله.',
          style: GoogleFonts.tajawal(fontSize: 12, color: Colors.grey),
        ),
        value: settings.dstEnabled,
        activeThumbColor: Colors.green,
        onChanged: (val) {
          settings.setDST(val);
          PrayerTimesService.instance.getCurrentPrayerTimes();
        },
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildCalculationMethodSelector() {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) => DropdownButtonFormField<String>(
        initialValue: settings.selectedCalculationMethod,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'طريقة الحساب',
          labelStyle: GoogleFonts.tajawal(),
        ),
        items: _calculationMethods.entries
            .map(
              (e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value, style: GoogleFonts.tajawal(fontSize: 14)),
              ),
            )
            .toList(),
        onChanged: (val) {
          if (val != null) {
            settings.setCalculationMethod(val);
            PrayerTimesService.instance.getCurrentPrayerTimes();
          }
        },
      ),
    );
  }

  Widget _buildMadhabSelector() {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) => DropdownButtonFormField<String>(
        initialValue: settings.selectedMadhab,
        decoration: InputDecoration(
          labelText: 'مذهب صلاة العصر',
          labelStyle: GoogleFonts.tajawal(),
        ),
        items: const [
          DropdownMenuItem(
            value: 'shafi',
            child: Text('الجمهور (شافعي، مالكي، حنبلي)'),
          ),
          DropdownMenuItem(value: 'hanafi', child: Text('الحنفي')),
        ],
        onChanged: (val) {
          if (val != null) {
            settings.setMadhab(val);
          }
        },
      ),
    );
  }

  Widget _buildThemeSelector(bool isDark) {
    return Consumer2<SettingsProvider, ThemeProvider>(
      builder: (context, settings, theme, _) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "الوضع الداكن",
            style: GoogleFonts.tajawal(fontWeight: FontWeight.w500),
          ),
          Switch(
            value: settings.themeMode == AppThemeMode.dark,
            onChanged: (val) {
              final mode = val ? AppThemeMode.dark : AppThemeMode.light;
              settings.setThemeMode(mode);
              theme.syncWithSettingsProvider(mode);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFontSettingsSection(bool isDark) {
    return Consumer<FontSettingsProvider>(
      builder: (context, fontSettings, child) {
        final percentage = (fontSettings.fontScale * 100).round();
        final lineHeightVal = fontSettings.lineHeight;

        return _buildSection(
          sectionIndex: 6,
          title: 'إعدادات القراءة والخط',
          icon: Icons.format_size_rounded,
          children: [
            // Header with reset button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'حجم ونمط خطوط القراءة',
                    style: GoogleFonts.tajawal(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    softWrap: true,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => fontSettings.resetToDefault(),
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.green),
                  label: Text(
                    'استعادة الافتراضي',
                    style: GoogleFonts.tajawal(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 1. Font scale slider
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'حجم الخط',
                      style: GoogleFonts.tajawal(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$percentage%',
                        style: GoogleFonts.tajawal(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.green,
                    inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
                    thumbColor: Colors.green,
                    overlayColor: Colors.green.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: fontSettings.fontScale,
                    min: FontSettingsProvider.minFontScale,
                    max: FontSettingsProvider.maxFontScale,
                    divisions: 11,
                    onChanged: (val) => fontSettings.setFontScale(val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 2. Line height slider
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'التباعد بين الأسطر',
                      style: GoogleFonts.tajawal(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        lineHeightVal.toStringAsFixed(1),
                        style: GoogleFonts.tajawal(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.blue,
                    inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
                    thumbColor: Colors.blue,
                    overlayColor: Colors.blue.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: fontSettings.lineHeight,
                    min: FontSettingsProvider.minLineHeight,
                    max: FontSettingsProvider.maxLineHeight,
                    divisions: 8,
                    onChanged: (val) => fontSettings.setLineHeight(val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3. Live Preview Box
            MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(fontSettings.fontScale),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF7F5EE),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFE0DDD2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.preview_rounded, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          'معاينة حية',
                          style: GoogleFonts.tajawal(
                            fontSize: 11,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'عنوان رئيسي تجريبي',
                      style: GoogleFonts.tajawal(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1B5E20),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'عنوان فرعي يوضح التباين النسبي والخطوط',
                      style: GoogleFonts.tajawal(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF555555),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'عن عمر بن الخطاب رضي الله عنه قال: سمعت رسول الله صلى الله عليه وسلم يقول: "إنما الأعمال بالنيات، وإنما لكل امرئ ما نوى فمن كانت هجرته إلى الله ورسوله فهجرته إلى الله ورسوله".',
                      style: GoogleFonts.amiri(
                        fontSize: 15,
                        height: lineHeightVal,
                        color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF2C2C2C),
                      ),
                      textAlign: TextAlign.justify,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        onPressed: _saveSettings,
        child: Text(
          widget.isFirstTimeSetup ? "ابدأ الاستخدام" : "حفظ التغييرات",
          style: GoogleFonts.tajawal(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required int sectionIndex,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final isExpanded = _expandedSections.contains(sectionIndex);
    return NeumorphicBox(
      borderRadius: 20,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedSections.remove(sectionIndex);
                  } else {
                    _expandedSections.add(sectionIndex);
                  }
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.green, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.tajawal(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: Colors.grey,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  const Divider(height: 25),
                  ...children,
                ],
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualCalibrationSection(bool isDark) {
    return _buildSection(
      sectionIndex: 3,
      title: 'ضبط المواقيت يدوياً',
      icon: Icons.tune_rounded,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تعديل التوقيت بالدقائق ليتوافق بدقة مع المسجد المحلي. اختر نمطاً واحداً: عام أو فردي. الشروق مستثنى دائماً من التعديل.',
                  style: GoogleFonts.tajawal(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // ── محدد النمط (عام / فردي) ──────────────────────────
        _buildCalibrationModeSelector(isDark),
        const SizedBox(height: 16),
        if (_stagedCalibrationMode == PrayerCalibrationMode.global)
          _buildGlobalCalibrationControls(isDark)
        else
          _buildIndividualCalibrationControls(isDark),
        const SizedBox(height: 10),
        // صف الشروق الموضح أنه مستثنى دائماً
        _buildSunriseRow(isDark),
        const SizedBox(height: 14),
        // زر استعادة المواقيت الأصلية
        Center(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange.shade800,
              side: BorderSide(
                color: isDark ? Colors.orange.shade700 : Colors.orange.shade300,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: _handleRestoreOriginalPrayerTimes,
            icon: const Icon(Icons.restore_rounded, size: 20),
            label: Text(
              'استعادة المواقيت الأصلية',
              style: GoogleFonts.tajawal(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalibrationModeSelector(bool isDark) {
    final isGlobal = _stagedCalibrationMode == PrayerCalibrationMode.global;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _handleModeSwitch(PrayerCalibrationMode.global),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                decoration: BoxDecoration(
                  color: isGlobal
                      ? (isDark ? Colors.green.shade800 : Colors.green)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isGlobal
                      ? [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.public_rounded,
                          size: 18,
                          color: isGlobal
                              ? Colors.white
                              : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'الوضع العام',
                          style: GoogleFonts.tajawal(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isGlobal
                                ? Colors.white
                                : (isDark ? Colors.grey.shade300 : Colors.grey.shade800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'تعديل موحد لكافة الصلوات',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.tajawal(
                        fontSize: 10,
                        color: isGlobal
                            ? Colors.white.withValues(alpha: 0.9)
                            : (isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              onTap: () => _handleModeSwitch(PrayerCalibrationMode.individual),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                decoration: BoxDecoration(
                  color: !isGlobal
                      ? (isDark ? Colors.green.shade800 : Colors.green)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: !isGlobal
                      ? [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: !isGlobal
                              ? Colors.white
                              : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'الوضع الفردي',
                          style: GoogleFonts.tajawal(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: !isGlobal
                                ? Colors.white
                                : (isDark ? Colors.grey.shade300 : Colors.grey.shade800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'تعديل مخصص لكل صلاة',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.tajawal(
                        fontSize: 10,
                        color: !isGlobal
                            ? Colors.white.withValues(alpha: 0.9)
                            : (isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalCalibrationControls(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'التعديل العام (لكافة الصلوات)',
                      style: GoogleFonts.tajawal(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'يُطبق بالتساوي على الصلوات الخمس (-15 إلى +15 دقيقة)',
                      style: GoogleFonts.tajawal(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              _buildOffsetBadge(_stagedGlobalOffset),
              const SizedBox(width: 8),
              _buildStepper(
                value: _stagedGlobalOffset,
                min: -15,
                max: 15,
                onChanged: (val) {
                  setState(() {
                    _stagedGlobalOffset = val;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'يطبق هذا التعديل على: الفجر، الظهر، العصر، المغرب، العشاء.',
                    style: GoogleFonts.tajawal(fontSize: 11, color: Colors.green),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndividualCalibrationControls(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'التعديل الفردي لكل صلاة (-15 إلى +15 دقيقة):',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 10),
        ...['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'].map((prayerKey) {
          final prayerName = _getPrayerNameArabic(prayerKey);
          final prayerIcon = _getPrayerIcon(prayerKey);
          final offset = _stagedPrayerOffsets[prayerKey] ?? 0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(prayerIcon, size: 20, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Text(
                    prayerName,
                    style: GoogleFonts.tajawal(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  _buildOffsetBadge(offset),
                  const SizedBox(width: 8),
                  _buildStepper(
                    value: offset,
                    min: -15,
                    max: 15,
                    onChanged: (val) {
                      setState(() {
                        _stagedPrayerOffsets[prayerKey] = val;
                      });
                    },
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSunriseRow(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF181818) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.wb_sunny_outlined, size: 20, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              'الشروق',
              style: GoogleFonts.tajawal(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'مستثنى دائماً من التعديل',
                style: GoogleFonts.tajawal(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffsetBadge(int offset) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: offset == 0
            ? Colors.grey.withValues(alpha: 0.15)
            : (offset > 0
                ? Colors.green.withValues(alpha: 0.15)
                : Colors.red.withValues(alpha: 0.15)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        offset == 0 ? 'مطابق' : (offset > 0 ? '+$offset د' : '$offset د'),
        style: GoogleFonts.tajawal(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: offset == 0
              ? Colors.grey
              : (offset > 0 ? Colors.green : Colors.red),
        ),
      ),
    );
  }

  Future<void> _handleModeSwitch(PrayerCalibrationMode newMode) async {
    if (_stagedCalibrationMode == newMode) return;

    final isSwitchingToIndividual =
        newMode == PrayerCalibrationMode.individual;
    final title = isSwitchingToIndividual
        ? 'التحويل إلى الوضع الفردي'
        : 'التحويل إلى الوضع العام';

    final message = isSwitchingToIndividual
        ? 'عند التحويل إلى الوضع الفردي:\n'
            '• سيتم إعادة ضبط التعديل العام الحالي إلى صفر.\n'
            '• سيبدأ الوضع الفردي بجميع قيم الصلوات الخمس مضبوطة على صفر.\n'
            '• لن يتم نقل قيم التعديل السابقة تلقائياً.\n\n'
            'هل ترغب في المتابعة؟'
        : 'عند التحويل إلى الوضع العام:\n'
            '• سيتم إعادة ضبط جميع التعديلات الفردية الخمسة إلى صفر.\n'
            '• سيبدأ الوضع العام بقيمة تعديل صفر.\n'
            '• لن يتم نقل أي من القيم الفردية السابقة.\n\n'
            'هل ترغب في المتابعة؟';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          style: GoogleFonts.tajawal(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'إلغاء',
              style: GoogleFonts.tajawal(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'تأكيد',
              style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _stagedCalibrationMode = newMode;
        _stagedGlobalOffset = 0;
        _stagedPrayerOffsets = {
          'fajr': 0,
          'dhuhr': 0,
          'asr': 0,
          'maghrib': 0,
          'isha': 0,
        };
      });
    }
  }

  Future<void> _handleRestoreOriginalPrayerTimes() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'استعادة المواقيت الأصلية',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في استعادة مواقيت الصلاة الأصلية؟\n\n'
          '• سيتم ضبط جميع التعديلات (العامة والفردية) على صفر.\n'
          '• ستتم العودة إلى الوضع الافتراضي (الوضع العام).\n'
          '• ستعود مواقيت الصلاة إلى قيمها المحسوبة الأصلية دون أي تعديل.\n\n'
          'لن تتأثر إعدادات المدينة أو طريقة الحساب أو المذهب أو التوقيت الصيفي.',
          style: GoogleFonts.tajawal(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'إلغاء',
              style: GoogleFonts.tajawal(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'استعادة',
              style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _stagedCalibrationMode = PrayerCalibrationMode.global;
        _stagedGlobalOffset = 0;
        _stagedPrayerOffsets = {
          'fajr': 0,
          'dhuhr': 0,
          'asr': 0,
          'maghrib': 0,
          'isha': 0,
        };
      });
    }
  }

  Widget _buildStepper({
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 22),
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 32,
          child: Text(
            value > 0 ? '+$value' : '$value',
            textAlign: TextAlign.center,
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 22),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }

  String _getPrayerNameArabic(String key) {
    switch (key) {
      case 'fajr':
        return 'الفجر';
      case 'dhuhr':
        return 'الظهر';
      case 'asr':
        return 'العصر';
      case 'maghrib':
        return 'المغرب';
      case 'isha':
        return 'العشاء';
      case 'sunrise':
        return 'الشروق';
      default:
        return key;
    }
  }

  IconData _getPrayerIcon(String key) {
    switch (key) {
      case 'fajr':
        return Icons.nights_stay_outlined;
      case 'dhuhr':
        return Icons.wb_sunny_rounded;
      case 'asr':
        return Icons.wb_cloudy_outlined;
      case 'maghrib':
        return Icons.wb_twilight_rounded;
      case 'isha':
        return Icons.bedtime_outlined;
      default:
        return Icons.access_time_rounded;
    }
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const SizedBox(height: 30),
        const Icon(
          Icons.settings_suggest_outlined,
          size: 80,
          color: Colors.green,
        ),
        const SizedBox(height: 15),
        Text(
          'إعداد التطبيق',
          style: GoogleFonts.tajawal(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildAthanSection(bool isDark) {
    return Consumer2<AthanProvider, AthanLibraryProvider>(
      builder: (context, provider, libraryProvider, child) {
        return _buildSection(
          sectionIndex: 2,
          title: 'إعدادات الأذان (الآذان متوفر بعد اختيار الموقع)',
          icon: Icons.notifications_active_outlined,
          children: [
            // Master Toggle
            SwitchListTile(
              title: Text(
                'تنبيه الأذان الصوتي',
                style: GoogleFonts.tajawal(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'إيقاف التنبيه الصوتي يحول الأذان إلى إشعار صامت فقط',
                style: GoogleFonts.tajawal(fontSize: 12, color: Colors.grey),
              ),
              value: provider.isAthanEnabled,
              activeThumbColor: Colors.green,
              onChanged: (val) => provider.setAthanEnabled(val),
              contentPadding: EdgeInsets.zero,
            ),
            if (provider.isAthanEnabled) ...[
              const Divider(height: 20),
              Text(
                'تفعيل الأذان لكل صلاة (التعطيل يجعله صامتاً):',
                style: GoogleFonts.tajawal(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 5),
              Consumer<SettingsProvider>(
                builder: (context, settings, _) => Column(
                  children: [
                    _buildPrayerToggleRow(
                      'الفجر',
                      settings.fajrAthanEnabled,
                      (v) => settings.setPrayerAthanEnabled('fajr', v),
                    ),
                    _buildPrayerToggleRow(
                      'الظهر',
                      settings.dhuhrAthanEnabled,
                      (v) => settings.setPrayerAthanEnabled('dhuhr', v),
                    ),
                    _buildPrayerToggleRow(
                      'العصر',
                      settings.asrAthanEnabled,
                      (v) => settings.setPrayerAthanEnabled('asr', v),
                    ),
                    _buildPrayerToggleRow(
                      'المغرب',
                      settings.maghribAthanEnabled,
                      (v) => settings.setPrayerAthanEnabled('maghrib', v),
                    ),
                    _buildPrayerToggleRow(
                      'العشاء',
                      settings.ishaAthanEnabled,
                      (v) => settings.setPrayerAthanEnabled('isha', v),
                    ),
                  ],
                ),
              ),
              const Divider(height: 20),
              SwitchListTile(
                title: Text(
                  'توحيد المؤذن لجميع الصلوات',
                  style: GoogleFonts.tajawal(fontSize: 15),
                ),
                value: provider.isUnifiedMuezzin,
                activeThumbColor: Colors.green,
                onChanged: (val) async {
                  await provider.setUnifiedMuezzin(val);
                  if (mounted) {
                    libraryProvider.syncFromPrefs();
                  }
                },
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 10),
              // ─── التحكم الموحد بأصوات الأذان داخل مكتبة الأذان ──────────────
              _buildUnifiedAthanLibrarySection(isDark, libraryProvider, provider),
            ],
          ],
        );
      },
    );
  }

  /// قسم إعدادات سطح المكتب لويندوز (بدء التشغيل التلقائي مع النظام)
  Widget _buildWindowsDesktopSettings(bool isDark) {
    return _buildSection(
      sectionIndex: 4,
      title: 'بدء التشغيل والنظام (Windows)',
      icon: Icons.desktop_windows_outlined,
      children: [
        SwitchListTile.adaptive(
          title: Text(
            'بدء تشغيل زاد تلقائياً مع ويندوز',
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            'تشغيل التطبيق في الخلفية وشريط المهام (System Tray) عند تسجيل الدخول إلى ويندوز',
            style: GoogleFonts.tajawal(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          value: _windowsAutoStartEnabled,
          activeColor: Colors.green,
          onChanged: (val) async {
            setState(() => _windowsAutoStartEnabled = val);
            final success =
                await WindowsDesktopService.instance.setAutoStartEnabled(val);
            if (!success && mounted) {
              setState(() => _windowsAutoStartEnabled = !val);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تعذّر تعديل إعداد بدء التشغيل التلقائي'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  /// 5. قسم الصلاحيات وتأمين عمل التطبيق
  Widget _buildPermissionsSection() {
    if (!Platform.isAndroid) return const SizedBox.shrink();
    return _buildSection(
      sectionIndex: 4,
      title: 'الصلاحيات وتأمين الخلفية',
      icon: Icons.security_rounded,
      children: [
        _buildActionTile(
          context,
          title: 'تأمين عمل التطبيق (Battery Optimization)',
          subtitle:
              'مهم جداً لشاومي وسامسونج لضمان عمل الأذان في الخلفية وقت الذروة',
          icon: Icons.battery_saver_rounded,
          isGranted: _permissionStatuses['battery_optimization'] ?? false,
          onTap: () =>
              PermissionsService.openBatteryOptimizationSettings(),
        ),
        const SizedBox(height: 10),
        _buildActionTile(
          context,
          title: 'إعدادات التشغيل التلقائي (Auto-start)',
          subtitle: 'خاص بهواتف Oppo, Realme, Huawei, Samsung, Xiaomi',
          icon: Icons.power_settings_new_rounded,
          isGranted: _permissionStatuses['system_alert'] ?? false,
          onTap: () => PermissionsService.openComprehensivePermissions(),
        ),
        const SizedBox(height: 10),
        _buildActionTile(
          context,
          title: 'صلاحيات شاومي الخاصة (Xiaomi Permissions)',
          subtitle: 'فعل "Show on Lock Screen" لتفتح الصور تلقائياً',
          icon: Icons.security_rounded,
          isGranted: _permissionStatuses['system_alert'] ?? false,
          onTap: () => PermissionsService.openComprehensivePermissions(),
        ),
      ],
    );
  }

  /// قسم إدارة واختيار أصوات الأذان وعرض الأصوات المحددة حالياً
  Widget _buildUnifiedAthanLibrarySection(
    bool isDark,
    AthanLibraryProvider libraryProvider,
    AthanProvider provider,
  ) {
    const accentColor = Color(0xFF4CAF50);

    void openLibrary() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AthanLibraryScreen()),
      ).then((_) {
        if (mounted) {
          Provider.of<AthanLibraryProvider>(
            context,
            listen: false,
          ).syncFromPrefs();
          Provider.of<AthanProvider>(
            context,
            listen: false,
          ).syncFromPrefs();
          setState(() {});
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─── زر فتح مكتبة الأذان الموحد ─────────────────────────────────────
        InkWell(
          onTap: openLibrary,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
                    : [const Color(0xFF2E7D32), const Color(0xFF388E3C)],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.library_music_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إدارة واختيار أصوات الأذان (مكتبة الأذان)',
                        style: GoogleFonts.tajawal(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                        ),
                      ),
                      Text(
                        'تصفح واستمع للأصوات المدمجة والسحابية',
                        style: GoogleFonts.tajawal(
                          color: Colors.white70,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_back_ios_rounded,
                  color: Colors.white70,
                  size: 16,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // ─── عرض الأصوات المختارة حالياً ─────────────────────────────────────
        InkWell(
          onTap: openLibrary,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.volume_up_rounded,
                      size: 16,
                      color: accentColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      provider.isUnifiedMuezzin
                          ? 'الأصوات المحددة حالياً (الوضع الموحد):'
                          : 'الأصوات المحددة لكل صلاة:',
                      style: GoogleFonts.tajawal(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (provider.isUnifiedMuezzin) ...[
                  _buildAthanNameRow(
                    label: 'صوت الأذان الموحد',
                    name: libraryProvider.getAssignedNameFor('dhuhr'),
                    icon: Icons.mosque_rounded,
                    iconColor: Colors.teal,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 6),
                  _buildAthanNameRow(
                    label: 'صوت أذان الفجر',
                    name: libraryProvider.getAssignedNameFor('fajr'),
                    icon: Icons.nightlight_round,
                    iconColor: Colors.orange,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '💡 يتم تطبيق الأذان الموحد على الظهر والعصر والمغرب والعشاء، مع بقاء أذان الفجر مستقلاً.',
                    style: GoogleFonts.tajawal(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black45,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ] else ...[
                  _buildAthanNameRow(
                    label: 'صلاة الفجر',
                    name: libraryProvider.getAssignedNameFor('fajr'),
                    icon: Icons.nightlight_round,
                    iconColor: Colors.orange,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 5),
                  _buildAthanNameRow(
                    label: 'صلاة الظهر',
                    name: libraryProvider.getAssignedNameFor('dhuhr'),
                    icon: Icons.wb_sunny_rounded,
                    iconColor: Colors.amber.shade700,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 5),
                  _buildAthanNameRow(
                    label: 'صلاة العصر',
                    name: libraryProvider.getAssignedNameFor('asr'),
                    icon: Icons.wb_twilight_rounded,
                    iconColor: Colors.deepOrange,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 5),
                  _buildAthanNameRow(
                    label: 'صلاة المغرب',
                    name: libraryProvider.getAssignedNameFor('maghrib'),
                    icon: Icons.nights_stay_rounded,
                    iconColor: Colors.indigo,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 5),
                  _buildAthanNameRow(
                    label: 'صلاة العشاء',
                    name: libraryProvider.getAssignedNameFor('isha'),
                    icon: Icons.star_rounded,
                    iconColor: Colors.deepPurple,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '💡 انقر لتغيير صوت أي صلاة من مكتبة الأذان.',
                    style: GoogleFonts.tajawal(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black45,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAthanNameRow({
    required String label,
    required String name,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.tajawal(
            fontSize: 13,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        Expanded(
          child: Text(
            name,
            style: GoogleFonts.tajawal(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool? isGranted,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.tajawal(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.tajawal(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (isGranted != null)
              Icon(
                isGranted
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                color: isGranted ? Colors.green : Colors.orange,
                size: 20,
              )
            else
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.green,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerToggleRow(
    String label,
    bool value,
    Function(bool) onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.tajawal(fontSize: 14)),
        Switch(
          value: value,
          activeThumbColor: Colors.green,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
