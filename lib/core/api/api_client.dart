/// API Client - Backend API bilan aloqa
/// 
/// ⚠️ MUHIM: Barcha sensitive operatsiyalar backend orqali!
/// Frontend to'g'ridan-to'g'ri Supabase ga yozmaydi.

import 'package:dio/dio.dart';
import '../config/env_config.dart';
import '../errors/failures.dart';
import '../utils/either.dart';

class ApiClient {
  static ApiClient? _instance;
  static ApiClient get instance {
    _instance ??= ApiClient._();
    return _instance!;
  }

  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: EnvConfig.backendApiUrl ?? '',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Interceptors qo'shish (logging, error handling)
    _dio.interceptors.add(LogInterceptor(
      requestBody: EnvConfig.isDevelopment,
      responseBody: EnvConfig.isDevelopment,
    ));
  }

  late Dio _dio;

  /// GET so'rov
  Future<Either<Failure, T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      return Right(response.data as T);
    } catch (e) {
      return Left(_handleError(e));
    }
  }

  /// POST so'rov
  Future<Either<Failure, T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return Right(response.data as T);
    } catch (e) {
      return Left(_handleError(e));
    }
  }

  /// PUT so'rov
  Future<Either<Failure, T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return Right(response.data as T);
    } catch (e) {
      return Left(_handleError(e));
    }
  }

  /// DELETE so'rov
  Future<Either<Failure, void>> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      await _dio.delete(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      return Right(null);
    } catch (e) {
      return Left(_handleError(e));
    }
  }

  /// Xatolikni handle qilish
  Failure _handleError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return ServerFailure('Connection timeout');
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          final message = error.response?.data?['message'] ?? 'Server error';
          return ServerFailure('Error $statusCode: $message');
        case DioExceptionType.cancel:
          return ServerFailure('Request cancelled');
        case DioExceptionType.unknown:
          return ServerFailure('Network error: ${error.message}');
        default:
          return ServerFailure('Unknown error: ${error.message}');
      }
    }
    return UnknownFailure('Unexpected error: $error');
  }
}




