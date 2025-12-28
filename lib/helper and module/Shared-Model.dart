class SharedList {
  final int id;
  final String name;
  final int ownerId;
  final String shareCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  SharedList({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.shareCode,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SharedList.fromJson(Map<String, dynamic> json) {
    return SharedList(
      id: json['id'],
      name: json['name'],
      ownerId: json['ownerId'],
      shareCode: json['shareCode'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ownerId': ownerId,
      'shareCode': shareCode,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Helper to check ownership
  bool isOwner(int userId) => ownerId == userId;
}
