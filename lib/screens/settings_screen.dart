import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/theme_provider.dart';
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
  AppThemeMode _selectedTheme = AppThemeMode.system;
  String _selectedCity = AppConstants.defaultCity;
  String _selectedCalculationMethod = AppConstants.defaultCalculationMethod;
  String _selectedMadhab = AppConstants.defaultMadhab;
  bool _dstEnabled = AppConstants.defaultDST;
  String _selectedAthanSound = AppConstants.defaultAthanSound;
  bool _notificationsEnabled = true;
  
  final Map<String, String> _calculationMethods = {
    'egyptian': 'Egyptian General Authority of Survey',
    'karachi': 'University of Islamic Sciences, Karachi',
    'umm_al_qura': 'Umm al-Qura University, Makkah',
    'muslim_world_league': 'Muslim World League',
    'north_america': 'Islamic Society of North America',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    if (!widget.isFirstTimeSetup) {
      setState(() {
        final themeMode = prefs.getString(AppConstants.themeModeKey) ?? 'system';
        _selectedTheme = AppThemeMode.values.firstWhere(
          (mode) => mode.toString().split('.').last == themeMode,
          orElse: () => AppThemeMode.system,
        );
        _selectedCity = prefs.getString(AppConstants.selectedCityKey) ?? AppConstants.defaultCity;
        _selectedCalculationMethod = prefs.getString(AppConstants.calculationMethodKey) ?? AppConstants.defaultCalculationMethod;
        _selectedMadhab = prefs.getString(AppConstants.madhabKey) ?? AppConstants.defaultMadhab;
        _dstEnabled = prefs.getBool(AppConstants.dstKey) ?? AppConstants.defaultDST;
        _selectedAthanSound = prefs.getString(AppConstants.athanSoundKey) ?? AppConstants.defaultAthanSound;
        _notificationsEnabled = prefs.getBool(AppConstants.notificationsKey) ?? true;
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString(AppConstants.themeModeKey, _selectedTheme.toString().split('.').last);
    await prefs.setString(AppConstants.selectedCityKey, _selectedCity);
    await prefs.setString(AppConstants.calculationMethodKey, _selectedCalculationMethod);
    await prefs.setString(AppConstants.madhabKey, _selectedMadhab);
    await prefs.setBool(AppConstants.dstKey, _dstEnabled);
    await prefs.setString(AppConstants.athanSoundKey, _selectedAthanSound);
    await prefs.setBool(AppConstants.notificationsKey, _notificationsEnabled);
    
    if (widget.isFirstTimeSetup) {
      await prefs.setBool(AppConstants.isFirstLaunchKey, false);
    }
    
    // Update theme provider
    context.read<ThemeProvider>().setThemeMode(_selectedTheme);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.isFirstTimeSetup ? null : AppBar(
        title: Text(
          'الإعدادات',
          style: GoogleFonts.tajawal(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
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
                      Icon(
                        Icons.settings,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'إعداد التطبيق',
                        style: GoogleFonts.tajawal(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'يرجى ضبط الإعدادات الأساسية للتطبيق',
                        style: GoogleFonts.tajawal(
                          fontSize: 16,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
              
              _buildSection(
                title: 'المظهر',
                icon: Icons.palette,
                children: [
                  _buildThemeSelector(),
                ],
              ),
              
              const SizedBox(height: 24),
              
              _buildSection(
                title: 'إعدادات الصلاة',
                icon: Icons.access_time,
                children: [
                  _buildCitySelector(),
                  const SizedBox(height: 16),
                  _buildCalculationMethodSelector(),
                  const SizedBox(height: 16),
                  _buildMadhabSelector(),
                  const SizedBox(height: 16),
                  _buildDstToggle(),
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
              
              if (widget.isFirstTimeSetup) ...[
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _saveSettings();
                      if (mounted) {
                        Navigator.of(context).pushReplacementNamed('/main');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.mediumBorderRadius),
                      ),
                    ),
                    child: Text(
                      'بدء استخدام التطبيق',
                      style: GoogleFonts.tajawal(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _saveSettings();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'تم حفظ الإعدادات',
                              style: GoogleFonts.tajawal(),
                            ),
                          ),
                        );
                      }
                    },
                    child: Text(
                      'حفظ الإعدادات',
                      style: GoogleFonts.tajawal(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
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
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppConstants.mediumBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppConstants.mediumPadding),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.tajawal(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: AppConstants.mediumPadding,
              right: AppConstants.mediumPadding,
              bottom: AppConstants.mediumPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'نوع المظهر',
          style: GoogleFonts.tajawal(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        ...AppThemeMode.values.map((mode) => RadioListTile<AppThemeMode>(
          title: Text(
            _getThemeDisplayName(mode),
            style: GoogleFonts.tajawal(),
          ),
          value: mode,
          groupValue: _selectedTheme,
          onChanged: (value) {
            setState(() {
              _selectedTheme = value!;
            });
          },
          contentPadding: EdgeInsets.zero,
        )),
      ],
    );
  }

  Widget _buildCalculationMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'طريقة حساب مواقيت الصلاة',
          style: GoogleFonts.tajawal(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedCalculationMethod,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
            ),
          ),
          items: _calculationMethods.entries.map((entry) {
            return DropdownMenuItem(
              value: entry.key,
              child: Text(
                entry.value,
                style: GoogleFonts.tajawal(fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedCalculationMethod = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildMadhabSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'المذهب الفقهي',
          style: GoogleFonts.tajawal(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedMadhab,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
            ),
          ),
          items: const [
            DropdownMenuItem(value: 'shafi', child: Text('الشافعي')),
            DropdownMenuItem(value: 'hanafi', child: Text('الحنفي')),
          ],
          onChanged: (value) {
            setState(() {
              _selectedMadhab = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildDstToggle() {
    return SwitchListTile(
      title: Text(
        'التوقيت الصيفي (DST)',
        style: GoogleFonts.tajawal(),
      ),
      subtitle: Text(
        'ضبط تلقائي للتوقيت الصيفي',
        style: GoogleFonts.tajawal(fontSize: 12),
      ),
      value: _dstEnabled,
      onChanged: (value) {
        setState(() {
          _dstEnabled = value;
        });
      },
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildNotificationsToggle() {
    return SwitchListTile(
      title: Text(
        'تفعيل الإشعارات',
        style: GoogleFonts.tajawal(),
      ),
      subtitle: Text(
        'تلقي إشعارات مواعيد الصلاة',
        style: GoogleFonts.tajawal(fontSize: 12),
      ),
      value: _notificationsEnabled,
      onChanged: (value) {
        setState(() {
          _notificationsEnabled = value;
        });
      },
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildAthanSoundSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'صوت الأذان',
          style: GoogleFonts.tajawal(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedAthanSound,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
            ),
          ),
          items: const [
            DropdownMenuItem(value: 'default', child: Text('الافتراضي')),
            DropdownMenuItem(value: 'makkah', child: Text('مكة المكرمة')),
            DropdownMenuItem(value: 'madinah', child: Text('المدينة المنورة')),
            DropdownMenuItem(value: 'egypt', child: Text('مصر')),
            DropdownMenuItem(value: 'silent', child: Text('صامت')),
          ],
          onChanged: (value) {
            setState(() {
              _selectedAthanSound = value!;
            });
          },
        ),
      ],
    );
  }

  String _getThemeDisplayName(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return 'فاتح';
      case AppThemeMode.dark:
        return 'داكن';
      case AppThemeMode.system:
        return 'نظام التشغيل';
    }
  }

  Widget _buildCitySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'المدينة',
          style: GoogleFonts.tajawal(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedCity,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: AppConstants.cities.map((city) {
            return DropdownMenuItem<String>(
              value: city['id'] as String,
              child: Text(
                '${city['name']} - ${city['country']}',
                style: GoogleFonts.tajawal(fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedCity = value!;
            });
          },
        ),
      ],
    );
  }
}
