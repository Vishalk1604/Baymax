class ClinicModel {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double? rating;
  final bool? isOpen;
  final String? phoneNumber;
  final double? distance;

  ClinicModel({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.rating,
    this.isOpen,
    this.phoneNumber,
    this.distance,
  });

  factory ClinicModel.fromJson(Map<String, dynamic> json, double currentLat, double currentLong) {
    final location = json['geometry']['location'];
    return ClinicModel(
      id: json['place_id'],
      name: json['name'],
      address: json['vicinity'] ?? json['formatted_address'] ?? 'No address available',
      latitude: location['lat'],
      longitude: location['lng'],
      rating: json['rating']?.toDouble(),
      isOpen: json['opening_hours']?['open_now'],
      // Note: Nearby search doesn't always return phone number, 
      // usually requires a separate Place Details request.
    );
  }
}
