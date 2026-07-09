class ExamGroup {
  final String id;
  final String name;
  final String colorHex;
  final int orderIndex;

  const ExamGroup({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.orderIndex,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'colorHex': colorHex,
      'orderIndex': orderIndex,
    };
  }

  factory ExamGroup.fromMap(String id, Map<String, dynamic> map) {
    return ExamGroup(
      id: id,
      name: map['name'] as String? ?? '',
      colorHex: map['colorHex'] as String? ?? '#3F51B5',
      orderIndex: map['orderIndex'] as int? ?? 0,
    );
  }

  ExamGroup copyWith({
    String? id,
    String? name,
    String? colorHex,
    int? orderIndex,
  }) {
    return ExamGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }
}
