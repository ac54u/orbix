import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class TranslateService {
  TranslateService._();
  static final TranslateService instance = TranslateService._();

  final _dio = Dio();

  Future<String> toChinese(String text) async {
    if (text.isEmpty) return text;
    try {
      final url = 'https://translate.googleapis.com/translate_a/single'
          '?client=gtx&sl=ja&tl=zh-CN&dt=t&q=${Uri.encodeComponent(text)}';
      final resp = await _dio.get(url);
      final data = resp.data;
      if (data is List && data.isNotEmpty && data[0] is List) {
        final parts = <String>[];
        for (final seg in (data[0] as List)) {
          if (seg is List && seg.length > 1 && seg[0] is String) {
            parts.add(seg[0] as String);
          }
        }
        if (parts.isNotEmpty) return parts.join();
      }
    } catch (e) {
      debugPrint('translate error: $e');
    }
    return text;
  }
}
