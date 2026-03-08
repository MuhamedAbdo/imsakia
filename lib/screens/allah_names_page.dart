import 'package:flutter/material.dart';
import 'package:imsakia/data/allah_names.dart';
import 'package:imsakia/screens/allah_name_detail_page.dart';

class AllahNamesPage extends StatefulWidget {
  const AllahNamesPage({super.key});

  @override
  State<AllahNamesPage> createState() => _AllahNamesPageState();
}

class _AllahNamesPageState extends State<AllahNamesPage> {
  bool isGrid = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFF121212) : const Color(0xFFE8E8E8);
    final textColor = isDark ? Colors.white : Colors.black87;
    final accentColor = const Color(0xffd4a574); 
    final cardColor = isDark ? Colors.black.withValues(alpha: 0.3) : Colors.white;

    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? primaryColor : Colors.blue,
        iconTheme: IconThemeData(color: isDark ? textColor : Colors.white),
        titleTextStyle: TextStyle(color: isDark ? textColor : Colors.white, fontSize: 20, fontFamily: 'cairo'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => setState(() => isGrid = !isGrid),
          icon: Icon(isGrid ? Icons.list : Icons.grid_view),
        ),
        title: const Text("أسماء الله الحسنى", style: TextStyle(fontFamily: 'cairo')),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_forward),
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: BoxDecoration(
            color: primaryColor,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark 
                ? [primaryColor, const Color(0xFF1a1a1a)] 
                : [primaryColor, accentColor.withValues(alpha: 0.1)],
            ),
          ),
          child: isGrid 
            ? _buildGridView(accentColor) 
            : _buildListView(isDark, cardColor, accentColor, textColor),
        ),
      ),
    );
  }

  Widget _buildGridView(Color accentColor) {
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1,
      ),
      itemCount: allahNamesAr.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => _navigateToDetail(index),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // صورة الإطار الخلفية
              Image.asset(
                'assets/images/nameborder.png',
                width: 100,
                height: 100,
                fit: BoxFit.contain,
              ),
              // اسم الله
              Padding(
                padding: const EdgeInsets.all(18.0), // لضمان بقاء النص داخل حدود الإطار
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    allahNamesAr[index]["name"] ?? "",
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 16,
                      fontFamily: 'cairo',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListView(bool isDark, Color cardColor, Color accentColor, Color textColor) {
    return ListView.builder(
      itemCount: allahNamesAr.length,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: accentColor.withValues(alpha: 0.2)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(10),
            onTap: () => _navigateToDetail(index),
            leading: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  'assets/images/nameborder.png',
                  width: 60,
                  height: 60,
                ),
                SizedBox(
                  width: 35,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      allahNamesAr[index]["name"] ?? "",
                      style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            title: Text(
              allahNamesAr[index]["name"] ?? "",
              style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontFamily: 'cairo'),
            ),
            subtitle: Text(
              allahNamesAr[index]["text"] ?? "",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: textColor.withValues(alpha: 0.7), fontFamily: 'cairo', fontSize: 13),
            ),
            trailing: Icon(Icons.arrow_back_ios_new, size: 14, color: accentColor),
          ),
        );
      },
    );
  }

  void _navigateToDetail(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AllahNameDetailPage(
          name: allahNamesAr[index]["name"] ?? "",
          text: allahNamesAr[index]["text"] ?? "",
          id: allahNamesAr[index]["id"] ?? 1,
        ),
      ),
    );
  }
}