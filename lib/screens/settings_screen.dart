import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:csc_picker_plus/csc_picker_plus.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../services/prayer_times_service.dart';

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
    } else if (country.contains("United States") ||
        country.contains("Canada")) {
      method = 'north_america';
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
                    disabledDropdownDecoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isDark ? Colors.black26 : Colors.grey.shade100,
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
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
                        if (value != null) _autoSelectMethod(value);
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
              _buildSection(
                title: 'التقويم والمظهر',
                icon: Icons.palette_outlined,
                children: [
                  _buildHijriAdjustmentControl(), // التعديل الجديد هنا
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

  // --- Widgets الفرعية المطورة ---

  Widget _buildHijriAdjustmentControl() {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تعديل التاريخ الهجري',
              style: GoogleFonts.tajawal(fontSize: 15),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.red,
                  ),
                  onPressed: () => settings.updateHijriAdjustment(
                    settings.hijriAdjustment - 1,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    settings.hijriAdjustment == 0
                        ? "تلقائي"
                        : (settings.hijriAdjustment > 0
                              ? "+${settings.hijriAdjustment} يوم"
                              : "${settings.hijriAdjustment} يوم"),
                    style: GoogleFonts.tajawal(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Colors.green,
                  ),
                  onPressed: () => settings.updateHijriAdjustment(
                    settings.hijriAdjustment + 1,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildDstToggle() {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return SwitchListTile(
          title: Text(
            'التوقيت الصيفي (+1 ساعة)',
            style: GoogleFonts.tajawal(fontSize: 15),
          ),
          subtitle: Text(
            'تعديل الوقت يدوياً في حال العمل بالتوقيت الصيفي',
            style: GoogleFonts.tajawal(fontSize: 11),
          ),
          value: settings.dstEnabled,
          activeColor: Colors.green,
          onChanged: (val) {
            settings.setDST(val);
            PrayerTimesService.instance.getCurrentPrayerTimes();
          },
          contentPadding: EdgeInsets.zero,
        );
      },
    );
  }

  Widget _buildCalculationMethodSelector() {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return DropdownButtonFormField<String>(
          value: settings.selectedCalculationMethod,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'طريقة الحساب',
            labelStyle: GoogleFonts.tajawal(),
          ),
          items: _calculationMethods.entries
              .map(
                (e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(
                    e.value,
                    style: GoogleFonts.tajawal(fontSize: 14),
                  ),
                ),
              )
              .toList(),
          onChanged: (val) {
            if (val != null) {
              settings.setCalculationMethod(val);
              PrayerTimesService.instance.getCurrentPrayerTimes();
            }
          },
        );
      },
    );
  }

  Widget _buildMadhabSelector() {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return DropdownButtonFormField<String>(
          value: settings.selectedMadhab,
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
          onChanged: (val) => val != null ? settings.setMadhab(val) : null,
        );
      },
    );
  }

  Widget _buildThemeSelector(bool isDark) {
    return Consumer2<SettingsProvider, ThemeProvider>(
      builder: (context, settings, theme, _) {
        return Row(
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
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
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
}
