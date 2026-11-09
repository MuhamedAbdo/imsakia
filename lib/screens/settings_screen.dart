import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audio_service/audio_service.dart';
import '../utils/app_constants.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../features/athan/providers/athan_provider.dart';
import '../features/athan_library/providers/athan_library_provider.dart';
import '../features/athan_library/ui/athan_library_screen.dart';
import '../services/prayer_times_service.dart';
import '../widgets/neumorphic_box.dart';
import '../features/audio/services/audio_handler.dart';
import '../services/permissions_service.dart';
import '../widgets/custom_localized_picker.dart';

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

  static const List<Map<String, dynamic>> _adjustablePrayers = [
    {
      'key': 'fajr',
      'name': 'الفجر',
      'icon': Icons.wb_twilight_rounded,
    },
    {
      'key': 'dhuhr',
      'name': 'الظهر',
      'icon': Icons.wb_sunny_rounded,
    },
    {
      'key': 'asr',
      'name': 'العصر',
      'icon': Icons.cloud_outlined,
    },
    {
      'key': 'maghrib',
      'name': 'المغرب',
      'icon': Icons.nights_stay_rounded,
    },
    {
      'key': 'isha',
      'name': 'العشاء',
      'icon': Icons.bedtime_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    _loadSavedLocation();

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

  void _testPlayAthan(String prayerKey) async {
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
    return Directionality(
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
          child: Column(
            children: [
              if (widget.isFirstTimeSetup) _buildHeader(),
              Consumer<SettingsProvider>(
                builder: (context, settings, _) =>
                    _buildLocationSection(settings),
              ),
              const SizedBox(height: 15),
              _buildManualAdjustmentSection(isDark),
              const SizedBox(height: 15),
              _buildAthanSection(isDark),
              if (Platform.isAndroid) ...[
                const SizedBox(height: 15),
                _buildSystemPermissionsSection(isDark),
              ],
              const SizedBox(height: 15),
              _buildCalendarSection(isDark),
              const SizedBox(height: 15),
              _buildAppearanceSection(isDark),
              const SizedBox(height: 15),
              _buildAboutSection(isDark),
              const SizedBox(height: 30),
              _buildSaveButton(),
            ],
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

  Widget _buildLocationSection(SettingsProvider settings) {
    return _buildCollapsibleSection(
      title: 'الموقع الجغرافي وحساب المواقيت',
      icon: Icons.location_on_rounded,
      subtitle: settings.selectedCityName.isNotEmpty
          ? settings.selectedCityName
          : 'حدد موقعك لحساب المواقيت بدقة',
      initiallyExpanded: true,
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
        const SizedBox(height: 15),
        _buildCalculationMethodSelector(),
        const SizedBox(height: 15),
        _buildMadhabSelector(),
        const Divider(height: 30),
        _buildDstToggle(),
      ],
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

  Widget _buildManualAdjustmentSection(bool isDark) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        final isGlobal =
            settings.prayerAdjustmentMode ==
            AppConstants.prayerAdjustmentModeGlobal;

        final subtitle = isGlobal
            ? (settings.prayerAdjustmentGlobal == 0
                ? 'الضبط الموحد (فلكي بدون تعديل)'
                : 'الضبط الموحد (${settings.prayerAdjustmentGlobal > 0 ? '+${settings.prayerAdjustmentGlobal}' : settings.prayerAdjustmentGlobal} دقيقة)')
            : 'مخصص لكل صلاة';

        return _buildCollapsibleSection(
          title: 'الضبط اليدوي لمواقيت الصلاة',
          icon: Icons.tune_rounded,
          subtitle: subtitle,
          initiallyExpanded: true,
          children: [
            Text(
              'يمكنك تقديم أو تأخير مواقيت الصلاة بالدقائق (من -30 إلى +30 دقيقة).\nالقيم الموجبة (+) تعني تأخير الوقت، والقيم السالبة (-) تعني تقديم الوقت.',
              style: GoogleFonts.tajawal(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            _buildAdjustmentModeSelector(settings, isDark),
            const SizedBox(height: 16),
            if (isGlobal) ...[
              _buildAdjustmentStepper(
                label: 'جميع الصلوات الخمس',
                icon: Icons.access_time_rounded,
                value: settings.prayerAdjustmentGlobal,
                isDark: isDark,
                onChanged: (delta) {
                  final newVal = settings.prayerAdjustmentGlobal + delta;
                  if (newVal >= AppConstants.minPrayerAdjustment &&
                      newVal <= AppConstants.maxPrayerAdjustment) {
                    settings.setGlobalPrayerAdjustment(newVal);
                    PrayerTimesService.instance.getCurrentPrayerTimes();
                  }
                },
                onReset: settings.prayerAdjustmentGlobal != 0
                    ? () {
                        settings.setGlobalPrayerAdjustment(0);
                        PrayerTimesService.instance.getCurrentPrayerTimes();
                      }
                    : null,
              ),
            ] else ...[
              ..._adjustablePrayers.map((prayer) {
                final key = prayer['key'] as String;
                final name = prayer['name'] as String;
                final icon = prayer['icon'] as IconData;
                final value = settings.getPrayerAdjustment(key);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildAdjustmentStepper(
                    label: name,
                    icon: icon,
                    value: value,
                    isDark: isDark,
                    onChanged: (delta) {
                      final newVal = value + delta;
                      if (newVal >= AppConstants.minPrayerAdjustment &&
                          newVal <= AppConstants.maxPrayerAdjustment) {
                        settings.setIndividualPrayerAdjustment(key, newVal);
                        PrayerTimesService.instance.getCurrentPrayerTimes();
                      }
                    },
                    onReset: value != 0
                        ? () {
                            settings.setIndividualPrayerAdjustment(key, 0);
                            PrayerTimesService.instance.getCurrentPrayerTimes();
                          }
                        : null,
                  ),
                );
              }),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'ملاحظة: وقت الشروق وقت فلكي بحت ولا يخضع للتعديل.',
                    style: GoogleFonts.tajawal(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildAdjustmentModeSelector(SettingsProvider settings, bool isDark) {
    final isGlobal =
        settings.prayerAdjustmentMode ==
        AppConstants.prayerAdjustmentModeGlobal;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeTab(
              title: 'الضبط الموحد',
              isSelected: isGlobal,
              isDark: isDark,
              onTap: () {
                if (!isGlobal) {
                  settings.setPrayerAdjustmentMode(
                    AppConstants.prayerAdjustmentModeGlobal,
                  );
                  PrayerTimesService.instance.getCurrentPrayerTimes();
                }
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildModeTab(
              title: 'مخصص لكل صلاة',
              isSelected: !isGlobal,
              isDark: isDark,
              onTap: () {
                if (isGlobal) {
                  settings.setPrayerAdjustmentMode(
                    AppConstants.prayerAdjustmentModeIndividual,
                  );
                  PrayerTimesService.instance.getCurrentPrayerTimes();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required String title,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            title,
            style: GoogleFonts.tajawal(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdjustmentStepper({
    required String label,
    required IconData icon,
    required int value,
    required bool isDark,
    required void Function(int delta) onChanged,
    VoidCallback? onReset,
  }) {
    Color valueColor;
    String valueText;

    if (value == 0) {
      valueColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
      valueText = '0 دقيقة';
    } else if (value > 0) {
      valueColor = Colors.orange[700]!;
      valueText = '+$value د (تأخير)';
    } else {
      valueColor = Colors.blue[600]!;
      valueText = '$value د (تقديم)';
    }

    final canDecrement = value > AppConstants.minPrayerAdjustment;
    final canIncrement = value < AppConstants.maxPrayerAdjustment;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value != 0
              ? Colors.green.withValues(alpha: 0.3)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: value != 0
                ? Colors.green
                : (isDark ? Colors.white60 : Colors.black54),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.tajawal(
                fontSize: 14,
                fontWeight: value != 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                iconSize: 22,
                color: canDecrement
                    ? Colors.red
                    : Colors.grey.withValues(alpha: 0.3),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                onPressed: canDecrement ? () => onChanged(-1) : null,
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: onReset,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 88),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: value == 0
                        ? (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.withValues(alpha: 0.1))
                        : (value > 0
                            ? Colors.orange.withValues(alpha: 0.12)
                            : Colors.blue.withValues(alpha: 0.12)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    valueText,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.tajawal(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: valueColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                iconSize: 22,
                color: canIncrement
                    ? Colors.green
                    : Colors.grey.withValues(alpha: 0.3),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                onPressed: canIncrement ? () => onChanged(1) : null,
              ),
            ],
          ),
        ],
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

  Widget _buildCollapsibleSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    String? subtitle,
    bool initiallyExpanded = false,
  }) {
    return NeumorphicBox(
      borderRadius: 20,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.green, size: 20),
          ),
          title: Text(
            title,
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle,
                  style: GoogleFonts.tajawal(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          iconColor: Colors.green,
          collapsedIconColor: Colors.grey,
          children: [
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
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
        final subtitle = provider.isAthanEnabled
            ? (provider.isUnifiedMuezzin
                ? 'تنبيه صوتي مفعّل (مؤذن موحد)'
                : 'تنبيه صوتي مفعّل (مخصص لكل صلاة)')
            : 'تنبيه صوتي متوقف (إشعار صامت فقط)';

        return _buildCollapsibleSection(
          title: 'إعدادات الأذان والتنبيه الصامت',
          icon: Icons.notifications_active_outlined,
          subtitle: subtitle,
          initiallyExpanded: false,
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
              if (provider.isUnifiedMuezzin) ...[
                // ─── وضع "موحد": الأذان السحابي يطغى على الاختيار الموحد ───
                _buildMuezzinDropdown(
                  label: 'صوت المؤذن الموحد',
                  prayerKey: 'dhuhr',
                  muezzins: provider.generalMuezzins,
                  selectedPath: provider.getPathForPrayer('dhuhr'),
                  // 🔑 إذا يوجد أذان سحابي للصلوات العادية → أقفل القائمة
                  isCloudOverride: libraryProvider.hasCloudAthanFor('dhuhr'),
                  cloudOverrideName: libraryProvider.getAssignedNameFor(
                    'dhuhr',
                  ),
                  onChanged: (path) =>
                      provider.setPrayerMuezzin('dhuhr', path!),
                  onTestPlay: () => _testPlayAthan('dhuhr'),
                  onCloudClear: () async {
                    await libraryProvider.clearDefault(prayerKey: 'dhuhr');
                    if (context.mounted) {
                      Provider.of<AthanProvider>(
                        context,
                        listen: false,
                      ).syncFromPrefs();
                    }
                  },
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    "💡 سيتم استخدام أذان مكة لصلاة الفجر بشكل افتراضي عند توحيد المؤذن",
                    style: GoogleFonts.tajawal(
                      fontSize: 11,
                      color: Colors.orange,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تخصيص أصوات الصلوات',
                        style: GoogleFonts.tajawal(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // ─── الفجر: يقفل عند وجود أذان فجر سحابي ──────────
                      _buildMuezzinDropdown(
                        label: 'أذان الفجر (الصلاة خير من النوم)',
                        prayerKey: 'fajr',
                        muezzins: provider.fajrMuezzins,
                        selectedPath: provider.getPathForPrayer('fajr'),
                        isCloudOverride: libraryProvider.hasCloudAthanFor(
                          'fajr',
                        ),
                        cloudOverrideName: libraryProvider.getAssignedNameFor(
                          'fajr',
                        ),
                        onChanged: (path) =>
                            provider.setPrayerMuezzin('fajr', path!),
                        onTestPlay: () => _testPlayAthan('fajr'),
                        onCloudClear: () async {
                          await libraryProvider.clearDefault(prayerKey: 'fajr');
                          if (context.mounted) {
                            Provider.of<AthanProvider>(
                              context,
                              listen: false,
                            ).syncFromPrefs();
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      // ─── الصلوات العادية: تقفل عند وجود أذان عادي سحابي ─
                      _buildMuezzinDropdown(
                        label: 'أذان الظهر',
                        prayerKey: 'dhuhr',
                        muezzins: provider.generalMuezzins,
                        selectedPath: provider.getPathForPrayer('dhuhr'),
                        isCloudOverride: libraryProvider.hasCloudAthanFor(
                          'dhuhr',
                        ),
                        cloudOverrideName: libraryProvider.getAssignedNameFor(
                          'dhuhr',
                        ),
                        onChanged: (path) =>
                            provider.setPrayerMuezzin('dhuhr', path!),
                        onTestPlay: () => _testPlayAthan('dhuhr'),
                        onCloudClear: () async {
                          await libraryProvider.clearDefault(
                            prayerKey: 'dhuhr',
                          );
                          if (context.mounted) {
                            Provider.of<AthanProvider>(
                              context,
                              listen: false,
                            ).syncFromPrefs();
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildMuezzinDropdown(
                        label: 'أذان العصر',
                        prayerKey: 'asr',
                        muezzins: provider.generalMuezzins,
                        selectedPath: provider.getPathForPrayer('asr'),
                        isCloudOverride: libraryProvider.hasCloudAthanFor(
                          'asr',
                        ),
                        cloudOverrideName: libraryProvider.getAssignedNameFor(
                          'asr',
                        ),
                        onChanged: (path) =>
                            provider.setPrayerMuezzin('asr', path!),
                        onTestPlay: () => _testPlayAthan('asr'),
                        onCloudClear: () async {
                          await libraryProvider.clearDefault(prayerKey: 'asr');
                          if (context.mounted) {
                            Provider.of<AthanProvider>(
                              context,
                              listen: false,
                            ).syncFromPrefs();
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildMuezzinDropdown(
                        label: 'أذان المغرب',
                        prayerKey: 'maghrib',
                        muezzins: provider.generalMuezzins,
                        selectedPath: provider.getPathForPrayer('maghrib'),
                        isCloudOverride: libraryProvider.hasCloudAthanFor(
                          'maghrib',
                        ),
                        cloudOverrideName: libraryProvider.getAssignedNameFor(
                          'maghrib',
                        ),
                        onChanged: (path) =>
                            provider.setPrayerMuezzin('maghrib', path!),
                        onTestPlay: () => _testPlayAthan('maghrib'),
                        onCloudClear: () async {
                          await libraryProvider.clearDefault(
                            prayerKey: 'maghrib',
                          );
                          if (context.mounted) {
                            Provider.of<AthanProvider>(
                              context,
                              listen: false,
                            ).syncFromPrefs();
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildMuezzinDropdown(
                        label: 'أذان العشاء',
                        prayerKey: 'isha',
                        muezzins: provider.generalMuezzins,
                        selectedPath: provider.getPathForPrayer('isha'),
                        isCloudOverride: libraryProvider.hasCloudAthanFor(
                          'isha',
                        ),
                        cloudOverrideName: libraryProvider.getAssignedNameFor(
                          'isha',
                        ),
                        onChanged: (path) =>
                            provider.setPrayerMuezzin('isha', path!),
                        onTestPlay: () => _testPlayAthan('isha'),
                        onCloudClear: () async {
                          await libraryProvider.clearDefault(prayerKey: 'isha');
                          if (context.mounted) {
                            Provider.of<AthanProvider>(
                              context,
                              listen: false,
                            ).syncFromPrefs();
                          }
                        },
                      ),
                    ],
                  ),
                ),

              // ─── بانر الأذان السحابي النشط + زر المكتبة ────────────────────
              const SizedBox(height: 8),
              _buildAthanLibraryBanner(isDark, libraryProvider, provider),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSystemPermissionsSection(bool isDark) {
    if (!Platform.isAndroid) return const SizedBox.shrink();

    return _buildCollapsibleSection(
      title: 'تحسين الأداء وصلاحيات النظام',
      icon: Icons.security_rounded,
      subtitle: 'تأمين عمل الأذان في الخلفية وعلى شاشة القفل',
      initiallyExpanded: false,
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

  Widget _buildCalendarSection(bool isDark) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        final subtitle = _tempAdjustment != 0
            ? 'معايرة مؤقتة: ${_tempAdjustment > 0 ? '+$_tempAdjustment' : _tempAdjustment} يوم'
            : (settings.hijriAdjustment != 0
                ? 'معايرة: ${settings.hijriAdjustment > 0 ? '+${settings.hijriAdjustment}' : settings.hijriAdjustment} يوم'
                : 'تلقائي (فلكي بدون تعديل)');

        return _buildCollapsibleSection(
          title: 'التقويم الهجري',
          icon: Icons.calendar_month_outlined,
          subtitle: subtitle,
          initiallyExpanded: false,
          children: [
            _buildHijriAdjustmentControl(),
          ],
        );
      },
    );
  }

  Widget _buildAppearanceSection(bool isDark) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        final subtitle = settings.themeMode == AppThemeMode.dark
            ? 'الوضع الداكن مفعّل'
            : 'الوضع الفاتح مفعّل';

        return _buildCollapsibleSection(
          title: 'المظهر والتخصيص',
          icon: Icons.palette_outlined,
          subtitle: subtitle,
          initiallyExpanded: false,
          children: [
            _buildThemeSelector(isDark),
          ],
        );
      },
    );
  }

  Widget _buildAboutSection(bool isDark) {
    return _buildCollapsibleSection(
      title: 'عن التطبيق',
      icon: Icons.info_outline_rounded,
      subtitle: 'زاد — رفيقك الإيماني (الإصدار 2.0.0)',
      initiallyExpanded: false,
      children: [
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mosque_rounded,
                  size: 40,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'تطبيق زاد (Zaad)',
                style: GoogleFonts.tajawal(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'الإصدار 2.0.0',
                style: GoogleFonts.tajawal(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'تطبيق إسلامي شامل لمواقيت الصلاة، الأذان الدقيق، التقويم الهجري، الأذكار اليومية، والمناسبات الإسلامية، يعمل بدون إنترنت مع حماية دقيقة للمنبهات في الخلفية.',
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// بانر زر فتح مكتبة الأذان
  Widget _buildAthanLibraryBanner(
    bool isDark,
    AthanLibraryProvider libraryProvider,
    AthanProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─── زر فتح مكتبة الأذان ─────────────────────────────────────
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AthanLibraryScreen()),
            ).then((_) {
              // ✨ بعد العودة: مزامنة الحالة من SharedPreferences لتحديث الواجهة تلقائياً
              if (mounted) {
                Provider.of<AthanLibraryProvider>(
                  context,
                  listen: false,
                ).syncFromPrefs();
                Provider.of<AthanProvider>(
                  context,
                  listen: false,
                ).syncFromPrefs();
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
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
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.library_music_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'مكتبة الأذان (تحميل المزيد) ☁️',
                  style: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_back_ios_rounded,
                  color: Colors.white70,
                  size: 14,
                ),
              ],
            ),
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

  Widget _buildMuezzinDropdown({
    required String label,
    required String prayerKey,
    required List<Muezzin> muezzins,
    required String selectedPath,
    required void Function(String?) onChanged,
    required VoidCallback onTestPlay,
    // ─── Cloud Override ────────────────────────────────────────────────────
    bool isCloudOverride = false,
    String? cloudOverrideName,
    VoidCallback? onCloudClear,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ══════════════════════════════════════════════════════════════════════
    // وضع الأذان السحابي: عرض شريحة مقفلة بدلاً من القائمة المنسدلة
    // ══════════════════════════════════════════════════════════════════════
    if (isCloudOverride) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.tajawal(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.green.withValues(alpha: 0.12)
                  : Colors.green.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.cloud_done_rounded,
                  color: Colors.green,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cloudOverrideName ?? 'أذان مخصص من المكتبة ☁️',
                    style: GoogleFonts.tajawal(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                // زر المعاينة يعمل حتى في وضع القفل
                StreamBuilder<PlaybackState>(
                  stream: audioHandler?.playbackState,
                  builder: (context, snapshot) {
                    final isThisPlaying =
                        snapshot.data?.playing == true &&
                        audioHandler
                                ?.mediaItem
                                .value
                                ?.extras?['activeTestKey'] ==
                            prayerKey;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            isThisPlaying
                                ? Icons.stop_circle_outlined
                                : Icons.play_circle_outline,
                            color: isThisPlaying ? Colors.red : Colors.green,
                            size: 28,
                          ),
                          tooltip: isThisPlaying
                              ? 'إيقاف التجربة'
                              : 'معاينة الأذان السحابي',
                          onPressed: onTestPlay,
                        ),
                        if (onCloudClear != null)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.cancel,
                              color: Colors.red.shade300,
                              size: 24,
                            ),
                            tooltip: 'إلغاء التخصيص',
                            onPressed: onCloudClear,
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      );
    }

    // ══════════════════════════════════════════════════════════════════════
    // الوضع الاعتيادي: القائمة المنسدلة بالأصوات المحلية
    // ══════════════════════════════════════════════════════════════════════
    Muezzin? current;
    try {
      current = muezzins.firstWhere((m) => m.path == selectedPath);
    } catch (_) {
      current = muezzins.first;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: current.path,
            decoration: InputDecoration(
              labelText: label,
              labelStyle: GoogleFonts.tajawal(),
            ),
            items: muezzins.map((m) {
              return DropdownMenuItem<String>(
                value: m.path,
                child: Text(m.name, style: GoogleFonts.tajawal(fontSize: 14)),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 8),
        StreamBuilder<PlaybackState>(
          stream: audioHandler?.playbackState,
          builder: (context, snapshot) {
            final state = snapshot.data;
            final isAthanPlaying = state?.playing == true;

            bool isThisTaskPlaying = false;
            if (audioHandler != null && isAthanPlaying) {
              final activeKey =
                  audioHandler!.mediaItem.value?.extras?['activeTestKey'];
              if (activeKey == prayerKey) {
                isThisTaskPlaying = true;
              }
            }

            return IconButton(
              icon: Icon(
                isThisTaskPlaying
                    ? Icons.stop_circle_outlined
                    : Icons.play_circle_outline,
                color: isThisTaskPlaying ? Colors.red : Colors.green,
                size: 30,
              ),
              tooltip: isThisTaskPlaying ? 'إيقاف التجربة' : 'تشغيل تجريبي',
              onPressed: onTestPlay,
            );
          },
        ),
      ],
    );
  }
}
