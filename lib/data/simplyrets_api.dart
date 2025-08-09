// lib/data/simplyrets_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SimplyRetsApi {
  final String base = dotenv.env['SIMPLYRETS_BASE'] ?? 'https://api.simplyrets.com';
  String get _authHeader {
    final user = dotenv.env['SIMPLYRETS_USER'] ?? '';
    final pass = dotenv.env['SIMPLYRETS_PASS'] ?? '';
    final basic = base64Encode(utf8.encode('$user:$pass'));
    return 'Basic $basic';
  }

  Future<List<Map<String, dynamic>>> search({
    String? q,
    int? minprice,
    int? maxprice,
    int? minbeds,
    int? minbaths,
    String status = 'Active',
    int limit = 25,
    int offset = 0,
    String? sort, // e.g. "-listDate" or "price"
  }) async {
    final qp = <String, String>{
      if (q != null && q.isNotEmpty) 'q': q,
      if (minprice != null) 'minprice': '$minprice',
      if (maxprice != null) 'maxprice': '$maxprice',
      if (minbeds != null) 'minbeds': '$minbeds',
      if (minbaths != null) 'minbaths': '$minbaths',
      if (status.isNotEmpty) 'status': status.toLowerCase(),
      'limit': '$limit',
      'offset': '$offset',
      if (sort != null) 'sort': sort,
    };

    final uri = Uri.parse('$base/properties').replace(queryParameters: qp);

    final res = await http.get(uri, headers: {'Authorization': _authHeader});
    if (res.statusCode != 200) {
      throw Exception('SimplyRETS ${res.statusCode}: ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    return const [];
  }
}
