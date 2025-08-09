// lib/search_results_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import 'data/rentcast_api.dart';
import 'listing_detail_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  final String? cityOrZip;
  final double? radiusMiles;
  final String? price; // "Up to $500k" style
  final String? beds;  // "3" or "10+"
  final String? baths; // "2" or "10+"
  final Position? position;

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
  final _api = RentcastApi();
  Set<String> favoritedListingIds = {};
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _future = _fetchResults();
  }

  Future<void> _loadFavorites() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    setState(() {
      favoritedListingIds = Set<String>.from(data?['favorites'] ?? []);
    });
  }

  Future<void> _toggleFavorite(String listingId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      if (favoritedListingIds.contains(listingId)) {
        favoritedListingIds.remove(listingId);
      } else {
        favoritedListingIds.add(listingId);
      }
    });

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      {'favorites': favoritedListingIds.toList()},
      SetOptions(merge: true),
    );
  }

  int? _parseMaxPrice(String? label) {
    if (label == null) return null;
    // examples: "Up to $500k", "Up to $1MM", "$10MM+"
    final cleaned = label.replaceAll(',', '').toLowerCase();
    if (cleaned.contains('mm')) {
      final numStr = cleaned.replaceAll(RegExp(r'[^\d]'), '');
      if (numStr.isEmpty) return null;
      final millions = int.tryParse(numStr);
      return millions != null ? millions * 1000000 : null;
    }
    final digits = cleaned.replaceAll(RegExp(r'[^\d]'), '');
    return digits.isEmpty ? null : int.tryParse(digits);
  }

  int? _parseMin(String? s) {
    if (s == null) return null;
    final t = s.replaceAll('+', '').trim();
    return int.tryParse(t);
  }

  Future<List<Map<String, dynamic>>> _fetchResults() async {
    // City vs ZIP
    final input = widget.cityOrZip?.trim();
    final isZip = (input != null && int.tryParse(input) != null);
    final city = (!isZip && input != null && input.isNotEmpty) ? input : null;
    final zip = (isZip) ? input : null;

    final maxPrice = _parseMaxPrice(widget.price);
    final bedsMin = _parseMin(widget.beds);
    final bathsMin = _parseMin(widget.baths);

    final results = await _api.saleListings(
      city: city,
      zip: zip,
      bedsMin: bedsMin,
      bathsMin: bathsMin,
      priceMax: maxPrice,
      latitude: widget.position?.latitude,
      longitude: widget.position?.longitude,
      radiusMiles: widget.radiusMiles,
      limit: 40,
    );

    // Normalize a few fields we use in UI & details screen
    return results.map<Map<String, dynamic>>((raw) {
      final id = _extractId(raw);
      final address = _extractAddress(raw);
      final photos = _extractPhotos(raw);
      final listPrice = raw['listPrice'] ?? raw['price'] ?? raw['listPriceCurrent'];

      return {
        'id': id,
        'mlsId': raw['mlsId'] ?? raw['listingId'] ?? id,
        'address': address,
        'listPrice': listPrice,
        'property': Map<String, dynamic>.from(raw['property'] ?? {}),
        'photos': photos,
        // keep full original payload for details
        ...raw,
      };
    }).toList();
  }

  String _extractId(Map<String, dynamic> m) {
    final id = m['listingId'] ?? m['mlsId'] ?? m['id'];
    if (id != null) return id.toString();
    // fallback hash of address+price
    final addr = jsonEncode(m['address'] ?? {});
    final price = (m['listPrice'] ?? m['price'] ?? '').toString();
    return base64Url.encode(utf8.encode('$addr|$price'));
  }

  Map<String, dynamic> _extractAddress(Map<String, dynamic> m) {
    final a = (m['address'] is Map) ? Map<String, dynamic>.from(m['address']) : <String, dynamic>{};
    if (a.isNotEmpty) return a;

    // try a few alternates
    final full = m['addressFull'] ?? m['fullAddress'];
    if (full is String) return {'full': full};

    // build from parts if available
    return {
      'streetNumber': m['streetNumber'] ?? m['street_number'],
      'streetName': m['streetName'] ?? m['street'],
      'city': m['city'],
      'state': m['state'],
      'postalCode': m['zipCode'] ?? m['postalCode'],
      'full': null,
    };
  }

  List<String> _extractPhotos(Map<String, dynamic> m) {
    final p = m['photos'];
    if (p is List) {
      return p.whereType<String>().toList();
    }
    if (m['photo'] is String) return [m['photo'] as String];
    if (m['imageUrl'] is String) return [m['imageUrl'] as String];
    return const <String>[];
  }

  String _priceText(dynamic value) {
    if (value == null) return '\$—';
    try {
      final n = (value is num) ? value.toInt() : int.parse(value.toString());
      final s = n.toString();
      final r = s.split('').reversed.toList();
      final out = StringBuffer();
      for (int i = 0; i < r.length; i++) {
        if (i != 0 && i % 3 == 0) out.write(',');
        out.write(r[i]);
      }
      return '\$${out.toString().split('').reversed.join()}';
    } catch (_) {
      return '\$${value.toString()}';
    }
  }

  String _addressText(Map<String, dynamic>? a) {
    if (a == null) return 'Unknown address';
    final full = a['full'];
    if (full is String && full.trim().isNotEmpty) return full;
    final parts = [
      a['streetNumber'],
      a['streetName'],
      a['city'],
      a['state'],
      a['postalCode'],
    ].where((e) => e != null && e.toString().trim().isNotEmpty).join(' ');
    return parts.isEmpty ? 'Unknown address' : parts;
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

          return ListView.builder(
            itemCount: listings.length,
            itemBuilder: (context, index) {
              final l = listings[index];
              final id = (l['id'] ?? '').toString();
              final isFav = favoritedListingIds.contains(id);

              final addressText = _addressText(l['address'] as Map<String, dynamic>?);
              final price = _priceText(l['listPrice']);
              final photos = (l['photos'] as List<String>? ?? const <String>[]);
              final heroTag = 'listing-photo-$id';

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ListingDetailsScreen(listing: l)),
                  );
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  clipBehavior: Clip.antiAlias,
                  elevation: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // PHOTO
                      SizedBox(
                        height: 200,
                        width: double.infinity,
                        child: photos.isEmpty
                            ? Container(
                                color: Colors.grey.shade200,
                                alignment: Alignment.center,
                                child: const Icon(Icons.photo, size: 48, color: Colors.grey),
                              )
                            : Hero(
                                tag: heroTag,
                                child: Image.network(
                                  photos.first,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey.shade200,
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                  ),
                                ),
                              ),
                      ),

                      // TEXT + HEART
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(price, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(addressText, style: const TextStyle(color: Colors.black87)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : null),
                              onPressed: () => _toggleFavorite(id),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
