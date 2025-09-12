class PhotoItem {
  String imagePath;
  String type;
  String description;
  double? latitude;
  double? longitude;
  String address;
  bool needsAddressLookup;

  PhotoItem({
    required this.imagePath,
    required this.type,
    required this.description,
    this.longitude,
    this.latitude,
    this.address = '',
    this.needsAddressLookup = false,
  });

  Map<String, dynamic> toJson() => {
        'imagePath': imagePath,
        'type': type,
        'description': description,
        'longitude': longitude,
        'latitude': latitude,
        'address': address,
        'needsAddressLookup': needsAddressLookup,
      };

  factory PhotoItem.fromJson(Map<String, dynamic> json) => PhotoItem(
        imagePath: json['imagePath'],
        type: json['type'],
        description: json['description'],
        longitude: json['longitude'],
        latitude: json['latitude'],
        address: json['address'],
        needsAddressLookup: json['needsAddressLookup'],
      );
}
