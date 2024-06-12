import 'package:dio/dio.dart';
import 'package:dio_http_cache/dio_http_cache.dart';

class DioHelper {
  static Dio? _dio;
  static DioCacheManager? _manager;
  static final baseUrl = "https://www.wanandroid.com/";

  static Dio getDio() {
    if (null == _dio) {
      _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          contentType: "application/x-www-form-urlencoded; charset=utf-8"))
        ..interceptors.add(getCacheManager().interceptor)
        ..interceptors.add(LogInterceptor(responseBody: true));
    }
    return _dio!;
  }

  static DioCacheManager getCacheManager() {
    if (null == _manager) {
      _manager =
          DioCacheManager(CacheConfig(baseUrl: "https://www.wanandroid.com/"));
    }
    return _manager!;
  }
}
