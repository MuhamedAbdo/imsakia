class SurahAudio {
  final int id; // 1 to 114
  final String name; // Arabic name
  final String reciterId;
  final String audioUrl;

  String? localPath;
  bool isDownloading;
  double downloadProgress;

  SurahAudio({
    required this.id,
    required this.name,
    required this.reciterId,
    required this.audioUrl,
    this.localPath,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
  });

  SurahAudio copyWith({
    String? localPath,
    bool? isDownloading,
    double? downloadProgress,
  }) {
    return SurahAudio(
      id: id,
      name: name,
      reciterId: reciterId,
      audioUrl: audioUrl,
      localPath: localPath ?? this.localPath,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'reciterId': reciterId,
      'audioUrl': audioUrl,
      'localPath': localPath,
    };
  }

  factory SurahAudio.fromJson(Map<String, dynamic> json) {
    return SurahAudio(
      id: json['id'] as int,
      name: json['name'].toString(),
      reciterId: json['reciterId'].toString(),
      audioUrl: json['audioUrl'].toString(),
      localPath: json['localPath'] as String?,
    );
  }
}
