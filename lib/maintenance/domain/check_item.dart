class CheckItem {
  int id;
  String name;
  int status; // 1 = BIEN, 2 = REGULAR, 3 = CORRECTIVA
  String? comment;
  String? imagePath;

  CheckItem({
    required this.id,
    required this.name,
    required this.status,
    this.comment,
    this.imagePath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status,
        'comment': comment,
        'imagePath': imagePath,
      };

  factory CheckItem.fromJson(Map<String, dynamic> json) => CheckItem(
        id: json['id'],
        name: json['name'],
        status: json['status'],
        comment: json['comment'],
        imagePath: json['imagePath'],
      );
}
