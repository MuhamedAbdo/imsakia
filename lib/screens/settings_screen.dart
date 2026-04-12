import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:csc_picker_plus/csc_picker_plus.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audio_service/audio_service.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../features/athan/providers/athan_provider.dart';
import '../services/prayer_times_service.dart';
import '../widgets/neumorphic_box.dart';
import '../features/audio/services/audio_handler.dart';
import '../features/athan/services/athan_manager.dart';
import '../services/permissions_service.dart';

class SettingsScreen extends StatefulWidget {
  final bool isFirstTimeSetup;
  const SettingsScreen({super.key, this.isFirstTimeSetup = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
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
          _settingsProvider.setThemeMode(isDark ? AppThemeMode.dark : AppThemeMode.light);
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
    if (audioHandler == null) return;
    
    final provider = Provider.of<AthanProvider>(context, listen: false);
    final state = audioHandler!.playbackState.value;
    final activeKey = audioHandler!.mediaItem.value?.extras?['activeTestKey'];
    final isPlayingThisKey = state.playing && activeKey == prayerKey;

    if (isPlayingThisKey) {
      await audioHandler!.stop();
    } else {
      final path = provider.getPathForPrayer(prayerKey);
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
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/main', (route) => false);
        } else {
          Navigator.of(context).pop();
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
              _buildSection(
                title: 'الموقع الجغرافي',
                icon: Icons.location_on_rounded,
                children: [
                  CSCPickerPlus(
                    layout: Layout.vertical,
                    currentCountry: _selectedCountry,
                    currentState: _selectedState,
                    showStates: true,
                    showCities: false,
                    flagState: CountryFlag.ENABLE,
                    dropdownDecoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isDark ? Colors.grey[900] : Colors.white,
                      border: Border.all(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                      ),
                    ),
                    selectedItemStyle: GoogleFonts.tajawal(
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    countryDropdownLabel: "اختر الدولة",
                    stateDropdownLabel: "اختر المحافظة / الولاية",
                    onCountryChanged: (value) {
                      setState(() {
                        _selectedCountry = value;
                        _autoSelectMethod(value);
                      });
                    },
                    onStateChanged: (value) =>
                        setState(() => _selectedState = value),
                    onCityChanged: (value) {},
                  ),
                ],
              ),
              const SizedBox(height: 15),
              _buildSection(
                title: 'الحساب الفقهي والوقت',
                icon: Icons.settings_outlined,
                children: [
                  _buildCalculationMethodSelector(),
                  const SizedBox(height: 15),
                  _buildMadhabSelector(),
                  const Divider(height: 30),
                  _buildDstToggle(),
                ],
              ),
              const SizedBox(height: 15),
              _buildAthanSection(isDark),
              const SizedBox(height: 15),
              _buildSection(
                title: 'التقويم والمظهر',
                icon: Icons.palette_outlined,
                children: [
                  _buildHijriAdjustmentControl(),
                  const Divider(height: 30),
                  _buildThemeSelector(isDark),
                ],
              ),
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
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return NeumorphicBox(
      borderRadius: 20,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.green, size: 20),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 25),
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
    return Consumer<AthanProvider>(
      builder: (context, provider, child) {
        return _buildSection(
          title: 'إعدادات الأذان (الآذان متوفر بعد اختيار الموقع)',
          icon: Icons.notifications_active_outlined,
          children: [
            // Master Toggle
            SwitchListTile(
              title: Text(
                'تفعيل الأذان',
                style: GoogleFonts.tajawal(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              value: provider.isAthanEnabled,
              activeThumbColor: Colors.green,
              onChanged: (val) => provider.setAthanEnabled(val),
              contentPadding: EdgeInsets.zero,
            ),
            if (provider.isAthanEnabled) ...[
              const Divider(height: 20),
              SwitchListTile(
                title: Text(
                  'توحيد المؤذن لجميع الصلوات',
                  style: GoogleFonts.tajawal(fontSize: 15),
                ),
                value: provider.isUnifiedMuezzin,
                activeThumbColor: Colors.green,
                onChanged: (val) => provider.setUnifiedMuezzin(val),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 10),
              if (provider.isUnifiedMuezzin) ...[
                _buildMuezzinDropdown(
                  label: 'صوت المؤذن الموحد',
                  prayerKey: 'dhuhr',
                  muezzins: provider.generalMuezzins,
                  selectedPath: provider.getPathForPrayer('dhuhr'),
                  onChanged: (path) => provider.setPrayerMuezzin('dhuhr', path!),
                  onTestPlay: () => _testPlayAthan('dhuhr'),
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
                Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    initiallyExpanded: true,
                    title: Text(
                      'تخصيص أصوات الصلوات',
                      style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                    ),
                    children: [
                      _buildMuezzinDropdown(
                        label: 'أذان الفجر (الصلاة خير من النوم)',
                        prayerKey: 'fajr',
                        muezzins: provider.fajrMuezzins,
                        selectedPath: provider.getPathForPrayer('fajr'),
                        onChanged: (path) => provider.setPrayerMuezzin('fajr', path!),
                        onTestPlay: () => _testPlayAthan('fajr'),
                      ),
                      const SizedBox(height: 10),
                      _buildMuezzinDropdown(
                        label: 'أذان الظهر',
                        prayerKey: 'dhuhr',
                        muezzins: provider.generalMuezzins,
                        selectedPath: provider.getPathForPrayer('dhuhr'),
                        onChanged: (path) => provider.setPrayerMuezzin('dhuhr', path!),
                        onTestPlay: () => _testPlayAthan('dhuhr'),
                      ),
                      const SizedBox(height: 10),
                      _buildMuezzinDropdown(
                        label: 'أذان العصر',
                        prayerKey: 'asr',
                        muezzins: provider.generalMuezzins,
                        selectedPath: provider.getPathForPrayer('asr'),
                        onChanged: (path) => provider.setPrayerMuezzin('asr', path!),
                        onTestPlay: () => _testPlayAthan('asr'),
                      ),
                      const SizedBox(height: 10),
                      _buildMuezzinDropdown(
                        label: 'أذان المغرب',
                        prayerKey: 'maghrib',
                        muezzins: provider.generalMuezzins,
                        selectedPath: provider.getPathForPrayer('maghrib'),
                        onChanged: (path) => provider.setPrayerMuezzin('maghrib', path!),
                        onTestPlay: () => _testPlayAthan('maghrib'),
                      ),
                      const SizedBox(height: 10),
                      _buildMuezzinDropdown(
                        label: 'أذان العشاء',
                        prayerKey: 'isha',
                        muezzins: provider.generalMuezzins,
                        selectedPath: provider.getPathForPrayer('isha'),
                        onChanged: (path) => provider.setPrayerMuezzin('isha', path!),
                        onTestPlay: () => _testPlayAthan('isha'),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 15),
            // Xiaomi & Performance Optimization Buttons
            if (Platform.isAndroid) ...[
              _buildActionTile(
                context,
                title: 'إيقاف قيود البطارية (No Restrictions)',
                subtitle: 'مهم جداً لضمان عمل الأذان في الخلفية',
                icon: Icons.battery_saver_rounded,
                isGranted: _permissionStatuses['battery_optimization'] ?? false,
                onTap: () => PermissionsService.openBatteryOptimizationSettings(),
              ),
              const SizedBox(height: 10),
              _buildActionTile(
                context,
                title: 'إعدادات التشغيل التلقائي (Auto-start)',
                subtitle: 'خاص بهواتف Oppo, Realme, Huawei, Samsung, Xiaomi',
                icon: Icons.power_settings_new_rounded,
                isGranted: _permissionStatuses['system_alert'] ?? false, // We check overlay/start status
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
              const SizedBox(height: 15),
              const Divider(height: 30),
              _buildActionTile(
                context,
                title: 'اختبار نظام الأذان (٥ دقائق)',
                subtitle: 'سيطلق الأذان بعد ٥ دقائق لاختبار الـ Restart والـ WakeLock',
                icon: Icons.timer_outlined,
                onTap: () async {
                  await AthanManager.testAthan();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('سيتم تشغيل الأذان التجريبي بعد ٥ دقائق. يمكنك الآن عمل Reboot للهاتف لتجربة استعادة الخدمة.'),
                        duration: Duration(seconds: 7),
                      ),
                    );
                  }
                },
              ),
            ],
          ],
        );
      },
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
                isGranted ? Icons.check_circle_rounded : Icons.warning_amber_rounded, 
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

  Widget _buildMuezzinDropdown({
    required String label,
    required String prayerKey,
    required List<Muezzin> muezzins,
    required String selectedPath,
    required void Function(String?) onChanged,
    required VoidCallback onTestPlay,
  }) {
    // العثور على المؤذن بناءً على المسار لضبط القيمة الأولية
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
            
            // Check if this specific key is the one playing
            bool isThisTaskPlaying = false;
            if (audioHandler != null && isAthanPlaying) {
               final activeKey = audioHandler!.mediaItem.value?.extras?['activeTestKey'];
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
          }
        ),
      ],
    );
  }
}
