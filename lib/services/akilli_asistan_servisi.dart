import 'dart:math';
import '../models/etkinlik.dart';
import '../models/finans_item.dart';
import 'dil_servisi.dart';
import 'varlik_servisi.dart';

class _TarihEslesme {
  final int baslangic;
  final DateTime tarih;
  _TarihEslesme(this.baslangic, this.tarih);
}

class AsistanIslemSonucu {
  final List<String> aksiyonlar;
  final String? asistanYaniti;

  const AsistanIslemSonucu({
    required this.aksiyonlar,
    this.asistanYaniti,
  });
}

extension FinansItemTakvimExt on FinansItem {
  static const Map<int, String> _gunKisaAdlar = {
    1: 'Pzt',
    2: 'Sal',
    3: 'Çrş',
    4: 'Pş',
    5: 'Cu',
    6: 'Ct',
    7: 'Pz',
  };

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
}

class AkilliAsistanServisi {
  static const Map<int, String> _gunKisaAdlar = {
    1: 'Pzt',
    2: 'Sal',
    3: 'Çrş',
    4: 'Pş',
    5: 'Cu',
    6: 'Ct',
    7: 'Pz',
  };

  static String trKucuk(String metin) {
    return metin.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
  }

  static String aramaNorm(String metin) {
    return trKucuk(metin)
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _basHarfBuyut(String metin) {
    final temiz = metin.trim();
    if (temiz.isEmpty) return '';
    return temiz[0].toUpperCase() + temiz.substring(1);
  }

  static List<String> anahtarKelimeleriCikar(String cumle) {
    final temiz = aramaNorm(_tarihMetinleriniTemizle(cumle));
    const stopWords = {
      'iptal',
      'oldu',
      'edildi',
      'gitmicem',
      'gitmeyecegim',
      'gitmiycem',
      'katilmayacagim',
      'katilmicam',
      'yapilmayacak',
      'olmayacak',
      'vazgectim',
      'kaldirildi',
      'normalde',
      'odeyecekti',
      'odeyecekmis',
      'odeyecek',
      'verecekmis',
      'verecek',
      'ertelendi',
      'ertelenecek',
      'ertele',
      'otelendi',
      'kaldi',
      'alindi',
      'kaydirildi',
      'yapilacakmis',
      'olacakmis',
      'gun',
      'sonra',
      'sonraya',
      'var',
      'bir',
      've',
      'ile',
      'icin',
      'de',
      'da',
      'falan',
      'artik',
    };

    final kelimeler = temiz
        .split(' ')
        .where((w) => w.isNotEmpty && !stopWords.contains(w))
        .toList();
    final Set<String> kokler = {};

    for (final k in kelimeler) {
      if (k == 'is' || k == 'ise' || k == 'isim' || k == 'isten') {
        kokler.addAll(['is', 'mesai', 'vardiya', 'ozen']);
        continue;
      }
      kokler.add(k);
      if (k.length >= 6) {
        kokler.add(k.substring(0, k.length - 3));
        kokler.add(k.substring(0, k.length - 2));
      } else if (k.length >= 4) {
        kokler.add(k.substring(0, k.length - 1));
      }
    }
    return kokler.toList();
  }

  static bool metinEslesiyorMu(String baslik, List<String> kokler) {
    if (kokler.isEmpty) return false;
    final normBaslik = aramaNorm(baslik);
    return kokler.any((k) => k.length >= 2 && normBaslik.contains(k));
  }

  static bool isKaydiMi(String metin) {
    final norm = aramaNorm(metin);
    return norm.contains('is') ||
        norm.contains('mesai') ||
        norm.contains('vardiya') ||
        norm.contains('ozen');
  }

  static bool mesaiGeliriMi(FinansItem f) {
    final norm = aramaNorm(f.baslik);
    return norm.contains('mesaigeliri') ||
        norm.contains('mesai geliri') ||
        norm.contains('yevmiye') ||
        norm.contains('mesai');
  }

  static AsistanIslemSonucu mesajIsle({
    required String hamMetin,
    required DateTime bazTarih,
    required String dilPrefix, // 'ozet' veya 'gs'
    required List<FinansItem> finansIslemleri,
    required List<Etkinlik> etkinlikler,
    String? Function(String cumle)? kartGuncelleyici,
    Function(FinansItem)? onFinansEkle,
    Function(FinansItem)? onFinansSil,
    Function(FinansItem, DateTime)? onFinansTekGunIptal,
    Function(FinansItem, DateTime)? onFinansTarihGuncelle,
    Function(Etkinlik)? onEtkinlikEkle,
    Function(Etkinlik)? onEtkinlikSil,
    Function(Etkinlik, DateTime)? onEtkinlikTekGunIptal,
    Function(Etkinlik, DateTime)? onEtkinlikTarihGuncelle,
  }) {
    VarlikServisi.instance.baslat();

    final List<String> aksiyonlar = [];

    final cumleler = hamMetin
        .split(RegExp(r'\n+|(?<=[.!?])\s+'))
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();

    int sira = 0;

    for (final cumle in cumleler) {
      if (_soruCumlesiMi(cumle)) continue;

      if (kartGuncelleyici != null) {
        final kartSonucu = kartGuncelleyici(cumle);
        if (kartSonucu != null) {
          aksiyonlar.add(kartSonucu);
          sira++;
          continue;
        }
      }

      final guncellemeSonuclari = _iptalVeyaErtelemeIsle(
        cumle: cumle,
        varsayilanTarih: bazTarih,
        dilPrefix: dilPrefix,
        finansIslemleri: finansIslemleri,
        etkinlikler: etkinlikler,
        onFinansSil: onFinansSil,
        onFinansTekGunIptal: onFinansTekGunIptal,
        onFinansTarihGuncelle: onFinansTarihGuncelle,
        onEtkinlikEkle: onEtkinlikEkle,
        onEtkinlikSil: onEtkinlikSil,
        onEtkinlikTekGunIptal: onEtkinlikTekGunIptal,
        onEtkinlikTarihGuncelle: onEtkinlikTarihGuncelle,
      );
      if (guncellemeSonuclari != null) {
        aksiyonlar.addAll(guncellemeSonuclari);
        sira++;
        continue;
      }

      // Döviz / Altın / Kripto / Hisse alım-satımını hem Varlık Kasası'na hem Finans'a işle
      final varlikSonuclari = _varlikIslemiAyikla(
        cumle: cumle,
        varsayilanTarih: bazTarih,
        sira: sira,
        onFinansEkle: onFinansEkle,
      );
      if (varlikSonuclari != null) {
        aksiyonlar.addAll(varlikSonuclari);
        sira++;
        continue;
      }

      final finans = _finansAyikla(cumle, bazTarih, sira, dilPrefix);
      if (finans != null) {
        onFinansEkle?.call(finans);
        final isaret =
            (finans.tur == 'Gelir' || finans.tur == 'Alacak') ? '+' : '-';
        aksiyonlar.add('${dilPrefix}_aks_finans_eklendi'.trParams({
          'tarih': '${finans.tarih.day}.${finans.tarih.month}',
          'isaret': isaret,
          'tutar': finans.miktar.toStringAsFixed(0),
          'baslik': finans.baslik,
        }));
        sira++;
        continue;
      }

      final etkinlik = _etkinlikAyikla(cumle, bazTarih, sira, dilPrefix);
      if (etkinlik != null) {
        onEtkinlikEkle?.call(etkinlik);
        aksiyonlar.add('${dilPrefix}_aks_takvim_eklendi'.trParams({
          'baslik': etkinlik.baslik,
          'tarih':
              '${etkinlik.tarih.day}.${etkinlik.tarih.month}.${etkinlik.tarih.year}',
          'saat': etkinlik.saat,
        }));
        sira++;
      }
    }

    final cevap = _soruCevapla(
      hamMetin: hamMetin,
      bazTarih: bazTarih,
      dilPrefix: dilPrefix,
      finansIslemleri: finansIslemleri,
    );

    return AsistanIslemSonucu(
      aksiyonlar: aksiyonlar,
      asistanYaniti: cevap,
    );
  }

  static const Map<String, String> _varlikAnahtarEslesmeleri = {
    // Dövizler
    'dolar': 'USD',
    'usd': 'USD',
    'euro': 'EUR',
    'avro': 'EUR',
    'eur': 'EUR',
    'sterlin': 'GBP',
    'pound': 'GBP',
    'gbp': 'GBP',
    'frank': 'CHF',
    'chf': 'CHF',
    'yen': 'JPY',
    'jpy': 'JPY',
    'riyal': 'SAR',
    'sar': 'SAR',
    'dirhem': 'AED',
    'aed': 'AED',
    'ruble': 'RUB',
    'rub': 'RUB',
    'yuan': 'CNY',
    'cny': 'CNY',
    'manat': 'AZN',
    'azn': 'AZN',

    // Altın & Kıymetli Madenler
    'çeyrek altın': 'CEYREK_ALTIN',
    'ceyrek altin': 'CEYREK_ALTIN',
    'çeyrek': 'CEYREK_ALTIN',
    'ceyrek': 'CEYREK_ALTIN',
    'yarım altın': 'YARIM_ALTIN',
    'yarim altin': 'YARIM_ALTIN',
    'tam altın': 'TAM_ALTIN',
    'tam altin': 'TAM_ALTIN',
    'cumhuriyet altını': 'CUMHURIYET_ALTIN',
    'cumhuriyet altini': 'CUMHURIYET_ALTIN',
    'ata altını': 'CUMHURIYET_ALTIN',
    'ata altini': 'CUMHURIYET_ALTIN',
    '22 ayar': 'BILEZIK_22',
    'bilezik': 'BILEZIK_22',
    'ons altın': 'ONS_ALTIN',
    'ons altin': 'ONS_ALTIN',
    'gram altın': 'GRAM_ALTIN',
    'gram altin': 'GRAM_ALTIN',
    'gr altın': 'GRAM_ALTIN',
    'gr altin': 'GRAM_ALTIN',
    'altın': 'GRAM_ALTIN',
    'altin': 'GRAM_ALTIN',
    'ons gümüş': 'ONS_GUMUS',
    'ons gumus': 'ONS_GUMUS',
    'gram gümüş': 'GRAM_GUMUS',
    'gram gumus': 'GRAM_GUMUS',
    'gümüş': 'GRAM_GUMUS',
    'gumus': 'GRAM_GUMUS',
    'platin': 'GRAM_PLATIN',
    'paladyum': 'GRAM_PALADYUM',

    // Kripto
    'bitcoin': 'BTC',
    'btc': 'BTC',
    'ethereum': 'ETH',
    'eth': 'ETH',
    'solana': 'SOL',
    'sol': 'SOL',
    'tether': 'USDT',
    'usdt': 'USDT',
    'ripple': 'XRP',
    'xrp': 'XRP',
    'binance coin': 'BNB',
    'bnb': 'BNB',
    'dogecoin': 'DOGE',
    'doge': 'DOGE',
    'cardano': 'ADA',
    'ada': 'ADA',
    'avalanche': 'AVAX',
    'avax': 'AVAX',
    'tron': 'TRX',
    'trx': 'TRX',
    'toncoin': 'TON',
    'ton': 'TON',
    'sui': 'SUI',
    'pepe': 'PEPE',
    'chainlink': 'LINK',
    'link': 'LINK',
    'polkadot': 'DOT',
    'dot': 'DOT',
    'shiba': 'SHIB',
    'shib': 'SHIB',

    // Popüler BIST & ABD Hisseleri
    'thyao': 'THYAO.IS',
    'türk hava yolları': 'THYAO.IS',
    'asels': 'ASELS.IS',
    'aselsan': 'ASELS.IS',
    'tuprs': 'TUPRS.IS',
    'tüpraş': 'TUPRS.IS',
    'kchol': 'KCHOL.IS',
    'koç holding': 'KCHOL.IS',
    'akbnk': 'AKBNK.IS',
    'akbank': 'AKBNK.IS',
    'garan': 'GARAN.IS',
    'garanti': 'GARAN.IS',
    'isctr': 'ISCTR.IS',
    'ykbnk': 'YKBNK.IS',
    'bimas': 'BIMAS.IS',
    'eregl': 'EREGL.IS',
    'erdemir': 'EREGL.IS',
    'sise': 'SISE.IS',
    'şişecam': 'SISE.IS',
    'sahol': 'SAHOL.IS',
    'tcell': 'TCELL.IS',
    'turkcell': 'TCELL.IS',
    'froto': 'FROTO.IS',
    'toaso': 'TOASO.IS',
    'tofaş': 'TOASO.IS',
    'sasa': 'SASA.IS',
    'astor': 'ASTOR.IS',
    'pgsus': 'PGSUS.IS',
    'pegasus': 'PGSUS.IS',
    'mgros': 'MGROS.IS',
    'migros': 'MGROS.IS',
    'hekts': 'HEKTS.IS',
    'apple': 'AAPL',
    'aapl': 'AAPL',
    'nvidia': 'NVDA',
    'nvda': 'NVDA',
    'tesla': 'TSLA',
    'tsla': 'TSLA',
    'microsoft': 'MSFT',
    'msft': 'MSFT',
    'google': 'GOOGL',
    'googl': 'GOOGL',
    'amazon': 'AMZN',
    'amzn': 'AMZN',
    'meta': 'META',
    'amd': 'AMD',
    'palantir': 'PLTR',
    'pltr': 'PLTR',
  };

  static String _miktarFormatla(double deger) {
    if (deger % 1 == 0) return deger.toStringAsFixed(0);
    return deger
        .toStringAsFixed(4)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  static List<String>? _varlikIslemiAyikla({
    required String cumle,
    required DateTime varsayilanTarih,
    required int sira,
    Function(FinansItem)? onFinansEkle,
  }) {
    final kucuk = trKucuk(cumle);
    final hedefTarih = _tarihAyikla(cumle, varsayilanTarih) ?? varsayilanTarih;

    final satisMi = RegExp(
      r'\b(sattım|bozdurdum|bozdum|çıkardım|sattık|bozdurduk)\b',
    ).hasMatch(kucuk);

    final alisMi = !satisMi &&
        RegExp(
          r'\b(aldım|aldık|ekle|ekledim|biriktirdim|yatırdım|yatırım yaptım)\b',
        ).hasMatch(kucuk);

    if (!alisMi && !satisMi) return null;

    final temiz = _tarihMetinleriniTemizle(kucuk).replaceAll(
      RegExp(r'\b\d{1,2}[:.]\d{2}(?:\s*-\s*\d{1,2}[:.]\d{2})?\b'),
      ' ',
    );

    String? bulunanSembol;
    final siraliAnahtarlar = _varlikAnahtarEslesmeleri.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final anahtar in siraliAnahtarlar) {
      if (RegExp(
              '(^|[^a-zçğıöşü0-9])${RegExp.escape(anahtar)}([^a-zçğıöşü0-9]|\$)')
          .hasMatch(temiz)) {
        bulunanSembol = _varlikAnahtarEslesmeleri[anahtar];
        break;
      }
    }

    if (bulunanSembol == null) {
      final lotMatch = RegExp(
        r'\b(\d+(?:[.,]\d+)?)\s*(?:lot|adet|tane)\s+([a-zçğıöşü]{3,6})(?:\s+hisse\w*)?\b',
      ).firstMatch(temiz);
      if (lotMatch != null) {
        final adayKod = lotMatch.group(2)!.toUpperCase();
        if (!{'PARA', 'LIRA', 'TL', 'GUN', 'AY', 'YIL'}.contains(adayKod)) {
          bulunanSembol = kucuk.contains('abd') || kucuk.contains('nasdaq')
              ? adayKod
              : '$adayKod.IS';
        }
      }
    }

    if (bulunanSembol == null) return null;

    final sayiMatch = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(temiz);
    if (sayiMatch == null) return null;

    String hamSayi = sayiMatch.group(1)!;
    if (RegExp(r'^\d{1,3}\.\d{3}$').hasMatch(hamSayi)) {
      hamSayi = hamSayi.replaceAll('.', '');
    } else {
      hamSayi = hamSayi.replaceAll(',', '.');
    }

    final girilenSayi = double.tryParse(hamSayi);
    if (girilenSayi == null || girilenSayi <= 0) return null;

    final servis = VarlikServisi.instance;
    final guncelKur = servis.kurGetir(bulunanSembol);

    final tlBazliMi = RegExp(
      r'\d+(?:[.,]\d+)?\s*(?:tl\s*lik|tllik|liralık|tl\s*değerinde|tl\s*tutarında|₺\s*lik)',
    ).hasMatch(temiz);

    double varlikMiktari = girilenSayi;
    if (tlBazliMi) {
      if (guncelKur <= 0) {
        return [
          '⚠️ ${bulunanSembol.replaceAll('.IS', '')} canlı kuru henüz yüklenmedi, TL karşılığı hesaplanamadı.'
        ];
      }
      varlikMiktari = girilenSayi / guncelKur;
    }

    final tanim = servis.tanimGetir(bulunanSembol);
    final miktarStr = _miktarFormatla(varlikMiktari);
    final List<String> sonuclar = [];

    if (satisMi) {
      final dusulen = servis.varlikAzalt(
        sembol: bulunanSembol,
        miktar: varlikMiktari,
      );
      if (dusulen <= 0) {
        return ['⚠️ Varlık Kasasında ${tanim.gorunenAd} bulunamadı.'];
      }
      final dusulenStr = _miktarFormatla(dusulen);
      final kurBilgisi =
          guncelKur > 0 ? ' (Kur: ${guncelKur.toStringAsFixed(2)} ₺)' : '';
      sonuclar.add(
        '💰 Varlık Kasası: -$dusulenStr ${tanim.birim} ${tanim.gorunenAd}$kurBilgisi',
      );

      if (guncelKur > 0 && onFinansEkle != null) {
        final toplamTl = tlBazliMi ? girilenSayi : (dusulen * guncelKur);
        final yuvarlanmisTl = double.parse(toplamTl.toStringAsFixed(2));
        onFinansEkle(
          FinansItem(
            id: '${DateTime.now().millisecondsSinceEpoch}_vf_$sira',
            baslik: '${tanim.gorunenAd} Satışı ($dusulenStr ${tanim.birim})',
            miktar: yuvarlanmisTl,
            tur: 'Gelir',
            tarih: hedefTarih,
            yineleme: 'Tek seferlik',
          ),
        );
        sonuclar.add(
          '💵 Finans: +${yuvarlanmisTl.toStringAsFixed(0)} ₺ (${tanim.gorunenAd} Satışı)',
        );
      }

      return sonuclar;
    }

    // Alım işlemi -> Varlık Kasası'na ekle + Finans'tan TL karşılığını Gider düş
    servis.varlikEkle(
      sembol: bulunanSembol,
      miktar: varlikMiktari,
      alisFiyatiTl: guncelKur > 0 ? guncelKur : null,
    );

    if (guncelKur > 0) {
      final toplamTl = tlBazliMi ? girilenSayi : (varlikMiktari * guncelKur);
      final yuvarlanmisTl = double.parse(toplamTl.toStringAsFixed(2));

      sonuclar.add(
        '💰 Varlık Kasası: +$miktarStr ${tanim.birim} ${tanim.gorunenAd} (Kur: ${guncelKur.toStringAsFixed(2)} ₺)',
      );

      if (onFinansEkle != null) {
        onFinansEkle(
          FinansItem(
            id: '${DateTime.now().millisecondsSinceEpoch}_vf_$sira',
            baslik: '${tanim.gorunenAd} Alımı ($miktarStr ${tanim.birim})',
            miktar: yuvarlanmisTl,
            tur: 'Gider',
            tarih: hedefTarih,
            yineleme: 'Tek seferlik',
          ),
        );
        sonuclar.add(
          '💸 Finans: -${yuvarlanmisTl.toStringAsFixed(0)} ₺ (${tanim.gorunenAd} Alımı)',
        );
      }
    } else {
      sonuclar.add(
        '💰 Varlık Kasası: +$miktarStr ${tanim.birim} ${tanim.gorunenAd} (Canlı kur bekleniyor, TL gideri işlenemedi)',
      );
    }

    return sonuclar;
  }

  static Map<String, dynamic> _donemFinansOzeti(
    List<FinansItem> finansIslemleri,
    DateTime baslangic,
    DateTime bitis,
  ) {
    double toplamGelir = 0;
    double toplamGider = 0;
    final List<String> kalemler = [];

    DateTime imlec = DateTime(baslangic.year, baslangic.month, baslangic.day);
    final son = DateTime(bitis.year, bitis.month, bitis.day);

    while (!imlec.isAfter(son)) {
      final gunAdi = _gunKisaAdlar[imlec.weekday] ?? '';
      for (final f in finansIslemleri) {
        if (!f.oGunAktifMi(imlec)) continue;
        final isPozitif = f.tur == 'Gelir' || f.tur == 'Alacak';
        final tutar = isPozitif
            ? f.miktar
            : (f.tur == 'Kredi Kartı' && (f.odendi || f.odenenMiktar > 0)
                ? (f.odenenMiktar > 0 ? f.odenenMiktar : f.miktar)
                : f.tahminiOdeme);

        if (isPozitif) {
          toplamGelir += tutar;
        } else {
          toplamGider += tutar;
        }

        kalemler.add(
          '- ${imlec.day}.${imlec.month} ($gunAdi): ${f.baslik} [${f.tur}] ${isPozitif ? "+" : "-"}${tutar.toStringAsFixed(0)} ₺',
        );
      }
      imlec = imlec.add(const Duration(days: 1));
    }

    return {
      'gelir': toplamGelir,
      'gider': toplamGider,
      'kalemler': kalemler,
    };
  }

  static bool _soruCumlesiMi(String metin) {
    final kucuk = trKucuk(metin).trim();
    if (kucuk.endsWith('?')) return true;
    return RegExp(
      r'\b(ne kadar|kaç|nasıl|neden|niye|hangi|sürer|hesapla|yorumla|söyle|nedir|ne durumda|durumu|özetle|göster|mı|mi|mu|mü)\b',
    ).hasMatch(kucuk);
  }

  static String? _kartSorusuCevapla(
    String kucuk,
    String dilPrefix,
    List<FinansItem> finansIslemleri,
  ) {
    final tumKartlar =
        finansIslemleri.where((f) => f.tur == 'Kredi Kartı').toList();

    const genelKartKelimeleri = {
      'kart',
      'kartı',
      'kartım',
      'kartlar',
      'kartlarım',
      'kredi',
      'banka',
      'limit',
      'limiti',
      'limitim',
      'ekstre',
      'asgari',
    };

    final ozelEslesenKartlar = tumKartlar.where((k) {
      final ad = trKucuk(k.baslik.trim());
      if (ad.isEmpty) return false;
      if (kucuk.contains(ad)) return true;
      final parcalar = ad
          .split(RegExp(r'[\s\-_]+'))
          .where((p) => p.length >= 3 && !genelKartKelimeleri.contains(p));
      return parcalar.any((p) => kucuk.contains(p));
    }).toList();

    final kartSorusuMu = ozelEslesenKartlar.isNotEmpty ||
        RegExp(
          r'\b(kart\w*|limit\w*|ekstre\w*|asgari\w*|hesap kesim|son ödeme)\b',
        ).hasMatch(kucuk);

    if (!kartSorusuMu) return null;

    if (tumKartlar.isEmpty) {
      return '${dilPrefix}_kart_yok'.tr;
    }

    final hedefler =
        ozelEslesenKartlar.isNotEmpty ? ozelEslesenKartlar : tumKartlar;

    double toplamLimitHepsi = 0;
    double toplamBorcHepsi = 0;
    double toplamKalanHepsi = 0;

    final List<String> satirlar = [];
    for (final k in hedefler) {
      final toplamLimit = k.kartLimiti ?? 0.0;
      final guncelBorc = k.odendi ? 0.0 : k.kalanMiktar;
      final kalanLimit = max(0.0, toplamLimit - guncelBorc);
      final asgari = guncelBorc * k.asgariOran;

      toplamLimitHepsi += toplamLimit;
      toplamBorcHepsi += guncelBorc;
      toplamKalanHepsi += kalanLimit;

      final limitBilgisi = toplamLimit > 0
          ? '${dilPrefix}_kart_kalan_limit'.trParams({
              'kalan': kalanLimit.toStringAsFixed(0),
              'limit': toplamLimit.toStringAsFixed(0),
            })
          : '${dilPrefix}_kart_limit_yok'.tr;
      final tarihBilgisi = '${dilPrefix}_kart_kesim_son_odeme'.trParams({
        'kesim': (k.hesapKesimGunu ?? '-').toString(),
        'son': (k.sonOdemeGunu ?? '-').toString(),
      });

      satirlar.add(
        '${dilPrefix}_kart_satir'.trParams({
          'kart': k.baslik,
          'borc': guncelBorc.toStringAsFixed(0),
          'asgari': asgari.toStringAsFixed(0),
          'limitBilgisi': limitBilgisi,
          'tarihBilgisi': tarihBilgisi,
        }),
      );
    }

    if (hedefler.length > 1 && toplamLimitHepsi > 0) {
      satirlar.add(
        '${dilPrefix}_kart_toplam_ozet'.trParams({
          'kalan': toplamKalanHepsi.toStringAsFixed(0),
          'limit': toplamLimitHepsi.toStringAsFixed(0),
          'borc': toplamBorcHepsi.toStringAsFixed(0),
        }),
      );
    }

    return satirlar.join('\n');
  }

  static String? _soruCevapla({
    required String hamMetin,
    required DateTime bazTarih,
    required String dilPrefix,
    required List<FinansItem> finansIslemleri,
  }) {
    final kucuk = trKucuk(hamMetin);
    final baz = DateTime(bazTarih.year, bazTarih.month, bazTarih.day);

    final kartCevabi = _kartSorusuCevapla(kucuk, dilPrefix, finansIslemleri);
    if (kartCevabi != null) return kartCevabi;

    final finansSorusuMu = RegExp(
      r'\b(ne kadar|giriş|çıkış|gelir|gider|bütçe|durum|özet|kalan|harca|para|kart|limit|sürer|borç|fatura|alacak)\b',
    ).hasMatch(kucuk);

    if (!finansSorusuMu) return null;

    if (kucuk.contains('hafta')) {
      final haftaninBasi = baz.subtract(Duration(days: baz.weekday - 1));
      final haftaninSonu = haftaninBasi.add(const Duration(days: 6));
      final ozet =
          _donemFinansOzeti(finansIslemleri, haftaninBasi, haftaninSonu);
      final gelir = (ozet['gelir'] as double).toStringAsFixed(0);
      final gider = (ozet['gider'] as double).toStringAsFixed(0);
      final kalemler = ozet['kalemler'] as List<String>;
      final detay = kalemler.isEmpty
          ? '${dilPrefix}_kayit_yok'.tr
          : kalemler.take(5).join('\n');
      return '${dilPrefix}_haftalik_ozet'.trParams({
        'bas': '${haftaninBasi.day}.${haftaninBasi.month}',
        'son': '${haftaninSonu.day}.${haftaninSonu.month}',
        'gelir': gelir,
        'gider': gider,
        'detay': detay,
      });
    }

    final ayinSonGunu = DateTime(baz.year, baz.month + 1, 0);
    final ozet = _donemFinansOzeti(finansIslemleri, baz, ayinSonGunu);
    final gelir = (ozet['gelir'] as double).toStringAsFixed(0);
    final gider = (ozet['gider'] as double).toStringAsFixed(0);
    final kalemler = ozet['kalemler'] as List<String>;
    final detay = kalemler.isEmpty
        ? '${dilPrefix}_ay_sonuna_kayit_yok'.tr
        : kalemler.take(6).join('\n');
    return '${dilPrefix}_ay_sonu_ozet'.trParams({
      'bas': '${baz.day}.${baz.month}',
      'son': '${ayinSonGunu.day}.${ayinSonGunu.month}',
      'gelir': gelir,
      'gider': gider,
      'detay': detay,
    });
  }

  static List<DateTime> _tumTarihleriAyikla(String cumle, DateTime bazTarih) {
    final kucuk = trKucuk(cumle);
    final temel = DateTime(bazTarih.year, bazTarih.month, bazTarih.day);
    final List<_TarihEslesme> eslesmeler = [];

    const ayMap = {
      'ocak': 1,
      'şubat': 2,
      'mart': 3,
      'nisan': 4,
      'mayıs': 5,
      'haziran': 6,
      'temmuz': 7,
      'ağustos': 8,
      'eylül': 9,
      'ekim': 10,
      'kasım': 11,
      'aralık': 12,
    };

    for (final m in RegExp(
      r"\b(\d{1,2})\s*(ocak|şubat|mart|nisan|mayıs|haziran|temmuz|ağustos|eylül|ekim|kasım|aralık)(?:['’]?(?:da|de|ta|te|a|e|ya|ye|ın|in|un|ün|nın|nin|nun|nün))?",
    ).allMatches(kucuk)) {
      final gun = int.parse(m.group(1)!);
      final ay = ayMap[m.group(2)!]!;
      if (gun >= 1 && gun <= 31) {
        int yil = temel.year;
        final aday = DateTime(yil, ay, gun);
        if (aday.isBefore(temel)) yil += 1;
        eslesmeler.add(_TarihEslesme(m.start, DateTime(yil, ay, gun)));
      }
    }

    final saatsiz = kucuk.replaceAll(
      RegExp(r'\bsaat\s*\d{1,2}[:.]\d{2}(?:\s*-\s*\d{1,2}[:.]\d{2})?\b'),
      ' ',
    );
    for (final m in RegExp(
      r"\b(\d{1,2})[./](\d{1,2})(?:[./](\d{2,4}))?(?:['’]?(?:da|de|ta|te|a|e|ya|ye|ın|in|un|ün))?",
    ).allMatches(saatsiz)) {
      final gun = int.parse(m.group(1)!);
      final ay = int.parse(m.group(2)!);
      if (gun >= 1 && gun <= 31 && ay >= 1 && ay <= 12) {
        int yil = temel.year;
        if (m.group(3) != null) {
          final y = int.parse(m.group(3)!);
          yil = y < 100 ? 2000 + y : y;
        }
        eslesmeler.add(_TarihEslesme(m.start, DateTime(yil, ay, gun)));
      }
    }

    for (final m
        in RegExp(r'\b(\d+)\s*gün\s*sonra(?:ya|sı)?\b').allMatches(kucuk)) {
      final ekGun = int.tryParse(m.group(1)!) ?? 0;
      eslesmeler.add(_TarihEslesme(m.start, temel.add(Duration(days: ekGun))));
    }

    for (final m in RegExp(r'\böbür\s*gün\b').allMatches(kucuk)) {
      eslesmeler.add(_TarihEslesme(m.start, temel.add(const Duration(days: 2))));
    }
    for (final m in RegExp(r'\byarın(?:ki|a)?\b').allMatches(kucuk)) {
      eslesmeler.add(_TarihEslesme(m.start, temel.add(const Duration(days: 1))));
    }
    for (final m in RegExp(r'\bbugün(?:kü|e)?\b').allMatches(kucuk)) {
      eslesmeler.add(_TarihEslesme(m.start, temel));
    }
    for (final m in RegExp(r'\bdün(?:kü)?\b').allMatches(kucuk)) {
      eslesmeler
          .add(_TarihEslesme(m.start, temel.subtract(const Duration(days: 1))));
    }

    const gunMap = {
      'pazartesi': 1,
      'salı': 2,
      'çarşamba': 3,
      'perşembe': 4,
      'cuma': 5,
      'cumartesi': 6,
      'pazar': 7,
    };
    for (final entry in gunMap.entries) {
      for (final m in RegExp(
        "\\b${entry.key}(?:['’]?(?:ya|ye|a|e|da|de|ta|te|ki))?",
      ).allMatches(kucuk)) {
        int fark = (entry.value - temel.weekday + 7) % 7;
        if (fark == 0 && kucuk.contains('haftaya')) fark = 7;
        eslesmeler.add(_TarihEslesme(m.start, temel.add(Duration(days: fark))));
      }
    }

    if (eslesmeler.isEmpty) {
      for (final m in RegExp(r'\bhaftaya\b').allMatches(kucuk)) {
        eslesmeler
            .add(_TarihEslesme(m.start, temel.add(const Duration(days: 7))));
      }
    }

    eslesmeler.sort((a, b) => a.baslangic.compareTo(b.baslangic));
    return eslesmeler.map((e) => e.tarih).toList();
  }

  static DateTime? _tarihAyikla(String cumle, DateTime bazTarih) {
    final liste = _tumTarihleriAyikla(cumle, bazTarih);
    return liste.isEmpty ? null : liste.first;
  }

  static String _tarihMetinleriniTemizle(String metin) {
    return metin
        .replaceAll(
          RegExp(
            r"\b\d{1,2}\s*(ocak|şubat|mart|nisan|mayıs|haziran|temmuz|ağustos|eylül|ekim|kasım|aralık)(?:['’]?(?:da|de|ta|te|a|e|ya|ye|ın|in|un|ün|nın|nin|nun|nün))?",
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r"\b\d{1,2}[./]\d{1,2}(?:[./]\d{2,4})?(?:['’]?(?:da|de|ta|te|a|e|ya|ye|ın|in|un|ün))?",
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r"\b(pazartesi|salı|çarşamba|perşembe|cuma|cumartesi|pazar)(?:['’]?(?:ya|ye|a|e|da|de|ta|te|ki))?\s*(günü)?",
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
              r'\b(yarınki|yarına|yarın|öbür gün|bugünkü|bugün|dünkü|dün|haftaya)\b',
              caseSensitive: false),
          ' ',
        )
        .replaceAll(
            RegExp(r'\b\d+\s*gün\s*sonra(?:ya|sı)?\b', caseSensitive: false),
            ' ');
  }

  static List<String>? _iptalVeyaErtelemeIsle({
    required String cumle,
    required DateTime varsayilanTarih,
    required String dilPrefix,
    required List<FinansItem> finansIslemleri,
    required List<Etkinlik> etkinlikler,
    Function(FinansItem)? onFinansSil,
    Function(FinansItem, DateTime)? onFinansTekGunIptal,
    Function(FinansItem, DateTime)? onFinansTarihGuncelle,
    Function(Etkinlik)? onEtkinlikEkle,
    Function(Etkinlik)? onEtkinlikSil,
    Function(Etkinlik, DateTime)? onEtkinlikTekGunIptal,
    Function(Etkinlik, DateTime)? onEtkinlikTarihGuncelle,
  }) {
    final kucuk = trKucuk(cumle);

    final iptalMi = RegExp(
      r'\b(iptal|gitmicem|gitmeyeceğim|gitmiycem|katılmayacağım|katılmıcam|yapılmayacak|olmayacak|vazgeçtim|kaldırıldı)\b',
    ).hasMatch(kucuk);

    final ertelemeMi = !iptalMi &&
        RegExp(
          r'\b(ertelendi|ertelenecek|ertele|ötelendi|kaldı|alındı|kaydırıldı|ödeyecekmiş|ödeyecek|verecekmiş|yapılacakmış|olacakmış|normalde)\b',
        ).hasMatch(kucuk);

    if (!iptalMi && !ertelemeMi) return null;

    final tarihler = _tumTarihleriAyikla(cumle, varsayilanTarih);
    final kokler = anahtarKelimeleriCikar(cumle);
    final isIlgili = isKaydiMi(cumle);
    final List<String> sonuclar = [];

    if (iptalMi) {
      final hedefTarih = tarihler.isNotEmpty
          ? tarihler.first
          : DateTime(
              varsayilanTarih.year, varsayilanTarih.month, varsayilanTarih.day);
      final tarihEtiketi = '${hedefTarih.day}.${hedefTarih.month}';

      final eslesenEtkinlikler = etkinlikler
          .where((e) =>
              e.oGunAktifMi(hedefTarih) && metinEslesiyorMu(e.baslik, kokler))
          .toList();

      for (final e in eslesenEtkinlikler) {
        if (e.yineleme == 'Tek seferlik') {
          onEtkinlikSil?.call(e);
          sonuclar.add('${dilPrefix}_aks_takvim_iptal'.trParams({
            'tarih': tarihEtiketi,
            'baslik': e.baslik,
          }));
        } else {
          onEtkinlikTekGunIptal?.call(e, hedefTarih);
          sonuclar.add('${dilPrefix}_aks_takvim_tek_gun_iptal'.trParams({
            'tarih': tarihEtiketi,
            'baslik': e.baslik,
          }));
        }
      }

      final eslesenFinanslar = finansIslemleri.where((f) {
        if (!f.oGunAktifMi(hedefTarih)) return false;
        if (isIlgili && mesaiGeliriMi(f)) return true;
        return metinEslesiyorMu(f.baslik, kokler);
      }).toList();

      for (final f in eslesenFinanslar) {
        if (f.yineleme == 'Tek seferlik') {
          onFinansSil?.call(f);
          sonuclar.add('${dilPrefix}_aks_finans_iptal'.trParams({
            'tarih': tarihEtiketi,
            'baslik': f.baslik,
          }));
        } else {
          onFinansTekGunIptal?.call(f, hedefTarih);
          sonuclar.add('${dilPrefix}_aks_finans_tek_gun_iptal'.trParams({
            'tarih': tarihEtiketi,
            'baslik': f.baslik,
          }));
        }
      }

      if (sonuclar.isEmpty) {
        sonuclar.add('${dilPrefix}_aks_iptal_bulunamadi'
            .trParams({'tarih': tarihEtiketi}));
      }
      return sonuclar;
    }

    if (tarihler.isEmpty) return null;

    final DateTime? eskiTarih = tarihler.length >= 2 ? tarihler.first : null;
    final DateTime yeniTarih = tarihler.last;
    final yeniTarihStr =
        '${yeniTarih.day}.${yeniTarih.month}.${yeniTarih.year}';

    var adayFinanslar = finansIslemleri.where((f) {
      if (f.odendi) return false;
      if (eskiTarih != null && !f.oGunAktifMi(eskiTarih)) return false;
      if (isIlgili && mesaiGeliriMi(f)) return true;
      return metinEslesiyorMu(f.baslik, kokler);
    }).toList();

    if (adayFinanslar.isEmpty && eskiTarih != null) {
      adayFinanslar = finansIslemleri
          .where((f) => !f.odendi && metinEslesiyorMu(f.baslik, kokler))
          .toList();
    }

    for (final f in adayFinanslar) {
      final eskiStr = '${f.tarih.day}.${f.tarih.month}';
      onFinansTarihGuncelle?.call(f, yeniTarih);
      sonuclar.add('${dilPrefix}_aks_finans_ertelendi'.trParams({
        'baslik': f.baslik,
        'eski': eskiStr,
        'yeni': yeniTarihStr,
      }));
    }

    var adayEtkinlikler = etkinlikler.where((e) {
      if (eskiTarih != null && !e.oGunAktifMi(eskiTarih)) return false;
      return metinEslesiyorMu(e.baslik, kokler);
    }).toList();

    if (adayEtkinlikler.isEmpty && eskiTarih != null) {
      adayEtkinlikler = etkinlikler
          .where((e) => metinEslesiyorMu(e.baslik, kokler))
          .toList();
    }

    for (final e in adayEtkinlikler) {
      if (e.yineleme == 'Tek seferlik') {
        final eskiStr = '${e.tarih.day}.${e.tarih.month}';
        onEtkinlikTarihGuncelle?.call(e, yeniTarih);
        sonuclar.add('${dilPrefix}_aks_takvim_ertelendi'.trParams({
          'baslik': e.baslik,
          'eski': eskiStr,
          'yeni': yeniTarihStr,
        }));
      } else {
        DateTime iptalGun = eskiTarih ??
            DateTime(varsayilanTarih.year, varsayilanTarih.month,
                varsayilanTarih.day);
        if (eskiTarih == null) {
          for (int i = 0; i < 14; i++) {
            final aday = DateTime(varsayilanTarih.year, varsayilanTarih.month,
                    varsayilanTarih.day)
                .add(Duration(days: i));
            if (e.oGunAktifMi(aday)) {
              iptalGun = aday;
              break;
            }
          }
        }
        onEtkinlikTekGunIptal?.call(e, iptalGun);
        onEtkinlikEkle?.call(
          Etkinlik(
            id: '${DateTime.now().microsecondsSinceEpoch}_ertelendi',
            baslik: e.baslik,
            aciklama: '${dilPrefix}_ertelenme_aciklama'.trParams(
                {'tarih': '${iptalGun.day}.${iptalGun.month}'}),
            saat: e.saat,
            tarih: yeniTarih,
            yineleme: 'Tek seferlik',
            katildim: false,
          ),
        );
        sonuclar.add('${dilPrefix}_aks_tek_gun_ertelendi'.trParams({
          'baslik': e.baslik,
          'eski': '${iptalGun.day}.${iptalGun.month}',
          'yeni': yeniTarihStr,
        }));
      }
    }

    if (sonuclar.isEmpty) {
      sonuclar.add('${dilPrefix}_aks_erteleme_bulunamadi'.tr);
    }
    return sonuclar;
  }

  static FinansItem? _finansAyikla(
    String cumle,
    DateTime varsayilanTarih,
    int sira,
    String dilPrefix,
  ) {
    final kucuk = trKucuk(cumle);
    final hedefTarih = _tarihAyikla(cumle, varsayilanTarih) ?? varsayilanTarih;

    final temizlenmis = _tarihMetinleriniTemizle(kucuk).replaceAll(
      RegExp(r'\b\d{1,2}[:.]\d{2}(?:\s*-\s*\d{1,2}[:.]\d{2})?\b'),
      ' ',
    );

    final paraBirimiRegex = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(?:(?:tl|lira|türk lirası)\b|₺)',
      caseSensitive: false,
    );
    final fiilliTutarRegex = RegExp(
      r'\b(\d+(?:[.,]\d+)?)\s*(?:para\s+)?(?:geldi|gelecek|harcadım|ödedim|verdim|aldım|kazandım|gitti|attı|yatırdı|gönderdi)\b',
      caseSensitive: false,
    );

    RegExpMatch? match = paraBirimiRegex.firstMatch(temizlenmis);
    match ??= fiilliTutarRegex.firstMatch(temizlenmis);

    if (match == null) return null;

    String hamSayi = match.group(1)!;
    if (RegExp(r'^\d{1,3}\.\d{3}$').hasMatch(hamSayi)) {
      hamSayi = hamSayi.replaceAll('.', '');
    } else {
      hamSayi = hamSayi.replaceAll(',', '.');
    }

    final miktar = double.tryParse(hamSayi);
    if (miktar == null || miktar <= 0) return null;

    String tur = 'Gider';
    if (kucuk.contains('borç verdim') || kucuk.contains('alacak')) {
      tur = 'Alacak';
    } else if (kucuk.contains('borç aldım') || kucuk.contains('borcum')) {
      tur = 'Borç';
    } else if (RegExp(
      r'\b(geldi|gelecek|kazandım|yatırdı|gönderdi|attı|maaş|burs|mesaigeliri|mesai geliri|harçlık|gelir|tahsil|satış)\b',
    ).hasMatch(kucuk)) {
      tur = 'Gelir';
    } else if (kucuk.contains('aldım') &&
        (kucuk.contains('para') ||
            kucuk.contains('elden') ||
            kucuk.contains('ücret'))) {
      tur = 'Gelir';
    }

    String baslik = _tarihMetinleriniTemizle(cumle)
        .replaceAll(
            RegExp(r'\d+(?:[.,]\d+)?\s*(?:(?:tl|lira|türk lirası)\b|₺)?',
                caseSensitive: false),
            ' ')
        .replaceAll(
          RegExp(
            r'\b(para geldi|geldi|gelecek|harcadım|ödedim|verdim|aldım|kazandım|gitti|attı|yatırdı|gönderdi|borç|para)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(
            RegExp(
                r"['’](?:a|e|ya|ye|da|de|ta|te|dan|den|tan|ten|yı|yi|yu|yü)\b",
                caseSensitive: false),
            '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (baslik.length < 2) {
      baslik = tur == 'Gelir'
          ? '${dilPrefix}_varsayilan_gelir'.tr
          : '${dilPrefix}_varsayilan_gider'.tr;
    } else {
      baslik = _basHarfBuyut(baslik);
    }

    return FinansItem(
      id: '${DateTime.now().millisecondsSinceEpoch}_f_$sira',
      baslik: baslik,
      miktar: miktar,
      tur: tur,
      tarih: hedefTarih,
      yineleme: 'Tek seferlik',
    );
  }

  static Etkinlik? _etkinlikAyikla(
    String cumle,
    DateTime varsayilanTarih,
    int sira,
    String dilPrefix,
  ) {
    final kucuk = trKucuk(cumle);
    final yakalananTarih = _tarihAyikla(cumle, varsayilanTarih);

    final acikKomut = RegExp(
      r'\b(takvime ekle|etkinlik:|ajanda:|hatırlat:|planla:)\b',
    ).hasMatch(kucuk);

    final saatMatch = RegExp(
      r'\b(?:saat\s*)?([01]?\d|2[0-3])[:.]([0-5]\d)(?:\s*-\s*([01]?\d|2[0-3])[:.]([0-5]\d))?\b',
    ).firstMatch(kucuk);

    final sadeceSaatMatch = RegExp(
      r"\bsaat\s*([01]?\d|2[0-3])(?:'?(?:te|ta|de|da))?\b",
    ).firstMatch(kucuk);

    final etkinlikKelimesi = RegExp(
      r'\b(randevu|randevusu|randevum|sınav|sınavı|sınavım|vize|final|toplantı|toplantısı|ders|dersim|maç|maçı|buluşma|vardiya|mesai|doğum günü|konser|etkinlik|doktor|dişçi|berber|kargo)\b',
    ).hasMatch(kucuk);

    if (!acikKomut &&
        yakalananTarih == null &&
        saatMatch == null &&
        sadeceSaatMatch == null &&
        !etkinlikKelimesi) {
      return null;
    }

    final hedefTarih = yakalananTarih ??
        DateTime(
            varsayilanTarih.year, varsayilanTarih.month, varsayilanTarih.day);

    String saatMetni = 'tum_gun'.tr;
    if (saatMatch != null) {
      final basSaat = saatMatch.group(1)!.padLeft(2, '0');
      final basDakika = saatMatch.group(2)!.padLeft(2, '0');
      if (saatMatch.group(3) != null && saatMatch.group(4) != null) {
        final bitSaat = saatMatch.group(3)!.padLeft(2, '0');
        final bitDakika = saatMatch.group(4)!.padLeft(2, '0');
        saatMetni = '$basSaat:$basDakika - $bitSaat:$bitDakika';
      } else {
        final bitisSaatInt = (int.parse(basSaat) + 1) % 24;
        final bitSaat = bitisSaatInt.toString().padLeft(2, '0');
        saatMetni = '$basSaat:$basDakika - $bitSaat:$basDakika';
      }
    } else if (sadeceSaatMatch != null) {
      final basSaat = sadeceSaatMatch.group(1)!.padLeft(2, '0');
      final bitisSaatInt = (int.parse(basSaat) + 1) % 24;
      final bitSaat = bitisSaatInt.toString().padLeft(2, '0');
      saatMetni = '$basSaat:00 - $bitSaat:00';
    }

    String baslik = _tarihMetinleriniTemizle(cumle)
        .replaceAll(
            RegExp(r'\b(takvime ekle|etkinlik:|ajanda:|hatırlat:|planla:)\b',
                caseSensitive: false),
            ' ')
        .replaceAll(
          RegExp(
            r"\b(?:saat\s*)?([01]?\d|2[0-3])[:.]([0-5]\d)(?:\s*-\s*([01]?\d|2[0-3])[:.]([0-5]\d))?(?:\s*['’]?(?:te|ta|de|da))?\b",
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(r"\bsaat\s*([01]?\d|2[0-3])(?:\s*['’]?(?:te|ta|de|da))?\b",
              caseSensitive: false),
          ' ',
        )
        .replaceAll(
            RegExp(r'\b(var|olacak|ekle|takvime)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'^[:\-\s]+|[:\-\s]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (baslik.length < 2) {
      baslik = '${dilPrefix}_varsayilan_etkinlik'.tr;
    } else {
      baslik = _basHarfBuyut(baslik);
    }

    return Etkinlik(
      id: '${DateTime.now().millisecondsSinceEpoch}_e_$sira',
      baslik: baslik,
      aciklama: '${dilPrefix}_otomatik_etkinlik_aciklama'.tr,
      saat: saatMetni,
      tarih: hedefTarih,
      yineleme: 'Tek seferlik',
      yinelemeBitis: null,
      katildim: false,
    );
  }
}