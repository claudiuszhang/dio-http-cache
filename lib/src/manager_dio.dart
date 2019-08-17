import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio_http_cache/src/core/config.dart';
import 'package:dio_http_cache/src/core/manager.dart';
import 'package:dio_http_cache/src/core/obj.dart';

const DIO_CACHE_KEY_MAX_AGE = "dio_cache_max_age";
const DIO_CACHE_KEY_MAX_STALE = "dio_cache_max_stale";
const DIO_CACHE_KEY_KEY = "dio_cache_key";
const DIO_CACHE_KEY_SUB_KEY = "dio_cache_sub_key";
const DIO_CACHE_KEY_FORCE_REFRESH = "dio_cache_force_refresh";

class DioCacheManager {
  CacheManager _manager;
  InterceptorsWrapper _interceptor;

  DioCacheManager(CacheConfig config) {
    _manager = CacheManager(config);
  }

  get interceptor {
    if (null == _interceptor) {
      _interceptor = InterceptorsWrapper(
          onRequest: _onRequest, onResponse: _onResponse, onError: _onError);
    }
    return _interceptor;
  }

  _onRequest(RequestOptions options) async {
    if (!options.extra.containsKey(DIO_CACHE_KEY_MAX_AGE)) {
      return options;
    }
    if (true == options.extra[DIO_CACHE_KEY_FORCE_REFRESH]) {
      return options;
    }
    var responseDataFromCache = await _pullFromCacheBeforeMaxAge(options);
    if (null != responseDataFromCache) {
      return _buildResponse(responseDataFromCache, options);
    }
    return options;
  }

  _onResponse(Response response) async {
    if (response.request.extra.containsKey(DIO_CACHE_KEY_MAX_AGE)) {
      await _pushToCache(response);
    }
    return response;
  }

  _onError(DioError e) async {
    if (e.request.extra.containsKey(DIO_CACHE_KEY_MAX_AGE)) {
      var responseDataFromCache = await _pullFromCacheBeforeMaxStale(e.request);
      if (null != responseDataFromCache)
        return _buildResponse(responseDataFromCache, e.request);
    }
    return e;
  }

  Response _buildResponse(String data, RequestOptions options) {
    return Response(
        data: (options.responseType == ResponseType.json)
            ? jsonDecode(data)
            : data,
        headers: DioHttpHeaders.fromMap(options.headers),
        extra: options.extra..remove(DIO_CACHE_KEY_MAX_AGE),
        statusCode: 200);
  }

  Future<String> _pullFromCacheBeforeMaxAge(RequestOptions options) {
    return _manager?.pullFromCacheBeforeMaxAge(
        _getPrimaryKeyFromOptions(options),
        subKey: _getSubKeyFromOptions(options));
  }

  Future<String> _pullFromCacheBeforeMaxStale(RequestOptions options) {
    return _manager?.pullFromCacheBeforeMaxStale(
        _getPrimaryKeyFromOptions(options),
        subKey: _getSubKeyFromOptions(options));
  }

  Future<bool> _pushToCache(Response response) {
    RequestOptions options = response.request;
    Duration maxAge = options.extra[DIO_CACHE_KEY_MAX_AGE];
    Duration maxStale = options.extra[DIO_CACHE_KEY_MAX_STALE];
    var obj = CacheObj(
        _getPrimaryKeyFromOptions(options), jsonEncode(response.data),
        subKey: _getSubKeyFromOptions(options),
        maxAge: maxAge,
        maxStale: maxStale);
    return _manager?.pushToCache(obj);
  }

  String _getPrimaryKeyFromOptions(RequestOptions options) {
    return options.extra.containsKey(DIO_CACHE_KEY_KEY)
        ? options.extra[DIO_CACHE_KEY_KEY]
        : "${options.uri.host}${options.uri.path}";
  }

  String _getSubKeyFromOptions(RequestOptions options) {
    return options.extra.containsKey(DIO_CACHE_KEY_SUB_KEY)
        ? options.extra[DIO_CACHE_KEY_SUB_KEY]
        : '''${options.data.toString()}_
             ${options.queryParameters.toString()}_
             ${options.uri.query}''';
  }

  Future<bool> delete(String key, {String subKey}) =>
      _manager?.delete(key, subKey: subKey);

  Future<bool> clearExpired() => _manager?.clearExpired();

  Future<bool> clearAll() => _manager?.clearAll();
}
