import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/fasting_fiqh_service.dart';
import '../models/fasting_fiqh_question.dart';

class FastingFiqhScreen extends StatefulWidget {
  const FastingFiqhScreen({super.key});

  @override
  State<FastingFiqhScreen> createState() => _FastingFiqhScreenState();
}

class _FastingFiqhScreenState extends State<FastingFiqhScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<FastingFiqhQuestion> _filteredQuestions = [];
  List<FastingFiqhQuestion> _allQuestions = [];
  bool _isSearching = false;
  double _answerFontSize = 16.0; // حجم الخط الافتراضي

  @override
  void initState() {
    super.initState();
    _allQuestions = FastingFiqhService.instance.getAllQuestions();
    _filteredQuestions = _allQuestions;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    setState(() {
      _isSearching = query.isNotEmpty;
      _filteredQuestions = _isSearching
          ? FastingFiqhService.instance.searchQuestions(query)
          : _allQuestions;
    });
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'حجم خط الإجابة',
            style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
          ),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_answerFontSize.toInt()}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Slider(
                    value: _answerFontSize,
                    min: 14,
                    max: 32,
                    divisions: 9,
                    activeColor: Theme.of(context).primaryColor,
                    onChanged: (value) {
                      setDialogState(() => _answerFontSize = value);
                      setState(() => _answerFontSize = value);
                    },
                  ),
                  Text(
                    'هذا النص للمعاينة',
                    style: GoogleFonts.tajawal(fontSize: _answerFontSize),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'تم',
                style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF121212)
            : const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: Text(
            'فقه الصائم',
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          backgroundColor: primaryColor,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.format_size, color: Colors.white),
              onPressed: _showFontSizeDialog,
              tooltip: 'تغيير حجم الخط',
            ),
          ],
        ),
        body: Column(
          children: [
            _buildSearchSection(isDark, primaryColor),

            if (_isSearching) _buildResultCount(primaryColor),

            Expanded(
              child: _filteredQuestions.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                      itemCount: _filteredQuestions.length,
                      itemBuilder: (context, index) => _buildQuestionCard(
                        _filteredQuestions[index],
                        isDark,
                        primaryColor,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1), // تم التعديل هنا
              blurRadius: 10,
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          style: GoogleFonts.tajawal(
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: 'ابحث عن فتوى...',
            hintStyle: GoogleFonts.tajawal(color: Colors.grey, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: primaryColor),
            suffixIcon: _isSearching
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => _searchController.clear(),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCount(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        'تم العثور على ${_filteredQuestions.length} نتيجة',
        style: GoogleFonts.tajawal(
          color: primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildQuestionCard(
    FastingFiqhQuestion question,
    bool isDark,
    Color primaryColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.black38 
                : Colors.grey.withValues(alpha: 0.1), // تم التعديل هنا
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: ExpansionTile(
          iconColor: primaryColor,
          collapsedIconColor: Colors.grey,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          title: Text(
            question.question,
            style: GoogleFonts.tajawal(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
              height: 1.4,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15), // تم التعديل هنا
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    question.category,
                    style: GoogleFonts.tajawal(
                      color: primaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : const Color(0xFFFDFDFD),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white10 : Colors.grey[100]!,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question.answer,
                    style: GoogleFonts.tajawal(
                      fontSize: _answerFontSize,
                      height: 1.8,
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                    ),
                  ),
                  if (question.keywords.isNotEmpty) ...[
                    const SizedBox(height: 15),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: question.keywords
                          .map((tag) => _buildTag(tag, isDark, primaryColor))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String label, bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withValues(alpha: 0.05) // تم التعديل هنا
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
      ),
      child: Text(
        "# $label",
        style: GoogleFonts.tajawal(
          fontSize: 10,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'لم نجد ما تبحث عنه',
            style: GoogleFonts.tajawal(
              fontSize: 18,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}