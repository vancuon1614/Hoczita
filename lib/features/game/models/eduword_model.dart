class EduwordType {
  final int id;
  final String title;
  final String slug;

  EduwordType({
    required this.id,
    required this.title,
    required this.slug,
  });

  factory EduwordType.fromJson(Map<String, dynamic> json) {
    return EduwordType(
      id: json['id'] as int,
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
    );
  }
}

class EduwordAcf {
  final String viword;
  final String description;
  final String videscription;
  final String img;
  final String transcription;
  final String example;
  final EduwordType? type;
  final String level;

  EduwordAcf({
    required this.viword,
    required this.description,
    required this.videscription,
    required this.img,
    required this.transcription,
    required this.example,
    this.type,
    required this.level,
  });

  factory EduwordAcf.fromJson(Map<String, dynamic> json) {
    return EduwordAcf(
      viword: json['viword'] ?? '',
      description: json['description'] ?? '',
      videscription: json['videscription'] ?? '',
      img: json['img'] ?? '',
      transcription: json['transcription'] ?? '',
      example: json['example'] ?? '',
      type: json['type'] != null ? EduwordType.fromJson(json['type']) : null,
      level: json['level'] ?? '',
    );
  }
}

class EduwordModel {
  final int id;
  final String title;
  final EduwordAcf acf;
  final String createdAt;

  EduwordModel({
    required this.id,
    required this.title,
    required this.acf,
    required this.createdAt,
  });

  factory EduwordModel.fromJson(Map<String, dynamic> json) {
    return EduwordModel(
      id: json['id'] as int,
      title: json['title'] ?? '',
      acf: EduwordAcf.fromJson(json['acf'] ?? {}),
      createdAt: json['created_at'] ?? '',
    );
  }
}
