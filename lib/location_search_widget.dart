import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationSearchWidget extends StatefulWidget {
  final Function(String query, double radiusMiles, Position? current) onSearch;

  const LocationSearchWidget({super.key, required this.onSearch});

  @override
  State<LocationSearchWidget> createState() => _LocationSearchWidgetState();
}

class _LocationSearchWidgetState extends State<LocationSearchWidget> {
  final TextEditingController _locationController = TextEditingController();
  double _radius = 10; // miles
  Position? _currentPosition;
  bool _locating = false;

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _locating = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
        setState(() => _locating = false);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission permanently denied. Enable it in Settings.'),
            duration: Duration(seconds: 4),
          ),
        );
        await Geolocator.openAppSettings();
        setState(() => _locating = false);
        return;
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission not granted.')),
        );
        setState(() => _locating = false);
        return;
      }

      // ✅ Correct API: pass a LocationSettings, not a LocationAccuracy directly
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _locating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location retrieved!')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _locating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          "Search Location",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Query field
        TextField(
          controller: _locationController,
          decoration: const InputDecoration(
            labelText: 'Enter ZIP code or city',
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 12),

        // Locate Me button
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.my_location),
                label: Text(_locating ? "Locating..." : "Locate Me"),
                onPressed: _locating ? null : _getCurrentLocation,
              ),
            ),
          ],
        ),

        if (_currentPosition != null) ...[
          const SizedBox(height: 8),
          Text(
            "Current: ${_currentPosition!.latitude.toStringAsFixed(4)}, "
            "${_currentPosition!.longitude.toStringAsFixed(4)}",
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],

        const SizedBox(height: 16),

        // Radius slider
        Text("Search radius: ${_radius.toInt()} miles"),
        Slider(
          value: _radius,
          min: 5,
          max: 100,
          divisions: 19,
          label: "${_radius.toInt()} mi",
          onChanged: (v) => setState(() => _radius = v),
        ),

        const SizedBox(height: 12),

        // Search button
        ElevatedButton.icon(
          icon: const Icon(Icons.search),
          label: const Text('Search'),
          onPressed: () {
            final query = _locationController.text.trim();
            widget.onSearch(query, _radius, _currentPosition);
          },
        ),
      ],
    );
  }
}
