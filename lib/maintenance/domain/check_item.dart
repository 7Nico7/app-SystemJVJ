class CheckItem {
  int id;
  String name;
  int status; // 1 = BIEN, 2 = REGULAR, 3 = CORRECTIVA
  String? comment;
  String? imagePath;
  double? latitude;
  double? longitude;
  String? address;
  bool needsAddressLookup;

  CheckItem({
    required this.id,
    required this.name,
    required this.status,
    this.comment,
    this.imagePath,
    this.latitude,
    this.longitude,
    this.address,
    this.needsAddressLookup = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status,
        'comment': comment,
        'imagePath': imagePath,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'needsAddressLookup': needsAddressLookup,
      };

  factory CheckItem.fromJson(Map<String, dynamic> json) => CheckItem(
        id: json['id'],
        name: json['name'],
        status: json['status'],
        comment: json['comment'],
        imagePath: json['imagePath'],
        latitude: json['latitude'],
        longitude: json['longitude'],
        address: json['address'],
        needsAddressLookup: json['needsAddressLookup'],
      );
}
