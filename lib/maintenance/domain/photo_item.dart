class PhotoItem {
  String imagePath;
  String type;
  String description;

  PhotoItem({
    required this.imagePath,
    required this.type,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
        'imagePath': imagePath,
        'type': type,
        'description': description,
      };

  factory PhotoItem.fromJson(Map<String, dynamic> json) => PhotoItem(
        imagePath: json['imagePath'],
        type: json['type'],
        description: json['description'],
      );
}
