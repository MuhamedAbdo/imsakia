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
    final primaryColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    final textColor = isDark ? Colors.white : Colors.black87;
    final accentColor = const Color(0xffd4a574); 
    final cardColor = isDark ? Colors.black.withValues(alpha: 0.3) : Colors.white;

    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? primaryColor : Colors.blue,
        iconTheme: IconThemeData(color: isDark ? textColor : Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontFamily: 'cairo'),
        automaticallyImplyLeading: false,
        title: const Text(
          "تفاصيل الاسم",
          style: TextStyle(fontFamily: 'cairo'),
        ),
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
          width: double.infinity,
          decoration: BoxDecoration(
            color: primaryColor,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark 
                ? [primaryColor, const Color(0xFF1a1a1a)] 
                : [primaryColor, accentColor.withValues(alpha: 0.05)],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                
                // الإطار الجمالي مع اسم الله
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset(
                      'assets/images/nameborder.png',
                      width: 280, 
                      height: 280,
                      fit: BoxFit.contain,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 50,
                            fontFamily: 'cairo',
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                offset: const Offset(2, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 30),
                
                // رقم الاسم بتصميم أنيق
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: accentColor.withValues(alpha: 0.3)),
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
                
                const SizedBox(height: 40),
                
                // كارت شرح الاسم
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      // تصحيح الأيقونة هنا واستخدام withValues
                      Icon(
                        Icons.format_quote, 
                        color: accentColor.withValues(alpha: 0.5), 
                        size: 40
                      ),
                      const SizedBox(height: 10),
                      Text(
                        text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 20,
                          fontFamily: 'cairo',
                          height: 1.8,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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