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
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _filteredQuestions = _allQuestions;
      });
    } else {
      setState(() {
        _isSearching = true;
        _filteredQuestions = FastingFiqhService.instance.searchQuestions(query);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        title: Text(
          'فقه الصائم',
          style: GoogleFonts.tajawal(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // شريط البحث
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ابحث عن سؤال (مثل: بخاخة، قطرة، إبرة...)',
                hintStyle: GoogleFonts.tajawal(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
                suffixIcon: _isSearching
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              style: GoogleFonts.tajawal(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 16,
              ),
            ),
          ),

          // عدد النتائج
          if (_isSearching)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'تم العثور على ${_filteredQuestions.length} سؤال',
                style: GoogleFonts.tajawal(
                  color: primaryColor,
                  fontSize: isDarkMode ? 16 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          const SizedBox(height: 8),

          // قائمة الأسئلة
          Expanded(
            child: _filteredQuestions.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredQuestions.length,
                    itemBuilder: (context, index) {
                      return _buildQuestionTile(_filteredQuestions[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isSearching ? Icons.search_off : Icons.menu_book,
            size: 80,
            color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _isSearching ? 'لا توجد نتائج للبحث' : 'لا توجد أسئلة',
            style: GoogleFonts.tajawal(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isSearching 
                ? 'جرب كلمات أخرى مثل: صيام، حائض، سفر'
                : 'يجب إضافة أسئلة الفقه',
            style: GoogleFonts.tajawal(
              color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionTile(FastingFiqhQuestion question) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ExpansionTile(
        title: Text(
          question.question,
          style: GoogleFonts.tajawal(
            color: isDarkMode ? Colors.white : Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDarkMode 
                  ? Colors.blue.withOpacity(0.3) 
                  : primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              question.category,
              style: GoogleFonts.tajawal(
                color: isDarkMode 
                    ? Colors.blue[300] 
                    : primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        childrenPadding: const EdgeInsets.all(16),
        expandedAlignment: Alignment.topRight,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        iconColor: primaryColor,
        collapsedIconColor: primaryColor,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[750] : Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDarkMode ? Colors.grey[600]! : Colors.grey[200]!,
                width: 1,
              ),
            ),
            child: Text(
              question.answer,
              style: GoogleFonts.tajawal(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : Theme.of(context).colorScheme.onSurface,
                fontSize: 15,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
            ),
          ),
          
          // الكلمات المفتاحية
          if (question.keywords.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.end,
              children: question.keywords.map((keyword) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryColor.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    keyword,
                    style: GoogleFonts.tajawal(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.white 
                          : Theme.of(context).colorScheme.onSurface,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
