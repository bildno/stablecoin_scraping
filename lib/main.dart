import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'news_model.dart';
import 'news_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZDNet 뉴스 스크래핑',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'ZDNet 뉴스'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _searchController = TextEditingController();
  List<News> newsList = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadNews('');
  }

  Future<void> _loadNews(String keyword) async {
    setState(() => isLoading = true);
    try {
      final fetched = await fetchNews(keyword);
      setState(() => newsList = fetched);
    } catch (e) {
      print(e);
    }
    setState(() => isLoading = false);
  }

  void _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              height: 40,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: '검색어 입력',
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        filled: true,
                        fillColor: Colors.white24,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 12,
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      cursorColor: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      _loadNews(_searchController.text);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: newsList.length,
                    itemBuilder: (context, index) {
                      final news = newsList[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 6.0,
                        ),
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              news.title.isNotEmpty ? news.title : '제목 없음',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                news.link.isNotEmpty ? news.link : '링크 없음',
                                style: const TextStyle(color: Colors.blueGrey),
                              ),
                            ),
                            onTap: news.link.isNotEmpty
                                ? () => _launchURL(news.link)
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: null, // pagination unsupported
                      child: const Text('이전'),
                    ),
                    const Text('페이지 1'),
                    ElevatedButton(
                      onPressed: null, // pagination unsupported
                      child: const Text('다음'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
