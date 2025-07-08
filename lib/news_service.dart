import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
// 아래는 웹에서는 사용되지 않지만, 웹에서 접근하면 안 되므로 분기처리로 안전하게 사용 가능
import 'dart:io' show Platform;

import 'news_model.dart';

Future<List<News>> fetchNews(String keyword) async {
  // 플랫폼에 따른 baseUrl 분기
  final String baseUrl;

  if (kIsWeb) {
    baseUrl = 'http://localhost:8080'; // 웹 실행 시
  } else if (Platform.isAndroid) {
    baseUrl = 'http://10.0.2.2:8080'; // Android 에뮬레이터
  } else {
    baseUrl = 'http://127.0.0.1:8080'; // iOS, macOS, 기타
  }

  final response = await http.get(
    Uri.parse('$baseUrl/api/news/stablecoin/$keyword'),
  );

  final decodedBody = utf8.decode(response.bodyBytes);

  if (response.statusCode == 200) {
    List data = json.decode(decodedBody);
    return data.map((e) => News.fromJson(e)).toList();
  } else {
    throw Exception('뉴스 로딩 실패');
  }
}
