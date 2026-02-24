import 'package:flutter/material.dart';

class AllahNameDetailPage extends StatelessWidget {
  final String name;
  final String text;
  final int id;

  const AllahNameDetailPage({
    super.key,
    required this.name,
    required this.text,
    required this.id,
  });

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
        leading: const SizedBox(), // إخفاء leading
        title: const Text(
          "تفاصيل الاسم",
          style: TextStyle(fontFamily: 'cairo'),
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
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // اسم الله في دائرة كبيرة
                Container(
                  width: 200,
                  height: 200,
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
                      width: 4,
                    ),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 32,
                          fontFamily: 'cairo',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // رقم الاسم
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    "الاسم رقم $id",
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 16,
                      fontFamily: 'cairo',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // شرح الاسم
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontFamily: 'cairo',
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
