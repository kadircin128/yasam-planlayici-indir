import 'dart:convert';
import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/etkinlik.dart';
import '../models/finans_item.dart';
import 'dil_servisi.dart';

@pragma('vm:entry-point')
void bildirimArkaPlanYaniti(NotificationResponse response) {
  // Uygulama kapalıyken/arka plandayken aksiyon butonundan veya metin girişinden gelen yanıtlar
  // main.dart içindeki kalıcı senkronizasyon köprüsü tarafından işlenir.
}

class SehirKoordinat {
  final String ad;
  final double enlem;
  final double boylam;

  const SehirKoordinat(this.ad, this.enlem, this.boylam);
}

class BildirimServisi {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _baslatildi = false;

  static const String _prefSehirKey = 'bildirim_sehir';
  static const String _prefGunSonuSaatKey = 'bildirim_gun_sonu_saat';
  static const String _prefGunSonuDakikaKey = 'bildirim_gun_sonu_dakika';
  static const String _prefEkstreBekleyenKey = 'bekleyen_ekstre_girisleri_v1';
  static const String _prefEtkinlikOnayKey = 'bekleyen_etkinlik_onaylari_v1';

  static const String actionEvvet = 'ACTION_EVET_YAPILDI';
  static const String actionHayir = 'ACTION_HAYIR_YAPILDI';
  static const String actionEkstreGir = 'ACTION_EKSTRE_GIR';
  static const String inputEkstreTutar = 'INPUT_EKSTRE_TUTAR';

  static const List<SehirKoordinat> turkiyeIlleri = [
    SehirKoordinat('Adana', 37.0000, 35.3213),
    SehirKoordinat('Adıyaman', 37.7648, 38.2786),
    SehirKoordinat('Afyonkarahisar', 38.7507, 30.5567),
    SehirKoordinat('Ağrı', 39.7191, 43.0503),
    SehirKoordinat('Aksaray', 38.3687, 34.0370),
    SehirKoordinat('Amasya', 40.6499, 35.8353),
    SehirKoordinat('Ankara', 39.9334, 32.8597),
    SehirKoordinat('Antalya', 36.8969, 30.7133),
    SehirKoordinat('Ardahan', 41.1105, 42.7022),
    SehirKoordinat('Artvin', 41.1828, 41.8183),
    SehirKoordinat('Aydın', 37.8560, 27.8416),
    SehirKoordinat('Balıkesir', 39.6484, 27.8826),
    SehirKoordinat('Bartın', 41.5811, 32.4610),
    SehirKoordinat('Batman', 37.8812, 41.1351),
    SehirKoordinat('Bayburt', 40.2552, 40.2249),
    SehirKoordinat('Bilecik', 40.1426, 29.9793),
    SehirKoordinat('Bingöl', 38.8854, 40.4980),
    SehirKoordinat('Bitlis', 38.3938, 42.1232),
    SehirKoordinat('Bolu', 40.7360, 31.6061),
    SehirKoordinat('Burdur', 37.7203, 30.2908),
    SehirKoordinat('Bursa', 40.1885, 29.0610),
    SehirKoordinat('Çanakkale', 40.1553, 26.4142),
    SehirKoordinat('Çankırı', 40.6013, 33.6134),
    SehirKoordinat('Çorum', 40.5506, 34.9556),
    SehirKoordinat('Denizli', 37.7765, 29.0864),
    SehirKoordinat('Diyarbakır', 37.9144, 40.2306),
    SehirKoordinat('Düzce', 40.8438, 31.1565),
    SehirKoordinat('Edirne', 41.6818, 26.5623),
    SehirKoordinat('Elazığ', 38.6810, 39.2264),
    SehirKoordinat('Erzincan', 39.7500, 39.5000),
    SehirKoordinat('Erzurum', 39.9000, 41.2700),
    SehirKoordinat('Eskişehir', 39.7767, 30.5206),
    SehirKoordinat('Gaziantep', 37.0662, 37.3833),
    SehirKoordinat('Giresun', 40.9128, 38.3895),
    SehirKoordinat('Gümüşhane', 40.4386, 39.5086),
    SehirKoordinat('Hakkari', 37.5833, 43.7333),
    SehirKoordinat('Hatay', 36.4018, 36.3498),
    SehirKoordinat('Iğdır', 39.9167, 44.0333),
    SehirKoordinat('Isparta', 37.7648, 30.5566),
    SehirKoordinat('İstanbul', 41.0082, 28.9784),
    SehirKoordinat('İzmir', 38.4237, 27.1428),
    SehirKoordinat('Kahramanmaraş', 37.5858, 36.9371),
    SehirKoordinat('Karabük', 41.2061, 32.6204),
    SehirKoordinat('Karaman', 37.1759, 33.2287),
    SehirKoordinat('Kars', 40.6167, 43.1000),
    SehirKoordinat('Kastamonu', 41.3887, 33.7827),
    SehirKoordinat('Kayseri', 38.7312, 35.4787),
    SehirKoordinat('Kırıkkale', 39.8468, 33.5153),
    SehirKoordinat('Kırklareli', 41.7333, 27.2167),
    SehirKoordinat('Kırşehir', 39.1425, 34.1709),
    SehirKoordinat('Kilis', 36.7184, 37.1212),
    SehirKoordinat('Kocaeli', 40.8533, 29.8815),
    SehirKoordinat('Konya', 37.8746, 32.4932),
    SehirKoordinat('Kütahya', 39.4242, 29.9833),
    SehirKoordinat('Malatya', 38.3552, 38.3095),
    SehirKoordinat('Manisa', 38.6191, 27.4289),
    SehirKoordinat('Mardin', 37.3212, 40.7245),
    SehirKoordinat('Mersin', 36.8000, 34.6333),
    SehirKoordinat('Muğla', 37.2153, 28.3636),
    SehirKoordinat('Muş', 38.9462, 41.7539),
    SehirKoordinat('Nevşehir', 38.6939, 34.6857),
    SehirKoordinat('Niğde', 37.9667, 34.6833),
    SehirKoordinat('Ordu', 40.9839, 37.8764),
    SehirKoordinat('Osmaniye', 37.0742, 36.2476),
    SehirKoordinat('Rize', 41.0201, 40.5234),
    SehirKoordinat('Sakarya', 40.7569, 30.3781),
    SehirKoordinat('Samsun', 41.2867, 36.3300),
    SehirKoordinat('Şanlıurfa', 37.1591, 38.7969),
    SehirKoordinat('Siirt', 37.9333, 41.9500),
    SehirKoordinat('Sinop', 42.0231, 35.1531),
    SehirKoordinat('Şırnak', 37.5164, 42.4611),
    SehirKoordinat('Sivas', 39.7477, 37.0179),
    SehirKoordinat('Tekirdağ', 40.9833, 27.5167),
    SehirKoordinat('Tokat', 40.3167, 36.5500),
    SehirKoordinat('Trabzon', 41.0027, 39.7168),
    SehirKoordinat('Tunceli', 39.1079, 39.5401),
    SehirKoordinat('Uşak', 38.6823, 29.4082),
    SehirKoordinat('Van', 38.4891, 43.4089),
    SehirKoordinat('Yalova', 40.6500, 29.2667),
    SehirKoordinat('Yozgat', 39.8181, 34.8147),
    SehirKoordinat('Zonguldak', 41.4564, 31.7987),
  ];

  static const Map<int, String> _gunKisaAdlar = {
    1: 'Pzt',
    2: 'Sal',
    3: 'Çrş',
    4: 'Pş',
    5: 'Cu',
    6: 'Ct',
    7: 'Pz',
  };

  static Future<void> baslat({
    void Function(NotificationResponse response)? onYanit,
  }) async {
    if (_baslatildi) {
      if (onYanit != null) {
        await _plugin.initialize(
          settings: _initSettings(),
          onDidReceiveNotificationResponse: onYanit,
          onDidReceiveBackgroundNotificationResponse: bildirimArkaPlanYaniti,
        );
      }
      return;
    }

    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    } catch (_) {}

    await _plugin.initialize(
      settings: _initSettings(),
      onDidReceiveNotificationResponse: onYanit,
      onDidReceiveBackgroundNotificationResponse: bildirimArkaPlanYaniti,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _baslatildi = true;
  }

  static InitializationSettings _initSettings() {
    const androidAyar = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosAyar = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    return const InitializationSettings(
      android: androidAyar,
      iOS: iosAyar,
    );
  }

  static Future<String?> sehirGetir() async {
    final prefs = await SharedPreferences.getInstance();
    final kayitli = prefs.getString(_prefSehirKey);
    if (kayitli == null || kayitli.trim().isEmpty) return null;
    return kayitli;
  }

  static Future<void> sehirKaydet(String? sehir) async {
    final prefs = await SharedPreferences.getInstance();
    if (sehir == null || sehir.trim().isEmpty) {
      await prefs.remove(_prefSehirKey);
    } else {
      await prefs.setString(_prefSehirKey, sehir);
    }
  }

  static Future<({int saat, int dakika})> gunSonuSaatiGetir() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      saat: prefs.getInt(_prefGunSonuSaatKey) ?? 21,
      dakika: prefs.getInt(_prefGunSonuDakikaKey) ?? 30,
    );
  }

  static Future<void> gunSonuSaatiKaydet(int saat, int dakika) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefGunSonuSaatKey, saat);
    await prefs.setInt(_prefGunSonuDakikaKey, dakika);
  }

  static SehirKoordinat _koordinatBul(String sehirAdi) {
    return turkiyeIlleri.firstWhere(
      (s) => s.ad.toLowerCase() == sehirAdi.toLowerCase(),
      orElse: () => const SehirKoordinat('Isparta', 37.7648, 30.5566),
    );
  }

  static String _havaTavsiyesiOlustur({
    required String sehir,
    required int weatherCode,
    required double maxSicaklik,
    required double minSicaklik,
    required double maxRuzgar,
  }) {
    final yagmurlu = (weatherCode >= 51 && weatherCode <= 67) ||
        (weatherCode >= 80 && weatherCode <= 82) ||
        weatherCode >= 95;
    final karli = (weatherCode >= 71 && weatherCode <= 77) ||
        weatherCode == 85 ||
        weatherCode == 86;
    final ruzgarli = maxRuzgar >= 30.0;
    final gunesliAcik = weatherCode == 0 || weatherCode == 1;

    if (karli) {
      return 'bildirim_hava_karli'.trParams({'sehir': sehir});
    }
    if (yagmurlu) {
      return 'bildirim_hava_yagmurlu'.trParams({'sehir': sehir});
    }
    if (ruzgarli) {
      return 'bildirim_hava_ruzgarli'.trParams({'sehir': sehir});
    }
    if (gunesliAcik && maxSicaklik >= 22) {
      return 'bildirim_hava_gunesli'.trParams({
        'sehir': sehir,
        'max': maxSicaklik.round().toString(),
      });
    }
    if (minSicaklik <= 6 || maxSicaklik <= 10) {
      return 'bildirim_hava_soguk'.trParams({
        'sehir': sehir,
        'min': minSicaklik.round().toString(),
        'max': maxSicaklik.round().toString(),
      });
    }
    return 'bildirim_hava_normal'.trParams({
      'sehir': sehir,
      'max': maxSicaklik.round().toString(),
    });
  }

  static Future<String?> _gunlukHavaTavsiyesiCek(String sehirAdi) async {
    try {
      final k = _koordinatBul(sehirAdi);
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${k.enlem}&longitude=${k.boylam}'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min,wind_speed_10m_max'
        '&timezone=Europe%2FIstanbul&forecast_days=1',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 7));
      if (resp.statusCode != 200) return null;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final daily = data['daily'] as Map<String, dynamic>?;
      if (daily == null) return null;

      final codes = daily['weather_code'] as List<dynamic>?;
      final maxTemps = daily['temperature_2m_max'] as List<dynamic>?;
      final minTemps = daily['temperature_2m_min'] as List<dynamic>?;
      final winds = daily['wind_speed_10m_max'] as List<dynamic>?;

      if (codes == null ||
          codes.isEmpty ||
          maxTemps == null ||
          maxTemps.isEmpty ||
          minTemps == null ||
          minTemps.isEmpty) {
        return null;
      }

      return _havaTavsiyesiOlustur(
        sehir: k.ad,
        weatherCode: (codes.first as num).toInt(),
        maxSicaklik: (maxTemps.first as num).toDouble(),
        minSicaklik: (minTemps.first as num).toDouble(),
        maxRuzgar: (winds != null && winds.isNotEmpty)
            ? (winds.first as num).toDouble()
            : 0.0,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> testBildirimiGonder() async {
    await baslat();
    final sehir = await sehirGetir();
    final hedefSehir =
        (sehir != null && sehir.isNotEmpty) ? sehir : 'Isparta';
    final havaMetni = await _gunlukHavaTavsiyesiCek(hedefSehir) ??
        'bildirim_test_varsayilan'.trParams({'sehir': hedefSehir});

    final detaylar = NotificationDetails(
      android: AndroidNotificationDetails(
        'asistan_hatirlatici_kanali',
        'bildirim_kanal_adi'.tr,
        channelDescription: 'bildirim_kanal_aciklama'.tr,
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.show(
      id: 999,
      title: 'bildirim_test_baslik'.trParams({'sehir': hedefSehir}),
      body: havaMetni,
      notificationDetails: detaylar,
    );
  }

  static Future<void> _zamanliBildirimKur({
    required int id,
    required String baslik,
    required String icerik,
    required DateTime zaman,
    String? payload,
    NotificationDetails? ozelDetaylar,
  }) async {
    if (!zaman.isAfter(DateTime.now())) return;

    final tzZaman = tz.TZDateTime(
      tz.local,
      zaman.year,
      zaman.month,
      zaman.day,
      zaman.hour,
      zaman.minute,
    );

    final varsayilanDetaylar = NotificationDetails(
      android: AndroidNotificationDetails(
        'asistan_hatirlatici_kanali',
        'bildirim_kanal_adi'.tr,
        channelDescription: 'bildirim_kanal_aciklama'.tr,
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.zonedSchedule(
      id: id,
      title: baslik,
      body: icerik,
      scheduledDate: tzZaman,
      notificationDetails: ozelDetaylar ?? varsayilanDetaylar,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  static DateTime _siradakiEkstreErtesiGun(int kesimGunu, int saat, int dakika) {
    final simdi = DateTime.now();
    int yil = simdi.year;
    int ay = simdi.month;

    DateTime adayOlustur(int y, int m) {
      final maxGun = DateTime(y, m + 1, 0).day;
      final kesimTarihi = DateTime(y, m, min(kesimGunu, maxGun));
      final ertesi = kesimTarihi.add(const Duration(days: 1));
      return DateTime(ertesi.year, ertesi.month, ertesi.day, saat, dakika);
    }

    DateTime aday = adayOlustur(yil, ay);
    if (!aday.isAfter(simdi)) {
      ay += 1;
      if (ay > 12) {
        ay = 1;
        yil += 1;
      }
      aday = adayOlustur(yil, ay);
    }
    return aday;
  }

  static DateTime _siradakiAyGunu(int gun, int saat, int dakika) {
    final simdi = DateTime.now();
    int yil = simdi.year;
    int ay = simdi.month;

    int maxGun = DateTime(yil, ay + 1, 0).day;
    DateTime aday = DateTime(yil, ay, min(gun, maxGun), saat, dakika);

    if (!aday.isAfter(simdi)) {
      ay += 1;
      if (ay > 12) {
        ay = 1;
        yil += 1;
      }
      maxGun = DateTime(yil, ay + 1, 0).day;
      aday = DateTime(yil, ay, min(gun, maxGun), saat, dakika);
    }
    return aday;
  }

  static bool _etkinlikOgunMu(Etkinlik e, DateTime hedefTarih) {
    final eTarih = DateTime(e.tarih.year, e.tarih.month, e.tarih.day);
    final hedef = DateTime(hedefTarih.year, hedefTarih.month, hedefTarih.day);

    if (hedef.isBefore(eTarih)) return false;
    if (e.oGunIptalMi(hedef)) return false;

    if (e.yinelemeBitis != null) {
      final bitis = DateTime(
        e.yinelemeBitis!.year,
        e.yinelemeBitis!.month,
        e.yinelemeBitis!.day,
      );
      if (hedef.isAfter(bitis)) return false;
    }

    if (e.yineleme.startsWith('Haftanın Günleri')) {
      final gunIsmi = _gunKisaAdlar[hedef.weekday];
      return gunIsmi != null && e.yineleme.contains(gunIsmi);
    }

    switch (e.yineleme) {
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

  static Future<void> _bekleyenEkstreKaydet(String kartId, String kartBaslik) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefEkstreBekleyenKey);
    final Map<String, dynamic> map =
        raw != null ? Map<String, dynamic>.from(jsonDecode(raw)) : {};
    map[kartId] = {
      'kartId': kartId,
      'kartBaslik': kartBaslik,
      'zaman': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_prefEkstreBekleyenKey, jsonEncode(map));
  }

  static Future<void> _bekleyenEtkinlikOnayKaydet({
    required String anahtar,
    required String etkinlikId,
    required DateTime gun,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefEtkinlikOnayKey);
    final Map<String, dynamic> map =
        raw != null ? Map<String, dynamic>.from(jsonDecode(raw)) : {};
    map[anahtar] = {
      'etkinlikId': etkinlikId,
      'yil': gun.year,
      'ay': gun.month,
      'gun': gun.day,
    };
    await prefs.setString(_prefEtkinlikOnayKey, jsonEncode(map));
  }

  static bool _oGunEtkinlikVarMi(List<Etkinlik> etkinlikler, DateTime gun) {
    return etkinlikler.any((e) => _etkinlikOgunMu(e, gun));
  }

  static DateTime _erkenBildirimIcinSaatAyarla({
    required List<Etkinlik> etkinlikler,
    required DateTime zaman,
  }) {
    final gun = DateTime(zaman.year, zaman.month, zaman.day);
    final etkinlikVar = _oGunEtkinlikVarMi(etkinlikler, gun);
    final erkenMi = zaman.hour < 10 || (zaman.hour == 10 && zaman.minute < 30);

    if (!etkinlikVar && erkenMi) {
      return DateTime(zaman.year, zaman.month, zaman.day, 10, 30);
    }
    return zaman;
  }

  // 🔄 Tüm finans, takvim, hava durumu ve gün sonu bildirimlerini günceller
  static Future<void> tumBildirimleriGuncelle(
    List<FinansItem> islemler,
    List<Etkinlik> etkinlikler,
  ) async {
    await baslat();
    await _plugin.cancelAll();

    int idSayac = 1000;
    final simdi = DateTime.now();

    // 0. HAVA DURUMU TAVSİYE BİLDİRİMİ (Şehir seçilmişse bugün sabah 08:15)
    final sehir = await sehirGetir();
    if (sehir != null && sehir.isNotEmpty) {
      final havaTavsiyesi = await _gunlukHavaTavsiyesiCek(sehir);
      if (havaTavsiyesi != null) {
        final sabahHavaZamani = _erkenBildirimIcinSaatAyarla(
          etkinlikler: etkinlikler,
          zaman: DateTime(simdi.year, simdi.month, simdi.day, 8, 15),
        );
        await _zamanliBildirimKur(
          id: idSayac++,
          baslik: 'bildirim_hava_baslik'.trParams({'sehir': sehir}),
          icerik: havaTavsiyesi,
          zaman: sabahHavaZamani,
          payload: 'hava|$sehir',
        );
      }
    }

    // 0.1 GÜN SONU DEĞERLENDİRME HATIRLATMASI
    final gunSonuSaat = await gunSonuSaatiGetir();
    DateTime gunSonuZamani = DateTime(
      simdi.year,
      simdi.month,
      simdi.day,
      gunSonuSaat.saat,
      gunSonuSaat.dakika,
    );
    if (!gunSonuZamani.isAfter(simdi)) {
      gunSonuZamani = gunSonuZamani.add(const Duration(days: 1));
    }
    await _zamanliBildirimKur(
      id: idSayac++,
      baslik: 'bildirim_gun_sonu_baslik'.tr,
      icerik: 'bildirim_gun_sonu_icerik'.tr,
      zaman: gunSonuZamani,
      payload: 'gun_sonu',
    );

    // 1. FİNANS BİLDİRİMLERİ (Ekstre +1 Gün, Kart Son Ödeme, Faturalar, Borçlar)
    final ekstreDetaylari = NotificationDetails(
      android: AndroidNotificationDetails(
        'asistan_hatirlatici_kanali',
        'bildirim_kanal_adi'.tr,
        channelDescription: 'bildirim_kanal_aciklama'.tr,
        importance: Importance.max,
        priority: Priority.high,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            actionEkstreGir,
            'bildirim_aksiyon_ekstre_gir'.tr,
            showsUserInterface: false,
            inputs: <AndroidNotificationActionInput>[
              AndroidNotificationActionInput(
                label: 'bildirim_input_ekstre_label'.tr,
              ),
            ],
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    for (final f in islemler) {
      if (idSayac > 1054) break;
      if (f.odendi) continue;

      if (f.tur == 'Kredi Kartı') {
        if (f.hesapKesimGunu != null) {
          final ekstreBildirimZamani =
              _siradakiEkstreErtesiGun(f.hesapKesimGunu!, 11, 0);
          final ekstreKey =
              'ekstre_${f.id}_${ekstreBildirimZamani.year}_${ekstreBildirimZamani.month}_${ekstreBildirimZamani.day}';
          await _bekleyenEkstreKaydet(ekstreKey, f.baslik);

          await _zamanliBildirimKur(
            id: idSayac++,
            baslik: 'bildirim_ekstre_kesildi_baslik'.trParams({'kart': f.baslik}),
            icerik: 'bildirim_ekstre_kesildi_icerik'.tr,
            zaman: ekstreBildirimZamani,
            payload: 'ekstre|$ekstreKey|${f.id}',
            ozelDetaylar: ekstreDetaylari,
          );
        }

        if (f.sonOdemeGunu != null && f.odenenMiktar <= 0) {
          final sonOdemeGunu = _siradakiAyGunu(f.sonOdemeGunu!, 10, 0);
          final birGunOnce = sonOdemeGunu.subtract(const Duration(days: 1));

          await _zamanliBildirimKur(
            id: idSayac++,
            baslik: 'bildirim_kart_yarin_baslik'.trParams({'kart': f.baslik}),
            icerik: 'bildirim_kart_yarin_icerik'
                .trParams({'tutar': f.tahminiOdeme.toStringAsFixed(0)}),
            zaman: birGunOnce,
          );

          await _zamanliBildirimKur(
            id: idSayac++,
            baslik: 'bildirim_kart_bugun_baslik'.trParams({'kart': f.baslik}),
            icerik: 'bildirim_kart_bugun_icerik'.tr,
            zaman: DateTime(
              sonOdemeGunu.year,
              sonOdemeGunu.month,
              sonOdemeGunu.day,
              9,
              30,
            ),
          );
        }
      } else if (f.tur == 'Fatura' && !f.otomatikOdemede) {
        final hedefGun = f.yineleme == 'Tek seferlik'
            ? DateTime(f.tarih.year, f.tarih.month, f.tarih.day, 10, 0)
            : _siradakiAyGunu(f.tarih.day, 10, 0);
        final birGunOnce = hedefGun.subtract(const Duration(days: 1));

        await _zamanliBildirimKur(
          id: idSayac++,
          baslik: f.isDegiskenFatura && !f.ekstreGirildi
              ? 'bildirim_fatura_yaklasiyor_baslik'.trParams({'baslik': f.baslik})
              : 'bildirim_fatura_yarin_baslik'.trParams({'baslik': f.baslik}),
          icerik: f.isDegiskenFatura && !f.ekstreGirildi
              ? 'bildirim_fatura_degisken_icerik'.tr
              : 'bildirim_odenecek_tutar_icerik'
                  .trParams({'tutar': f.tahminiOdeme.toStringAsFixed(0)}),
          zaman: birGunOnce,
        );
      } else if (f.tur == 'Borç') {
        final vade = DateTime(f.tarih.year, f.tarih.month, f.tarih.day, 10, 0);
        final birGunOnce = vade.subtract(const Duration(days: 1));
        await _zamanliBildirimKur(
          id: idSayac++,
          baslik: 'bildirim_borc_yarin_baslik'.trParams({'baslik': f.baslik}),
          icerik: 'bildirim_odenecek_tutar_icerik'
              .trParams({'tutar': f.tahminiOdeme.toStringAsFixed(0)}),
          zaman: birGunOnce,
        );
      }
    }

    // 2. TAKVİM BİLDİRİMLERİ (Önümüzdeki 14 gün: 1 Saat Önce + "Yapıldı mı?" EVET/HAYIR)
    final yapildiDetaylari = NotificationDetails(
      android: AndroidNotificationDetails(
        'asistan_hatirlatici_kanali',
        'bildirim_kanal_adi'.tr,
        channelDescription: 'bildirim_kanal_aciklama'.tr,
        importance: Importance.max,
        priority: Priority.high,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            actionEvvet,
            'bildirim_aksiyon_evet'.tr,
            showsUserInterface: false,
          ),
          AndroidNotificationAction(
            actionHayir,
            'bildirim_aksiyon_hayir'.tr,
            cancelNotification: true,
            showsUserInterface: false,
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    for (int gunFarki = 0; gunFarki <= 14; gunFarki++) {
      if (idSayac > 1058) break;
      final kontrolGunu = DateTime(
        simdi.year,
        simdi.month,
        simdi.day + gunFarki,
      );

      for (final e in etkinlikler) {
        if (idSayac > 1058) break;
        if (e.oGunTamamlandiMi(kontrolGunu)) continue;
        if (!_etkinlikOgunMu(e, kontrolGunu)) continue;

        if (e.saat != 'Tüm Gün' && e.saat.contains(':')) {
          final baslangicParca = e.saat.split(' - ').first.trim();
          final saatDakika = baslangicParca.split(':');
          if (saatDakika.length == 2) {
            final s = int.tryParse(saatDakika[0]) ?? 9;
            final d = int.tryParse(saatDakika[1]) ?? 0;
            final etkinlikZamani = DateTime(
              kontrolGunu.year,
              kontrolGunu.month,
              kontrolGunu.day,
              s,
              d,
            );

            final birSaatOnce = etkinlikZamani.subtract(const Duration(hours: 1));
            await _zamanliBildirimKur(
              id: idSayac++,
              baslik: 'bildirim_etkinlik_1saat_baslik'.trParams({'baslik': e.baslik}),
              icerik: 'bildirim_etkinlik_1saat_icerik'.trParams({
                'saat': e.saat,
                'aciklama':
                    e.aciklama.isNotEmpty ? ' • ${e.aciklama}' : '',
              }),
              zaman: birSaatOnce,
            );

            if (idSayac <= 1058) {
              final onayKey =
                  'onay_${e.id}_${kontrolGunu.year}_${kontrolGunu.month}_${kontrolGunu.day}';
              await _bekleyenEtkinlikOnayKaydet(
                anahtar: onayKey,
                etkinlikId: e.id,
                gun: kontrolGunu,
              );
              await _zamanliBildirimKur(
                id: idSayac++,
                baslik: 'bildirim_etkinlik_onay_baslik'.trParams({'baslik': e.baslik}),
                icerik: 'bildirim_etkinlik_onay_icerik'.tr,
                zaman: etkinlikZamani.add(const Duration(hours: 1)),
                payload:
                    'etkinlik_onay|$onayKey|${e.id}|${kontrolGunu.year}-${kontrolGunu.month}-${kontrolGunu.day}',
                ozelDetaylar: yapildiDetaylari,
              );
            }
          }
        } else {
          final sabahHatirlatma = DateTime(
            kontrolGunu.year,
            kontrolGunu.month,
            kontrolGunu.day,
            8,
            30,
          );
          await _zamanliBildirimKur(
            id: idSayac++,
            baslik: 'bildirim_tum_gun_baslik'.trParams({'baslik': e.baslik}),
            icerik: e.aciklama.isNotEmpty
                ? e.aciklama
                : 'bildirim_tum_gun_varsayilan_icerik'.tr,
            zaman: sabahHatirlatma,
          );
        }
      }
    }
  }
}