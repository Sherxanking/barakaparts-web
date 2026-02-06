import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class TelegramNotificationService {
  static const String _botToken = 'YOUR_TELEGRAM_BOT_TOKEN_HERE'; // Replace with actual token
  static const String _chatId = 'YOUR_CHAT_ID_HERE'; // Replace with actual chat ID

  /// Send a notification to Telegram channel/group
  static Future<bool> sendNotification(String message) async {
    try {
      // In development, we'll just log the message
      debugPrint('🔔 TELEGRAM NOTIFICATION: $message');
      
      // Uncomment the following lines when ready to use with real Telegram bot
      /*
      final url = Uri.parse('https://api.telegram.org/bot$_botToken/sendMessage');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': _chatId,
          'text': message,
          'parse_mode': 'HTML',
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Telegram notification sent successfully');
        return true;
      } else {
        debugPrint('❌ Failed to send Telegram notification: ${response.body}');
        return false;
      }
      */
      
      // For now, simulate successful send
      return true;
    } catch (e) {
      debugPrint('❌ Error sending Telegram notification: $e');
      return false;
    }
  }

  /// Send order creation notification
  static Future<bool> sendOrderCreatedNotification(String productName, int quantity) async {
    final message = '''
📦 NEW ORDER CREATED
Product: $productName
Quantity: $quantity
Status: Pending
''';
    return sendNotification(message);
  }

  /// Send parts shortage notification
  static Future<bool> sendPartsShortageNotification(List<Map<String, dynamic>> shortages) async {
    final shortageList = shortages.map((item) => 
      '• ${item['partName']}: ${item['shortage']} needed'
    ).join('\n');
    
    final message = '''
⚠️ PARTS SHORTAGE DETECTED
The following parts are insufficient for the order:
$shortageList
''';
    return sendNotification(message);
  }

  /// Send ready order notification
  static Future<bool> sendReadyOrderNotification(int count, String courierName) async {
    final message = '''
✅ $count items ready for pickup
Courier: $courierName can collect them
''';
    return sendNotification(message);
  }

  /// Send order completion notification
  static Future<bool> sendOrderCompletedNotification(String productName, int quantity) async {
    final message = '''
✅ ORDER COMPLETED
Product: $productName
Quantity: $quantity
Status: Completed
''';
    return sendNotification(message);
  }

  /// Send order taken notification
  static Future<bool> sendOrderTakenNotification(
    String productName,
    int takenQuantity,
    int totalTaken,
    int totalRequired,
  ) async {
    final message = '''
📦 ORDER TAKEN
Product: $productName
Taken: $takenQuantity items
Total taken: $totalTaken/$totalRequired
''';
    return sendNotification(message);
  }
}