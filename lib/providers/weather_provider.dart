import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 天气信息（ip-api.com 定位 + open-meteo.com 天气，均免费无需 key）
class WeatherInfo {
  final String temp;
  final String desc;
  final String location;
  final String icon;

  const WeatherInfo({
    required this.temp,
    required this.desc,
    required this.location,
    required this.icon,
  });
}

final weatherProvider = FutureProvider<WeatherInfo?>((ref) async {
  try {
    final dio = Dio()..options.connectTimeout = const Duration(seconds: 5);

    // Step 1: IP 定位获取经纬度和城市名
    final geoResp = await dio.get(
      'http://ip-api.com/json/',
      queryParameters: {'lang': 'zh-CN', 'fields': 'city,lat,lon'},
      options: Options(responseType: ResponseType.plain),
    );
    final geo = jsonDecode(geoResp.data as String) as Map<String, dynamic>;
    final lat = (geo['lat'] as num).toDouble();
    final lon = (geo['lon'] as num).toDouble();
    final city = geo['city'] as String? ?? '';

    // Step 2: 通过经纬度获取实时天气
    final weatherResp = await dio.get(
      'https://api.open-meteo.com/v1/forecast',
      queryParameters: {
        'latitude': lat,
        'longitude': lon,
        'current': 'temperature_2m,weather_code',
        'timezone': 'auto',
      },
      options: Options(responseType: ResponseType.plain),
    );
    final weather = jsonDecode(weatherResp.data as String) as Map<String, dynamic>;
    final current = weather['current'] as Map<String, dynamic>;

    final temp = (current['temperature_2m'] as num).round();
    final code = (current['weather_code'] as num).toInt();

    return WeatherInfo(
      temp: '$temp°C',
      desc: _wmoDesc(code),
      location: city,
      icon: _wmoIcon(code),
    );
  } catch (_) {
    return null;
  }
});

/// WMO Weather interpretation codes → 中文描述
String _wmoDesc(int code) => switch (code) {
  0 => '晴',
  1 => '大部晴',
  2 => '多云',
  3 => '阴',
  45 || 48 => '雾',
  51 || 53 || 55 => '毛毛雨',
  56 || 57 => '冻毛毛雨',
  61 || 63 || 65 => '雨',
  66 || 67 => '冻雨',
  71 || 73 || 75 => '雪',
  77 => '雪粒',
  80 || 81 || 82 => '阵雨',
  85 || 86 => '阵雪',
  95 => '雷暴',
  96 || 99 => '冰雹雷暴',
  _ => '晴',
};

/// WMO codes → emoji
String _wmoIcon(int code) => switch (code) {
  0 => '☀️',
  1 || 2 => '⛅',
  3 => '☁️',
  45 || 48 => '🌫️',
  51 || 53 || 55 || 56 || 57 => '🌦️',
  61 || 63 || 65 || 66 || 67 || 80 || 81 || 82 => '🌧️',
  71 || 73 || 75 || 77 || 85 || 86 => '🌨️',
  95 || 96 || 99 => '⛈️',
  _ => '🌤️',
};
