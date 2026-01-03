class FastingFiqhQuestion {
  final int id;
  final String category;
  final String question;
  final String answer;
  final List<String> keywords;

  const FastingFiqhQuestion({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    required this.keywords,
  });

  factory FastingFiqhQuestion.fromJson(Map<String, dynamic> json) {
    return FastingFiqhQuestion(
      id: json['id'],
      category: json['category'],
      question: json['question'],
      answer: json['answer'],
      keywords: List<String>.from(json['keywords']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'question': question,
      'answer': answer,
      'keywords': keywords,
    };
  }
}
