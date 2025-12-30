import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../services/prayer_times_service.dart';
import '../utils/app_constants.dart';

class SettingsScreen extends StatefulWidget {
  final bool isFirstTimeSetup;
  
  const SettingsScreen({
    super.key,
    this.isFirstTimeSetup = false,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SettingsProvider _settingsProvider;
  
  final Map<String, String> _calculationMethods = {
    'egyptian': 'الهيئة المصرية العامة للمساحة',
    'karachi': 'جامعة العلوم الإسلامية بكراتشي',
    'umm_al_qura': 'جامعة أم القرى، مكة المكرمة',
    'muslim_world_league': 'رابطة العالم الإسلامي',
    'north_america': 'الجمعية الإسلامية لأمريكا الشمالية',
  };

  @override
  void initState() {
    super.initState();
    _settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    if (!_settingsProvider.isInitialized) {
      _settingsProvider.initialize();
    }
  }

  Future<void> _saveSettings() async {
    try {
      if (widget.isFirstTimeSetup) {
        await _settingsProvider.setFirstLaunchComplete();
      }
      
      await PrayerTimesService.instance.getCurrentPrayerTimes();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حفظ الإعدادات بنجاح', style: GoogleFonts.tajawal()),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            if (widget.isFirstTimeSetup) {
              Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
            } else {
              Navigator.of(context).pop();
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء حفظ الإعدادات', style: GoogleFonts.tajawal()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.isFirstTimeSetup ? null : AppBar(
        title: Text('الإعدادات', style: GoogleFonts.tajawal(fontSize: 20, fontWeight: FontWeight.w600)),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.mediumPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.isFirstTimeSetup) ...[
                const SizedBox(height: 40),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.settings, size: 64, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 16),
                      Text('إعداد التطبيق', style: GoogleFonts.tajawal(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                      const SizedBox(height: 8),
                      Text('يرجى ضبط الإعدادات الأساسية للتطبيق', style: GoogleFonts.tajawal(fontSize: 16), textAlign: TextAlign.center),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
              
              _buildSection(
                title: 'المظهر',
                icon: Icons.palette,
                children: [_buildThemeSelector()],
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: 'إعدادات الصلاة والتقويم',
                icon: Icons.access_time,
                children: [
                  _buildCitySelector(),
                  const SizedBox(height: 16),
                  _buildCalculationMethodSelector(),
                  const SizedBox(height: 16),
                  _buildMadhabSelector(),
                  const SizedBox(height: 16),
                  _buildDstToggle(),
                  const SizedBox(height: 16),
                  _buildHijriAdjustmentSelector(),
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: 'الإشعارات',
                icon: Icons.notifications,
                children: [
                  _buildNotificationsToggle(),
                  const SizedBox(height: 16),
                  _buildAthanSoundSelector(),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveSettings,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.mediumBorderRadius)),
                  ),
                  child: Text(widget.isFirstTimeSetup ? 'بدء استخدام التطبيق' : 'حفظ الإعدادات', style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppConstants.mediumBorderRadius),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppConstants.mediumPadding),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Text(title, style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: AppConstants.mediumPadding, right: AppConstants.mediumPadding, bottom: AppConstants.mediumPadding),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelector() {
    return Consumer2<SettingsProvider, ThemeProvider>(
      builder: (context, settings, themeProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('نوع المظهر', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            ...AppThemeMode.values.map((mode) => RadioListTile<AppThemeMode>(
              title: Text(_getThemeDisplayName(mode), style: GoogleFonts.tajawal()),
              value: mode,
              groupValue: settings.themeMode,
              onChanged: (value) {
                if (value != null) {
                  settings.setThemeMode(value);
                  themeProvider.syncWithSettingsProvider(value);
                }
              },
              contentPadding: EdgeInsets.zero,
            )),
          ],
        );
      },
    );
  }

  Widget _buildCitySelector() {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المدينة', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: settings.selectedCity,
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius))),
              items: AppConstants.cities.map((city) {
                return DropdownMenuItem<String>(
                  value: city['id'] as String,
                  child: Text('${city['name']} - ${city['country']}', style: GoogleFonts.tajawal(fontSize: 14)),
                );
              }).toList(),
              onChanged: (value) { if (value != null) settings.setCity(value); },
            ),
          ],
        );
      },
    );
  }

  Widget _buildCalculationMethodSelector() {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('طريقة حساب مواقيت الصلاة', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: settings.selectedCalculationMethod,
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius))),
              items: _calculationMethods.entries.map((entry) {
                return DropdownMenuItem(value: entry.key, child: Text(entry.value, style: GoogleFonts.tajawal(fontSize: 14)));
              }).toList(),
              onChanged: (value) { if (value != null) settings.setCalculationMethod(value); },
            ),
          ],
        );
      },
    );
  }

  Widget _buildMadhabSelector() {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المذهب الفقهي', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: settings.selectedMadhab,
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius))),
              items: const [
                DropdownMenuItem(value: 'shafi', child: Text('الشافعي / أخرى')),
                DropdownMenuItem(value: 'hanafi', child: Text('الحنفي')),
              ],
              onChanged: (value) { if (value != null) settings.setMadhab(value); },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDstToggle() {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return SwitchListTile(
          title: Text('التوقيت الصيفي (DST)', style: GoogleFonts.tajawal()),
          value: settings.dstEnabled,
          onChanged: (value) => settings.setDST(value),
          contentPadding: EdgeInsets.zero,
        );
      },
    );
  }

  Widget _buildHijriAdjustmentSelector() {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تعديل التاريخ الهجري', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: settings.hijriAdjustment,
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius))),
              items: [-2, -1, 0, 1, 2].map((offset) {
                String label = offset == 0 ? "تاريخ اليوم" : (offset > 0 ? "+$offset يوم" : "$offset يوم");
                return DropdownMenuItem<int>(value: offset, child: Text(label, style: GoogleFonts.tajawal()));
              }).toList(),
              onChanged: (value) { if (value != null) settings.setHijriAdjustment(value); },
            ),
          ],
        );
      },
    );
  }

  Widget _buildNotificationsToggle() {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return SwitchListTile(
          title: Text('تفعيل الإشعارات', style: GoogleFonts.tajawal()),
          value: settings.notificationsEnabled,
          onChanged: (value) => settings.setNotifications(value),
          contentPadding: EdgeInsets.zero,
        );
      },
    );
  }

  Widget _buildAthanSoundSelector() {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('صوت الأذان', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: settings.selectedAthanSound,
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius))),
              items: const [
                DropdownMenuItem(value: 'default', child: Text('الافتراضي')),
                DropdownMenuItem(value: 'makkah', child: Text('مكة المكرمة')),
                DropdownMenuItem(value: 'madinah', child: Text('المدينة المنورة')),
                DropdownMenuItem(value: 'egypt', child: Text('مصر')),
                DropdownMenuItem(value: 'silent', child: Text('صامت')),
              ],
              onChanged: (value) { if (value != null) settings.setAthanSound(value); },
            ),
          ],
        );
      },
    );
  }

  String _getThemeDisplayName(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light: return 'فاتح';
      case AppThemeMode.dark: return 'داكن';
      case AppThemeMode.system: return 'نظام التشغيل';
    }
  }
}