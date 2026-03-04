class Category {
  final int? id;
  final String name;
  final String icon;
  final String colorHex;

  Category({
    this.id,
    required this.name,
    required this.icon,
    required this.colorHex,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
        'colorHex': colorHex,
      };

  factory Category.fromMap(Map<String, dynamic> map) => Category(
        id: map['id'],
        name: map['name'],
        icon: map['icon'],
        colorHex: map['colorHex'],
      );

  Category copyWith({int? id, String? name, String? icon, String? colorHex}) =>
      Category(
        id: id ?? this.id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        colorHex: colorHex ?? this.colorHex,
      );
}
