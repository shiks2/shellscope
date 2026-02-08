import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class DioClient {
  static final DioClient _instance = DioClient._internal();
  static DioClient get instance => _instance;

  late final Dio _dio;

  DioClient._internal() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Accept': 'application/json'},
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }
  }

  Future<Response?> get(String url) async {
    try {
      return await _dio.get(url);
    } on DioException catch (e) {
      if (kDebugMode) {
        print("DioError: ${e.message}");
      }
      return null;
    }
  }
}
