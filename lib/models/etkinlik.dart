import '../services/dil_servisi.dart';

class Etkinlik {
  final String id;
  final String baslik;
  final String aciklama;
  final String saat;
  final DateTime tarih;
  final String yineleme;
  final DateTime? yinelemeBitis;
  final List<DateTime> iptalTarihler;
  final List<DateTime> tamamlananTarihler;
  bool katildim;

  static const Map<int, String> _gunKisaAdlar = {
    1: 'Pzt',
    2: 'Sal',
    3: 'Çrş',
    4: 'Pş',
    5: 'Cu',
    6: 'Ct',
    7: 'Pz',
  };

  Etkinlik({
    required this.id,
    required this.baslik,
    required this.aciklama,
    required this.saat,
    DateTime? tarih,
    this.yineleme = 'Tek seferlik',
    this.yinelemeBitis,
    List<DateTime>? iptalTarihler,
    List<DateTime>? tamamlananTarihler,
    this.katildim = false,
  })  : tarih = tarih ?? DateTime.now(),
        iptalTarihler = iptalTarihler ?? [],
        tamamlananTarihler =
            tamamlananTarihler ?? (katildim && tarih != null ? [tarih] : []);

  String get saatEtiketi => saat == 'Tüm Gün' ? 'tum_gun'.tr : saat;

  String get yinelemeEtiketi {
    if (yineleme.startsWith('Haftanın Günleri')) {
      final icerik = yineleme.replaceFirst('Haftanın Günleri', '').trim();
      return '${'Haftanın Günleri'.tr}$icerik';
    }
    return yineleme.tr;
  }

  bool oGunIptalMi(DateTime gun) {
    return iptalTarihler.any(
      (t) => t.year == gun.year && t.month == gun.month && t.day == gun.day,
    );
  }

  bool oGunTamamlandiMi(DateTime gun) {
    if (yineleme == 'Tek seferlik') {
      return katildim ||
          tamamlananTarihler.any(
            (t) => t.year == gun.year && t.month == gun.month && t.day == gun.day,
          );
    }
    return tamamlananTarihler.any(
      (t) => t.year == gun.year && t.month == gun.month && t.day == gun.day,
    );
  }

  bool oGunAktifMi(DateTime hedefTarih) {
    final eTarih = DateTime(tarih.year, tarih.month, tarih.day);
    final hedef = DateTime(hedefTarih.year, hedefTarih.month, hedefTarih.day);

    if (hedef.isBefore(eTarih)) return false;
    if (oGunIptalMi(hedef)) return false;

    if (yinelemeBitis != null) {
      final bitis = DateTime(
        yinelemeBitis!.year,
        yinelemeBitis!.month,
        yinelemeBitis!.day,
      );
      if (hedef.isAfter(bitis)) return false;
    }

    if (yineleme.startsWith('Haftanın Günleri')) {
      final gunIsmi = _gunKisaAdlar[hedef.weekday];
      return gunIsmi != null && yineleme.contains(gunIsmi);
    }

    switch (yineleme) {
      case 'Her gün':
        return true;
      case 'Hafta içi':
        return hedef.weekday >= 1 && hedef.weekday <= 5;
      case 'Hafta sonu':
        return hedef.weekday == 6 || hedef.weekday == 7;
      case 'Haftada bir':
        return hedef.weekday == eTarih.weekday;
      case 'Ayda bir':
        return hedef.day == eTarih.day;
      case 'Yılda bir (Doğum Günü / Özel Gün)':
        return hedef.month == eTarih.month && hedef.day == eTarih.day;
      case 'Her ayın ilk günü':
        return hedef.day == 1;
      case 'Her ayın son günü':
        final sonGun = DateTime(hedef.year, hedef.month + 1, 0).day;
        return hedef.day == sonGun;
      case 'Tek seferlik':
      default:
        return eTarih.year == hedef.year &&
            eTarih.month == hedef.month &&
            eTarih.day == hedef.day;
    }
  }

  Etkinlik copyWith({
    String? id,
    String? baslik,
    String? aciklama,
    String? saat,
    DateTime? tarih,
    String? yineleme,
    DateTime? yinelemeBitis,
    List<DateTime>? iptalTarihler,
    List<DateTime>? tamamlananTarihler,
    bool? katildim,
  }) {
    return Etkinlik(
      id: id ?? this.id,
      baslik: baslik ?? this.baslik,
      aciklama: aciklama ?? this.aciklama,
      saat: saat ?? this.saat,
      tarih: tarih ?? this.tarih,
      yineleme: yineleme ?? this.yineleme,
      yinelemeBitis: yinelemeBitis ?? this.yinelemeBitis,
      iptalTarihler: iptalTarihler ?? List<DateTime>.from(this.iptalTarihler),
      tamamlananTarihler:
          tamamlananTarihler ?? List<DateTime>.from(this.tamamlananTarihler),
      katildim: katildim ?? this.katildim,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'baslik': baslik,
        'aciklama': aciklama,
        'saat': saat,
        'tarih': tarih.toIso8601String(),
        'yineleme': yineleme,
        'yinelemeBitis': yinelemeBitis?.toIso8601String(),
        'iptalTarihler': iptalTarihler.map((t) => t.toIso8601String()).toList(),
        'tamamlananTarihler':
            tamamlananTarihler.map((t) => t.toIso8601String()).toList(),
        'katildim': katildim,
      };

  factory Etkinlik.fromJson(Map<String, dynamic> json) {
    final parsedTarih =
        DateTime.tryParse(json['tarih']?.toString() ?? '') ?? DateTime.now();
    final parsedTamamlanan = (json['tamamlananTarihler'] as List<dynamic>?)
            ?.map((e) => DateTime.tryParse(e.toString()))
            .whereType<DateTime>()
            .toList() ??
        [];
    final eskiKatildim = json['katildim'] ?? false;
    final yinelemeStr = json['yineleme']?.toString() ?? 'Tek seferlik';

    if (parsedTamamlanan.isEmpty &&
        eskiKatildim &&
        yinelemeStr != 'Tek seferlik') {
      parsedTamamlanan.add(parsedTarih);
    }

    return Etkinlik(
      id: json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      baslik: json['baslik']?.toString() ?? '',
      aciklama: json['aciklama']?.toString() ?? '',
      saat: json['saat']?.toString() ?? 'Tüm Gün',
      tarih: parsedTarih,
      yineleme: yinelemeStr,
      yinelemeBitis: json['yinelemeBitis'] != null
          ? DateTime.tryParse(json['yinelemeBitis'].toString())
          : null,
      iptalTarihler: (json['iptalTarihler'] as List<dynamic>?)
              ?.map((e) => DateTime.tryParse(e.toString()))
              .whereType<DateTime>()
              .toList() ??
          [],
      tamamlananTarihler: parsedTamamlanan,
      katildim: eskiKatildim,
    );
  }
}