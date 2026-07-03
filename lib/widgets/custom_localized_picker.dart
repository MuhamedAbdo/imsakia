import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/location_translation_service.dart';

class CustomLocalizedPicker extends StatefulWidget {
  final String? initialCountry;
  final String? initialState;
  final Function(String? country, String? state) onSelectionChanged;

  const CustomLocalizedPicker({
    super.key,
    this.initialCountry,
    this.initialState,
    required this.onSelectionChanged,
  });

  @override
  State<CustomLocalizedPicker> createState() => _CustomLocalizedPickerState();
}

class _CustomLocalizedPickerState extends State<CustomLocalizedPicker> {
  String? _selectedCountry;
  String? _selectedState;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // 🌍 Comprehensive Country List (English Keys)
  final List<String> _allCountries = [
    'Egypt', 'Saudi Arabia', 'United Arab Emirates', 'Kuwait', 'Qatar', 'Oman', 'Bahrain', 
    'Jordan', 'Palestine', 'Lebanon', 'Syria', 'Iraq', 'Yemen', 'Libya', 'Tunisia', 
    'Algeria', 'Morocco', 'Sudan', 'Mauritania', 'Somalia', 'Djibouti', 'Comoros',
    'United States', 'United Kingdom', 'Canada', 'Australia', 'Germany', 'France', 
    'Turkey', 'Indonesia', 'Malaysia', 'Pakistan', 'India', 'Russia', 'Spain', 'Italy'
  ];

  // 🏛 States for major countries (simplified for demo/core users)
  final Map<String, List<String>> _statesData = {
    'Egypt': [
      'Cairo', 'Giza', 'Alexandria', 'Dakahlia', 'Red Sea', 'Beheira', 'Faiyum', 
      'Gharbia', 'Ismailia', 'Monufia', 'Minya', 'Qalyubia', 'New Valley', 'Suez', 
      'Aswan', 'Assiut', 'Beni Suef', 'Port Said', 'Damietta', 'Sharqia', 
      'South Sinai', 'Kafr el-Sheikh', 'Matrouh', 'Luxor', 'Qena', 'North Sinai', 'Sohag'
    ],
    'Saudi Arabia': [
      'Riyadh', 'Makkah', 'Madinah', 'Jeddah', 'Eastern Province', 'Asir', 'Tabuk', 
      'Hail', 'Qassim', 'Jazan', 'Najran', 'Al Bahah', 'Al Jawf'
    ],
    'United Arab Emirates': [
      'Dubai', 'Abu Dhabi', 'Sharjah', 'Ajman', 'Umm Al Quwain', 'Ras Al Khaimah', 'Fujairah'
    ],
  };

  @override
  void initState() {
    super.initState();
    _selectedCountry = widget.initialCountry;
    _selectedState = widget.initialState;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSelectionBox(
          label: "اختر الدولة",
          value: _selectedCountry != null 
              ? LocationTranslationService.getArabicCountryName(_selectedCountry!) 
              : null,
          icon: Icons.public_rounded,
          onTap: () => _showPicker(isCountry: true),
        ),
        const SizedBox(height: 15),
        _buildSelectionBox(
          label: "اختر المحافظة / الولاية",
          value: _selectedState != null 
              ? LocationTranslationService.getArabicStateName(_selectedState!) 
              : null,
          icon: Icons.location_city_rounded,
          enabled: _selectedCountry != null,
          onTap: () => _showPicker(isCountry: false),
        ),
      ],
    );
  }

  Widget _buildSelectionBox({
    required String label, 
    String? value, 
    required IconData icon, 
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: enabled 
              ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white)
              : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey[100]),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
          ),
          boxShadow: [
            if (enabled && !isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: enabled ? Colors.green : Colors.grey, size: 22),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                value ?? label,
                style: GoogleFonts.tajawal(
                  fontSize: 15,
                  color: value != null 
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? Colors.white38 : Colors.grey),
                  fontWeight: value != null ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            Icon(
              Icons.expand_more_rounded, 
              color: isDark ? Colors.white38 : Colors.grey,
              size: 20
            ),
          ],
        ),
      ),
    );
  }

  void _showPicker({required bool isCountry}) {
    _searchController.clear();
    setState(() => _searchQuery = "");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          
          // Filtering logic
          List<String> items = isCountry 
              ? _allCountries 
              : (_statesData[_selectedCountry] ?? []);
          
          if (_searchQuery.isNotEmpty) {
            items = items.where((item) {
              final arName = isCountry 
                  ? LocationTranslationService.getArabicCountryName(item)
                  : LocationTranslationService.getArabicStateName(item);
              return item.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                     arName.contains(_searchQuery);
            }).toList();
          }

          // Sorting logic for countries: Arab ones at top
          if (isCountry && _searchQuery.isEmpty) {
            items.sort((a, b) {
              final aIsArab = LocationTranslationService.isArabCountry(a);
              final bIsArab = LocationTranslationService.isArabCountry(b);
              if (aIsArab && !bIsArab) return -1;
              if (!aIsArab && bIsArab) return 1;
              return a.compareTo(b);
            });
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Material(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
              clipBehavior: Clip.antiAlias,
              child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      hintText: isCountry ? "بحث عن دولة... (Riyadh / الرياض)" : "بحث عن محافظة...",
                      prefixIcon: const Icon(Icons.search, color: Colors.green),
                      filled: true,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      hintStyle: GoogleFonts.tajawal(fontSize: 14),
                    ),
                    onChanged: (val) {
                      setModalState(() => _searchQuery = val);
                    },
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final arName = isCountry 
                          ? LocationTranslationService.getArabicCountryName(item)
                          : LocationTranslationService.getArabicStateName(item);
                      final isSelected = isCountry ? (_selectedCountry == item) : (_selectedState == item);
                      final isArab = isCountry && LocationTranslationService.isArabCountry(item);

                      return ListTile(
                        leading: isCountry ? _buildFlag(item) : const Icon(Icons.location_city, size: 20),
                        title: Text(
                          arName,
                          style: GoogleFonts.tajawal(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isArab ? Colors.green[700] : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                        subtitle: Text(
                          item,
                          style: GoogleFonts.tajawal(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : null,
                        onTap: () {
                          setState(() {
                            if (isCountry) {
                              _selectedCountry = item;
                              _selectedState = null;
                            } else {
                              _selectedState = item;
                            }
                            widget.onSelectionChanged(_selectedCountry, _selectedState);
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFlag(String country) {
    // Basic Flag Emoji Map (Major countries)
    final Map<String, String> flags = {
      'Egypt': '🇪🇬', 'Saudi Arabia': '🇸🇦', 'United Arab Emirates': '🇦🇪', 
      'Kuwait': '🇰🇼', 'Qatar': '🇶🇦', 'Oman': '🇴🇲', 'Bahrain': '🇧🇭', 
      'Jordan': '🇯🇴', 'Palestine': '🇵🇸', 'Lebanon': '🇱🇧', 'Syria': '🇸🇾', 
      'Iraq': '🇮🇶', 'Yemen': '🇾🇪', 'Libya': '🇱🇾', 'Tunisia': '🇹🇳', 
      'Algeria': '🇩🇿', 'Morocco': '🇲🇦', 'Sudan': '🇸🇩', 'Mauritania': '🇲🇷', 
      'Somalia': '🇸🇴', 'Djibouti': '🇩🇯', 'Comoros': '🇰🇲',
      'United States': '🇺🇸', 'United Kingdom': '🇬🇧', 'Canada': '🇨🇦',
      'Australia': '🇦🇺', 'Germany': '🇩🇪', 'France': '🇫🇷', 'Turkey': '🇹🇷'
    };
    return Text(flags[country] ?? '🏳️', style: const TextStyle(fontSize: 24));
  }
}
