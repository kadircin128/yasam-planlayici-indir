import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dil_servisi.dart';

class VarlikKalemi {
  final String id;
  final String sembol;
  final double miktar;
  final double alisFiyatiTl;

  const VarlikKalemi({
    required this.id,
    required this.sembol,
    required this.miktar,
    required this.alisFiyatiTl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sembol': sembol,
        'miktar': miktar,
        'alisFiyatiTl': alisFiyatiTl,
      };

  factory VarlikKalemi.fromJson(Map<String, dynamic> json) => VarlikKalemi(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        sembol: (json['sembol'] ?? 'USD').toString().toUpperCase(),
        miktar: (json['miktar'] as num?)?.toDouble() ?? 0.0,
        alisFiyatiTl: (json['alisFiyatiTl'] as num?)?.toDouble() ?? 0.0,
      );
}

class VarlikTanim {
  final String sembol;
  final String ad;
  final String? adKey;
  final String birim;
  final String kategori; // 'doviz', 'altin', 'kripto', 'hisse'
  final String? aramaAnahtarlari;

  const VarlikTanim({
    required this.sembol,
    required this.ad,
    this.adKey,
    required this.birim,
    required this.kategori,
    this.aramaAnahtarlari,
  });

  String get gorunenAd {
    if (adKey != null) {
      final ceviri = adKey!.tr;
      if (ceviri != adKey) return ceviri;
    }
    return ad;
  }

  Map<String, dynamic> toJson() => {
        'sembol': sembol,
        'ad': ad,
        'adKey': adKey,
        'birim': birim,
        'kategori': kategori,
      };

  factory VarlikTanim.fromJson(Map<String, dynamic> json) => VarlikTanim(
        sembol: (json['sembol'] ?? '').toString().toUpperCase(),
        ad: (json['ad'] ?? json['sembol'] ?? '').toString(),
        adKey: json['adKey']?.toString(),
        birim: (json['birim'] ?? '').toString(),
        kategori: (json['kategori'] ?? 'doviz').toString(),
      );
}

class VarlikServisi {
  VarlikServisi._() {
    baslat();
  }

  static final VarlikServisi instance = VarlikServisi._();

  final ValueNotifier<int> degisimNotifier = ValueNotifier<int>(0);

  List<VarlikKalemi> _varliklar = [];
  Map<String, double> _canliKurlar = {};
  final Map<String, VarlikTanim> _tanimHaritasi = {};

  bool _baslatildi = false;
  bool _yukleniyor = false;
  bool _baglantiHatasi = false;
  String _sonGuncelleme = '';

  List<VarlikKalemi> get varliklar => List.unmodifiable(_varliklar);
  Map<String, double> get canliKurlar => Map.unmodifiable(_canliKurlar);
  bool get yukleniyor => _yukleniyor;
  bool get baglantiHatasi => _baglantiHatasi;
  String get sonGuncelleme =>
      _sonGuncelleme.isEmpty ? 'yukleniyor'.tr : _sonGuncelleme;

  List<VarlikTanim> get tumTanimlar {
    final liste = _tanimHaritasi.values.toList();
    liste.sort((a, b) {
      final oncelikA = _oncelikSirasi(a.sembol);
      final oncelikB = _oncelikSirasi(b.sembol);
      if (oncelikA != oncelikB) return oncelikA.compareTo(oncelikB);
      return a.gorunenAd.compareTo(b.gorunenAd);
    });
    return liste;
  }

  int _oncelikSirasi(String sembol) {
    const oncelikler = [
      'USD',
      'EUR',
      'GBP',
      'CHF',
      'JPY',
      'SAR',
      'AED',
      'RUB',
      'CNY',
      'CAD',
      'AUD',
      'GRAM_ALTIN',
      'CEYREK_ALTIN',
      'YARIM_ALTIN',
      'TAM_ALTIN',
      'CUMHURIYET_ALTIN',
      'BILEZIK_22',
      'ONS_ALTIN',
      'GRAM_GUMUS',
      'BTC',
      'ETH',
      'SOL',
      'USDT',
      'BNB',
      'XRP',
      'DOGE',
      'ADA',
      'AVAX',
      'TRX',
      'TON',
      'SUI',
      'PEPE',
      'THYAO.IS',
      'ASELS.IS',
      'TUPRS.IS',
      'KCHOL.IS',
      'AKBNK.IS',
      'GARAN.IS',
      'BIMAS.IS',
      'EREGL.IS',
      'SASA.IS',
      'ASTOR.IS',
      'AAPL',
      'NVDA',
      'TSLA',
      'MSFT',
      'GOOGL',
      'AMZN',
      'META',
    ];
    final idx = oncelikler.indexOf(sembol);
    return idx == -1 ? 999 : idx;
  }

  void _bildir() {
    degisimNotifier.value++;
  }

  static const Set<String> _fiatKodlari = {
    'usd', 'eur', 'gbp', 'chf', 'jpy', 'cad', 'aud', 'nzd', 'sek', 'nok',
    'dkk', 'sar', 'aed', 'qar', 'kwd', 'bhd', 'omr', 'jod', 'rub', 'cny',
    'hkd', 'sgd', 'krw', 'inr', 'brl', 'mxn', 'zar', 'pln', 'czk', 'huf',
    'ron', 'bgn', 'ils', 'thb', 'myr', 'idr', 'php', 'vnd', 'egp', 'azn',
    'gel', 'uah', 'kzt', 'uzs', 'kgs', 'tjs', 'tmt', 'amd', 'byn', 'mdl',
    'rsd', 'bam', 'mkd', 'all', 'isk', 'pkr', 'bdt', 'lkr', 'npr', 'mmk',
    'khr', 'lak', 'mnt', 'twd', 'clp', 'cop', 'pen', 'ars', 'uyu', 'pyg',
    'bob', 'ves', 'crc', 'gtq', 'hnl', 'nio', 'pab', 'dop', 'jmd', 'ttd',
    'bsd', 'bbd', 'bzd', 'gyd', 'srd', 'mad', 'dzd', 'tnd', 'lyd', 'sdg',
    'etb', 'kes', 'ugx', 'tzs', 'rwf', 'ghs', 'ngn', 'xof', 'xaf', 'zmw',
    'bwp', 'nad', 'mur', 'scr', 'mzn', 'aoa', 'cdf', 'mga', 'mwk', 'szl',
    'lsl', 'gmd', 'gnf', 'sll', 'lrd', 'cve', 'stn', 'djf', 'ern', 'sos',
    'ssp', 'bif', 'kmf', 'iqd', 'irr', 'syp', 'lbp', 'yer', 'afn', 'fjd',
    'pgk', 'sbd', 'top', 'vuv', 'wst', 'xpf', 'ang', 'awg', 'bmd', 'kyd',
    'fkp', 'gip', 'shp', 'cup', 'htg', 'mop', 'mvr', 'btn', 'bnd',
  };

  static const Map<String, String> _turkceDovizAdlari = {
    'USD': 'Amerikan Doları',
    'EUR': 'Euro',
    'GBP': 'İngiliz Sterlini',
    'CHF': 'İsviçre Frangı',
    'JPY': 'Japon Yeni',
    'CAD': 'Kanada Doları',
    'AUD': 'Avustralya Doları',
    'NZD': 'Yeni Zelanda Doları',
    'SAR': 'Suudi Arabistan Riyali',
    'AED': 'BAE Dirhemi',
    'QAR': 'Katar Riyali',
    'KWD': 'Kuveyt Dinarı',
    'BHD': 'Bahreyn Dinarı',
    'OMR': 'Umman Riyali',
    'JOD': 'Ürdün Dinarı',
    'RUB': 'Rus Rublesi',
    'CNY': 'Çin Yuanı',
    'HKD': 'Hong Kong Doları',
    'SGD': 'Singapur Doları',
    'KRW': 'Güney Kore Wonu',
    'INR': 'Hindistan Rupisi',
    'SEK': 'İsveç Kronu',
    'NOK': 'Norveç Kronu',
    'DKK': 'Danimarka Kronu',
    'PLN': 'Polonya Zlotisi',
    'CZK': 'Çek Korunası',
    'HUF': 'Macar Forinti',
    'RON': 'Rumen Leyi',
    'BGN': 'Bulgar Levası',
    'AZN': 'Azerbaycan Manatı',
    'GEL': 'Gürcistan Larisi',
    'UAH': 'Ukrayna Grivnası',
    'KZT': 'Kazakistan Tengesi',
    'UZS': 'Özbekistan Somu',
    'EGP': 'Mısır Lirası',
    'ILS': 'İsrail Şekeli',
    'BRL': 'Brezilya Reali',
    'MXN': 'Meksika Pesosu',
    'ZAR': 'Güney Afrika Randı',
    'THB': 'Tayland Bahtı',
    'MYR': 'Malezya Ringgiti',
    'IDR': 'Endonezya Rupiahı',
    'PHP': 'Filipin Pesosu',
    'IQD': 'Irak Dinarı',
    'IRR': 'İran Riyali',
  };

  static const List<VarlikTanim> _sabitTanimlar = [
    // Başlıca Dövizler
    VarlikTanim(
      sembol: 'USD',
      ad: 'Amerikan Doları',
      adKey: 'varlik_ad_usd',
      birim: '\$',
      kategori: 'doviz',
      aramaAnahtarlari: 'dolar usd american dollar',
    ),
    VarlikTanim(
      sembol: 'EUR',
      ad: 'Euro',
      adKey: 'varlik_ad_eur',
      birim: '€',
      kategori: 'doviz',
      aramaAnahtarlari: 'euro avro eur',
    ),
    VarlikTanim(
      sembol: 'GBP',
      ad: 'İngiliz Sterlini',
      adKey: 'varlik_ad_gbp',
      birim: '£',
      kategori: 'doviz',
      aramaAnahtarlari: 'sterlin pound gbp',
    ),
    VarlikTanim(
      sembol: 'CHF',
      ad: 'İsviçre Frangı',
      birim: 'CHF',
      kategori: 'doviz',
      aramaAnahtarlari: 'frank isvicre chf',
    ),
    VarlikTanim(
      sembol: 'JPY',
      ad: 'Japon Yeni',
      birim: '¥',
      kategori: 'doviz',
      aramaAnahtarlari: 'yen japon jpy',
    ),
    VarlikTanim(
      sembol: 'SAR',
      ad: 'Suudi Arabistan Riyali',
      birim: 'SAR',
      kategori: 'doviz',
      aramaAnahtarlari: 'riyal suudi sar',
    ),
    VarlikTanim(
      sembol: 'AED',
      ad: 'BAE Dirhemi',
      birim: 'AED',
      kategori: 'doviz',
      aramaAnahtarlari: 'dirhem dubai bae aed',
    ),
    VarlikTanim(
      sembol: 'RUB',
      ad: 'Rus Rublesi',
      birim: '₽',
      kategori: 'doviz',
      aramaAnahtarlari: 'ruble rus rub',
    ),

    // Altın & Kıymetli Madenler
    VarlikTanim(
      sembol: 'GRAM_ALTIN',
      ad: 'Gram Altın (24K)',
      adKey: 'varlik_ad_gram_altin',
      birim: 'gr',
      kategori: 'altin',
      aramaAnahtarlari: 'gram altin has 24 ayar',
    ),
    VarlikTanim(
      sembol: 'BILEZIK_22',
      ad: '22 Ayar Bilezik (Gram)',
      birim: 'gr',
      kategori: 'altin',
      aramaAnahtarlari: '22 ayar bilezik gram altin',
    ),
    VarlikTanim(
      sembol: 'CEYREK_ALTIN',
      ad: 'Çeyrek Altın',
      adKey: 'varlik_ad_ceyrek_altin',
      birim: 'Adet',
      kategori: 'altin',
      aramaAnahtarlari: 'ceyrek altin',
    ),
    VarlikTanim(
      sembol: 'YARIM_ALTIN',
      ad: 'Yarım Altın',
      birim: 'Adet',
      kategori: 'altin',
      aramaAnahtarlari: 'yarim altin',
    ),
    VarlikTanim(
      sembol: 'TAM_ALTIN',
      ad: 'Tam Altın',
      birim: 'Adet',
      kategori: 'altin',
      aramaAnahtarlari: 'tam altin ziynet',
    ),
    VarlikTanim(
      sembol: 'CUMHURIYET_ALTIN',
      ad: 'Cumhuriyet / Ata Altını',
      birim: 'Adet',
      kategori: 'altin',
      aramaAnahtarlari: 'cumhuriyet ata altin',
    ),
    VarlikTanim(
      sembol: 'ONS_ALTIN',
      ad: 'Ons Altın (XAU)',
      birim: 'Ons',
      kategori: 'altin',
      aramaAnahtarlari: 'ons altin xau',
    ),
    VarlikTanim(
      sembol: 'GRAM_GUMUS',
      ad: 'Gram Gümüş',
      birim: 'gr',
      kategori: 'altin',
      aramaAnahtarlari: 'gram gumus silver xag',
    ),
    VarlikTanim(
      sembol: 'ONS_GUMUS',
      ad: 'Ons Gümüş (XAG)',
      birim: 'Ons',
      kategori: 'altin',
      aramaAnahtarlari: 'ons gumus silver xag',
    ),
    VarlikTanim(
      sembol: 'GRAM_PLATIN',
      ad: 'Gram Platin (XPT)',
      birim: 'gr',
      kategori: 'altin',
      aramaAnahtarlari: 'gram platin platinum xpt',
    ),
    VarlikTanim(
      sembol: 'GRAM_PALADYUM',
      ad: 'Gram Paladyum (XPD)',
      birim: 'gr',
      kategori: 'altin',
      aramaAnahtarlari: 'gram paladyum palladium xpd',
    ),

    // Başlıca Kriptolar
    VarlikTanim(
      sembol: 'BTC',
      ad: 'Bitcoin',
      adKey: 'varlik_ad_btc',
      birim: 'BTC',
      kategori: 'kripto',
      aramaAnahtarlari: 'bitcoin btc kripto',
    ),
    VarlikTanim(
      sembol: 'ETH',
      ad: 'Ethereum',
      adKey: 'varlik_ad_eth',
      birim: 'ETH',
      kategori: 'kripto',
      aramaAnahtarlari: 'ethereum eth eter',
    ),
    VarlikTanim(
      sembol: 'SOL',
      ad: 'Solana',
      adKey: 'varlik_ad_sol',
      birim: 'SOL',
      kategori: 'kripto',
      aramaAnahtarlari: 'solana sol',
    ),
    VarlikTanim(
      sembol: 'USDT',
      ad: 'Tether (USDT)',
      birim: 'USDT',
      kategori: 'kripto',
      aramaAnahtarlari: 'tether usdt sabit coin',
    ),
    VarlikTanim(
      sembol: 'BNB',
      ad: 'BNB (Binance Coin)',
      birim: 'BNB',
      kategori: 'kripto',
      aramaAnahtarlari: 'bnb binance coin',
    ),
    VarlikTanim(
      sembol: 'XRP',
      ad: 'Ripple (XRP)',
      birim: 'XRP',
      kategori: 'kripto',
      aramaAnahtarlari: 'ripple xrp',
    ),
    VarlikTanim(
      sembol: 'DOGE',
      ad: 'Dogecoin',
      birim: 'DOGE',
      kategori: 'kripto',
      aramaAnahtarlari: 'dogecoin doge',
    ),
    VarlikTanim(
      sembol: 'ADA',
      ad: 'Cardano (ADA)',
      birim: 'ADA',
      kategori: 'kripto',
      aramaAnahtarlari: 'cardano ada',
    ),
    VarlikTanim(
      sembol: 'AVAX',
      ad: 'Avalanche (AVAX)',
      birim: 'AVAX',
      kategori: 'kripto',
      aramaAnahtarlari: 'avalanche avax',
    ),
    VarlikTanim(
      sembol: 'TRX',
      ad: 'TRON (TRX)',
      birim: 'TRX',
      kategori: 'kripto',
      aramaAnahtarlari: 'tron trx',
    ),
    VarlikTanim(
      sembol: 'TON',
      ad: 'Toncoin (TON)',
      birim: 'TON',
      kategori: 'kripto',
      aramaAnahtarlari: 'toncoin ton telegram',
    ),
    VarlikTanim(
      sembol: 'SUI',
      ad: 'Sui (SUI)',
      birim: 'SUI',
      kategori: 'kripto',
      aramaAnahtarlari: 'sui',
    ),
    VarlikTanim(
      sembol: 'PEPE',
      ad: 'Pepe (PEPE)',
      birim: 'PEPE',
      kategori: 'kripto',
      aramaAnahtarlari: 'pepe',
    ),
    VarlikTanim(
      sembol: 'LINK',
      ad: 'Chainlink (LINK)',
      birim: 'LINK',
      kategori: 'kripto',
      aramaAnahtarlari: 'chainlink link',
    ),
    VarlikTanim(
      sembol: 'DOT',
      ad: 'Polkadot (DOT)',
      birim: 'DOT',
      kategori: 'kripto',
      aramaAnahtarlari: 'polkadot dot',
    ),
    VarlikTanim(
      sembol: 'SHIB',
      ad: 'Shiba Inu (SHIB)',
      birim: 'SHIB',
      kategori: 'kripto',
      aramaAnahtarlari: 'shiba inu shib',
    ),

    // BIST Popüler Hisseler
    VarlikTanim(
      sembol: 'THYAO.IS',
      ad: 'Türk Hava Yolları (THYAO)',
      birim: 'Lot',
      kategori: 'hisse',
      aramaAnahtarlari: 'thyao turk hava yollari bist',
    ),
    VarlikTanim(
      sembol: 'ASELS.IS',
      ad: 'Aselsan (ASELS)',
      birim: 'Lot',
      kategori: 'hisse',
      aramaAnahtarlari: 'asels aselsan bist',
    ),
    VarlikTanim(
      sembol: 'TUPRS.IS',
      ad: 'Tüpraş (TUPRS)',
      birim: 'Lot',
      kategori: 'hisse',
      aramaAnahtarlari: 'tuprs tupras bist',
    ),
    VarlikTanim(
      sembol: 'KCHOL.IS',
      ad: 'Koç Holding (KCHOL)',
      birim: 'Lot',
      kategori: 'hisse',
      aramaAnahtarlari: 'kchol koc holding bist',
    ),
    VarlikTanim(
      sembol: 'AKBNK.IS',
      ad: 'Akbank (AKBNK)',
      birim: 'Lot',
      kategori: 'hisse',
      aramaAnahtarlari: 'akbnk akbank bist',
    ),
    VarlikTanim(
      sembol: 'GARAN.IS',
      ad: 'Garanti BBVA (GARAN)',
      birim: 'Lot',
      kategori: 'hisse',
      aramaAnahtarlari: 'garan garanti bbva bist',
    ),
    VarlikTanim(
      sembol: 'ISCTR.IS',
      ad: 'İş Bankası C (ISCTR)',
      birim: 'Lot',
      kategori: 'hisse',
      aramaAnahtarlari: 'isctr is bankasi bist',
    ),
    VarlikTanim(
      sembol: 'YKBNK.IS',
      ad: 'Yapı Kredi (YKBNK)',
      birim: 'Lot',
      kategori: 'hisse',
      aramaAnahtarlari: 'ykbnk yapi kredi bist',
    ),
    VarlikTanim(
      sembol: 'BIMAS.IS',
      ad: 'BİM Mağazalar (BIMAS)',
      birim: 'Lot',
      kategori: 'hisse',
      aramaAnahtarlari: 'bimas bim bist',
    ),
    VarlikTanim(
      sembol: 'EREGL.IS',
      ad: 'Erdemir (EREGL)',
      birim: 'Lot',
      kategori: 'hisse',
      aramaAnahtarlari: 'eregl erdemir eregli bist',
    ),
    VarlikTanim(
      sembol: 'SISE.IS',
      ad: 'Şişecam (SISE)',
      birim: 'Lot',
      kategori: 'hisse',
      aramaAnahtarlari: 'sise sisecam bist',
    ),
    VarlikTanim(
      sembol: 'SAHOL.IS',
      ad: 'Sabancı Holding (SAHOL)',
      birim: 'Lot',
      kategori: 'hisse',
      aramaAnahtarlari: 'sahol sabanci holding bist',
    ),
    VarlikTanim(
      sembol: 'TCELL.IS',
      ad: 'Turkcell (TCELL)',
      birim: 'Lot',
      kategori: 'hisse',
      aramaAnahtarlari: 'tcell turkcell bist',
    ),
    VarlikTanim(
      sembol: 'FROTO.IS',
      ad: 'Ford Otosan (FROTO)',
      birim: 'Lot',
      kategori: 'hisse',
      aramaAnahtarlari: 'froto ford otosan bist',
    ),
    VarlikTanim(
      sembol: 'TOASO.IS',
      ad: 'Tofaş Oto (TOASO)',
      birim: 'Lot',
      kategori: 'hisse',
      aramaAnahtarlari: 'toaso tofas bist',
    ),
    VarlikTanim(
      sembol: 'SASA.IS',
      ad: 'SASA Polyester (SASA)',
      birim: 'Lot',
      kategori: 'hisse',
      aramaAnahtarlari: 'sasa polyester bist',
    ),
    VarlikTanim(
      sembol: 'ASTOR.IS',
      ad: 'Astor Enerji (ASTOR)',
      birim: 'Lot',
      kategori: 'hisse',
      aramaAnahtarlari: 'astor enerji bist',
    ),
    VarlikTanim(
      sembol: 'PGSUS.IS',
      ad: 'Pegasus (PGSUS)',
      birim: 'Lot',
      kategori: 'hisse',
      aramaAnahtarlari: 'pgsus pegasus bist',
    ),
    VarlikTanim(
      sembol: 'MGROS.IS',
      ad: 'Migros (MGROS)',
      birim: 'Lot',
      kategori: 'hisse',
      aramaAnahtarlari: 'mgros migros bist',
    ),
    VarlikTanim(
      sembol: 'HEKTS.IS',
      ad: 'Hektaş (HEKTS)',
      birim: 'Lot',
      kategori: 'hisse',
      aramaAnahtarlari: 'hekts hektas bist',
    ),

    // ABD & Dünya Popüler Hisseler
    VarlikTanim(
      sembol: 'AAPL',
      ad: 'Apple (AAPL)',
      birim: 'Adet',
      kategori: 'hisse',
      aramaAnahtarlari: 'apple aapl abd nasdaq',
    ),
    VarlikTanim(
      sembol: 'NVDA',
      ad: 'NVIDIA (NVDA)',
      birim: 'Adet',
      kategori: 'hisse',
      aramaAnahtarlari: 'nvidia nvda abd nasdaq',
    ),
    VarlikTanim(
      sembol: 'TSLA',
      ad: 'Tesla (TSLA)',
      birim: 'Adet',
      kategori: 'hisse',
      aramaAnahtarlari: 'tesla tsla abd nasdaq',
    ),
    VarlikTanim(
      sembol: 'MSFT',
      ad: 'Microsoft (MSFT)',
      birim: 'Adet',
      kategori: 'hisse',
      aramaAnahtarlari: 'microsoft msft abd nasdaq',
    ),
    VarlikTanim(
      sembol: 'GOOGL',
      ad: 'Alphabet / Google (GOOGL)',
      birim: 'Adet',
      kategori: 'hisse',
      aramaAnahtarlari: 'google alphabet googl abd nasdaq',
    ),
    VarlikTanim(
      sembol: 'AMZN',
      ad: 'Amazon (AMZN)',
      birim: 'Adet',
      kategori: 'hisse',
      aramaAnahtarlari: 'amazon amzn abd nasdaq',
    ),
    VarlikTanim(
      sembol: 'META',
      ad: 'Meta Platforms (META)',
      birim: 'Adet',
      kategori: 'hisse',
      aramaAnahtarlari: 'meta facebook instagram abd nasdaq',
    ),
    VarlikTanim(
      sembol: 'AMD',
      ad: 'AMD (AMD)',
      birim: 'Adet',
      kategori: 'hisse',
      aramaAnahtarlari: 'amd abd nasdaq',
    ),
    VarlikTanim(
      sembol: 'PLTR',
      ad: 'Palantir (PLTR)',
      birim: 'Adet',
      kategori: 'hisse',
      aramaAnahtarlari: 'palantir pltr abd nyse',
    ),
  ];

  void _sabitTanimlariYukle() {
    for (final t in _sabitTanimlar) {
      _tanimHaritasi[t.sembol] = t;
    }
  }

  VarlikTanim tanimGetir(String sembol) {
    final ust = sembol.trim().toUpperCase();
    return _tanimHaritasi[ust] ??
        VarlikTanim(
          sembol: ust,
          ad: ust,
          birim: ust.endsWith('.IS') ? 'Lot' : ust,
          kategori: ust.endsWith('.IS') ? 'hisse' : 'kripto',
        );
  }

  void tanimKaydet(VarlikTanim tanim) {
    _tanimHaritasi[tanim.sembol.toUpperCase()] = tanim;
    _ozelTanimlariKaydet();
    _bildir();
  }

  double kurGetir(String sembol) {
    return _canliKurlar[sembol.trim().toUpperCase()] ?? 0.0;
  }

  Future<void> baslat() async {
    if (_baslatildi) return;
    _baslatildi = true;
    _sabitTanimlariYukle();

    final prefs = await SharedPreferences.getInstance();

    final kayitliVarliklar = prefs.getString('canli_varlik_kasasi_v1');
    if (kayitliVarliklar != null) {
      try {
        final List<dynamic> decoded = jsonDecode(kayitliVarliklar);
        _varliklar = decoded.map((e) => VarlikKalemi.fromJson(e)).toList();
      } catch (_) {}
    }

    final kayitliMeta = prefs.getString('canli_varlik_meta_v1');
    if (kayitliMeta != null) {
      try {
        final Map<String, dynamic> decodedMeta = jsonDecode(kayitliMeta);
        decodedMeta.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            final t = VarlikTanim.fromJson(value);
            _tanimHaritasi.putIfAbsent(t.sembol, () => t);
          }
        });
      } catch (_) {}
    }

    final kayitliKurlar = prefs.getString('canli_kurlar_cache_v2');
    if (kayitliKurlar != null) {
      try {
        final Map<String, dynamic> decodedKurlar = jsonDecode(kayitliKurlar);
        decodedKurlar.forEach((key, value) {
          final v = (value as num).toDouble();
          if (v > 0) _canliKurlar[key.toUpperCase()] = v;
        });
      } catch (_) {}
    }

    final kayitliZaman = prefs.getString('canli_kurlar_zaman_v2');
    if (kayitliZaman != null && kayitliZaman.isNotEmpty) {
      _sonGuncelleme = 'varlik_canli_saat'.trParams({'saat': kayitliZaman});
    }

    _bildir();
    await canliKurlariGuncelle();
  }

  Future<void> _varliklariKaydet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'canli_varlik_kasasi_v1',
      jsonEncode(_varliklar.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _ozelTanimlariKaydet() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> harita = {};
    _tanimHaritasi.forEach((k, v) {
      harita[k] = v.toJson();
    });
    await prefs.setString('canli_varlik_meta_v1', jsonEncode(harita));
  }

  Future<void> _kurlariOnbellegeKaydet(
      Map<String, double> kurlar, String zaman) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('canli_kurlar_cache_v2', jsonEncode(kurlar));
    await prefs.setString('canli_kurlar_zaman_v2', zaman);
  }

  Future<dynamic> _getJsonDynamic(Uri uri, {int timeoutSaniye = 5}) async {
    final client = HttpClient();
    client.connectionTimeout = Duration(seconds: timeoutSaniye);
    try {
      final Future<dynamic> istek = () async {
        final request = await client.getUrl(uri);
        request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0');
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        final response = await request.close();
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          return jsonDecode(body);
        }
        return null;
      }();

      return await istek.timeout(
        Duration(seconds: timeoutSaniye),
        onTimeout: () {
          client.close(force: true);
          return null;
        },
      );
    } catch (_) {
      return null;
    } finally {
      try {
        client.close(force: true);
      } catch (_) {}
    }
  }

  void _fawazVerisiniIsle(
    Map<String, dynamic> data,
    Map<String, double> hedef,
    Map<String, dynamic>? isimSozlugu,
  ) {
    final usdMap = data['usd'];
    if (usdMap is! Map) return;

    final tryRate = (usdMap['try'] as num?)?.toDouble();
    if (tryRate == null || tryRate <= 0) return;

    hedef['USD'] = tryRate;

    // Tüm fiat dövizler ve tüm kripto paralar
    usdMap.forEach((rawKod, rawOran) {
      final kodKucuk = rawKod.toString().toLowerCase();
      final kodBuyuk = kodKucuk.toUpperCase();
      if (kodKucuk == 'try' || kodKucuk == 'usd') return;

      final oran = (rawOran as num?)?.toDouble();
      if (oran == null || oran <= 0) return;

      // Kıymetli madenleri özel hesaplıyoruz
      if (kodKucuk == 'xau' ||
          kodKucuk == 'xag' ||
          kodKucuk == 'xpt' ||
          kodKucuk == 'xpd') {
        return;
      }

      final tlDegeri = tryRate / oran;
      if (tlDegeri.isFinite && tlDegeri > 0) {
        hedef[kodBuyuk] = tlDegeri;

        if (!_tanimHaritasi.containsKey(kodBuyuk)) {
          final isFiat = _fiatKodlari.contains(kodKucuk);
          final hamAd = isimSozlugu?[kodKucuk]?.toString() ?? kodBuyuk;
          final ad = isFiat
              ? (_turkceDovizAdlari[kodBuyuk] ?? hamAd)
              : hamAd;
          _tanimHaritasi[kodBuyuk] = VarlikTanim(
            sembol: kodBuyuk,
            ad: ad,
            birim: kodBuyuk,
            kategori: isFiat ? 'doviz' : 'kripto',
          );
        }
      }
    });

    // Altın (XAU = 1 Troy Ons = 31.1034768 gram 24K)
    final xauRate = (usdMap['xau'] as num?)?.toDouble();
    if (xauRate != null && xauRate > 0 && xauRate < 0.05) {
      final onsAltin = tryRate / xauRate;
      final gramAltin = onsAltin / 31.1034768;
      hedef['ONS_ALTIN'] = onsAltin;
      hedef['GRAM_ALTIN'] = gramAltin;
      hedef['BILEZIK_22'] = gramAltin * 0.916;
      hedef['CEYREK_ALTIN'] = gramAltin * 1.606;
      hedef['YARIM_ALTIN'] = gramAltin * 3.212;
      hedef['TAM_ALTIN'] = gramAltin * 6.424;
      hedef['CUMHURIYET_ALTIN'] = gramAltin * 6.61;
    }

    // Gümüş (XAG)
    final xagRate = (usdMap['xag'] as num?)?.toDouble();
    if (xagRate != null && xagRate > 0 && xagRate < 1.0) {
      final onsGumus = tryRate / xagRate;
      hedef['ONS_GUMUS'] = onsGumus;
      hedef['GRAM_GUMUS'] = onsGumus / 31.1034768;
    }

    // Platin (XPT)
    final xptRate = (usdMap['xpt'] as num?)?.toDouble();
    if (xptRate != null && xptRate > 0 && xptRate < 0.1) {
      hedef['GRAM_PLATIN'] = (tryRate / xptRate) / 31.1034768;
    }

    // Paladyum (XPD)
    final xpdRate = (usdMap['xpd'] as num?)?.toDouble();
    if (xpdRate != null && xpdRate > 0 && xpdRate < 0.1) {
      hedef['GRAM_PALADYUM'] = (tryRate / xpdRate) / 31.1034768;
    }
  }

  Future<double> hisseFiyatiGetir(String hisseSembolu,
      {double? usdTryKuru}) async {
    final sembol = hisseSembolu.trim().toUpperCase();
    final data = await _getJsonDynamic(
      Uri.https(
        'query1.finance.yahoo.com',
        '/v8/finance/chart/$sembol',
        {'interval': '1d', 'range': '1d'},
      ),
      timeoutSaniye: 4,
    );

    if (data is Map) {
      final chart = data['chart'];
      if (chart is Map && chart['result'] is List) {
        final resultList = chart['result'] as List;
        if (resultList.isNotEmpty && resultList.first is Map) {
          final meta = resultList.first['meta'];
          if (meta is Map) {
            final fiyat = (meta['regularMarketPrice'] as num?)?.toDouble();
            final paraBirimi =
                (meta['currency'] ?? 'USD').toString().toUpperCase();
            if (fiyat != null && fiyat > 0) {
              if (paraBirimi == 'TRY') {
                return fiyat;
              }
              final usdTry = usdTryKuru ?? _canliKurlar['USD'] ?? 0.0;
              if (paraBirimi == 'USD' && usdTry > 0) {
                return fiyat * usdTry;
              }
              final digerKur = _canliKurlar[paraBirimi] ?? 0.0;
              if (digerKur > 0) {
                return fiyat * digerKur;
              }
            }
          }
        }
      }
    }
    return 0.0;
  }

  Future<void> _seciliHisseleriGuncelle(Map<String, double> hedef) async {
    final Set<String> cekilecekHisseler = {
      'THYAO.IS',
      'ASELS.IS',
      'TUPRS.IS',
      'KCHOL.IS',
      'AKBNK.IS',
      'GARAN.IS',
      'BIMAS.IS',
      'EREGL.IS',
      'SASA.IS',
      'ASTOR.IS',
      'AAPL',
      'NVDA',
      'TSLA',
      'MSFT',
      'GOOGL',
      'AMZN',
      'META',
    };

    for (final v in _varliklar) {
      final t = tanimGetir(v.sembol);
      if (t.kategori == 'hisse' || v.sembol.endsWith('.IS')) {
        cekilecekHisseler.add(v.sembol);
      }
    }

    final usdTry = hedef['USD'] ?? _canliKurlar['USD'] ?? 0.0;
    final liste = cekilecekHisseler.toList();

    for (int i = 0; i < liste.length; i += 6) {
      final grup = liste.sublist(i, (i + 6).clamp(0, liste.length));
      await Future.wait(grup.map((sembol) async {
        final tlFiyat = await hisseFiyatiGetir(sembol, usdTryKuru: usdTry);
        if (tlFiyat > 0) {
          hedef[sembol] = tlFiyat;
        }
      }));
    }
  }

  /// Piyasadaki herhangi bir hisse veya kripto için canlı arama
  Future<List<VarlikTanim>> canliVarlikAra(String sorgu) async {
    final temiz = sorgu.trim();
    if (temiz.length < 2) return [];

    final List<VarlikTanim> sonuclar = [];

    // 1. Yahoo Finance üzerinden BIST & Dünya Hisse Senetleri
    final yahooData = await _getJsonDynamic(
      Uri.https(
        'query1.finance.yahoo.com',
        '/v1/finance/search',
        {'q': temiz, 'quotesCount': '12', 'newsCount': '0'},
      ),
      timeoutSaniye: 4,
    );

    if (yahooData is Map && yahooData['quotes'] is List) {
      for (final q in (yahooData['quotes'] as List)) {
        if (q is! Map) continue;
        final quoteType = (q['quoteType'] ?? '').toString().toUpperCase();
        if (quoteType != 'EQUITY' && quoteType != 'ETF') continue;

        final sym = (q['symbol'] ?? '').toString().toUpperCase();
        if (sym.isEmpty) continue;

        final kisaAd =
            (q['shortname'] ?? q['longname'] ?? sym).toString().trim();
        final tanim = VarlikTanim(
          sembol: sym,
          ad: '$kisaAd ($sym)',
          birim: sym.endsWith('.IS') ? 'Lot' : 'Adet',
          kategori: 'hisse',
        );
        _tanimHaritasi.putIfAbsent(sym, () => tanim);
        sonuclar.add(tanim);
      }
    }

    // 2. CoinGecko üzerinden tüm kripto paralar
    final cgData = await _getJsonDynamic(
      Uri.https(
        'api.coingecko.com',
        '/api/v3/search',
        {'query': temiz},
      ),
      timeoutSaniye: 4,
    );

    if (cgData is Map && cgData['coins'] is List) {
      final coins = (cgData['coins'] as List).take(8).toList();
      final List<String> ids = [];
      final Map<String, String> idToSym = {};

      for (final c in coins) {
        if (c is! Map) continue;
        final id = (c['id'] ?? '').toString();
        final sym = (c['symbol'] ?? '').toString().toUpperCase();
        final name = (c['name'] ?? sym).toString();
        if (id.isEmpty || sym.isEmpty) continue;

        ids.add(id);
        idToSym[id] = sym;
        final tanim = VarlikTanim(
          sembol: sym,
          ad: '$name ($sym)',
          birim: sym,
          kategori: 'kripto',
        );
        _tanimHaritasi.putIfAbsent(sym, () => tanim);
        if (!sonuclar.any((s) => s.sembol == sym)) {
          sonuclar.add(tanim);
        }
      }

      if (ids.isNotEmpty) {
        final fiyatData = await _getJsonDynamic(
          Uri.https(
            'api.coingecko.com',
            '/api/v3/simple/price',
            {'ids': ids.join(','), 'vs_currencies': 'try'},
          ),
          timeoutSaniye: 4,
        );
        if (fiyatData is Map) {
          fiyatData.forEach((id, val) {
            if (val is Map && val['try'] is num) {
              final sym = idToSym[id];
              final tl = (val['try'] as num).toDouble();
              if (sym != null && tl > 0) {
                _canliKurlar[sym] = tl;
              }
            }
          });
        }
      }
    }

    if (sonuclar.isNotEmpty) {
      await _ozelTanimlariKaydet();
      _bildir();
    }

    return sonuclar;
  }

  Future<bool> canliKurlariGuncelle() async {
    if (_yukleniyor) return false;

    _yukleniyor = true;
    _baglantiHatasi = false;
    _bildir();

    try {
      final yeniKurlar = Map<String, double>.from(_canliKurlar);

      final sonuclar = await Future.wait([
        _getJsonDynamic(
          Uri.https(
            'cdn.jsdelivr.net',
            '/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.min.json',
          ),
        ),
        _getJsonDynamic(
          Uri.https(
            'latest.currency-api.pages.dev',
            '/v1/currencies/usd.min.json',
          ),
        ),
        _getJsonDynamic(
          Uri.https(
            'cdn.jsdelivr.net',
            '/npm/@fawazahmed0/currency-api@latest/v1/currencies.min.json',
          ),
        ),
        _getJsonDynamic(
          Uri.https('api.frankfurter.app', '/latest', {
            'from': 'USD',
            'to': 'TRY,EUR,GBP',
          }),
        ),
      ]);

      final jsdelivrData = sonuclar[0];
      final cloudflareData = sonuclar[1];
      final isimSozlugu =
          sonuclar[2] is Map<String, dynamic> ? sonuclar[2] as Map<String, dynamic> : null;
      final frankfurterData = sonuclar[3];

      if (jsdelivrData is Map<String, dynamic>) {
        _fawazVerisiniIsle(jsdelivrData, yeniKurlar, isimSozlugu);
      } else if (cloudflareData is Map<String, dynamic>) {
        _fawazVerisiniIsle(cloudflareData, yeniKurlar, isimSozlugu);
      }

      if (frankfurterData is Map && frankfurterData['rates'] is Map) {
        final rates = frankfurterData['rates'] as Map<String, dynamic>;
        final tryRate = (rates['TRY'] as num?)?.toDouble();
        final eurRate = (rates['EUR'] as num?)?.toDouble();
        final gbpRate = (rates['GBP'] as num?)?.toDouble();

        if (tryRate != null && tryRate > 0) {
          yeniKurlar['USD'] = tryRate;
          if (eurRate != null && eurRate > 0) {
            yeniKurlar['EUR'] = tryRate / eurRate;
          }
          if (gbpRate != null && gbpRate > 0) {
            yeniKurlar['GBP'] = tryRate / gbpRate;
          }
        }
      }

      await _seciliHisseleriGuncelle(yeniKurlar);

      final basariliMi = (yeniKurlar['USD'] ?? 0) > 0 &&
          (jsdelivrData != null ||
              cloudflareData != null ||
              frankfurterData != null);

      if (basariliMi) {
        final simdi = DateTime.now();
        final saatStr =
            '${simdi.hour.toString().padLeft(2, '0')}:${simdi.minute.toString().padLeft(2, '0')}';

        _canliKurlar = yeniKurlar;
        _sonGuncelleme = 'varlik_canli_saat'.trParams({'saat': saatStr});
        _baglantiHatasi = false;

        await _kurlariOnbellegeKaydet(yeniKurlar, saatStr);
        await _ozelTanimlariKaydet();

        // Kuru 0 olarak eklenmiş bekleyen kalem varsa maliyetini canlı kurdan tamamla
        bool guncellendi = false;
        for (int i = 0; i < _varliklar.length; i++) {
          final v = _varliklar[i];
          final kur = _canliKurlar[v.sembol] ?? 0.0;
          if (v.alisFiyatiTl <= 0 && kur > 0) {
            _varliklar[i] = VarlikKalemi(
              id: v.id,
              sembol: v.sembol,
              miktar: v.miktar,
              alisFiyatiTl: kur,
            );
            guncellendi = true;
          }
        }
        if (guncellendi) {
          await _varliklariKaydet();
        }
      } else {
        _baglantiHatasi = true;
        _sonGuncelleme = (_canliKurlar['USD'] ?? 0) > 0
            ? 'varlik_onbellek_baglanti_yok'.tr
            : 'varlik_internet_yok'.tr;
      }

      return basariliMi;
    } finally {
      _yukleniyor = false;
      _bildir();
    }
  }

  void varlikEkle({
    required String sembol,
    required double miktar,
    double? alisFiyatiTl,
  }) {
    if (miktar <= 0) return;
    final kod = sembol.trim().toUpperCase();
    final guncelKur = _canliKurlar[kod] ?? 0.0;
    final kullanilanAlis =
        (alisFiyatiTl != null && alisFiyatiTl > 0) ? alisFiyatiTl : guncelKur;

    final mevcutIndex = _varliklar.indexWhere((e) => e.sembol == kod);
    if (mevcutIndex != -1) {
      final eski = _varliklar[mevcutIndex];
      final yeniToplamMiktar = eski.miktar + miktar;
      final yeniOrtalamaAlis = kullanilanAlis > 0
          ? ((eski.miktar * eski.alisFiyatiTl) + (miktar * kullanilanAlis)) /
              yeniToplamMiktar
          : eski.alisFiyatiTl;

      _varliklar[mevcutIndex] = VarlikKalemi(
        id: eski.id,
        sembol: eski.sembol,
        miktar: yeniToplamMiktar,
        alisFiyatiTl: yeniOrtalamaAlis,
      );
    } else {
      _varliklar.add(
        VarlikKalemi(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sembol: kod,
          miktar: miktar,
          alisFiyatiTl: kullanilanAlis,
        ),
      );
    }

    _varliklariKaydet();
    _bildir();

    // Kuru henüz hafızada yoksa arka planda canlı kuru çekip maliyeti otomatik yaz
    if (kullanilanAlis <= 0) {
      _tekSembolKurTamamla(kod);
    }
  }

  Future<void> _tekSembolKurTamamla(String kod) async {
    double kur = 0.0;
    if (kod.endsWith('.IS') || tanimGetir(kod).kategori == 'hisse') {
      kur = await hisseFiyatiGetir(kod);
    }
    if (kur <= 0) {
      await canliKurlariGuncelle();
      kur = _canliKurlar[kod] ?? 0.0;
    }
    if (kur > 0) {
      _canliKurlar[kod] = kur;
      for (int i = 0; i < _varliklar.length; i++) {
        if (_varliklar[i].sembol == kod && _varliklar[i].alisFiyatiTl <= 0) {
          _varliklar[i] = VarlikKalemi(
            id: _varliklar[i].id,
            sembol: kod,
            miktar: _varliklar[i].miktar,
            alisFiyatiTl: kur,
          );
        }
      }
      await _varliklariKaydet();
      _bildir();
    }
  }

  double varlikAzalt({
    required String sembol,
    required double miktar,
  }) {
    if (miktar <= 0) return 0.0;
    final kod = sembol.trim().toUpperCase();
    final idx = _varliklar.indexWhere((e) => e.sembol == kod);
    if (idx == -1) return 0.0;

    final eski = _varliklar[idx];
    final dusulen = miktar >= eski.miktar ? eski.miktar : miktar;
    final kalan = eski.miktar - dusulen;

    if (kalan <= 0.000001) {
      _varliklar.removeAt(idx);
    } else {
      _varliklar[idx] = VarlikKalemi(
        id: eski.id,
        sembol: eski.sembol,
        miktar: kalan,
        alisFiyatiTl: eski.alisFiyatiTl,
      );
    }

    _varliklariKaydet();
    _bildir();
    return dusulen;
  }

  void varlikSil(int index) {
    if (index < 0 || index >= _varliklar.length) return;
    _varliklar.removeAt(index);
    _varliklariKaydet();
    _bildir();
  }
}