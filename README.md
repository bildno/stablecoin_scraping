 ## 개요
 사용자가 검색한 키워드 기반으로 Google 뉴스에서 스크래핑해 기사 제목과 링크를 화면에 띄워주고 클릭 시 해당 뉴스로 리다이렉트하는 기능과 버튼을 누르게 되면 Firebase Cloud Messaging(FCM)을 통해 푸시 알림을 전송하는 시스템을 구현했습니다 백엔드는 Spring Boot 프론트엔드는 Flutter 웹 및 모바일 앱으로 구성되어 있습니다.

## 시스템 흐름도

사용자 (Flutter 앱)


↓ HTTP 요청


Spring Boot 서버 (/api/news/{keyword})


↓

Jsoup으로 뉴스 스크래핑

----
사용자 (Flutter 앱)


 ↓ HTTP 요청

       
Spring Boot 서버 (/api/news/send-push, /api/news/send-push-delayed)


 ↓

    
 Firebase Admin SDK로 FCM 전송

 
 ↓


       
사용자 디바이스로 푸시 알림 도착 

-----

## 백엔드 (Java Spring)
```
src
└── main
    └── java
        └── com
            └── example
                └── scraping
                    └── Scraping_Practice
	                    ├── config
		                │   └── FirebaseConfig.java
                        ├── controller
                        │   └── NewsController.java
                        ├── dto
                        │   ├── NewsDto.java
                        │   └── PushRequest.java
                        ├── service
                        │   ├── NewsService.java
                        │   └── NewsServiceImpl.java
                        └── ScrapingPracticeApplication.java

```


## API 명세
### 1. 뉴스 스크래핑 API

| 메서드 | 경로                               | 설명               | 요청 파라미터          | 응답 형태           |
| --- | -------------------------------- | ---------------- | ---------------- | --------------- |
| GET | `/api/news/stablecoin/{keyword}` | 키워드 기반으로 뉴스 스크래핑 | `keyword` (Path) | `List<NewsDto>` |

#### 상세코드
```java
public List<NewsDto> fetchStablecoinNews(String keyword) throws IOException {  
  
    String url = "https://news.google.com/search?q=" + keyword + "&hl=ko&gl=KR&ceid=KR%3Ako";  
  
    Document doc = Jsoup.connect(url).get();  
    Elements newsHeadlines = doc.select("article");  
  
    for (Element item : newsHeadlines) {  
        String title = item.select("a.JtKRv").text();  
        String link = "https://news.google.com" + item.select("a.JtKRv").attr("href");  
        if (!title.isEmpty() && !link.equals("https://news.google.com")) {  
            result.add(new NewsDto(title, link));  
        }  
    }  
  
    System.out.println("[뉴스 결과] " + result.size() + "건 수집됨");  
    result.forEach(news -> System.out.println("제목: " + news.title() + " | URL: " + news.url()));  
    return result;  
}

```


#### 응답 예시

```json
[
  {
    "title": "에스앤피랩, 캐나다 진출",
    "url": "https://news.google.com/..."
  },
  {
     "title": "에스엔피랩 등, '더 배터리쇼 유럽'서 291억원 수출계약",
     "url": "https://news.google.com/..."
  },
  ...
]
```



### 2. 실시간 푸시 알림 API

| 메서드 | 경로                      | 설명                | 요청 Body 필드                         | 응답 |
|--------|---------------------------|---------------------|----------------------------------------|------|
| POST   | `/api/news/send-push`     | FCM으로 푸시 전송 (즉시) | `token`, `title`, `body` (JSON 형태)   | 200 OK |

#### 상세코드
```java
@Override  
public ResponseEntity<String> sendPushNotification(PushRequest request) {  
    try {  
        System.out.println(" sendPushNotification() 진입");  
        String response = firebaseService.sendMessage(request.getToken(), request.getTitle(), request.getBody());  
        System.out.println(" Firebase 전송 응답: " + response);  
        return ResponseEntity.ok("푸시 전송 성공: " + response);  
    } catch (Exception e) {  
        System.out.println(" 푸시 전송 중 오류 발생: " + e.getMessage());  
        return ResponseEntity.internalServerError().body("푸시 전송 실패: " + e.getMessage());  
    }  
}
```


#### 요청 예시

```json
{
  "token": "fcm_token_123",
  "title": "5초 후 푸쉬 전송",
  "body": "지금 확인해보세요!"
}
```



### 3. 예약 푸시 알림 API

| 메서드  | 경로                            | 설명               | 요청 Body 필드                         | 응답     |
| ---- | ----------------------------- | ---------------- | ---------------------------------- | ------ |
| POST | `/api/news/send-push-delayed` | FCM 푸시 전송 (5초 후) | `token`, `title`, `body` (JSON 형태) | 200 OK |

### 상세코드
```Java
@Override  
public ResponseEntity<String> sendPushDelayed(PushRequest request) {  
    try {  
        System.out.println(" 푸시 예약 요청 수신됨 - 5초 후 전송 예정");  
        Thread.sleep(5000);  
        String response = firebaseService.sendMessage(request.getToken(), request.getTitle(), request.getBody());  
        return ResponseEntity.ok("푸시 전송 성공: " + response);  
    } catch (Exception e) {  
        System.out.println(" 예약 푸시 전송 실패: " + e.getMessage());  
        return ResponseEntity.internalServerError().body("푸시 전송 실패: " + e.getMessage());  
    }  
}
```

```json

{

  "token": "fcm_token_123",

  "title": "앱이 포그라운드로 전환 후 5초 뒤 푸쉬 전송",

  "body": "푸시 본문 내용입니다."

}

```
----------

## 프론트엔드(Flutter)
```
lib
├── main.dart
├── news_model.dart
├── news_service.dart
├── screens
│   └── home_screen.dart (main.dart 분리 예정 시)
├── widgets
│   └── news_tile.dart (뉴스 항목 카드 분리 시)
├── utils
│   └── fcm_helper.dart (FCM 관련 유틸 함수들 분리 시)
```


### firebase 초기화 및 권한 요청

```
await Firebase.initializeApp();

if (Platform.isAndroid || Platform.isIOS) {
  await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
}
```


### FCM 수신 및 로컬 푸시 알림 표시(포그라운드)
```
FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
  flutterLocalNotificationsPlugin.show(
    0,
    message.notification!.title,
    message.notification!.body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'push_channel_id',
        'Push Channel',
        importance: Importance.max,
        priority: Priority.high,
      ),
    ),
  );
});

```






## 화면

![Image](https://github.com/user-attachments/assets/2dd2af21-7471-44e8-bea1-635d68a13390)

화면 하단에 종 모양 버튼을 누르면 푸쉬 알림, 앱이 포그라운드로 전환되면 5초 후 푸쉬,
에스앤피랩을 키워드로 Google News 검색 후 스크래핑해 앱 화면에 뉴스 제목과 링크를 렌더링
클릭하면 해당 뉴스로 리다이렉트

-------

## 한계
안드로이드, IOS 모두 스크래핑의 기능은 모두 구현됐지만,
Firebase를 활용한 푸쉬 기능은 IOS는 애뮬레이터로 시현이 불가능 추후 실제 기기를 활용한 테스트를 진행해봐야합니다.
