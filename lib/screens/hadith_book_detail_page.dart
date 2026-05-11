import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/hadith_book.dart';

class HadithBookDetailPage extends StatefulWidget {
  final HadithBook book;

  const HadithBookDetailPage({super.key, required this.book});

  @override
  State<HadithBookDetailPage> createState() => _HadithBookDetailPageState();
}

class _HadithBookDetailPageState extends State<HadithBookDetailPage> {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: widget.book.coverColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search_rounded, color: Colors.white, size: 28),
              onPressed: () {
                // Future search implementation
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Center(
                child: Hero(
                  tag: widget.book.jsonPath,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.75,
                    height: (MediaQuery.of(context).size.width * 0.75) * (3 / 2),
                    decoration: BoxDecoration(
                      color: widget.book.coverColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(10),
                        bottomLeft: Radius.circular(10),
                        topRight: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                          offset: const Offset(-10, 15),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Spine shadow
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.black.withValues(alpha: 0.3),
                                  Colors.transparent,
                                ],
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(10),
                                bottomLeft: Radius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        // Content
                        Padding(
                          padding: const EdgeInsets.all(30.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.auto_stories_rounded,
                                color: Color(0xFFFFD700),
                                size: 80,
                              ),
                              const SizedBox(height: 40),
                              Text(
                                widget.book.title,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.amiri(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Container(
                                width: 60,
                                height: 2,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                widget.book.author,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.tajawal(
                                  fontSize: 16,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
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
              const SizedBox(height: 60),
              // Placeholder for chapters/content
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                ),
                child: Column(
                  children: [
                    Text(
                      'جاري تحميل المحتوى...',
                      style: GoogleFonts.tajawal(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(color: Colors.white30),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
