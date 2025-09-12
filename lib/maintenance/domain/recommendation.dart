class Recommendation {
  String id;
  String description;
  String? imagePath;
  double? latitude;
  double? longitude;
  String? address;
  bool needsAddressLookup;

  Recommendation({
    required this.id,
    required this.description,
    this.imagePath,
    this.latitude,
    this.longitude,
    this.address,
    this.needsAddressLookup = false,
  });
}
