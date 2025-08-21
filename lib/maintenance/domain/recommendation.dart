class Recommendation {
  String id;
  String description;
  String? imagePath;

  Recommendation({
    required this.id,
    required this.description,
    this.imagePath,
  });
}
