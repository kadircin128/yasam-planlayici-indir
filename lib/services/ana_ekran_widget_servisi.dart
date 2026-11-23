import 'dart:math';
import 'package:home_widget/home_widget.dart';
import '../models/etkinlik.dart';
import '../models/finans_item.dart';
import 'dil_servisi.dart';

class AnaEkranWidgetServisi {
  static const String _androidWidgetAdi = 'AsistanWidgetProvider';
  static const String _iosWidgetAdi = 'AsistanWidget';

  static const Map<int, String> _gunKisaAdlar = {
    1: 'Pzt',
    2: 'Sal',
    3: 'Çrş',
    4: 'Pş',
    5: 'Cu',
    6: 'Ct',
    7: 'Pz',
  };

  static bool _tarihlerAyniMi(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  static DateTime _kartSonOdemeTarihiBul(FinansItem f) {
    final base = DateTime(f.tarih.year, f.tarih.month, f.tarih.day);
    if (f.sonOdemeGunu == null) return base;

    int yil = base.year;
    int ay = base.month;
    if (base.day > f.sonOdemeGunu!) {
      ay += 1;
      if (ay > 12) {
        ay = 1;
        yil += 1;
      }
    }
    final maxGun = DateTime(yil, ay + 1, 0).day;
    return DateTime(yil, ay, min(f.sonOdemeGunu!, maxGun));
  }

  static bool _islemGunuMu(FinansItem f, DateTime hedefTarih) {
    final fTarih = DateTime(f.tarih.year, f.tarih.month, f.tarih.day);
    final hedef = DateTime(hedefTarih.year, hedefTarih.month, hedefTarih.day);

    if (hedef.isBefore(fTarih)) return false;

    if (f.yineleme.startsWith('Haftanın Günleri')) {
      final gunIsmi = _gunKisaAdlar[hedef.weekday];
      return gunIsmi != null && f.yineleme.contains(gunIsmi);
    }

    if (f.yineleme.startsWith('Yılda bir')) {
      return hedef.month == fTarih.month && hedef.day == fTarih.day;
    }

    switch (f.yineleme) {
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
        return _tarihlerAyniMi(fTarih, hedef);
    }
  }

  static int _tekrarSayisiHesapla(FinansItem f, DateTime hedefTarih) {
    final fBaslangic = DateTime(f.tarih.year, f.tarih.month, f.tarih.day);
    final sadeceHedefTarih =
        DateTime(hedefTarih.year, hedefTarih.month, hedefTarih.day);

    if (f.tur == 'Kredi Kartı') return 1;
    if (fBaslangic.isAfter(sadeceHedefTarih)) return 0;
    if (f.yineleme == 'Tek seferlik') return 1;

    int sayac = 0;
    DateTime temp = fBaslangic;
    while (!temp.isAfter(sadeceHedefTarih)) {
      if (_islemGunuMu(f, temp)) {
        sayac++;
      }
      temp = DateTime(temp.year, temp.month, temp.day + 1);
    }
    return sayac;
  }

  static double _hesaplaBugunBakiye(List<FinansItem> islemler) {
    final bugun = DateTime.now();
    final sadeceHedef = DateTime(bugun.year, bugun.month, bugun.day);
    double bakiye = 0;

    for (final f in islemler) {
      double etki = 0.0;
      if (f.tur == 'Kredi Kartı') {
        final odemeYapildiMi = f.odendi || f.odenenMiktar > 0;
        final sonOdemeTarihi = _kartSonOdemeTarihiBul(f);

        if (odemeYapildiMi) {
          final odemeGunu = DateTime(f.tarih.year, f.tarih.month, f.tarih.day);
          if (!sadeceHedef.isBefore(odemeGunu)) {
            final odenenTutar = f.odenenMiktar > 0 ? f.odenenMiktar : f.miktar;
            if (!f.odendi &&
                odenenTutar < f.tahminiOdeme &&
                !sadeceHedef.isBefore(sonOdemeTarihi)) {
              etki = f.tahminiOdeme;
            } else {
              etki = odenenTutar;
            }
          }
        } else if (!sadeceHedef.isBefore(sonOdemeTarihi)) {
          etki = f.tahminiOdeme;
        }
      } else {
        final tekrar = _tekrarSayisiHesapla(f, sadeceHedef);
        if (tekrar > 0) {
          final isPozitif = f.tur == 'Gelir' || f.tur == 'Alacak';
          etki = isPozitif ? (f.miktar * tekrar) : (f.tahminiOdeme * tekrar);
        }
      }

      if (etki == 0) continue;
      final isPozitif = f.tur == 'Gelir' || f.tur == 'Alacak';
      bakiye += isPozitif ? etki : -etki;
    }

    return bakiye;
  }

  static bool _etkinlikOgunMu(Etkinlik e, DateTime hedefTarih) {
    final eTarih = DateTime(e.tarih.year, e.tarih.month, e.tarih.day);
    final hedef = DateTime(hedefTarih.year, hedefTarih.month, hedefTarih.day);

    if (hedef.isBefore(eTarih)) return false;

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
        return _tarihlerAyniMi(eTarih, hedef);
    }
  }

  // 🔄 Ana ekran widget verilerini günceller
  static Future<void> widgetGuncelle(
    List<FinansItem> islemler,
    List<Etkinlik> etkinlikler,
  ) async {
    try {
      final simdi = DateTime.now();
      final netBakiye = _hesaplaBugunBakiye(islemler);
      final bakiyeMetni = '${netBakiye.toStringAsFixed(0)} ₺';

      final bugunEtkinlikler = etkinlikler
          .where((e) => _etkinlikOgunMu(e, simdi) && !e.katildim)
          .toList()
        ..sort((a, b) => a.saat.compareTo(b.saat));

      String siradakiMetin = 'widget_bekleyen_plan_yok'.tr;
      if (bugunEtkinlikler.isNotEmpty) {
        final ilk = bugunEtkinlikler.first;
        final saatEtiketi =
            ilk.saat == 'Tüm Gün' ? 'tum_gun'.tr : ilk.saat;
        siradakiMetin = '$saatEtiketi • ${ilk.baslik}';
      }

      final gorevSayisiMetni = bugunEtkinlikler.isEmpty
          ? 'widget_tum_gorevler_tamam'.tr
          : 'widget_kalan_gorev'.trParams({'sayi': '${bugunEtkinlikler.length}'});

      final saatMetni =
          '${simdi.hour.toString().padLeft(2, '0')}:${simdi.minute.toString().padLeft(2, '0')}';

      await HomeWidget.saveWidgetData<String>('net_bakiye', bakiyeMetni);
      await HomeWidget.saveWidgetData<String>(
        'siradaki_etkinlik',
        siradakiMetin,
      );
      await HomeWidget.saveWidgetData<String>('kalan_gorev', gorevSayisiMetni);
      await HomeWidget.saveWidgetData<String>('son_guncelleme', saatMetni);

      await HomeWidget.updateWidget(
        androidName: _androidWidgetAdi,
        iOSName: _iosWidgetAdi,
      );
    } catch (_) {}
  }
}