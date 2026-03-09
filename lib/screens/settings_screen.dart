import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:csc_picker_plus/csc_picker_plus.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../features/athan/providers/athan_provider.dart';
import '../services/prayer_times_service.dart';
import '../widgets/neumorphic_box.dart';

class SettingsScreen extends StatefulWidget {
  final bool isFirstTimeSetup;
  const SettingsScreen({super.key, this.isFirstTimeSetup = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SettingsProvider _settingsProvider;
  String? _selectedCountry;
  String? _selectedState;
  int _tempAdjustment = 0; // عداد مؤقت يظهر للمستخدم فقط

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
              if (provider.isLoading)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.green),
                  ),
                ),
              if (provider.isUnifiedMuezzin)
                _buildMuezzinDropdown(
                  label: 'صوت المؤذن',
                  muezzins: provider.muezzins,
                  selected: provider.selectedNormalMuezzin,
                  onChanged: (m) => provider.selectMuezzinForNormal(m!),
                )
              else
                Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      'تخصيص الأذان',
                      style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                    ),
                    children: [
                      _buildMuezzinDropdown(
                        label: 'الظهر، العصر، المغرب، العشاء',
                        muezzins: provider.muezzins,
                        selected: provider.selectedNormalMuezzin,
                        onChanged: (m) => provider.selectMuezzinForNormal(m!),
                      ),
                      const SizedBox(height: 10),
                      _buildMuezzinDropdown(
                        label: 'أذان الفجر (الصلاة خير من النوم)',
                        muezzins: provider.muezzins,
                        selected: provider.selectedFajrMuezzin,
                        onChanged: (m) => provider.selectMuezzinForFajr(m!),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildMuezzinDropdown({
    required String label,
    required List<Muezzin> muezzins,
    required Muezzin? selected,
    required void Function(Muezzin?) onChanged,
  }) {
    return DropdownButtonFormField<Muezzin>(
      isExpanded: true,
      initialValue: selected,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.tajawal(),
      ),
      items: muezzins.map((m) {
        return DropdownMenuItem<Muezzin>(
          value: m,
          child: Text(m.name, style: GoogleFonts.tajawal(fontSize: 14)),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
