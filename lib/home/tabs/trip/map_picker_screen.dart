import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/src/misc/position.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng _pickedLocation = const LatLng(20.5937, 78.9629);
  final MapController _mapController = MapController();
  Timer? _debounce;

  String _addressText = "Move the map to pin your location";
  bool _isResolving = false;
  bool _isLoadingLocation = false;
  bool _mapReady = false;

  // Search
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDebounce;
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    // Location is requested in _onMapReady so the map is ready to move
  }

  // ── Map ready callback ────────────────────────────────────────────────────
  Future<void> _onMapReady() async {
    setState(() => _mapReady = true);
    await _goToCurrentLocation();
  }

  // ── Ask permission + fly to GPS ───────────────────────────────────────────
  Future<void> _goToCurrentLocation() async {
    if (!mounted) return;
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack("Please enable location services.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnack("Location permission permanently denied. Enable it in Settings.");
        return;
      }
      if (permission == LocationPermission.denied) {
        _showSnack("Location permission denied.");
        return;
      }

      final Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final LatLng current = LatLng(pos.latitude, pos.longitude);
      if (mounted) setState(() => _pickedLocation = current);
      if (_mapReady) _mapController.move(current, 16.0);
      await _reverseGeocode(current);
    } catch (e) {
      _showSnack("Could not get location.");
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  // ── Reverse geocode (drag pin) ────────────────────────────────────────────
  Future<void> _reverseGeocode(LatLng position) async {
    if (!mounted) return;
    setState(() => _isResolving = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json'
        '&lat=${position.latitude}'
        '&lon=${position.longitude}'
        '&zoom=18'
        '&addressdetails=1',
      );
      final response = await http.get(
        uri,
        headers: {'Accept-Language': 'en', 'User-Agent': 'FlutterTripApp/1.0'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String displayName = data['display_name'] ?? 'Unknown location';
        final parts = displayName.split(',');
        final short = parts.take(3).join(',').trim();
        if (mounted) setState(() => _addressText = short);
      } else {
        if (mounted) setState(() => _addressText = 'Could not resolve address');
      }
    } catch (_) {
      if (mounted) setState(() => _addressText = 'Could not resolve address');
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  // ── Forward search (search bar) ───────────────────────────────────────────
  Future<void> _searchPlace(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showResults = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?format=json'
        '&q=${Uri.encodeComponent(query)}'
        '&limit=5'
        '&addressdetails=1',
      );
      final response = await http.get(
        uri,
        headers: {'Accept-Language': 'en', 'User-Agent': 'FlutterTripApp/1.0'},
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _searchResults =
                data.map((e) => e as Map<String, dynamic>).toList();
            _showResults = _searchResults.isNotEmpty;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() { _searchResults = []; _showResults = false; });
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _searchPlace(value);
    });
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    final double lat = double.parse(result['lat']);
    final double lon = double.parse(result['lon']);
    final LatLng loc = LatLng(lat, lon);
    final String name = result['display_name'] ?? '';
    final parts = name.split(',');
    final short = parts.take(3).join(',').trim();

    setState(() {
      _pickedLocation = loc;
      _addressText = short;
      _searchResults = [];
      _showResults = false;
      _searchController.clear();
    });
    _mapController.move(loc, 16.0);
    FocusScope.of(context).unfocus();
  }

  // ── Map drag ──────────────────────────────────────────────────────────────
  void _onMapPositionChanged(MapPosition position, bool hasGesture) {
    if (position.center != null) {
      setState(() => _pickedLocation = position.center!);
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 600), () {
        _reverseGeocode(_pickedLocation);
      });
    }
  }

  void _confirmLocation() {
    Navigator.pop(context, {
      'latlng': _pickedLocation,
      'address': _addressText,
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Pin Your Start Location",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [

          // ╔══════════════════════════════════╗
          // ║         MAP  (Expanded)          ║
          // ╚══════════════════════════════════╝
          Expanded(
            child: Stack(
              children: [

                // ── Tiles ──────────────────────────────────────────────────
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _pickedLocation,
                    initialZoom: 5.0,
                    onMapReady: _onMapReady,
                    onPositionChanged: _onMapPositionChanged,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.flutter_app',
                    ),
                  ],
                ),

                // ── Centre pin ─────────────────────────────────────────────
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_pin, color: Colors.red, size: 48),
                      SizedBox(
                        width: 12,
                        height: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius:
                                BorderRadius.all(Radius.circular(4)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Search bar + dropdown ──────────────────────────────────
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Column(
                    children: [
                      // Search field
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: "Search a place...",
                            hintStyle: const TextStyle(
                                color: Colors.grey, fontSize: 14),
                            prefixIcon: const Icon(Icons.search,
                                color: Colors.grey, size: 20),
                            suffixIcon: _isSearching
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  )
                                : _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.close,
                                            size: 18, color: Colors.grey),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {
                                            _searchResults = [];
                                            _showResults = false;
                                          });
                                        },
                                      )
                                    : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),

                      // Results list
                      if (_showResults)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.10),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _searchResults.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1, indent: 16),
                            itemBuilder: (context, index) {
                              final result = _searchResults[index];
                              final name =
                                  result['display_name'] as String? ?? '';
                              final parts = name.split(',');
                              final title = parts.first.trim();
                              final subtitle = parts
                                  .skip(1)
                                  .take(2)
                                  .join(',')
                                  .trim();
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.location_on,
                                    color: Colors.red, size: 18),
                                title: Text(title,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(subtitle,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                onTap: () =>
                                    _selectSearchResult(result),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),

                // ── My-location FAB — bottom-right of map, never overlaps card
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'myLocation',
                    backgroundColor: Colors.white,
                    elevation: 4,
                    onPressed: _isLoadingLocation
                        ? null
                        : _goToCurrentLocation,
                    child: _isLoadingLocation
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.my_location,
                            color: Colors.black),
                  ),
                ),
              ],
            ),
          ),

          // ╔══════════════════════════════════╗
          // ║      BOTTOM CARD (fixed)         ║
          // ╚══════════════════════════════════╝
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "SELECTED LOCATION",
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _isResolving
                          ? const Row(
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text("Resolving address...",
                                    style:
                                        TextStyle(color: Colors.grey)),
                              ],
                            )
                          : Text(
                              _addressText,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "${_pickedLocation.latitude.toStringAsFixed(5)}, "
                  "${_pickedLocation.longitude.toStringAsFixed(5)}",
                  style:
                      const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_isResolving ||
                            _addressText ==
                                "Move the map to pin your location")
                        ? null
                        : _confirmLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      padding:
                          const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text(
                      "Confirm Location",
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
