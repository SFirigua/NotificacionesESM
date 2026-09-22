/// Persona a la que se le recuerda su cumpleaños.
class Birthday {
  const Birthday({this.id, required this.name, required this.birthDate});

  /// Id autogenerado por SQLite. Se reutiliza como id de la notificación.
  final int? id;

  final String name;

  /// Solo importan el día y el mes; el año se usa para calcular la edad.
  final DateTime birthDate;

  Birthday copyWith({int? id, String? name, DateTime? birthDate}) {
    return Birthday(
      id: id ?? this.id,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'birth_date': birthDate.toIso8601String(),
    };
  }

  factory Birthday.fromMap(Map<String, Object?> map) {
    return Birthday(
      id: map['id'] as int?,
      name: map['name'] as String,
      birthDate: DateTime.parse(map['birth_date'] as String),
    );
  }
}
