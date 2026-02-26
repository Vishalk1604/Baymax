import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../models/clinic_model.dart';

class PlacesService {
  // Using multiple mirrors for better reliability
  static const List<String> _overpassMirrors = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://lz4.overpass-api.de/api/interpreter"
  ];

  Future<List<ClinicModel>> fetchNearbyClinics(double lat, double lng) async {
    // Increased radius to 80,000 meters (80km) for much broader coverage
    final String query = """
    [out:json][timeout:25];
    (
      node["amenity"~"hospital|clinic|doctors|dentist|pharmacy"](around:80000,$lat,$lng);
      way["amenity"~"hospital|clinic|doctors|dentist|pharmacy"](around:80000,$lat,$lng);
    );
    out center;
    """;

    String? lastError;

    for (String baseUrl in _overpassMirrors) {
      try {
        final response = await http.post(
          Uri.parse(baseUrl),
          body: {'data': query},
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          if (data.containsKey('remark') && data['remark'].toString().contains('timeout')) {
            lastError = "Server timeout, trying next mirror...";
            continue;
          }

          final List elements = data['elements'] ?? [];
          List<ClinicModel> clinics = [];

          for (var element in elements) {
            final tags = element['tags'] ?? {};
            final double clat = element['lat'] ?? element['center']?['lat'] ?? 0.0;
            final double clng = element['lon'] ?? element['center']?['lon'] ?? 0.0;
            
            if (clat == 0.0 || clng == 0.0) continue;

            final double distanceInMeters = Geolocator.distanceBetween(lat, lng, clat, clng);

            clinics.add(ClinicModel(
              id: element['id'].toString(),
              name: tags['name'] ?? tags['operator'] ?? 'Medical Center',
              address: tags['addr:full'] ?? 
                       "${tags['addr:city'] ?? ''} ${tags['addr:street'] ?? ''} ${tags['addr:housenumber'] ?? ''}".trim(),
              latitude: clat,
              longitude: clng,
              distance: distanceInMeters / 1000,
              isOpen: true,
              rating: null,
            ));
          }
          
          if (clinics.isEmpty) continue;

          clinics.sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));
          return clinics;
        } else {
          lastError = "Mirror $baseUrl returned ${response.statusCode}";
        }
      } catch (e) {
        lastError = "Connection to $baseUrl failed: $e";
      }
    }

    throw Exception(lastError ?? "Failed to load clinics from all available OSM mirrors");
  }
}
