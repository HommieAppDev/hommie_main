import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RentcastApi {
  RentcastApi()
      : _base = 'https://api.rentcast.io/v1',
        _key = dotenv.env['RENTCAST_API_KEY'] ?? '';

  final String _base;
  final String _key;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'X-Api-Key': _key,
      };

  /// Sale listings (for-sale)
  Future<List<Map<String, dynamic>>> saleListings({
    String? city,
    String? state,
    String? zip,
    double? latitude,
    double? longitude,
    double? radiusMiles,
    int? bedsMin,
    int? bathsMin,
    int? priceMax,
    int limit = 30,
    int offset = 0,
  }) async {
    final uri = Uri.parse('$_base/listings/sale').replace(queryParameters: {
      if (city != null && city.isNotEmpty) 'city': city,
      if (state != null && state.isNotEmpty) 'state': state,
      if (zip != null && zip.isNotEmpty) 'zipCode': zip,
      if (latitude != null) 'latitude': latitude.toString(),
      if (longitude != null) 'longitude': longitude.toString(),
      if (radiusMiles != null) 'radius': radiusMiles.toString(),
      if (bedsMin != null) 'minBeds': bedsMin.toString(),
      if (bathsMin != null) 'minBaths': bathsMin.toString(),
      if (priceMax != null) 'maxPrice': priceMax.toString(),
      'limit': limit.toString(),
      'offset': offset.toString(),
    });

    final res = await http.get(uri, headers: _headers);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body);
      // RentCast returns { "listings": [...] } per their schema
      final List list = (data is Map && data['listings'] is List)
          ? data['listings']
          : (data is List ? data : []);
      return list.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      throw Exception('RentCast ${res.statusCode}: ${res.body}');
    }
  }

  /// Rental listings (for-rent) – same shape, different endpoint
  Future<List<Map<String, dynamic>>> rentalListings({
    String? city,
    String? state,
    String? zip,
    double? latitude,
    double? longitude,
    double? radiusMiles,
    int limit = 30,
    int offset = 0,
  }) async {
    final uri = Uri.parse('$_base/listings/rental/long-term').replace(queryParameters: {
      if (city != null && city.isNotEmpty) 'city': city,
      if (state != null && state.isNotEmpty) 'state': state,
      if (zip != null && zip.isNotEmpty) 'zipCode': zip,
      if (latitude != null) 'latitude': latitude.toString(),
      if (longitude != null) 'longitude': longitude.toString(),
      if (radiusMiles != null) 'radius': radiusMiles.toString(),
      'limit': limit.toString(),
      'offset': offset.toString(),
    });

    final res = await http.get(uri, headers: _headers);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body);
      final List list = (data is Map && data['listings'] is List)
          ? data['listings']
          : (data is List ? data : []);
      return list.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      throw Exception('RentCast ${res.statusCode}: ${res.body}');
    }
  }
}
