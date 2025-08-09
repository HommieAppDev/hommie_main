import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String? selectedPrice; // e.g., "Up to $500k"
  String? selectedBeds;  // e.g., "3" or "10+"
  String? selectedBaths; // e.g., "2" or "10+"
  String locationQuery = '';
  double radius = 25.0;
  Position? currentPosition;
  bool useCurrentLocation = false;
  bool _locating = false;

  final List<String> priceOptions = [
    'Up to \$100k', 'Up to \$200k', 'Up to \$300k', 'Up to \$400k', 'Up to \$500k',
    'Up to \$600k', 'Up to \$700k', 'Up to \$800k', 'Up to \$900k', 'Up to \$1MM',
    'Up to \$2MM', 'Up to \$5MM', 'Up to \$10MM', '\$10MM+'
  ];

  final List<String> bedroomOptions = List.generate(10, (i) => '${i + 1}')..add('10+');
  final List<String> bathroomOptions = List.generate(10, (i) => '${i + 1}')..add('10+');

  void _openAdvancedSearch() async {
    final result = await Navigator.pushNamed(context, '/advanced-search');
    if (!mounted) return;
    if (result is Map) {
      setState(() {
        selectedBeds = result['beds'] == 11 ? '10+' : result['beds']?.toString();
        selectedBaths = result['baths'] == 11 ? '10+' : result['baths']?.toString();
      });
    }
  }

  Future<void> _determinePosition() async {
    setState(() => _locating = true);

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _locating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled.')),
      );
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
        setState(() => _locating = false);
        return;
      }
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    if (!mounted) return;
    setState(() {
      currentPosition = position;
      _locating = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location retrieved!')),
    );
  }

  // Converts "Up to $500k" => "500000" (as a string) for downstream parsing
  String? _priceToMaxDollars(String? label) {
    if (label == null) return null;
    final lower = label.toLowerCase();
    if (lower.contains('10mm+')) return null; // treat as no cap
    // Pull digits out, then scale if “k” or “mm” present
    final digits = RegExp(r'\d+').allMatches(lower).map((m) => m.group(0)).join();
    if (digits.isEmpty) return null;

    int base = int.parse(digits);
    if (lower.contains('mm')) {
      base *= 1000000;
    } else if (lower.contains('k')) {
      base *= 1000;
    }
    return base.toString();
  }

  void _submitSearch() {
    // We pass simple args; SearchResultsScreen already parses them.
    Navigator.pushNamed(
      context,
      '/search-results',
      arguments: {
        'query': useCurrentLocation ? null : locationQuery.trim(),
        'radius': useCurrentLocation ? radius : null,
        'price': _priceToMaxDollars(selectedPrice), // purely a max cap
        'beds': selectedBeds,
        'baths': selectedBaths,
        'latitude': currentPosition?.latitude,
        'longitude': currentPosition?.longitude,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCityZipEnabled = !useCurrentLocation;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Listings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                enabled: isCityZipEnabled,
                decoration: InputDecoration(
                  hintText: 'Search by city or zip...',
                  prefixIcon: const Icon(Icons.search),
                  filled: !isCityZipEnabled,
                  fillColor: isCityZipEnabled ? null : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onChanged: (val) => locationQuery = val,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: useCurrentLocation,
                    onChanged: (val) async {
                      setState(() => useCurrentLocation = val ?? false);
                      if (val == true) {
                        await _determinePosition();
                      }
                    },
                  ),
                  const Text("Use My Location"),
                  const SizedBox(width: 12),
                  if (_locating) const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
              const SizedBox(height: 8),
              Text('Search Radius: ${radius.round()} miles'),
              Slider(
                min: 5,
                max: 100,
                divisions: 19,
                value: radius,
                label: '${radius.round()} mi',
                onChanged: useCurrentLocation ? (val) => setState(() => radius = val) : null,
              ),
              const SizedBox(height: 16),

              const Text('Price (max)'),
              DropdownButton<String>(
                value: selectedPrice,
                hint: const Text('Select Price'),
                isExpanded: true,
                onChanged: (val) => setState(() => selectedPrice = val),
                items: priceOptions.map((price) => DropdownMenuItem(
                  value: price,
                  child: Text(price),
                )).toList(),
              ),
              const SizedBox(height: 16),

              const Text('Bedrooms (min)'),
              DropdownButton<String>(
                value: selectedBeds,
                hint: const Text('Select Bedrooms'),
                isExpanded: true,
                onChanged: (val) => setState(() => selectedBeds = val),
                items: bedroomOptions.map((bed) => DropdownMenuItem(
                  value: bed,
                  child: Text(bed),
                )).toList(),
              ),
              const SizedBox(height: 16),

              const Text('Bathrooms (min)'),
              DropdownButton<String>(
                value: selectedBaths,
                hint: const Text('Select Bathrooms'),
                isExpanded: true,
                onChanged: (val) => setState(() => selectedBaths = val),
                items: bathroomOptions.map((bath) => DropdownMenuItem(
                  value: bath,
                  child: Text(bath),
                )).toList(),
              ),

              const SizedBox(height: 16),
              TextButton(
                onPressed: _openAdvancedSearch,
                child: const Text('Advanced Search'),
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitSearch,
                  child: const Text('Search'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
