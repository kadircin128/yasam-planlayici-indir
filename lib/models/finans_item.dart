import 'dart:math';
import '../services/dil_servisi.dart';

class FinansItem {
  final String id;
  final String baslik;
  final double miktar;
  final String tur;
  final DateTime tarih;
  final String yineleme;
  final List<DateTime> iptalTarihler;
  final bool odendi;
  final double odenenMiktar;
  final int? hesapKesimGunu;
  final int? sonOdemeGunu;
  final bool ekstreGirildi;
  final bool isDegiskenFatura;
  final bool otomatikOdemede;
  final double? gecenAykiTutar;
  final double? kartLimiti;

  static const Map<int, String> _gunKisaAdlar = {
    1: 'Pzt',
    2: 'Sal',
    3: 'Çrş',
    4: 'Pş',
    5: 'Cu',
    6: 'Ct',
    7: 'Pz',
  };

  FinansItem({
    required this.id,
    required this.baslik,
    required this.miktar,
    required this.tur,
    required this.tarih,
    this.yineleme = 'Tek seferlik',
    List<DateTime>? iptalTarihler,
    this.odendi = false,
    this.odenenMiktar = 0.0,
    this.hesapKesimGunu,
    this.sonOdemeGunu,
    this.ekstreGirildi = true,
    this.isDegiskenFatura = false,
    this.otomatikOdemede = false,
    this.gecenAykiTutar,
    this.kartLimiti,
  }) : iptalTarihler = iptalTarihler ?? [];

  String get turEtiketi {
    switch (tur) {
      case 'Gelir':
        return 'finans_tur_gelir'.tr;
      case 'Gider':
        return 'finans_tur_gider'.tr;
      case 'Fatura':
        return 'finans_tur_fatura'.tr;
      case 'Kredi Kartı':
        return 'finans_tur_kredi_karti'.tr;
      case 'Borç':
        return 'finans_tur_borc'.tr;
      case 'Alacak':
        return 'finans_tur_alacak'.tr;
      default:
        return tur.tr;
    }
  }

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

  /// Dönem özeti, gün karnesi, acil faturalar ve asistan işlemleri için
  bool oGunAktifMi(DateTime hedefTarih) {
    final fTarih = DateTime(tarih.year, tarih.month, tarih.day);
    final hedef = DateTime(hedefTarih.year, hedefTarih.month, hedefTarih.day);

    if (tur == 'Kredi Kartı') {
      if (odendi || odenenMiktar > 0) {
        return fTarih.year == hedef.year &&
            fTarih.month == hedef.month &&
            fTarih.day == hedef.day;
      }
      if (sonOdemeGunu != null) {
        final maxGun = DateTime(hedef.year, hedef.month + 1, 0).day;
        return hedef.day == min(sonOdemeGunu!, maxGun) &&
            !hedef.isBefore(fTarih);
      }
      return fTarih.year == hedef.year &&
          fTarih.month == hedef.month &&
          fTarih.day == hedef.day;
    }

    return _tekrarliGunEslesiyorMu(fTarih, hedef);
  }

  /// Takvim noktaları ve günlük akış kartları için (hesap kesim günü dahil)
  bool takvimdeOgunMu(DateTime hedefTarih) {
    final fTarih = DateTime(tarih.year, tarih.month, tarih.day);
    final hedef = DateTime(hedefTarih.year, hedefTarih.month, hedefTarih.day);

    if (hedef.isBefore(fTarih)) return false;
    if (oGunIptalMi(hedef)) return false;

    if (tur == 'Kredi Kartı') {
      final kesimMi = hesapKesimGunu != null && hedef.day == hesapKesimGunu;
      final sonOdemeMi = sonOdemeGunu != null && hedef.day == sonOdemeGunu;
      final odemeGunuMu = (odendi || odenenMiktar > 0) &&
          fTarih.year == hedef.year &&
          fTarih.month == hedef.month &&
          fTarih.day == hedef.day;
      return kesimMi || sonOdemeMi || odemeGunuMu;
    }

    return _tekrarliGunEslesiyorMu(fTarih, hedef);
  }

  bool _tekrarliGunEslesiyorMu(DateTime fTarih, DateTime hedef) {
    if (hedef.isBefore(fTarih)) return false;
    if (oGunIptalMi(hedef)) return false;

    if (yineleme.startsWith('Haftanın Günleri')) {
      final gunIsmi = _gunKisaAdlar[hedef.weekday];
      return gunIsmi != null && yineleme.contains(gunIsmi);
    }

    if (yineleme.startsWith('Yılda bir')) {
      return hedef.month == fTarih.month && hedef.day == fTarih.day;
    }

    switch (yineleme) {
      case 'Her gün':
        return true;
      case 'Hafta içi':
        return hedef.weekday >= 1 && hedef.weekday <= 5;
      case 'Hafta sonu':
        return hedef.weekday == 6 || hedef.weekday == 7;
      case 'Haftada bir':
        return hedef.weekday == fTarih.weekday;
      case 'Ayda bir':
      case 'Her ay (Aynı gün)':
        return hedef.day == fTarih.day;
      case 'Her ayın 15\'i (Maaş günü)':
        return hedef.day == 15;
      case 'Her ayın 1\'i':
      case 'Her ayın ilk günü':
        return hedef.day == 1;
      case 'Her ayın son günü':
        final ayinSonGunu = DateTime(hedef.year, hedef.month + 1, 0).day;
        return hedef.day == ayinSonGunu;
      case 'Tek seferlik':
      default:
        return fTarih.year == hedef.year &&
            fTarih.month == hedef.month &&
            fTarih.day == hedef.day;
    }
  }

  double get asgariOran => 0.20;

  double get kalanMiktar {
    final fark = miktar - odenenMiktar;
    return fark > 0 ? fark : 0.0;
  }

  double get tahminiOdeme {
    if (tur == 'Kredi Kartı') {
      if (odendi) return 0.0;
      if (odenenMiktar > 0) return odenenMiktar + kalanMiktar;
      return miktar * asgariOran;
    }
    if (tur == 'Fatura' && isDegiskenFatura && !ekstreGirildi) {
      return gecenAykiTutar ?? 0.0;
    }
    return miktar;
  }

  FinansItem copyWith({
    String? id,
    String? baslik,
    double? miktar,
    String? tur,
    DateTime? tarih,
    String? yineleme,
    List<DateTime>? iptalTarihler,
    bool? odendi,
    double? odenenMiktar,
    int? hesapKesimGunu,
    int? sonOdemeGunu,
    bool? ekstreGirildi,
    bool? isDegiskenFatura,
    bool? otomatikOdemede,
    double? gecenAykiTutar,
    double? kartLimiti,
  }) {
    return FinansItem(
      id: id ?? this.id,
      baslik: baslik ?? this.baslik,
      miktar: miktar ?? this.miktar,
      tur: tur ?? this.tur,
      tarih: tarih ?? this.tarih,
      yineleme: yineleme ?? this.yineleme,
      iptalTarihler: iptalTarihler ?? List<DateTime>.from(this.iptalTarihler),
      odendi: odendi ?? this.odendi,
      odenenMiktar: odenenMiktar ?? this.odenenMiktar,
      hesapKesimGunu: hesapKesimGunu ?? this.hesapKesimGunu,
      sonOdemeGunu: sonOdemeGunu ?? this.sonOdemeGunu,
      ekstreGirildi: ekstreGirildi ?? this.ekstreGirildi,
      isDegiskenFatura: isDegiskenFatura ?? this.isDegiskenFatura,
      otomatikOdemede: otomatikOdemede ?? this.otomatikOdemede,
      gecenAykiTutar: gecenAykiTutar ?? this.gecenAykiTutar,
      kartLimiti: kartLimiti ?? this.kartLimiti,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'baslik': baslik,
        'miktar': miktar,
        'tur': tur,
        'tarih': tarih.toIso8601String(),
        'yineleme': yineleme,
        'iptalTarihler': iptalTarihler.map((t) => t.toIso8601String()).toList(),
        'odendi': odendi,
        'odenenMiktar': odenenMiktar,
        'hesapKesimGunu': hesapKesimGunu,
        'sonOdemeGunu': sonOdemeGunu,
        'ekstreGirildi': ekstreGirildi,
        'isDegiskenFatura': isDegiskenFatura,
        'otomatikOdemede': otomatikOdemede,
        'gecenAykiTutar': gecenAykiTutar,
        'kartLimiti': kartLimiti,
      };

  factory FinansItem.fromJson(Map<String, dynamic> json) => FinansItem(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        baslik: json['baslik'] ?? '',
        miktar: (json['miktar'] as num?)?.toDouble() ?? 0.0,
        tur: json['tur'] ?? 'Gider',
        tarih: DateTime.tryParse(json['tarih'] ?? '') ?? DateTime.now(),
        yineleme: json['yineleme'] ?? 'Tek seferlik',
        iptalTarihler: (json['iptalTarihler'] as List<dynamic>?)
                ?.map((e) => DateTime.tryParse(e.toString()))
                .whereType<DateTime>()
                .toList() ??
            [],
        odendi: json['odendi'] ?? false,
        odenenMiktar: (json['odenenMiktar'] as num?)?.toDouble() ?? 0.0,
        hesapKesimGunu: (json['hesapKesimGunu'] as num?)?.toInt(),
        sonOdemeGunu: (json['sonOdemeGunu'] as num?)?.toInt(),
        ekstreGirildi: json['ekstreGirildi'] ?? true,
        isDegiskenFatura: json['isDegiskenFatura'] ?? false,
        otomatikOdemede: json['otomatikOdemede'] ?? false,
        gecenAykiTutar: (json['gecenAykiTutar'] as num?)?.toDouble(),
        kartLimiti: (json['kartLimiti'] as num?)?.toDouble(),
      );
}