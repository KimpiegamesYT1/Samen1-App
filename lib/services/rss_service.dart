import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'log_service.dart';

class RSSService {
  static const _feedUrl = 'https://samen1.nl/feed/';
  static const _lastCheckKey = 'last_rss_check';

  static Future<String> checkForNewContent() async {
    try {
      LogService.log('Checking for new RSS content', category: 'rss');
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getString(_lastCheckKey) ?? '';

      final firstItem = await _fetchLatestItem();
      if (firstItem == null) {
        LogService.log('Failed to fetch RSS feed', category: 'rss_error');
        return 'Fout bij ophalen feed';
      }
      
      if (firstItem.pubDate != lastCheck) {
        LogService.log('New content found, sending notification', category: 'rss');
        await NotificationService.showNotification(
          title: 'Samen1 Nieuwsbericht',
          body: firstItem.title,
          payload: firstItem.link,
          imageUrl: firstItem.imageUrl,
        );
        await prefs.setString(_lastCheckKey, firstItem.pubDate);
        return 'Nieuwe melding verzonden: ${firstItem.title}';
      }
      
      LogService.log('No new content found', category: 'rss');
      return 'Geen nieuwe artikelen gevonden';
    } catch (e) {
      LogService.log('Error checking RSS: $e', category: 'rss_error');
      return 'Fout: $e';
    }
  }

  static Future<String> sendTestNotification() async {
    try {
      LogService.log('Sending test notification', category: 'rss');
      final firstItem = await _fetchLatestItem();
      if (firstItem == null) {
        return 'Fout bij ophalen feed';
      }

      LogService.log('Sending notification for: ${firstItem.title}', category: 'rss');
      await NotificationService.showNotification(
        title: 'Samen1 Nieuws',
        body: firstItem.title,
        payload: firstItem.link,
        imageUrl: firstItem.imageUrl,
      );
      return 'Test melding verzonden voor: ${firstItem.title}';
    } catch (e) {
      LogService.log('Error sending test notification: $e', category: 'rss_error');
      return 'Fout: $e';
    }
  }

  static Future<RSSItem?> _fetchLatestItem() async {
    final response = await http.get(Uri.parse(_feedUrl));
    if (response.statusCode != 200) return null;
    return _parseFirstItem(response.body);
  }

  static RSSItem? _parseFirstItem(String xmlString) {
    LogService.log('Parsing RSS feed', category: 'rss');

    final itemRegex = RegExp(r'<item>(.*?)</item>', dotAll: true);
    final itemMatch = itemRegex.firstMatch(xmlString);

    if (itemMatch != null) {
      final itemContent = itemMatch.group(1) ?? '';
      
      final titleRegex = RegExp(r'<title>\s*(.*?)\s*</title>', dotAll: true);
      final linkRegex = RegExp(r'<link>\s*(.*?)\s*</link>', dotAll: true);
      final dateRegex = RegExp(r'<pubDate>\s*(.*?)\s*</pubDate>', dotAll: true);
      final imageRegex = RegExp(r'<(media:content|enclosure)[^>]*(?:url|src)="([^"]*)"', dotAll: true);
      final descRegex = RegExp(r'<description><!\[CDATA\[(.*?)\]\]></description>', dotAll: true);

      final title = titleRegex.firstMatch(itemContent)?.group(1)?.trim();
      final link = linkRegex.firstMatch(itemContent)?.group(1)?.trim();
      final pubDate = dateRegex.firstMatch(itemContent)?.group(1)?.trim();
      final imageMatch = imageRegex.firstMatch(itemContent);
      var imageUrl = imageMatch?.group(2)?.trim();
      final description = descRegex.firstMatch(itemContent)?.group(1)?.trim() ?? '';
      
      // Transform thumbnail URL to full image URL
      if (imageUrl != null && imageUrl.contains('-150x150')) {
        imageUrl = imageUrl.replaceAll('-150x150', '');
        LogService.log('Transformed image URL: $imageUrl', category: 'rss');
      }

      if (title != null && link != null && pubDate != null) {
        LogService.log('Successfully parsed RSS item', category: 'rss');
        return RSSItem(
          title: title,
          link: link,
          pubDate: pubDate,
          description: description,
          imageUrl: imageUrl,
        );
      }
    }
    LogService.log('No valid RSS item found', category: 'rss_error');
    return null;
  }
}

class RSSItem {
  final String title;
  final String link;
  final String pubDate;
  final String description;
  final String? imageUrl;

  RSSItem({
    required this.title, 
    required this.link, 
    required this.pubDate, 
    required this.description,
    this.imageUrl,
  });
}
