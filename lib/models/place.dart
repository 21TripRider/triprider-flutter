class Place {
  final String name;
  final double lat;
  final double lon;
  final String? phone;
  final String? address;
  final String? url;

  const Place({
    required this.name,
    required this.lat,
    required this.lon,
    this.phone,
    this.address,
    this.url,
  });

  factory Place.fromKakaoDoc(Map<String, dynamic> d) {
    final name = d['place_name']?.toString() ?? '';
    final y = double.tryParse(d['y']?.toString() ?? '') ?? 0.0;
    final x = double.tryParse(d['x']?.toString() ?? '') ?? 0.0;
    return Place(
      name: name,
      lat: y,
      lon: x,
      phone: d['phone']?.toString(),
      address: d['road_address_name']?.toString() ?? d['address_name']?.toString(),
      url: d['place_url']?.toString(),
    );
  }
}


