// listing_detail_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ListingDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> listing;

  const ListingDetailsScreen({super.key, required this.listing});

  @override
  State<ListingDetailsScreen> createState() => _ListingDetailsScreenState();
}

class _ListingDetailsScreenState extends State<ListingDetailsScreen> {
  late final List<String> _photos;
  late final String _mlsId;

  int _photoIndex = 0;
  bool _savingVisited = false;

  @override
  void initState() {
    super.initState();
    _photos = _safePhotos(widget.listing);
    _mlsId = (widget.listing['mlsId'] ??
            widget.listing['listingId'] ??
            widget.listing['id'] ??
            '')
        .toString();
  }

  List<String> _safePhotos(Map<String, dynamic> l) {
    final v = l['photos'];
    if (v is List) {
      return v.whereType<String>().toList();
    }
    return const <String>[];
  }

  Map<String, String> _imageAuthHeaders() {
    final user = dotenv.env['SIMPLYRETS_USER'] ?? 'simplyrets';
    final pass = dotenv.env['SIMPLYRETS_PASS'] ?? 'simplyrets';
    final token = base64Encode(utf8.encode('$user:$pass'));
    return {'Authorization': 'Basic $token'};
  }

  String _priceText(dynamic value) {
    if (value == null) return '\$—';
    try {
      final n = (value is num) ? value.toInt() : int.parse(value.toString());
      return '\$${_comma(n)}';
    } catch (_) {
      return '\$${value.toString()}';
    }
  }

  String _comma(int n) {
    final s = n.toString();
    final r = s.split('').reversed.toList();
    final out = StringBuffer();
    for (int i = 0; i < r.length; i++) {
      if (i != 0 && i % 3 == 0) out.write(',');
      out.write(r[i]);
    }
    return out.toString().split('').reversed.join();
  }

  String _address(Map<String, dynamic>? a) {
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

  Future<void> _markVisited() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to save visited homes.')),
      );
      return;
    }
    if (_mlsId.isEmpty) return;

    setState(() => _savingVisited = true);
    try {
      // Store inside user doc as an array + map with lastVisitedAt
      final docRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        final data = snap.data() ?? {};
        final List visited = List.from(data['visited'] ?? const []);
        // keep unique mlsId
        if (!visited.contains(_mlsId)) visited.add(_mlsId);

        tx.set(
          docRef,
          {
            'visited': visited,
            // optional: lastVisited map with timestamps
            'visitedMeta': {
              _mlsId: {
                'lastVisitedAt': FieldValue.serverTimestamp(),
                'address':
                    _address(widget.listing['address'] as Map<String, dynamic>?),
                'price': widget.listing['listPrice'],
                'thumb': _photos.isNotEmpty ? _photos.first : null,
              }
            }
          },
          SetOptions(merge: true),
        );
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Saved to 'Visited Properties'.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingVisited = false);
    }
  }

  void _openGallery(int start) {
    final headers = _imageAuthHeaders();
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (_) {
        int index = start;
        final controller = PageController(initialPage: start);
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Dismissible(
            key: const ValueKey('gallery'),
            direction: DismissDirection.down,
            onDismissed: (_) => Navigator.pop(context),
            child: Stack(
              children: [
                PageView.builder(
                  controller: controller,
                  itemCount: _photos.length,
                  onPageChanged: (i) => index = i,
                  itemBuilder: (_, i) => InteractiveViewer(
                    child: Container(
                      color: Colors.black,
                      alignment: Alignment.center,
                      child: Image.network(
                        _photos[i],
                        headers: headers,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image,
                          color: Colors.white70,
                          size: 80,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  top: 40,
                  child: IconButton(
                    color: Colors.white,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final headers = _imageAuthHeaders();
    final l = widget.listing;

    final address = _address(l['address'] as Map<String, dynamic>?);
    final price = _priceText(l['listPrice']);
    final property = (l['property'] as Map?) ?? {};
    final beds = property['bedrooms'] ?? l['beds'];
    final baths = property['bathsFull'] ?? l['baths'];
    final sqft = property['area'] ?? l['livingArea'];
    final lot = property['lotSize'] ?? property['lotSizeArea'];
    final year = property['yearBuilt'];
    final mls = (l['mls'] as Map?) ?? {};
    final dom = mls['daysOnMarket'] ?? l['daysOnMarket'];
    final remarks = l['remarks'] ?? l['publicRemarks'] ?? l['privateRemarks'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listing Details'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _savingVisited ? null : _markVisited,
        icon: _savingVisited
            ? const SizedBox(
                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.check_circle),
        label: const Text("I've Visited"),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // --- PHOTO CAROUSEL ---
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                PageView.builder(
                  itemCount: _photos.isEmpty ? 1 : _photos.length,
                  onPageChanged: (i) => setState(() => _photoIndex = i),
                  itemBuilder: (_, i) {
                    if (_photos.isEmpty) {
                      return Container(
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const Icon(Icons.photo, size: 48, color: Colors.grey),
                      );
                    }
                    return GestureDetector(
                      onTap: () => _openGallery(i),
                      child: Image.network(
                        _photos[i],
                        headers: headers,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        ),
                      ),
                    );
                  },
                ),
                if (_photos.length > 1)
                  Positioned(
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_photoIndex + 1} / ${_photos.length}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // --- HEADER: PRICE + ADDRESS ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              price,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              address,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
            ),
          ),

          // --- QUICK FACTS ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _fact(Icons.bed, '${beds ?? '—'} bd'),
                _fact(Icons.bathtub, '${baths ?? '—'} ba'),
                _fact(Icons.square_foot, '${sqft ?? '—'} sqft'),
                _fact(Icons.park, lot != null ? '$lot lot' : '— lot'),
                _fact(Icons.calendar_month, year != null ? '$year built' : '—'),
                _fact(Icons.timelapse, dom != null ? '$dom DOM' : '— DOM'),
                if (_mlsId.isNotEmpty) _fact(Icons.confirmation_number, 'MLS $_mlsId'),
              ],
            ),
          ),

          const Divider(height: 24),

          // --- REMARKS ---
          if (remarks != null && remarks.toString().trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                remarks.toString(),
                style: const TextStyle(fontSize: 16, height: 1.35),
              ),
            ),

          // (Optional) More sections you can add later:
          // - Schools, HOA, taxes, coordinates map, open house dates, etc.
          const SizedBox(height: 90), // keep space for FAB
        ],
      ),
    );
  }

  Widget _fact(IconData icon, String text) {
    return Chip(
      label: Text(text),
      avatar: Icon(icon, size: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
