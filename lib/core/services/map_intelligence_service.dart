import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class MapIntelligenceService {
  // OpenRouteService API Key (provided by user)
  static const String _orsKey = "EyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjIzZmQ0MDA0ZWI2YTQzNTQ5N2YzMmU2ZjkwNzYwZDljIiwiaCI6Im11cm11cjY0In0=";

  static final MapIntelligenceService instance = MapIntelligenceService._init();
  MapIntelligenceService._init();

  /// Converts Coordinates (Lat/Lng) to a real Ghana address using OpenRouteService
  Future<String> getAddressFromLatLng(LatLng position) async {
    final url = Uri.parse(
      'https://api.openrouteservice.org/geocode/reverse?api_key=$_orsKey&point.lon=${position.longitude}&point.lat=${position.latitude}'
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['features'] != null && data['features'].isNotEmpty) {
          return data['features'][0]['properties']['label'];
        }
      }
      return "Ghana Security Sector [${position.latitude.toStringAsFixed(2)}]";
    } catch (e) {
      return "Accra, Ghana (Local sector detected)";
    }
  }

  /// PRO FEATURE: Gets optimized route directions between two points
  Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
      'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$_orsKey&start=${start.longitude},${start.latitude}&end=${end.longitude},${end.latitude}'
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coords = data['features'][0]['geometry']['coordinates'] as List;
        return coords.map((c) => LatLng(c[1], c[0])).toList();
      }
    } catch (e) {
      print("Routing error: $e");
    }
    return [];
  }
}
