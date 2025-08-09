import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'data/simplyrets_api.dart';
import 'listing_detail_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  final String? cityOrZip;
  final double? radiusMiles;
  final String? price;
  final String? beds;
  final String? baths;
  final dynamic position; // not used in demo dataset

  const SearchResultsScreen({
    super.key,
    this.cityOrZip,
    this.radiusMiles,
    this.price,
    this.beds,
    this.baths,
    this.position,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  Set<String> _favoritedIds = {};

  @override
  void initState() {
    super.initState();
    _future = _fetchResults();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      setState(() {
        _favoritedIds = Set<String>.from(data?['favorites'] ?? []);
      });
    } catch (_) {}
  }

  Future<void> _toggleFavorite(String mlsId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _favoritedIds.contains(mlsId) ? _favoritedIds.remove(mlsId) : _favoritedIds.add(mlsId);
    });

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      {'favorites': _favoritedIds.toList()},
      SetOptions(merge: true),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchResults() async {
    final api = SimplyRetsApi();

    final String? q = (widget.cityOrZip?.trim().isNotEmpty ?? false) ? widget.cityOrZip!.trim() : null;
    final int? maxPrice = _parseInt(widget.price);
    final int? minBeds = _parseInt(widget.beds);
    final int? minBaths = _parseInt(widget.baths);

    final results = await api.search(
      q: q,
      maxprice: maxPrice,
      minbeds: minBeds,
      minbaths: minBaths,
      status: 'Active',
      limit: 50,
    );

    return results.map<Map<String, dynamic>>((raw) {
      final address = raw['address'] as Map<String, dynamic>?;
      final mlsId = (raw['mlsId'] ?? raw['listingId'] ?? raw['id'] ?? '').toString();
      final photos = (raw['photos'] is List) ? List<String>.from(raw['photos']) : const <String>[];
      final price = raw['listPrice'];
      final beds = raw['property']?['bedrooms'] ?? raw['beds'];
      final baths = raw['property']?['bathsFull'] ?? raw['baths'];
      final sqft = raw['property']?['area'] ?? raw['livingArea'];
      final addr = address?['full'] ??
          [
            address?['streetNumber'],
            address?['streetName'],
            address?['city'],
            address?['state'],
            address?['postalCode'],
          ].where((e) => (e != null && e.toString().trim().isNotEmpty)).join(' ');

      return {
        'mlsId': mlsId,
        'photos': photos,
        'listPrice': price,
        'beds': beds,
        'baths': baths,
        'sqft': sqft,
        'address': addr,
        ...raw, // keep raw for details
      };
    }).toList();
  }

  // ---- helpers ----
  int? _parseInt(String? input) {
    if (input == null) return null;
    final digits = RegExp(r'\d+').allMatches(input).map((m) => m.group(0)).join();
    if (digits.isEmpty) return null;
    return int.tryParse(digits);
  }

  String _priceText(dynamic value) {
    if (value == null) return '\$—';
    try {
      final n = (value is num) ? value.toInt() : int.parse(value.toString());
      return '\$${_formatWithCommas(n)}';
    } catch (_) {
      return '\$${value.toString()}';
    }
  }

  String _formatWithCommas(int n) {
    final s = n.toString();
    final r = s.split('').reversed.toList();
    final out = StringBuffer();
    for (int i = 0; i < r.length; i++) {
      if (i != 0 && i % 3 == 0) out.write(',');
      out.write(r[i]);
    }
    return out.toString().split('').reversed.join();
  }

  Map<String, String> _imageAuthHeaders() {
    final user = dotenv.env['SIMPLYRETS_USER'] ?? 'simplyrets';
    final pass = dotenv.env['SIMPLYRETS_PASS'] ?? 'simplyrets';
    final token = base64Encode(utf8.encode('$user:$pass'));
    return {'Authorization': 'Basic $token'};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Results')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final listings = snap.data ?? const [];

          if (listings.isEmpty) {
            return const Center(child: Text('No listings found.'));
          }

          final headers = _imageAuthHeaders();

          return ListView.builder(
            itemCount: listings.length,
            itemBuilder: (context, i) {
              final l = listings[i];
              final mlsId = (l['mlsId'] ?? '').toString();
              final isFav = _favoritedIds.contains(mlsId);
              final photos = (l['photos'] is List<String>) ? l['photos'] as List<String> : const <String>[];
              final img = photos.isNotEmpty ? photos.first : null;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Photo
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: img != null
                          ? Image.network(
                              img,
                              headers: headers, // <-- required for SimplyRETS photos
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                              ),
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              alignment: Alignment.center,
                              child: const Icon(Icons.photo, size: 40, color: Colors.grey),
                            ),
                    ),

                    // Info rows
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left block
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_priceText(l['listPrice']),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(
                                  (l['address'] ?? 'Unknown address').toString(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 14,
                                  children: [
                                    if (l['beds'] != null) _chip('${l['beds']} bd', Icons.bed),
                                    if (l['baths'] != null) _chip('${l['baths']} ba', Icons.bathtub),
                                    if (l['sqft'] != null) _chip('${l['sqft']} sqft', Icons.square_foot),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Favorite button
                          IconButton(
                            icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                                color: isFav ? Colors.red : null),
                            onPressed: mlsId.isEmpty ? null : () => _toggleFavorite(mlsId),
                          ),
                        ],
                      ),
                    ),

                    // Tap area to open details
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ListingDetailsScreen(listing: l)),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: Text('View details', style: TextStyle(color: Colors.blue)),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _chip(String text, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 4),
        Text(text),
      ],
    );
  }
}
