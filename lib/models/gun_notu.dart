class GunNotu {
  final String id;
  final String metin;
  final DateTime tarih;

  GunNotu({
    required this.id,
    required this.metin,
    required this.tarih,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'metin': metin,
        'tarih': tarih.toIso8601String(),
      };

  factory GunNotu.fromJson(Map<String, dynamic> json) => GunNotu(
        id: json['id'],
        metin: json['metin'],
        tarih: DateTime.parse(json['tarih']),
      );
}