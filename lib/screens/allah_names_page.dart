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
    final accentColor = const Color(0xffd4a574); // لون ذهبي أكثر وضوحاً
    final cardColor = isDark ? Colors.black.withValues(alpha: 0.3) : Colors.white;

    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? primaryColor : Colors.blue,
        iconTheme: IconThemeData(color: isDark ? textColor : Colors.white),
        titleTextStyle: TextStyle(color: isDark ? textColor : Colors.white, fontSize: 20, fontFamily: 'cairo'),
        automaticallyImplyLeading: false, // إخفاء أيقونة الرجوع الافتراضية
        leading: IconButton(
          onPressed: () {
            setState(() {
              isGrid = !isGrid;
            });
          },
          icon: Icon(isGrid == false ? Icons.list : Icons.grid_view),
        ),
        title: Text(
          "أسماء الله الحسنى",
          style: TextStyle(
            fontFamily: 'cairo',
          ),
        ),
        centerTitle: true,
        actions: [
          // أيقونة الرجوع في اليمين (تشير لليمين)
          IconButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
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
              colors: isDark ? [
                primaryColor,
                primaryColor.withValues(alpha: 0.8),
                const Color(0xFF1a1a1a),
              ] : [
                primaryColor,
                primaryColor.withValues(alpha: 0.9),
                accentColor.withValues(alpha: 0.1),
              ],
            ),
          ),
          child: isGrid ? _buildGridView(isDark, cardColor, accentColor, textColor) : _buildListView(isDark, cardColor, accentColor, textColor),
        ),
      ),
    );
  }

  Widget _buildGridView(bool isDark, Color cardColor, Color accentColor, Color textColor) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
      ),
      itemCount: allahNamesAr.length,
      itemBuilder: (BuildContext context, int index) {
        return GestureDetector(
          onTap: () {
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
          },
          child: Container(
            margin: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cardColor,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accentColor.withValues(alpha: 0.3),
                        accentColor.withValues(alpha: 0.1),
                      ],
                    ),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                ),
                Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      allahNamesAr[index]["name"] ?? "",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 12,
                        fontFamily: 'cairo',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accentColor.withValues(alpha: 0.5))),
          child: GestureDetector(
            onTap: () {
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
            },
            child: Column(
              children: [
                Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cardColor,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              accentColor.withValues(alpha: 0.3),
                              accentColor.withValues(alpha: 0.1),
                            ],
                          ),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.5),
                            width: 3,
                          ),
                        ),
                      ),
                      Container(
                        width: 90,
                        height: 90,
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            allahNamesAr[index]["name"] ?? "",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 18,
                              fontFamily: 'cairo',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  allahNamesAr[index]["text"] ?? "",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontFamily: 'cairo'),
                ),
                const SizedBox(height: 10),
                IconButton(
                  onPressed: () {
                    setState(() {
                      isGrid = true;
                    });
                  },
                  icon: Icon(Icons.grid_view, color: accentColor),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}