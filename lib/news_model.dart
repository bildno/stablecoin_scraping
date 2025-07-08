class News {
  final String title;
  final String link;

  News({required this.title, required this.link});

  factory News.fromJson(Map<String, dynamic> json) {
    return News(
      title: json['title']?.toString() ?? '',
      link: json['url']?.toString() ?? '',
    );
  }
}
