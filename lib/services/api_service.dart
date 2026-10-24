import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/book.dart';
import '../models/booking.dart';
import '../models/order_model.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
}

class SingleArtResponse {
  final String title;
  final String conceptAr;
  final String conceptEn;
  final String artStyle;
  final String promptEn;

  SingleArtResponse({
    required this.title,
    required this.conceptAr,
    required this.conceptEn,
    required this.artStyle,
    required this.promptEn,
  });

  factory SingleArtResponse.fromJson(Map<String, dynamic> j) => SingleArtResponse(
        title: j['title'] ?? 'لوحة تلوين فنية',
        conceptAr: j['concept_ar'] ?? '',
        conceptEn: j['concept_en'] ?? '',
        artStyle: j['art_style'] ?? '',
        promptEn: j['prompt_en'] ?? '',
      );
}

class ApiService {
  // Default URL set to your PC's actual local Wi-Fi IP
  static String baseUrl = const String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://192.168.100.102:8000',
  );

  static Future<bool> testConnection([String? url]) async {
    try {
      final target = (url ?? baseUrl).replaceAll(RegExp(r'/+$'), '');
      final res = await http.get(Uri.parse('$target/health')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['ok'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<String> uploadAudio(String path, Booking b) async {
    try {
      final target = baseUrl.replaceAll(RegExp(r'/+$'), '');
      final req = http.MultipartRequest('POST', Uri.parse('$target/create-book'));
      req.fields['child_name'] = b.childName;
      req.fields['gender'] = b.gender;
      req.fields['age_group'] = b.ageGroup;
      req.fields['art_style'] = b.artStyle;
      req.fields['imagination'] = b.imagination;
      req.files.add(await http.MultipartFile.fromPath('audio', path));
      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 429) {
        throw ApiException('كتبنا كتب كتير النهاردة! جرّب بعد شوية 😊');
      }
      if (res.statusCode != 200) {
        throw ApiException('حصلت مشكلة في الإرسال (${res.statusCode})، جرّب تاني');
      }
      return jsonDecode(res.body)['job_id'] as String;
    } on SocketException {
      throw ApiException('تعذر الاتصال بالسيرفر 📶 اتأكد من اتصال الهاتف والكمبيوتر بنفس شبكة الواي فاي');
    } on TimeoutException {
      throw ApiException('الاتصال بالسيرفر بطيء أو أخذ وقتاً أطول من المعتاد، جرّب تاني');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('تعذر الاتصال بالسيرفر ($baseUrl)\nتأكد أن الهاتف والكمبيوتر متصلان بنفس شبكة الواي فاي ($e)');
    }
  }

  static Future<SingleArtResponse> createSingleArt({
    required String ageGroup,
    required String gender,
    required String artStyle,
    String descriptionText = '',
    String? audioPath,
    bool includeText = false,
  }) async {
    try {
      final target = baseUrl.replaceAll(RegExp(r'/+$'), '');
      final req = http.MultipartRequest('POST', Uri.parse('$target/create-single-art'));
      req.fields['age_group'] = ageGroup;
      req.fields['gender'] = gender;
      req.fields['art_style'] = artStyle;
      req.fields['description_text'] = descriptionText;
      req.fields['include_text'] = includeText ? 'true' : 'false';

      if (audioPath != null && audioPath.isNotEmpty && File(audioPath).existsSync()) {
        req.files.add(await http.MultipartFile.fromPath('audio', audioPath));
      }

      final streamed = await req.send().timeout(const Duration(seconds: 45));
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode != 200) {
        throw ApiException('تعذر توليد برومبت اللوحة (${res.statusCode})، حاول مرة أخرى');
      }
      return SingleArtResponse.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    } on SocketException {
      throw ApiException('تعذر الاتصال بالسيرفر 📶 تأكد من اتصال الهاتف بالواي فاي');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('حصلت مشكلة في توليد اللوحة ($e)');
    }
  }

  static Future<JobStatus> getStatus(String jobId) async {
    try {
      final target = baseUrl.replaceAll(RegExp(r'/+$'), '');
      final res = await http
          .get(Uri.parse('$target/status/$jobId'))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 404) {
        throw ApiException('حصلت مشكلة، جرّب تسجيل الحكاية تاني');
      }
      if (res.statusCode != 200) throw ApiException('حصلت مشكلة، جرّب تاني');
      return JobStatus.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    } on SocketException {
      throw ApiException('انقطع الاتصال بالسيرفر 📶 اتأكد من اتصال الواي فاي');
    } on TimeoutException {
      throw ApiException('الاتصال بطيء، جرّب تاني');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('حصل خطأ في متابعة حالة الكتاب ($e)');
    }
  }

  static Future<List<CustomerOrder>> getOrders({String status = 'all'}) async {
    try {
      final target = baseUrl.replaceAll(RegExp(r'/+$'), '');
      final res = await http
          .get(Uri.parse('$target/api/orders?status=$status'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw ApiException('تعذر جلب الطلبات (${res.statusCode})');
      }
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final List list = data['orders'] ?? [];
      return list.map((e) => CustomerOrder.fromJson(e)).toList();
    } on SocketException {
      throw ApiException('تعذر الاتصال بالسيرفر 📶 اتأكد من الواي فاي');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('حدث خطأ أثناء تحميل الطلبات ($e)');
    }
  }

  static Future<Map<String, dynamic>> processOrder(String orderId) async {
    try {
      final target = baseUrl.replaceAll(RegExp(r'/+$'), '');
      final res = await http
          .post(Uri.parse('$target/api/orders/$orderId/process'))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        throw ApiException('تعذر معالجة الطلب (${res.statusCode})');
      }
      return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('خطأ في معالجة الطلب ($e)');
    }
  }

  static Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      final target = baseUrl.replaceAll(RegExp(r'/+$'), '');
      final res = await http
          .patch(
            Uri.parse('$target/api/orders/$orderId/status'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'status': newStatus}),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw ApiException('تعذر تحديث حالة الطلب');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('خطأ في تحديث الحالة ($e)');
    }
  }

  static String getOrderAudioUrl(String orderId) {
    final target = baseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$target/api/orders/$orderId/audio';
  }
}
