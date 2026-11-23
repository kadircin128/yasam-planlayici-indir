import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/finans_item.dart';
import '../services/dil_servisi.dart';
import '../widgets/varlik_kasasi_sheet.dart';
import '../widgets/sayfa_kilavuzu.dart';
import '../theme/app_renkler.dart';

class _KumbaraHedef {
  final String id;
  final String baslik;
  final String ikon;
  final double hedefTutar;
  final double birikenTutar;

  _KumbaraHedef({
    required this.id,
    required this.baslik,
    required this.ikon,
    required this.hedefTutar,
    required this.birikenTutar,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'baslik': baslik,
        'ikon': ikon,
        'hedefTutar': hedefTutar,
        'birikenTutar': birikenTutar,
      };

  factory _KumbaraHedef.fromJson(Map<String, dynamic> json) => _KumbaraHedef(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        baslik: json['baslik'] ?? '',
        ikon: json['ikon'] ?? '🎯',
        hedefTutar: (json['hedefTutar'] as num?)?.toDouble() ?? 0.0,
        birikenTutar: (json['birikenTutar'] as num?)?.toDouble() ?? 0.0,
      );
}

class _PastaDilimi {
  final String etiket;
  final double tutar;
  final Color renk;

  const _PastaDilimi({
    required this.etiket,
    required this.tutar,
    required this.renk,
  });
}

class _PastaGrafikPainter extends CustomPainter {
  final List<_PastaDilimi> dilimler;
  final Color ayiriciRenk;
  final Color bosRenk;

  _PastaGrafikPainter({
    required this.dilimler,
    required this.ayiriciRenk,
    required this.bosRenk,
  });

  Color _tonAyarla(Color renk, double miktar) {
    final hsl = HSLColor.fromColor(renk);
    final yeniIsik = (hsl.lightness + miktar).clamp(0.0, 1.0);
    return hsl.withLightness(yeniIsik).toColor();
  }

  void _cizKlasik3DDilim({
    required Canvas canvas,
    required Rect ustOval,
    required Rect altOval,
    required double startAngle,
    required double sweepAngle,
    required Color baseColor,
    required Color separatorColor,
    required bool drawSeparators,
  }) {
    final ustMerkez = ustOval.center;
    final altMerkez = altOval.center;
    final rx = ustOval.width / 2;
    final ry = ustOval.height / 2;

    Offset ustNokta(double aci) => Offset(
          ustMerkez.dx + rx * cos(aci),
          ustMerkez.dy + ry * sin(aci),
        );

    Offset altNokta(double aci) => Offset(
          altMerkez.dx + rx * cos(aci),
          altMerkez.dy + ry * sin(aci),
        );

    final endAngle = startAngle + sweepAngle;
    final yanDuvarKoyu = _tonAyarla(baseColor, -0.22);
    final yanDuvarOrta = _tonAyarla(baseColor, -0.09);

    // 1. İç yarıçap kesit duvarları (dilim yan yüzeyleri)
    final pUstStart = ustNokta(startAngle);
    final pAltStart = altNokta(startAngle);
    final kesit1 = Path()
      ..moveTo(ustMerkez.dx, ustMerkez.dy)
      ..lineTo(pUstStart.dx, pUstStart.dy)
      ..lineTo(pAltStart.dx, pAltStart.dy)
      ..lineTo(altMerkez.dx, altMerkez.dy)
      ..close();
    canvas.drawPath(
      kesit1,
      Paint()
        ..color = _tonAyarla(baseColor, -0.15)
        ..style = PaintingStyle.fill,
    );

    final pUstEnd = ustNokta(endAngle);
    final pAltEnd = altNokta(endAngle);
    final kesit2 = Path()
      ..moveTo(ustMerkez.dx, ustMerkez.dy)
      ..lineTo(pUstEnd.dx, pUstEnd.dy)
      ..lineTo(pAltEnd.dx, pAltEnd.dy)
      ..lineTo(altMerkez.dx, altMerkez.dy)
      ..close();
    canvas.drawPath(
      kesit2,
      Paint()
        ..color = _tonAyarla(baseColor, -0.19)
        ..style = PaintingStyle.fill,
    );

    // 2. Dış kavisli silindir duvarı (ön tarafa bakan 3D derinlik yüzeyi)
    final adimSayisi = max(20, (sweepAngle / (pi / 45)).ceil());
    final dAci = sweepAngle / adimSayisi;

    for (int i = 0; i < adimSayisi; i++) {
      final a1 = startAngle + i * dAci;
      final a2 = a1 + dAci;
      final ortaAci = (a1 + a2) / 2;

      if (sin(ortaAci) < -0.05) continue;

      final u1 = ustNokta(a1);
      final u2 = ustNokta(a2);
      final b1 = altNokta(a1);
      final b2 = altNokta(a2);

      final isikFaktoru = ((cos(ortaAci - pi * 0.35) + 1) / 2).clamp(0.0, 1.0);
      final seritRenk =
          Color.lerp(yanDuvarKoyu, yanDuvarOrta, isikFaktoru) ?? yanDuvarKoyu;

      final duvarSeridi = Path()
        ..moveTo(u1.dx, u1.dy)
        ..lineTo(u2.dx, u2.dy)
        ..lineTo(b2.dx, b2.dy)
        ..lineTo(b1.dx, b1.dy)
        ..close();

      canvas.drawPath(
        duvarSeridi,
        Paint()
          ..color = seritRenk
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        duvarSeridi,
        Paint()
          ..color = seritRenk
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6,
      );
    }

    // 3. Dolu üst pasta dilimi yüzeyi (doğal ışık-gölge geçişli)
    final ustYuzey = Path()
      ..moveTo(ustMerkez.dx, ustMerkez.dy)
      ..arcTo(ustOval, startAngle, sweepAngle, false)
      ..close();

    final ustBoya = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          _tonAyarla(baseColor, 0.11),
          baseColor,
          _tonAyarla(baseColor, -0.06),
        ],
      ).createShader(ustOval)
      ..style = PaintingStyle.fill;

    canvas.drawPath(ustYuzey, ustBoya);

    // 4. Dilim ayırıcı çizgiler (üst yüzey + ön yan duvar dikey ek yeri)
    if (drawSeparators) {
      final ayiriciBoya = Paint()
        ..color = separatorColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(ustYuzey, ayiriciBoya);

      if (sin(startAngle) > 0.02) {
        canvas.drawLine(
          pUstStart,
          pAltStart,
          Paint()
            ..color = separatorColor.withAlpha(190)
            ..strokeWidth = 1.4,
        );
      }
      if (sin(endAngle) > 0.02) {
        canvas.drawLine(
          pUstEnd,
          pAltEnd,
          Paint()
            ..color = separatorColor.withAlpha(190)
            ..strokeWidth = 1.4,
        );
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final derinlik = (size.height * 0.16).clamp(18.0, 28.0);
    final yatayYaricap = (size.width * 0.46).clamp(52.0, size.width / 2);
    final dikeyYaricap = ((size.height - derinlik) * 0.38)
        .clamp(34.0, (size.height - derinlik) / 2);

    final ustMerkez = Offset(size.width / 2, (size.height - derinlik) / 2 + 1);
    final altMerkez = Offset(ustMerkez.dx, ustMerkez.dy + derinlik);

    final ustOval = Rect.fromCenter(
      center: ustMerkez,
      width: yatayYaricap * 2,
      height: dikeyYaricap * 2,
    );
    final altOval = Rect.fromCenter(
      center: altMerkez,
      width: yatayYaricap * 2,
      height: dikeyYaricap * 2,
    );

    // Zemin 3D gölgesi
    final golgeOval = Rect.fromCenter(
      center: Offset(altMerkez.dx, altMerkez.dy + 4),
      width: yatayYaricap * 2.02,
      height: dikeyYaricap * 2.0,
    );
    canvas.drawOval(
      golgeOval,
      Paint()
        ..color = Colors.black.withAlpha(65)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );

    final toplam =
        dilimler.fold<double>(0.0, (sum, d) => sum + max(0.0, d.tutar));

    if (toplam <= 0) {
      _cizKlasik3DDilim(
        canvas: canvas,
        ustOval: ustOval,
        altOval: altOval,
        startAngle: 0,
        sweepAngle: 2 * pi - 0.0001,
        baseColor: bosRenk,
        separatorColor: ayiriciRenk,
        drawSeparators: false,
      );
      canvas.drawOval(
        ustOval,
        Paint()
          ..color = ayiriciRenk
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
      return;
    }

    final aktifDilimler = dilimler.where((d) => d.tutar > 0).toList();
    final cokluDilim = aktifDilimler.length > 1;

    final List<({double start, double sweep, _PastaDilimi dilim})> parcalar = [];
    double baslangicAci = -pi / 2;

    for (final dilim in aktifDilimler) {
      final hamTarama = (dilim.tutar / toplam) * 2 * pi;
      final tarama = cokluDilim ? hamTarama : (2 * pi - 0.0001);
      parcalar.add((
        start: baslangicAci,
        sweep: tarama,
        dilim: dilim,
      ));
      baslangicAci += hamTarama;
    }

    // 3D derinlik sıralaması: arka dilimler önce, ön dilimler sonra çizilir
    parcalar.sort((a, b) {
      final ortaA = a.start + a.sweep / 2;
      final ortaB = b.start + b.sweep / 2;
      return sin(ortaA).compareTo(sin(ortaB));
    });

    for (final p in parcalar) {
      _cizKlasik3DDilim(
        canvas: canvas,
        ustOval: ustOval,
        altOval: altOval,
        startAngle: p.start,
        sweepAngle: p.sweep,
        baseColor: p.dilim.renk,
        separatorColor: ayiriciRenk,
        drawSeparators: cokluDilim,
      );
    }

    // Üst dış elips çerçevesi
    canvas.drawOval(
      ustOval,
      Paint()
        ..color = ayiriciRenk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
  }

  @override
  bool shouldRepaint(covariant _PastaGrafikPainter oldDelegate) {
    return oldDelegate.dilimler != dilimler ||
        oldDelegate.ayiriciRenk != ayiriciRenk ||
        oldDelegate.bosRenk != bosRenk;
  }
}

/// Gün Sonu ekranındaki sohbetten gelen mesajlarla kredi kartı limitini güncelleyen yardımcı sınıf.
class KrediKartiChatYardimcisi {
  static String _turkceKucult(String metin) {
    return metin
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .replaceAll('Ş', 'ş')
        .replaceAll('Ğ', 'ğ')
        .replaceAll('Ü', 'ü')
        .replaceAll('Ö', 'ö')
        .replaceAll('Ç', 'ç')
        .toLowerCase();
  }

  static String? mesajdanKartGuncelle({
    required String mesaj,
    required List<FinansItem> islemler,
    required Function(int, FinansItem) onIslemDuzenle,
  }) {
    final dil = DilServisi.instance;
    final temizMesaj = _turkceKucult(mesaj.trim());
    if (temizMesaj.isEmpty) return null;

    int eslesenIndex = -1;
    FinansItem? eslesenKart;

    const genelKelimeler = {
      'kart',
      'kartı',
      'kartım',
      'kredi',
      'banka',
      'hesap',
      'limit',
      'limitim',
      'limiti',
    };

    for (int i = 0; i < islemler.length; i++) {
      final item = islemler[i];
      if (item.tur != 'Kredi Kartı') continue;

      final kartAdi = _turkceKucult(item.baslik.trim());
      if (kartAdi.isEmpty) continue;

      if (temizMesaj.contains(kartAdi)) {
        eslesenIndex = i;
        eslesenKart = item;
        break;
      }

      final kelimeler = kartAdi
          .split(RegExp(r'[\s\-_]+'))
          .where((k) => k.length >= 3 && !genelKelimeler.contains(k));

      for (final k in kelimeler) {
        if (temizMesaj.contains(k)) {
          eslesenIndex = i;
          eslesenKart = item;
          break;
        }
      }
      if (eslesenKart != null) break;
    }

    if (eslesenKart == null || eslesenIndex == -1) return null;

    RegExpMatch? match = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(?:(?:tl|lira)\b|₺)',
      caseSensitive: false,
    ).firstMatch(temizMesaj);

    match ??= RegExp(
      r'(?:limit\w*|kalan\w*)\s*(\d+(?:[.,]\d+)?)|(\d+(?:[.,]\d+)?)\s*(?:kaldı|kaldi|kalan)',
      caseSensitive: false,
    ).firstMatch(temizMesaj);

    if (match == null) return null;

    String? rawSayi =
        match.group(1) ?? (match.groupCount >= 2 ? match.group(2) : null);
    if (rawSayi == null) return null;

    if (RegExp(r'^\d{1,3}\.\d{3}$').hasMatch(rawSayi)) {
      rawSayi = rawSayi.replaceAll('.', '');
    } else {
      rawSayi = rawSayi.replaceAll(',', '.');
    }

    final tutar = double.tryParse(rawSayi);
    if (tutar == null || tutar < 0) return null;

    final toplamLimit = eslesenKart.kartLimiti ?? 0.0;
    final double mevcutKullanilan =
        eslesenKart.odendi ? 0.0 : eslesenKart.kalanMiktar;

    final kalanLimitBildirimiMi = (temizMesaj.contains('kaldı') ||
            temizMesaj.contains('kaldi') ||
            temizMesaj.contains('kalan limit') ||
            temizMesaj.contains('kalanı') ||
            temizMesaj.contains('kalani')) &&
        (temizMesaj.contains('limit') || temizMesaj.contains('kart'));

    if (kalanLimitBildirimiMi) {
      if (toplamLimit <= 0) {
        return dil.cevir(
          'chat_kart_limit_tanimli_degil',
          {'kart': eslesenKart.baslik},
        );
      }

      final double yeniKullanilan =
          (toplamLimit - tutar).clamp(0.0, toplamLimit);
      final double guncelKalan = max(0.0, toplamLimit - yeniKullanilan);

      final guncelKart = FinansItem(
        id: eslesenKart.id,
        baslik: eslesenKart.baslik,
        miktar: yeniKullanilan,
        tur: eslesenKart.tur,
        tarih: eslesenKart.tarih,
        yineleme: eslesenKart.yineleme,
        iptalTarihler: eslesenKart.iptalTarihler,
        odendi: yeniKullanilan <= 0,
        odenenMiktar: 0.0,
        hesapKesimGunu: eslesenKart.hesapKesimGunu,
        sonOdemeGunu: eslesenKart.sonOdemeGunu,
        ekstreGirildi: eslesenKart.ekstreGirildi,
        isDegiskenFatura: eslesenKart.isDegiskenFatura,
        otomatikOdemede: eslesenKart.otomatikOdemede,
        gecenAykiTutar: eslesenKart.gecenAykiTutar,
        kartLimiti: eslesenKart.kartLimiti,
      );

      onIslemDuzenle(eslesenIndex, guncelKart);

      return dil.cevir(
        'chat_kart_kalan_guncellendi',
        {
          'kart': eslesenKart.baslik,
          'kalan': guncelKalan.toStringAsFixed(0),
          'kullanilan': yeniKullanilan.toStringAsFixed(0),
        },
      );
    }

    if (tutar <= 0) return null;

    final odemeMi = (temizMesaj.contains('borç öde') ||
            temizMesaj.contains('borc ode') ||
            temizMesaj.contains('kartıma yatır') ||
            temizMesaj.contains('kartima yatir') ||
            temizMesaj.contains('kartıma öde') ||
            temizMesaj.contains('kartima ode') ||
            temizMesaj.contains('ekstre öde') ||
            temizMesaj.contains('ekstre ode') ||
            temizMesaj.contains('iade')) &&
        !temizMesaj.contains('kartımdan') &&
        !temizMesaj.contains('kartimdan') &&
        !temizMesaj.contains('kartımla') &&
        !temizMesaj.contains('kartimla');

    final double yeniKullanilan = odemeMi
        ? max(0.0, mevcutKullanilan - tutar)
        : (mevcutKullanilan + tutar);

    final guncelKart = FinansItem(
      id: eslesenKart.id,
      baslik: eslesenKart.baslik,
      miktar: yeniKullanilan,
      tur: eslesenKart.tur,
      tarih: eslesenKart.tarih,
      yineleme: eslesenKart.yineleme,
      iptalTarihler: eslesenKart.iptalTarihler,
      odendi: yeniKullanilan <= 0,
      odenenMiktar: 0.0,
      hesapKesimGunu: eslesenKart.hesapKesimGunu,
      sonOdemeGunu: eslesenKart.sonOdemeGunu,
      ekstreGirildi: eslesenKart.ekstreGirildi,
      isDegiskenFatura: eslesenKart.isDegiskenFatura,
      otomatikOdemede: eslesenKart.otomatikOdemede,
      gecenAykiTutar: eslesenKart.gecenAykiTutar,
      kartLimiti: eslesenKart.kartLimiti,
    );

    onIslemDuzenle(eslesenIndex, guncelKart);

    final kalanLimit = max(0.0, toplamLimit - yeniKullanilan);

    if (toplamLimit > 0) {
      return dil.cevir(
        'chat_kart_islem_guncellendi',
        {
          'kart': eslesenKart.baslik,
          'isaret': odemeMi ? '-' : '+',
          'tutar': tutar.toStringAsFixed(0),
          'kalan': kalanLimit.toStringAsFixed(0),
        },
      );
    }
    return dil.cevir(
      'chat_kart_borc_guncellendi',
      {
        'kart': eslesenKart.baslik,
        'borc': yeniKullanilan.toStringAsFixed(0),
      },
    );
  }
}

class FinansEkrani extends StatefulWidget {
  final List<FinansItem> islemler;
  final Function(FinansItem) onIslemEkle;
  final Function(int, FinansItem) onIslemDuzenle;
  final Function(int) onIslemSil;

  const FinansEkrani({
    super.key,
    required this.islemler,
    required this.onIslemEkle,
    required this.onIslemDuzenle,
    required this.onIslemSil,
  });

  @override
  State<FinansEkrani> createState() => _FinansEkraniState();
}

class _FinansEkraniState extends State<FinansEkrani> {
  int _secilenAltSekme = 0; // 0: Hareketler, 1: Analiz, 2: Kumbara

  final GlobalKey _keyVarlikKasasi = GlobalKey();
  final GlobalKey _keyEkleButonu = GlobalKey();
  final GlobalKey _keyAltSekmeler = GlobalKey();
  final GlobalKey _keyBakiyeTarihi = GlobalKey();
  final GlobalKey _keyNetBakiye = GlobalKey();

  final TextEditingController _baslikController = TextEditingController();
  final TextEditingController _miktarController = TextEditingController();
  final TextEditingController _gecenAykiTutarController =
      TextEditingController();
  final TextEditingController _hesapKesimController = TextEditingController();
  final TextEditingController _sonOdemeController = TextEditingController();
  final TextEditingController _kartLimitiController = TextEditingController();
  final TextEditingController _kartGuncelBorcController =
      TextEditingController();

  String _secilenTur = 'Fatura';
  String _secilenYineleme = 'Her ay (Aynı gün)';
  bool _isDegiskenFatura = false;
  bool _otomatikOdemede = false;
  DateTime _secilenTarih = DateTime.now();
  DateTime _bakiyeHesapTarihi = DateTime.now();

  List<_KumbaraHedef> _hedefler = [];

  final List<String> _yinelemeSecenekleri = [
    'Tek seferlik',
    'Her gün',
    'Hafta içi',
    'Hafta sonu',
    'Haftada bir',
    'Her ay (Aynı gün)',
    'Her ayın 15\'i (Maaş günü)',
    'Her ayın 1\'i',
    'Her ayın son günü',
    'Yılda bir',
  ];

  final Map<int, String> _gunKisaAdlar = {
    1: 'Pzt',
    2: 'Sal',
    3: 'Çrş',
    4: 'Pş',
    5: 'Cu',
    6: 'Ct',
    7: 'Pz',
  };

  List<KilavuzAdimi> _kilavuzAdimlari() => [
        KilavuzAdimi(
          key: _keyBakiyeTarihi,
          ikon: Icons.date_range_rounded,
          baslik: 'kilavuz_bakiye_tarih_baslik'.tr,
          aciklama: 'kilavuz_bakiye_tarih_aciklama'.tr,
        ),
        KilavuzAdimi(
          key: _keyNetBakiye,
          ikon: Icons.account_balance_wallet_rounded,
          baslik: 'kilavuz_net_bakiye_baslik'.tr,
          aciklama: 'kilavuz_net_bakiye_aciklama'.tr,
        ),
        KilavuzAdimi(
          key: _keyEkleButonu,
          ikon: Icons.add_circle_outline_rounded,
          baslik: 'kilavuz_ekle_baslik'.tr,
          aciklama: 'kilavuz_ekle_aciklama'.tr,
        ),
        KilavuzAdimi(
          key: _keyAltSekmeler,
          ikon: Icons.tab_rounded,
          baslik: 'kilavuz_sekmeler_baslik'.tr,
          aciklama: 'kilavuz_sekmeler_aciklama'.tr,
        ),
        KilavuzAdimi(
          key: _keyVarlikKasasi,
          ikon: Icons.currency_exchange_rounded,
          baslik: 'kilavuz_varlik_baslik'.tr,
          aciklama: 'kilavuz_varlik_aciklama'.tr,
        ),
      ];

  void _kilavuzuBaslat() {
    if (_secilenAltSekme != 0) {
      setState(() => _secilenAltSekme = 0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        SayfaKilavuzu.goster(
          context: context,
          sayfaId: 'finans',
          adimlar: _kilavuzAdimlari(),
        );
      });
    } else {
      SayfaKilavuzu.goster(
        context: context,
        sayfaId: 'finans',
        adimlar: _kilavuzAdimlari(),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _hedefleriYukle();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SayfaKilavuzu.ilkGirisKontrolEt(
        context: context,
        sayfaId: 'finans',
        adimlar: _kilavuzAdimlari(),
      );
    });
  }

  @override
  void dispose() {
    _baslikController.dispose();
    _miktarController.dispose();
    _gecenAykiTutarController.dispose();
    _hesapKesimController.dispose();
    _sonOdemeController.dispose();
    _kartLimitiController.dispose();
    _kartGuncelBorcController.dispose();
    super.dispose();
  }

  Future<void> _hedefleriYukle() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('kumbara_hedefleri_v1');
    if (raw != null && mounted) {
      final List<dynamic> decoded = jsonDecode(raw);
      setState(() {
        _hedefler = decoded.map((e) => _KumbaraHedef.fromJson(e)).toList();
      });
    }
  }

  Future<void> _hedefleriKaydet() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_hedefler.map((e) => e.toJson()).toList());
    await prefs.setString('kumbara_hedefleri_v1', encoded);
  }

  bool _tarihlerAyniMi(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  DateTime _kartSonOdemeTarihiBul(FinansItem f) {
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

  bool _islemGunuMu(FinansItem f, DateTime hedefTarih) {
    final fTarih = DateTime(f.tarih.year, f.tarih.month, f.tarih.day);
    final hedef = DateTime(hedefTarih.year, hedefTarih.month, hedefTarih.day);

    if (hedef.isBefore(fTarih)) return false;
    if (f.oGunIptalMi(hedef)) return false;

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

  int _tekrarSayisiHesapla(FinansItem f, DateTime hedefTarih) {
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

  double _itemBakiyeEtkisi(FinansItem f, DateTime hedefTarih) {
    final sadeceHedef =
        DateTime(hedefTarih.year, hedefTarih.month, hedefTarih.day);

    if (f.tur == 'Kredi Kartı') {
      final odemeYapildiMi = f.odendi || f.odenenMiktar > 0;
      final sonOdemeTarihi = _kartSonOdemeTarihiBul(f);

      if (odemeYapildiMi) {
        final odemeGunu = DateTime(f.tarih.year, f.tarih.month, f.tarih.day);
        if (sadeceHedef.isBefore(odemeGunu)) return 0.0;

        final odenenTutar = f.odenenMiktar > 0 ? f.odenenMiktar : f.miktar;
        if (!f.odendi &&
            odenenTutar < f.tahminiOdeme &&
            !sadeceHedef.isBefore(sonOdemeTarihi)) {
          return f.tahminiOdeme;
        }
        return odenenTutar;
      } else {
        if (sadeceHedef.isBefore(sonOdemeTarihi)) return 0.0;
        return f.tahminiOdeme;
      }
    }

    final tekrar = _tekrarSayisiHesapla(f, sadeceHedef);
    if (tekrar == 0) return 0.0;

    final isPozitif = f.tur == 'Gelir' || f.tur == 'Alacak';
    return isPozitif ? (f.miktar * tekrar) : (f.tahminiOdeme * tekrar);
  }

  double _hesaplaBakiye(DateTime hedefTarih) {
    double bakiye = 0;

    for (var f in widget.islemler) {
      final etki = _itemBakiyeEtkisi(f, hedefTarih);
      if (etki == 0) continue;

      final isPozitif = f.tur == 'Gelir' || f.tur == 'Alacak';
      if (isPozitif) {
        bakiye += etki;
      } else {
        bakiye -= etki;
      }
    }
    return bakiye;
  }

  void _krediKartiFormDialog({int? duzenlenecekIndex, FinansItem? mevcutKart}) {
    final r = AppRenkler.of(context);
    final duzenlemeModu = mevcutKart != null && duzenlenecekIndex != null;

    _baslikController.text = duzenlemeModu ? mevcutKart.baslik : '';
    _hesapKesimController.text =
        duzenlemeModu && mevcutKart.hesapKesimGunu != null
            ? mevcutKart.hesapKesimGunu.toString()
            : '';
    _sonOdemeController.text =
        duzenlemeModu && mevcutKart.sonOdemeGunu != null
            ? mevcutKart.sonOdemeGunu.toString()
            : '';
    _kartLimitiController.text =
        duzenlemeModu && mevcutKart.kartLimiti != null
            ? mevcutKart.kartLimiti!.toStringAsFixed(0)
            : '';
    final double baslangicBorc = duzenlemeModu
        ? (mevcutKart.odendi ? 0.0 : mevcutKart.kalanMiktar)
        : 0.0;
    _kartGuncelBorcController.text =
        baslangicBorc > 0 ? baslangicBorc.toStringAsFixed(0) : '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: r.dialog,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: r.kenarlik, width: 1.2),
          ),
          title: Row(
            children: [
              Icon(Icons.credit_card_rounded, color: r.mavi, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  duzenlemeModu
                      ? 'kredi_karti_duzenle'.tr
                      : 'yeni_kredi_karti'.tr,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _baslikController,
                    autofocus: !duzenlemeModu,
                    decoration: InputDecoration(
                      labelText: 'karta_isim_verme'.tr,
                      hintText: 'karta_isim_hint'.tr,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _hesapKesimController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'ekstre_kesim_tarihi'.tr,
                      hintText: '15',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sonOdemeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'son_odeme_tarihi'.tr,
                      hintText: '25',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _kartLimitiController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'toplam_limit'.tr,
                      hintText: '25000',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _kartGuncelBorcController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'guncel_borc_varsa'.tr,
                      hintText: 'guncel_borc_hint'.tr,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('iptal'.tr, style: TextStyle(color: r.altMetin)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                final kartAdi = _baslikController.text.trim();
                final kesimGunu =
                    int.tryParse(_hesapKesimController.text.trim());
                final sonOdemeGunu =
                    int.tryParse(_sonOdemeController.text.trim());
                final toplamLimit = double.tryParse(
                      _kartLimitiController.text.trim().replaceAll(',', '.'),
                    ) ??
                    0.0;
                final guncelBorc = double.tryParse(
                      _kartGuncelBorcController.text
                          .trim()
                          .replaceAll(',', '.'),
                    ) ??
                    0.0;

                if (kartAdi.isEmpty || toplamLimit <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('kart_gecerli_limit_uyari'.tr),
                    ),
                  );
                  return;
                }

                final yeniKart = FinansItem(
                  id: duzenlemeModu
                      ? mevcutKart.id
                      : DateTime.now().millisecondsSinceEpoch.toString(),
                  baslik: kartAdi,
                  miktar: guncelBorc,
                  tur: 'Kredi Kartı',
                  tarih: duzenlemeModu ? mevcutKart.tarih : DateTime.now(),
                  yineleme: 'Her ay (Aynı gün)',
                  iptalTarihler:
                      duzenlemeModu ? mevcutKart.iptalTarihler : const [],
                  odendi: false,
                  odenenMiktar: 0.0,
                  hesapKesimGunu: kesimGunu,
                  sonOdemeGunu: sonOdemeGunu,
                  kartLimiti: toplamLimit,
                  ekstreGirildi:
                      duzenlemeModu ? mevcutKart.ekstreGirildi : false,
                );

                if (duzenlemeModu) {
                  widget.onIslemDuzenle(duzenlenecekIndex, yeniKart);
                } else {
                  widget.onIslemEkle(yeniKart);
                }

                _baslikController.clear();
                _hesapKesimController.clear();
                _sonOdemeController.clear();
                _kartLimitiController.clear();
                _kartGuncelBorcController.clear();
                Navigator.pop(context);
              },
              child: Text(
                duzenlemeModu ? 'guncelle'.tr : 'karti_kaydet'.tr,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _kalanLimitGuncelleDialog(int index, FinansItem kart) {
    final r = AppRenkler.of(context);
    final toplamLimit = kart.kartLimiti ?? 0.0;
    final mevcutKullanilan = kart.odendi ? 0.0 : kart.kalanMiktar;
    final mevcutKalan = max(0.0, toplamLimit - mevcutKullanilan);

    final kalanLimitController = TextEditingController(
      text: mevcutKalan.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final girilenKalan = double.tryParse(
                  kalanLimitController.text.trim().replaceAll(',', '.'),
                ) ??
                mevcutKalan;
            final hesaplananBorc =
                (toplamLimit - girilenKalan).clamp(0.0, toplamLimit);
            final yuzde = toplamLimit > 0
                ? ((hesaplananBorc / toplamLimit) * 100).round()
                : 0;

            return AlertDialog(
              backgroundColor: r.dialog,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text('limit_guncelle_baslik'.trParams({'kart': kart.baslik})),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'toplam_limit_bilgi'.trParams(
                        {'tutar': toplamLimit.toStringAsFixed(0)}),
                    style: TextStyle(fontSize: 13, color: r.altMetin),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: kalanLimitController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: 'guncel_kalan_limit'.tr,
                      hintText: '3400',
                      prefixIcon: Icon(Icons.account_balance_wallet_rounded,
                          color: r.mavi),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: r.ikincilKart,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'yeni_kullanilan_limit'.trParams({
                        'tutar': hesaplananBorc.toStringAsFixed(0),
                        'yuzde': yuzde.toString(),
                      }),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: yuzde > 75 ? r.turuncu : r.mavi,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 4,
                    children: [
                      if (!kart.odendi && kart.kalanMiktar > 0)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _odemeYapDialog(index, kart);
                          },
                          icon: Icon(Icons.payments_rounded,
                              size: 16, color: r.yesil),
                          label: Text(
                            'borc_ode_secenek'.tr,
                            style: TextStyle(
                                fontSize: 11.5,
                                color: r.yesil,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _krediKartiFormDialog(
                            duzenlenecekIndex: index,
                            mevcutKart: kart,
                          );
                        },
                        icon: Icon(Icons.settings_rounded,
                            size: 16, color: r.morAcik),
                        label: Text(
                          'karti_duzenle'.tr,
                          style: TextStyle(fontSize: 11.5, color: r.morAcik),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('iptal'.tr, style: TextStyle(color: r.altMetin)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent),
                  onPressed: () {
                    final temiz =
                        kalanLimitController.text.trim().replaceAll(',', '.');
                    final yeniKalan = double.tryParse(temiz);
                    if (yeniKalan != null && yeniKalan >= 0) {
                      final yeniKullanilan =
                          (toplamLimit - yeniKalan).clamp(0.0, toplamLimit);
                      final guncel = FinansItem(
                        id: kart.id,
                        baslik: kart.baslik,
                        miktar: yeniKullanilan,
                        tur: kart.tur,
                        tarih: kart.tarih,
                        yineleme: kart.yineleme,
                        iptalTarihler: kart.iptalTarihler,
                        odendi: yeniKullanilan <= 0,
                        odenenMiktar: 0.0,
                        hesapKesimGunu: kart.hesapKesimGunu,
                        sonOdemeGunu: kart.sonOdemeGunu,
                        ekstreGirildi: kart.ekstreGirildi,
                        kartLimiti: kart.kartLimiti,
                      );
                      widget.onIslemDuzenle(index, guncel);
                      Navigator.pop(context);
                    }
                  },
                  child: Text('kaydet'.tr,
                      style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _ekstreTutarGirDialog(int index, FinansItem item) {
    final r = AppRenkler.of(context);
    final double mevcutKullanim = item.odendi ? 0.0 : item.kalanMiktar;
    final TextEditingController ekstreController = TextEditingController(
      text: mevcutKullanim > 0 ? mevcutKullanim.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: r.dialog,
          title: Text('ekstre_tutari_baslik'.trParams({'kart': item.baslik})),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (mevcutKullanim > 0) ...[
                Text(
                  'ekstre_mevcut_kullanim_bilgi'
                      .trParams({'tutar': mevcutKullanim.toStringAsFixed(0)}),
                  style: TextStyle(fontSize: 12, color: r.altMetin),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: ekstreController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'gelen_ekstre_borcu'.tr,
                  hintText: '4500',
                  prefixIcon: Icon(Icons.receipt_long_rounded, color: r.mavi),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('iptal'.tr, style: TextStyle(color: r.altMetin)),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: () {
                final temiz = ekstreController.text.replaceAll(',', '.');
                final miktar = double.tryParse(temiz);
                if (miktar != null && miktar >= 0) {
                  final guncel = FinansItem(
                    id: item.id,
                    baslik: item.baslik,
                    miktar: miktar,
                    tur: item.tur,
                    tarih: item.tarih,
                    yineleme: item.yineleme,
                    iptalTarihler: item.iptalTarihler,
                    odendi: miktar == 0,
                    odenenMiktar: 0.0,
                    hesapKesimGunu: item.hesapKesimGunu,
                    sonOdemeGunu: item.sonOdemeGunu,
                    ekstreGirildi: true,
                    kartLimiti: item.kartLimiti,
                  );
                  widget.onIslemDuzenle(index, guncel);
                  Navigator.pop(context);
                }
              },
              child: Text('kaydet'.tr,
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _faturaTutarGirDialog(int index, FinansItem item) {
    final r = AppRenkler.of(context);
    final TextEditingController tutarController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: r.dialog,
          title:
              Text('fatura_tutari_baslik'.trParams({'fatura': item.baslik})),
          content: TextField(
            controller: tutarController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'gelen_fatura_borcu'.tr,
              hintText: '480',
              prefixIcon: Icon(Icons.receipt_long_rounded, color: r.turuncu),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('iptal'.tr, style: TextStyle(color: r.altMetin)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent),
              onPressed: () {
                final temiz = tutarController.text.replaceAll(',', '.');
                final miktar = double.tryParse(temiz);
                if (miktar != null && miktar >= 0) {
                  final guncel = FinansItem(
                    id: item.id,
                    baslik: item.baslik,
                    miktar: miktar,
                    tur: item.tur,
                    tarih: item.tarih,
                    yineleme: item.yineleme,
                    iptalTarihler: item.iptalTarihler,
                    odendi: item.odendi,
                    odenenMiktar: item.odenenMiktar,
                    ekstreGirildi: true,
                    isDegiskenFatura: item.isDegiskenFatura,
                    otomatikOdemede: item.otomatikOdemede,
                    gecenAykiTutar: miktar,
                  );
                  widget.onIslemDuzenle(index, guncel);
                  Navigator.pop(context);
                }
              },
              child: Text('kaydet'.tr,
                  style: const TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  void _odemeYapDialog(int index, FinansItem item) {
    final r = AppRenkler.of(context);

    if (item.tur == 'Gider' || item.tur == 'Fatura') {
      final guncel = FinansItem(
        id: item.id,
        baslik: item.baslik,
        miktar: item.miktar,
        tur: item.tur,
        tarih: item.tarih,
        yineleme: item.yineleme,
        iptalTarihler: item.iptalTarihler,
        odendi: !item.odendi,
        odenenMiktar: !item.odendi ? item.miktar : 0,
        hesapKesimGunu: item.hesapKesimGunu,
        sonOdemeGunu: item.sonOdemeGunu,
        isDegiskenFatura: item.isDegiskenFatura,
        otomatikOdemede: item.otomatikOdemede,
        ekstreGirildi: item.ekstreGirildi,
      );
      widget.onIslemDuzenle(index, guncel);
      return;
    }

    final double kalan = item.kalanMiktar > 0 ? item.kalanMiktar : item.miktar;
    if (kalan <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('aktif_borc_bulunmuyor'.trParams({'baslik': item.baslik})),
        ),
      );
      return;
    }

    String secim = item.tur == 'Kredi Kartı' ? 'asgari' : 'tamami';
    final TextEditingController tutarController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final double asgariTutar = kalan * item.asgariOran;

            return AlertDialog(
              backgroundColor: r.dialog,
              title: Text('kart_odemesi_baslik'.trParams({'baslik': item.baslik})),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${'guncel_borc_detay'.trParams({'kalan': kalan.toStringAsFixed(0)})}'
                    '${item.odenenMiktar > 0 ? 'daha_once_odenen'.trParams({'odenen': item.odenenMiktar.toStringAsFixed(0)}) : ''}',
                    style: TextStyle(color: r.altMetin, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  RadioGroup<String>(
                    groupValue: secim,
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => secim = val);
                      }
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.tur == 'Kredi Kartı')
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            title: Text('asgarisini_odedim'
                                .trParams({'tutar': asgariTutar.toStringAsFixed(0)})),
                            value: 'asgari',
                            activeColor: r.mor,
                          ),
                        RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: Text('tamamini_odedim'
                              .trParams({'tutar': kalan.toStringAsFixed(0)})),
                          value: 'tamami',
                          activeColor: r.mor,
                        ),
                        RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: Text('ozel_tutar_odedim'.tr),
                          value: 'diger',
                          activeColor: r.mor,
                        ),
                      ],
                    ),
                  ),
                  if (secim == 'diger') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: tutarController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'odenen_tutar_maks'
                            .trParams({'maks': kalan.toStringAsFixed(0)}),
                        hintText: '1000',
                        prefixIcon:
                            Icon(Icons.payments_rounded, color: r.yesil),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('iptal'.tr, style: TextStyle(color: r.altMetin)),
                ),
                ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () {
                    double odenecek = 0;
                    if (secim == 'asgari') {
                      odenecek = asgariTutar;
                    } else if (secim == 'tamami') {
                      odenecek = kalan;
                    } else {
                      final temiz = tutarController.text.replaceAll(',', '.');
                      final girilen = double.tryParse(temiz) ?? 0;
                      odenecek = girilen > kalan ? kalan : girilen;
                    }

                    if (odenecek > 0) {
                      final yeniOdenen = item.odenenMiktar + odenecek;
                      final tamKapandi = yeniOdenen >= item.miktar;

                      final guncelItem = FinansItem(
                        id: item.id,
                        baslik: item.baslik,
                        miktar: item.miktar,
                        tur: item.tur,
                        tarih: item.tur == 'Kredi Kartı'
                            ? DateTime.now()
                            : item.tarih,
                        yineleme: item.yineleme,
                        iptalTarihler: item.iptalTarihler,
                        odendi: tamKapandi,
                        odenenMiktar: yeniOdenen,
                        hesapKesimGunu: item.hesapKesimGunu,
                        sonOdemeGunu: item.sonOdemeGunu,
                        ekstreGirildi: item.ekstreGirildi,
                        isDegiskenFatura: item.isDegiskenFatura,
                        otomatikOdemede: item.otomatikOdemede,
                        kartLimiti: item.kartLimiti,
                      );

                      widget.onIslemDuzenle(index, guncelItem);
                      Navigator.pop(context);
                    }
                  },
                  child: Text('odemeyi_kaydet'.tr,
                      style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _islemFormDialog({int? duzenlenecekIndex, FinansItem? mevcutItem}) {
    if (mevcutItem != null &&
        duzenlenecekIndex != null &&
        mevcutItem.tur == 'Kredi Kartı') {
      _krediKartiFormDialog(
        duzenlenecekIndex: duzenlenecekIndex,
        mevcutKart: mevcutItem,
      );
      return;
    }

    final r = AppRenkler.of(context);
    final duzenlemeModu = mevcutItem != null && duzenlenecekIndex != null;

    _baslikController.text = duzenlemeModu ? mevcutItem.baslik : '';
    _miktarController.text = (duzenlemeModu && mevcutItem.miktar > 0)
        ? mevcutItem.miktar.toStringAsFixed(0)
        : '';
    _gecenAykiTutarController.text =
        duzenlemeModu && mevcutItem.gecenAykiTutar != null
            ? mevcutItem.gecenAykiTutar!.toStringAsFixed(0)
            : '';
    _secilenTur = duzenlemeModu ? mevcutItem.tur : 'Fatura';
    _secilenYineleme =
        duzenlemeModu ? mevcutItem.yineleme : 'Her ay (Aynı gün)';
    _secilenTarih = duzenlemeModu ? mevcutItem.tarih : DateTime.now();
    _isDegiskenFatura = duzenlemeModu ? mevcutItem.isDegiskenFatura : false;
    _otomatikOdemede = duzenlemeModu ? mevcutItem.otomatikOdemede : false;

    final mevcutSecenekler = List<String>.from(_yinelemeSecenekleri);
    if (!mevcutSecenekler.contains(_secilenYineleme)) {
      mevcutSecenekler.add(_secilenYineleme);
    }

    const genelTurler = ['Fatura', 'Gider', 'Gelir', 'Alacak', 'Borç'];
    if (!genelTurler.contains(_secilenTur)) {
      _secilenTur = 'Fatura';
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: r.dialog,
              title: Text(duzenlemeModu
                  ? 'islemi_duzenle'.tr
                  : 'yeni_finansal_islem'.tr),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () async {
                        final secilen = await showDatePicker(
                          context: context,
                          initialDate: _secilenTarih,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (secilen != null && context.mounted) {
                          setDialogState(() => _secilenTarih = secilen);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: r.ikincilKart,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: r.mor),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                'tarih_secili'.trParams({
                                  'tarih':
                                      '${_secilenTarih.day}.${_secilenTarih.month}.${_secilenTarih.year}'
                                }),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Icon(Icons.edit_calendar_rounded,
                                size: 18, color: r.mor),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _baslikController,
                      decoration: InputDecoration(
                          labelText: 'aciklama_fatura_adi'.tr,
                          hintText: 'aciklama_fatura_hint'.tr),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _secilenTur,
                      dropdownColor: r.dialog,
                      decoration: InputDecoration(labelText: 'islem_turu'.tr),
                      items: genelTurler
                          .map((t) => DropdownMenuItem(
                              value: t, child: Text('tur_$t'.tr)))
                          .toList(),
                      onChanged: (v) => setDialogState(() => _secilenTur = v!),
                    ),
                    const SizedBox(height: 12),
                    if (_secilenTur == 'Fatura') ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('degisken_fatura_mi'.tr,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold)),
                        subtitle: Text('degisken_fatura_alt'.tr,
                            style: TextStyle(fontSize: 11, color: r.altMetin)),
                        value: _isDegiskenFatura,
                        activeThumbColor: r.turuncu,
                        onChanged: (val) =>
                            setDialogState(() => _isDegiskenFatura = val),
                      ),
                      const SizedBox(height: 8),
                      if (_isDegiskenFatura) ...[
                        TextField(
                          controller: _gecenAykiTutarController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText: 'gecen_ayki_tutar'.tr,
                            hintText: '450',
                            prefixIcon:
                                Icon(Icons.history_rounded, color: r.morAcik),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        TextField(
                          controller: _miktarController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                              labelText: 'sabit_fatura_tutari'.tr,
                              hintText: '240'),
                        ),
                        const SizedBox(height: 12),
                      ],
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('otomatik_odemede_mi'.tr,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold)),
                        subtitle: Text('otomatik_odemede_alt'.tr,
                            style: TextStyle(fontSize: 11, color: r.altMetin)),
                        value: _otomatikOdemede,
                        activeThumbColor: r.mavi,
                        onChanged: (val) =>
                            setDialogState(() => _otomatikOdemede = val),
                      ),
                    ] else ...[
                      TextField(
                        controller: _miktarController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                            labelText: 'miktar_tl'.tr, hintText: '2500'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    DropdownButtonFormField<String>(
                      initialValue: _secilenYineleme,
                      isExpanded: true,
                      dropdownColor: r.dialog,
                      decoration: InputDecoration(
                          labelText: 'yineleme_periyot'.tr,
                          prefixIcon: Icon(Icons.repeat_rounded, color: r.mor)),
                      items: mevcutSecenekler
                          .map((y) => DropdownMenuItem(
                              value: y,
                              child: Text(_yinelemeSecenekleri.contains(y)
                                  ? 'yin_$y'.tr
                                  : y)))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => _secilenYineleme = v!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child:
                        Text('iptal'.tr, style: TextStyle(color: r.altMetin))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple),
                  onPressed: () {
                    final miktar = double.tryParse(
                            _miktarController.text.replaceAll(',', '.')) ??
                        0.0;
                    final gecenAyki = double.tryParse(
                        _gecenAykiTutarController.text.replaceAll(',', '.'));

                    if (_baslikController.text.isNotEmpty) {
                      final yeniItem = FinansItem(
                        id: duzenlemeModu
                            ? mevcutItem.id
                            : DateTime.now().toString(),
                        baslik: _baslikController.text,
                        miktar: _isDegiskenFatura
                            ? (duzenlemeModu ? mevcutItem.miktar : 0.0)
                            : miktar,
                        tur: _secilenTur,
                        tarih: _secilenTarih,
                        yineleme: _secilenYineleme,
                        iptalTarihler:
                            duzenlemeModu ? mevcutItem.iptalTarihler : const [],
                        odendi: duzenlemeModu ? mevcutItem.odendi : false,
                        odenenMiktar:
                            duzenlemeModu ? mevcutItem.odenenMiktar : 0.0,
                        isDegiskenFatura: _isDegiskenFatura,
                        otomatikOdemede: _otomatikOdemede,
                        gecenAykiTutar: gecenAyki,
                        ekstreGirildi: duzenlemeModu
                            ? mevcutItem.ekstreGirildi
                            : !_isDegiskenFatura,
                      );

                      if (duzenlemeModu) {
                        widget.onIslemDuzenle(duzenlenecekIndex, yeniItem);
                      } else {
                        widget.onIslemEkle(yeniItem);
                      }

                      _baslikController.clear();
                      _miktarController.clear();
                      _gecenAykiTutarController.clear();
                      Navigator.pop(context);
                    }
                  },
                  child: Text(duzenlemeModu ? 'guncelle'.tr : 'ekle'.tr,
                      style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _kumbaraHedefDialog() {
    final r = AppRenkler.of(context);
    final adController = TextEditingController();
    final hedefController = TextEditingController();
    final baslangicController = TextEditingController();
    String secilenIkon = '🎯';
    final ikonlar = [
      '🎯',
      '💻',
      '✈️',
      '🚗',
      '📱',
      '🏠',
      '🎓',
      '💰',
      '🏍️',
      '💍',
      '⌚',
      '🎸',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: r.dialog,
              title: Text('yeni_birikim_hedefi'.tr),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'kumbara_simgesi_secin'.tr,
                      style: TextStyle(fontSize: 12, color: r.altMetin),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ikonlar.map((ikon) {
                        final secili = secilenIkon == ikon;
                        return GestureDetector(
                          onTap: () => setDialogState(() => secilenIkon = ikon),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: secili ? Colors.deepPurple : r.ikincilKart,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: secili ? r.morAcik : r.kenarlik,
                              ),
                            ),
                            child: Text(ikon,
                                style: const TextStyle(fontSize: 20)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: adController,
                      decoration: InputDecoration(
                        labelText: 'hedef_adi'.tr,
                        hintText: 'hedef_adi_hint'.tr,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: hedefController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'hedef_tutar'.tr,
                        hintText: '30000',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: baslangicController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'mevcut_birikim_opsiyonel'.tr,
                        hintText: '2500',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('iptal'.tr, style: TextStyle(color: r.altMetin)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple),
                  onPressed: () {
                    final hedef = double.tryParse(
                            hedefController.text.replaceAll(',', '.')) ??
                        0;
                    final baslangic = double.tryParse(
                            baslangicController.text.replaceAll(',', '.')) ??
                        0;

                    if (adController.text.trim().isNotEmpty && hedef > 0) {
                      setState(() {
                        _hedefler.add(
                          _KumbaraHedef(
                            id: DateTime.now()
                                .millisecondsSinceEpoch
                                .toString(),
                            baslik: adController.text.trim(),
                            ikon: secilenIkon,
                            hedefTutar: hedef,
                            birikenTutar: baslangic,
                          ),
                        );
                      });
                      _hedefleriKaydet();
                      Navigator.pop(context);
                    }
                  },
                  child: Text('olustur'.tr,
                      style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _kumbaraParaIslemDialog(int index, {required bool eklemeMi}) {
    final r = AppRenkler.of(context);
    final hedef = _hedefler[index];
    final tutarController = TextEditingController();
    bool bakiyeyeYansit = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: r.dialog,
              title: Text(
                  '${hedef.ikon} ${hedef.baslik} • ${eklemeMi ? 'para_aktar'.tr : 'para_cek'.tr}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: tutarController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: eklemeMi
                          ? 'aktarilacak_tutar'.tr
                          : 'cekilecek_tutar'.tr,
                      hintText: '500',
                      prefixIcon: Icon(
                        eklemeMi
                            ? Icons.savings_rounded
                            : Icons.outbond_rounded,
                        color: eklemeMi ? r.yesil : r.turuncu,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      eklemeMi
                          ? 'ana_bakiyeden_dus'.tr
                          : 'ana_bakiyeye_ekle'.tr,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      eklemeMi
                          ? 'kumbara_gider_alt'.tr
                          : 'kumbara_gelir_alt'.tr,
                      style: TextStyle(fontSize: 11, color: r.altMetin),
                    ),
                    value: bakiyeyeYansit,
                    activeThumbColor: r.mor,
                    onChanged: (val) =>
                        setDialogState(() => bakiyeyeYansit = val),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('iptal'.tr, style: TextStyle(color: r.altMetin)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        eklemeMi ? Colors.green : Colors.orangeAccent,
                  ),
                  onPressed: () {
                    final girilen = double.tryParse(
                            tutarController.text.replaceAll(',', '.')) ??
                        0;
                    if (girilen <= 0) return;

                    final islemTutari =
                        eklemeMi ? girilen : min(girilen, hedef.birikenTutar);

                    if (islemTutari <= 0) return;

                    setState(() {
                      _hedefler[index] = _KumbaraHedef(
                        id: hedef.id,
                        baslik: hedef.baslik,
                        ikon: hedef.ikon,
                        hedefTutar: hedef.hedefTutar,
                        birikenTutar: eklemeMi
                            ? hedef.birikenTutar + islemTutari
                            : hedef.birikenTutar - islemTutari,
                      );
                    });
                    _hedefleriKaydet();

                    if (bakiyeyeYansit) {
                      widget.onIslemEkle(
                        FinansItem(
                          id: '${DateTime.now().millisecondsSinceEpoch}_k',
                          baslik: eklemeMi
                              ? 'Kumbara: ${hedef.baslik}'
                              : 'Kumbaradan Çekim: ${hedef.baslik}',
                          miktar: islemTutari,
                          tur: eklemeMi ? 'Gider' : 'Gelir',
                          tarih: DateTime.now(),
                          yineleme: 'Tek seferlik',
                        ),
                      );
                    }

                    Navigator.pop(context);
                  },
                  child: Text(
                    eklemeMi ? 'kumbaraya_ekle'.tr : 'cek_btn'.tr,
                    style: TextStyle(
                        color: eklemeMi ? Colors.white : Colors.black),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Ortak Kumbara Hedef Kartı
  Widget _buildKumbaraHedefKarti(AppRenkler r, int index,
      {required bool mobil}) {
    final h = _hedefler[index];
    final oran = h.hedefTutar > 0
        ? (h.birikenTutar / h.hedefTutar).clamp(0.0, 1.0)
        : 0.0;
    final yuzde = (oran * 100).round();
    final tamamlandi = h.birikenTutar >= h.hedefTutar;
    final vurguRenk = tamamlandi ? r.yesil : r.sari;

    return Container(
      decoration: BoxDecoration(
        color: tamamlandi ? r.tamamlananKart : r.kart,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: tamamlandi ? r.yesil.withAlpha(130) : r.kenarlik,
          width: 1.3,
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  mobil ? 10 : 14,
                  mobil ? 10 : 12,
                  mobil ? 10 : 14,
                  mobil ? 10 : 14),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () =>
                                _kumbaraParaIslemDialog(index, eklemeMi: true),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: mobil ? 7 : 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'ekle_kisa'.tr,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          if (h.birikenTutar > 0) ...[
                            const SizedBox(width: 4),
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _kumbaraParaIslemDialog(index,
                                  eklemeMi: false),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: mobil ? 6 : 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: r.turuncu.withAlpha(35),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'cek_kisa'.tr,
                                  style: TextStyle(
                                    color: r.turuncu,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          setState(() => _hedefler.removeAt(index));
                          _hedefleriKaydet();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 17,
                            color: r.altMetin,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: mobil ? 64 : 84,
                            height: mobil ? 64 : 84,
                            decoration: BoxDecoration(
                              color: r.ikincilKart,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: vurguRenk.withAlpha(90),
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              h.ikon,
                              style: TextStyle(fontSize: mobil ? 34 : 44),
                            ),
                          ),
                          SizedBox(height: mobil ? 6 : 10),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${h.birikenTutar.toStringAsFixed(0)} ₺ / ${h.hedefTutar.toStringAsFixed(0)} ₺',
                              style: TextStyle(
                                fontSize: mobil ? 11 : 12,
                                fontWeight: FontWeight.w700,
                                color: r.altMetin,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                        horizontal: mobil ? 10 : 12, vertical: mobil ? 6 : 7),
                    decoration: BoxDecoration(
                      color: r.ikincilKart,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: vurguRenk.withAlpha(140),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              tamamlandi ? 'tamamlandi'.tr : 'ilerleme'.tr,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: r.altMetin,
                              ),
                            ),
                            Text(
                              '%$yuzde',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                color: vurguRenk,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: oran,
                            minHeight: 5,
                            backgroundColor: r.kart,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(vurguRenk),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, thickness: 1.2, color: r.kenarlik),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
                horizontal: 10, vertical: mobil ? 10 : 14),
            decoration: BoxDecoration(
              color: r.ikincilKart.withAlpha(140),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(21),
              ),
            ),
            child: Text(
              h.baslik,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: mobil ? 13 : 14.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Telefon (Dar Ekran) 2 Sütunlu Kumbara Grid Görünümü
  Widget _buildMobilKumbaraGorunumu(AppRenkler r,
      {required bool yukseklikSinirli}) {
    final toplamBiriken =
        _hedefler.fold<double>(0, (sum, h) => sum + h.birikenTutar);
    final toplamHedef =
        _hedefler.fold<double>(0, (sum, h) => sum + h.hedefTutar);

    Widget kumbaraEkleKarti() {
      return InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: _kumbaraHedefDialog,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: r.kart,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: r.sari.withAlpha(120), width: 1.3),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: r.sari.withAlpha(r.isDark ? 35 : 28),
                  shape: BoxShape.circle,
                  border: Border.all(color: r.sari.withAlpha(120), width: 1.8),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '🐷',
                  style: TextStyle(fontSize: 38),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'kumbara_buyuk'.tr,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
              if (toplamHedef > 0) ...[
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${toplamBiriken.toStringAsFixed(0)} / ${toplamHedef.toStringAsFixed(0)} ₺',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: r.altMetin,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Colors.deepPurple,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: !yukseklikSinirli,
      physics: yukseklikSinirli
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: _hedefler.length + 1,
      itemBuilder: (context, index) {
        if (index < _hedefler.length) {
          return _buildKumbaraHedefKarti(r, index, mobil: true);
        }
        return kumbaraEkleKarti();
      },
    );
  }

  Widget _buildGenisKumbaraGorunumu(AppRenkler r) {
    final toplamBiriken =
        _hedefler.fold<double>(0, (sum, h) => sum + h.birikenTutar);
    final toplamHedef =
        _hedefler.fold<double>(0, (sum, h) => sum + h.hedefTutar);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 7,
          child: _hedefler.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: r.kart,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: r.kenarlik, width: 1.2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🎯', style: TextStyle(fontSize: 54)),
                      const SizedBox(height: 12),
                      Text(
                        'henuz_birikim_hedefi_yok'.tr,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'henuz_birikim_hedefi_alt'.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: r.altMetin, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _hedefler.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) => SizedBox(
                    width: 245,
                    child: _buildKumbaraHedefKarti(r, index, mobil: false),
                  ),
                ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: r.kart,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: r.sari.withAlpha(110), width: 1.3),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: r.sari.withAlpha(r.isDark ? 35 : 28),
                    shape: BoxShape.circle,
                    border: Border.all(color: r.sari.withAlpha(120), width: 2),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '🐷',
                    style: TextStyle(fontSize: 56),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'kumbara_buyuk'.tr,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  toplamHedef > 0
                      ? 'toplam_birikim_oran'.trParams({
                          'biriken': toplamBiriken.toStringAsFixed(0),
                          'hedef': toplamHedef.toStringAsFixed(0),
                        })
                      : 'yeni_birikim_hedefi_olustur'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: r.altMetin,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 22),
                Material(
                  color: Colors.deepPurple,
                  shape: const CircleBorder(),
                  elevation: 3,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _kumbaraHedefDialog,
                    child: const SizedBox(
                      width: 64,
                      height: 64,
                      child: Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'hedef_ekle'.tr,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: r.morAcik,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  double _itemAylikEtki(FinansItem f, DateTime ayBasi, DateTime aySonu) {
    final fBaslangic = DateTime(f.tarih.year, f.tarih.month, f.tarih.day);

    if (f.tur == 'Kredi Kartı') {
      final odemeYapildiMi = f.odendi || f.odenenMiktar > 0;
      final buAySonOdeme = f.sonOdemeGunu != null
          ? DateTime(
              ayBasi.year, ayBasi.month, min(f.sonOdemeGunu!, aySonu.day))
          : fBaslangic;

      if (odemeYapildiMi) {
        final odemeBuAydaMi =
            !fBaslangic.isBefore(ayBasi) && !fBaslangic.isAfter(aySonu);
        final odenenTutar = f.odenenMiktar > 0 ? f.odenenMiktar : f.miktar;

        if (!f.odendi &&
            odenenTutar < f.tahminiOdeme &&
            !buAySonOdeme.isBefore(fBaslangic)) {
          return f.tahminiOdeme;
        }
        return odemeBuAydaMi ? odenenTutar : 0.0;
      } else {
        if (buAySonOdeme.isBefore(fBaslangic)) return 0.0;
        return f.tahminiOdeme;
      }
    }

    int aylikTekrar = 0;
    DateTime temp = ayBasi;
    while (!temp.isAfter(aySonu)) {
      if (_islemGunuMu(f, temp)) {
        aylikTekrar++;
      }
      temp = DateTime(temp.year, temp.month, temp.day + 1);
    }

    if (aylikTekrar == 0) return 0.0;
    final isPozitif = f.tur == 'Gelir' || f.tur == 'Alacak';
    return isPozitif
        ? (f.miktar * aylikTekrar)
        : (f.tahminiOdeme * aylikTekrar);
  }

  Map<String, double> _hesaplaAylikDenge() {
    final now = DateTime.now();
    final ayBasi = DateTime(now.year, now.month, 1);
    final aySonu = DateTime(now.year, now.month + 1, 0);

    double toplamGelir = 0;
    double toplamGider = 0;
    double kartGideri = 0;
    double faturaGideri = 0;
    double rutinGider = 0;
    double borcGideri = 0;
    double aylikKumbaraBirikimi = 0;

    for (var f in widget.islemler) {
      final etki = _itemAylikEtki(f, ayBasi, aySonu);
      if (etki == 0) continue;

      final isPozitif = f.tur == 'Gelir' || f.tur == 'Alacak';

      if (isPozitif) {
        toplamGelir += etki;
      } else {
        toplamGider += etki;

        if (f.tur == 'Kredi Kartı') {
          kartGideri += etki;
        } else if (f.tur == 'Fatura') {
          faturaGideri += etki;
        } else if (f.tur == 'Borç') {
          borcGideri += etki;
        } else if (f.baslik.startsWith('Kumbara:')) {
          aylikKumbaraBirikimi += etki;
        } else {
          rutinGider += etki;
        }
      }
    }

    final toplamKumbaraBirikimi =
        _hedefler.fold<double>(0.0, (sum, h) => sum + max(0.0, h.birikenTutar));
    final double birikimTutar = aylikKumbaraBirikimi > 0
        ? aylikKumbaraBirikimi
        : toplamKumbaraBirikimi;

    return {
      'gelir': toplamGelir,
      'gider': toplamGider,
      'kart': kartGideri,
      'fatura': faturaGideri,
      'rutin': rutinGider,
      'borc': borcGideri,
      'birikim': birikimTutar,
    };
  }

  List<_PastaDilimi> _olusturPastaDilimleri(
      AppRenkler r, Map<String, double> denge) {
    final double krediKartiTutar = denge['kart'] ?? 0;
    final double borcTutar = denge['borc'] ?? 0;
    final double rutinTutar = denge['rutin'] ?? 0;
    final double faturaTutar = denge['fatura'] ?? 0;
    final double birikimTutar = denge['birikim'] ?? 0;
    final double netKalanTutar =
        max(0.0, (denge['gelir'] ?? 0) - (denge['gider'] ?? 0));

    return [
      // Üst satır: Kredi Kartı (Bordo), Borç (Sarı), Rutin Ödemeler (Yeşil)
      _PastaDilimi(
        etiket: 'kat_kredi_karti'.tr,
        tutar: krediKartiTutar,
        renk: const Color(0xFF9B1B30),
      ),
      _PastaDilimi(
        etiket: 'kat_borc'.tr,
        tutar: borcTutar,
        renk: r.sari,
      ),
      _PastaDilimi(
        etiket: 'kat_rutin_odemeler'.tr,
        tutar: rutinTutar,
        renk: r.yesil,
      ),
      // Alt satır: Faturalar (Mavi), Net Kalan (Mor), Birikim (Pembe)
      _PastaDilimi(
        etiket: 'kat_faturalar'.tr,
        tutar: faturaTutar,
        renk: r.mavi,
      ),
      _PastaDilimi(
        etiket: 'kat_net_kalan'.tr,
        tutar: netKalanTutar,
        renk: r.morAcik,
      ),
      _PastaDilimi(
        etiket: 'kat_birikim'.tr,
        tutar: birikimTutar,
        renk: const Color(0xFFF472B6),
      ),
    ];
  }

  Widget _buildPastaLejantElemani(_PastaDilimi dilim, double pastaToplam) {
    final yuzde =
        pastaToplam > 0 ? ((dilim.tutar / pastaToplam) * 100).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: dilim.renk,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                dilim.etiket,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 15),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${dilim.tutar.toStringAsFixed(0)} ₺ (%$yuzde)',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: dilim.renk,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLejantGrid(List<_PastaDilimi> dilimler, double pastaToplam) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildPastaLejantElemani(dilimler[0], pastaToplam)),
            const SizedBox(width: 6),
            Expanded(child: _buildPastaLejantElemani(dilimler[1], pastaToplam)),
            const SizedBox(width: 6),
            Expanded(child: _buildPastaLejantElemani(dilimler[2], pastaToplam)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildPastaLejantElemani(dilimler[3], pastaToplam)),
            const SizedBox(width: 6),
            Expanded(child: _buildPastaLejantElemani(dilimler[4], pastaToplam)),
            const SizedBox(width: 6),
            Expanded(child: _buildPastaLejantElemani(dilimler[5], pastaToplam)),
          ],
        ),
      ],
    );
  }

  /// Telefon (Dar Ekran) Analiz + Klasik 3D Pasta Grafik Görünümü
  Widget _buildMobilAnalizGorunumu(AppRenkler r) {
    final now = DateTime.now();
    final ayBasi = DateTime(now.year, now.month, 1);
    final aySonu = DateTime(now.year, now.month + 1, 0);

    final denge = _hesaplaAylikDenge();
    final toplamGelir = denge['gelir'] ?? 0;
    final toplamGider = denge['gider'] ?? 0;
    final faturaGideri = denge['fatura'] ?? 0;
    final rutinGider = denge['rutin'] ?? 0;
    final borcGideri = denge['borc'] ?? 0;
    final double krediKartiTutar = denge['kart'] ?? 0;
    final double birikimTutar = denge['birikim'] ?? 0;

    final double netFark = toplamGelir - toplamGider;
    final double toplamAkis = toplamGelir + toplamGider;
    final double gelirOrani =
        toplamAkis > 0 ? (toplamGelir / toplamAkis) : 0.5;

    final dilimler = _olusturPastaDilimleri(r, denge);
    final double pastaToplam =
        dilimler.fold<double>(0.0, (sum, d) => sum + max(0.0, d.tutar));

    final double kategoriToplam = krediKartiTutar +
        faturaGideri +
        rutinGider +
        borcGideri +
        birikimTutar;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: r.kart,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: r.kenarlik, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'aylik_gelir_gider_dengesi'.tr,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${ayBasi.day}.${ayBasi.month} - ${aySonu.day}.${aySonu.month}',
                      style: TextStyle(fontSize: 11, color: r.altMetin),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: gelirOrani,
                    minHeight: 12,
                    backgroundColor: r.kirmizi,
                    valueColor: AlwaysStoppedAnimation<Color>(r.yesil),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'gelir_etiket'
                          .trParams({'tutar': toplamGelir.toStringAsFixed(0)}),
                      style: TextStyle(
                        color: r.yesil,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                    Text(
                      'gider_etiket'
                          .trParams({'tutar': toplamGider.toStringAsFixed(0)}),
                      style: TextStyle(
                        color: r.kirmizi,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
                Divider(height: 22, color: r.kenarlik),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'aylik_net_durum'.tr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: r.altMetin,
                      ),
                    ),
                    Text(
                      '${netFark >= 0 ? '+' : ''}${netFark.toStringAsFixed(0)} ₺',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: netFark >= 0 ? r.yesil : r.kirmizi,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: r.kart,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: r.kenarlik, width: 1.2),
            ),
            child: Column(
              children: [
                _buildLejantGrid(dilimler, pastaToplam),
                const SizedBox(height: 14),
                SizedBox(
                  height: 170,
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(225, 160),
                          painter: _PastaGrafikPainter(
                            dilimler: dilimler,
                            ayiriciRenk: r.kart,
                            bosRenk: r.ikincilKart,
                          ),
                        ),
                        if (pastaToplam <= 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: r.kart.withAlpha(220),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'bu_ay_veri_yok'.tr,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: r.altMetin,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 22, color: r.kenarlik),
                _buildKategoriBar(
                    r,
                    'kat_kredi_karti'.tr,
                    krediKartiTutar,
                    kategoriToplam,
                    const Color(0xFF9B1B30),
                    Icons.credit_card_rounded),
                _buildKategoriBar(r, 'kat_borc_odemeleri'.tr, borcGideri,
                    kategoriToplam, r.sari, Icons.handshake_rounded),
                _buildKategoriBar(r, 'kat_rutin_odemeler'.tr, rutinGider,
                    kategoriToplam, r.yesil, Icons.shopping_bag_rounded),
                _buildKategoriBar(r, 'kat_faturalar'.tr, faturaGideri,
                    kategoriToplam, r.mavi, Icons.receipt_long_rounded),
                _buildKategoriBar(r, 'kat_birikim'.tr, birikimTutar,
                    kategoriToplam, const Color(0xFFF472B6),
                    Icons.savings_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenisAnalizGorunumu(AppRenkler r) {
    final now = DateTime.now();
    final ayBasi = DateTime(now.year, now.month, 1);
    final aySonu = DateTime(now.year, now.month + 1, 0);

    final denge = _hesaplaAylikDenge();
    final toplamGelir = denge['gelir'] ?? 0;
    final toplamGider = denge['gider'] ?? 0;
    final faturaGideri = denge['fatura'] ?? 0;
    final rutinGider = denge['rutin'] ?? 0;
    final borcGideri = denge['borc'] ?? 0;
    final double krediKartiTutar = denge['kart'] ?? 0;
    final double birikimTutar = denge['birikim'] ?? 0;

    final double netFark = toplamGelir - toplamGider;
    final double toplamAkis = toplamGelir + toplamGider;
    final double gelirOrani =
        toplamAkis > 0 ? (toplamGelir / toplamAkis) : 0.5;

    final dilimler = _olusturPastaDilimleri(r, denge);
    final double pastaToplam =
        dilimler.fold<double>(0.0, (sum, d) => sum + max(0.0, d.tutar));

    final double kategoriToplam = krediKartiTutar +
        faturaGideri +
        rutinGider +
        borcGideri +
        birikimTutar;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: r.kart,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: r.kenarlik, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'aylik_gelir_gider_dengesi'.tr,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${ayBasi.day}.${ayBasi.month}.${ayBasi.year} - ${aySonu.day}.${aySonu.month}.${aySonu.year}',
                      style: TextStyle(fontSize: 11, color: r.altMetin),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: gelirOrani,
                    minHeight: 14,
                    backgroundColor: r.kirmizi,
                    valueColor: AlwaysStoppedAnimation<Color>(r.yesil),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'gelir_etiket'
                          .trParams({'tutar': toplamGelir.toStringAsFixed(0)}),
                      style: TextStyle(
                        color: r.yesil,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      'gider_etiket'
                          .trParams({'tutar': toplamGider.toStringAsFixed(0)}),
                      style: TextStyle(
                        color: r.kirmizi,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
                Divider(height: 22, color: r.kenarlik),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${'aylik_net_durum'.tr}:',
                      style: TextStyle(
                        color: r.altMetin,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${netFark >= 0 ? '+' : ''}${netFark.toStringAsFixed(0)} ₺',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: netFark >= 0 ? r.yesil : r.kirmizi,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildKategoriBar(
                            r,
                            'kat_kredi_karti'.tr,
                            krediKartiTutar,
                            kategoriToplam,
                            const Color(0xFF9B1B30),
                            Icons.credit_card_rounded),
                        _buildKategoriBar(r, 'kat_borc_odemeleri'.tr,
                            borcGideri, kategoriToplam, r.sari,
                            Icons.handshake_rounded),
                        _buildKategoriBar(
                            r,
                            'kat_rutin_odemeler'.tr,
                            rutinGider,
                            kategoriToplam,
                            r.yesil,
                            Icons.shopping_bag_rounded),
                        _buildKategoriBar(r, 'kat_faturalar'.tr, faturaGideri,
                            kategoriToplam, r.mavi, Icons.receipt_long_rounded),
                        _buildKategoriBar(
                            r,
                            'kat_birikim'.tr,
                            birikimTutar,
                            kategoriToplam,
                            const Color(0xFFF472B6),
                            Icons.savings_rounded),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: r.kart,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: r.kenarlik, width: 1.2),
            ),
            child: Column(
              children: [
                _buildLejantGrid(dilimler, pastaToplam),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, pieConstraints) {
                        final genislik = (pieConstraints.maxWidth * 0.88)
                            .clamp(160.0, 325.0);
                        final yukseklik = min(
                          pieConstraints.maxHeight * 0.90,
                          genislik * 0.72,
                        ).clamp(115.0, 230.0);

                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: Size(genislik, yukseklik),
                              painter: _PastaGrafikPainter(
                                dilimler: dilimler,
                                ayiriciRenk: r.kart,
                                bosRenk: r.ikincilKart,
                              ),
                            ),
                            if (pastaToplam <= 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: r.kart.withAlpha(220),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'bu_ay_veri_yok'.tr,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: r.altMetin,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKategoriBar(AppRenkler r, String baslik, double tutar,
      double toplamGider, Color renk, IconData icon) {
    final double oran = toplamGider > 0 ? (tutar / toplamGider) : 0.0;
    final int yuzde = (oran * 100).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: r.ikincilKart,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: r.kenarlik),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: renk, size: 17),
              const SizedBox(width: 8),
              Expanded(
                child: Text(baslik,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12.5)),
              ),
              const SizedBox(width: 6),
              Text('${tutar.toStringAsFixed(0)} ₺ (%$yuzde)',
                  style: TextStyle(
                      color: renk, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: oran,
              minHeight: 5,
              backgroundColor: r.kart,
              valueColor: AlwaysStoppedAnimation<Color>(renk),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIslemKarti(AppRenkler r, int index, int bugunGunu) {
    final item = widget.islemler[index];
    final isPozitif = item.tur == 'Gelir' || item.tur == 'Alacak';
    final renk = isPozitif ? r.yesil : r.kirmizi;
    final tekrar = _tekrarSayisiHesapla(item, _bakiyeHesapTarihi);
    final kartOdendiMi = item.odendi || item.odenenMiktar > 0;
    final kesimGunuGeldiMi =
        item.hesapKesimGunu != null && bugunGunu >= item.hesapKesimGunu!;

    String altMetin =
        '${item.tarih.day}.${item.tarih.month}.${item.tarih.year} • ${'tur_${item.tur}'.tr}';
    if (item.tur == 'Kredi Kartı') {
      altMetin = 'kart_kesim_son_odeme'.trParams({
        'kesim': (item.hesapKesimGunu ?? '-').toString(),
        'son': (item.sonOdemeGunu ?? '-').toString(),
      });
    } else if (item.yineleme != 'Tek seferlik') {
      final yinMetin = _yinelemeSecenekleri.contains(item.yineleme)
          ? 'yin_${item.yineleme}'.tr
          : item.yineleme;
      altMetin += ' • 🔄 $yinMetin';
    }
    if (item.otomatikOdemede) {
      altMetin += ' • ${'otomatik_odeme_etiket'.tr}';
    }

    final hasLimit = item.tur == 'Kredi Kartı' &&
        item.kartLimiti != null &&
        item.kartLimiti! > 0;
    final guncelKartBorcu = item.odendi ? 0.0 : item.kalanMiktar;
    final kalanKartLimiti = hasLimit
        ? (item.kartLimiti! - guncelKartBorcu).clamp(0.0, item.kartLimiti!)
        : 0.0;
    final limitDoluluk =
        hasLimit ? (guncelKartBorcu / item.kartLimiti!).clamp(0.0, 1.0) : 0.0;

    return Card(
      color: item.odendi ? r.tamamlananKart : r.ikincilKart,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: r.kenarlik),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 18,
              backgroundColor:
                  item.odendi ? r.yesil.withAlpha(40) : renk.withAlpha(30),
              child: Icon(
                item.odendi
                    ? Icons.check_circle_rounded
                    : (isPozitif
                        ? Icons.arrow_downward_rounded
                        : (item.tur == 'Kredi Kartı'
                            ? Icons.credit_card_rounded
                            : Icons.receipt_rounded)),
                color: item.odendi ? r.yesil : renk,
                size: 19,
              ),
            ),
            title: Text(
              item.baslik,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                decoration: item.odendi ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Text(
              altMetin,
              style: TextStyle(color: r.altMetin, fontSize: 11.5),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (item.tur == 'Kredi Kartı') ...[
                      if (!kesimGunuGeldiMi && !item.ekstreGirildi) ...[
                        Text('donem_ici'.tr,
                            style: TextStyle(
                                fontSize: 11.5,
                                color: r.mavi,
                                fontWeight: FontWeight.bold)),
                        if (guncelKartBorcu > 0)
                          Text(
                            'guncel_borc_etiket'.trParams(
                                {'tutar': guncelKartBorcu.toStringAsFixed(0)}),
                            style: TextStyle(
                                fontSize: 9.5,
                                color: r.turuncu,
                                fontWeight: FontWeight.bold),
                          ),
                      ] else if (!item.ekstreGirildi) ...[
                        Text('ekstre_kesildi'.tr,
                            style: TextStyle(
                                fontSize: 11.5,
                                color: r.sari,
                                fontWeight: FontWeight.bold)),
                        if (guncelKartBorcu > 0)
                          Text(
                            'kullanilan_etiket'.trParams(
                                {'tutar': guncelKartBorcu.toStringAsFixed(0)}),
                            style: TextStyle(fontSize: 9.5, color: r.altMetin),
                          ),
                      ] else
                        Text('-${guncelKartBorcu.toStringAsFixed(0)} ₺',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: item.odendi ? r.altMetin : renk)),
                    ] else if (item.tur == 'Fatura' &&
                        item.isDegiskenFatura &&
                        !item.ekstreGirildi) ...[
                      Text('fatura_bekliyor'.tr,
                          style: TextStyle(
                              fontSize: 11.5,
                              color: r.turuncu,
                              fontWeight: FontWeight.bold)),
                      if (item.gecenAykiTutar != null)
                        Text(
                            'tahmini_kisa'.trParams({
                              'tutar': item.gecenAykiTutar!.toStringAsFixed(0)
                            }),
                            style: TextStyle(fontSize: 10, color: r.altMetin)),
                    ] else ...[
                      Text(
                          '${isPozitif ? '+' : '-'}${item.miktar.toStringAsFixed(0)} ₺',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: item.odendi ? r.altMetin : renk)),
                      if (tekrar > 1)
                        Text(
                          '${tekrar}x = ${isPozitif ? '+' : '-'}${(item.tahminiOdeme * tekrar).toStringAsFixed(0)} ₺',
                          style: TextStyle(
                              fontSize: 10,
                              color: isPozitif ? r.yesil : r.turuncu,
                              fontWeight: FontWeight.bold),
                        ),
                    ],
                    if (item.tur == 'Kredi Kartı' && item.ekstreGirildi) ...[
                      if (kartOdendiMi)
                        Text(
                          'odendi_tarih_tutar'.trParams({
                            'tarih': '${item.tarih.day}.${item.tarih.month}',
                            'tutar': (item.odenenMiktar > 0
                                    ? item.odenenMiktar
                                    : item.miktar)
                                .toStringAsFixed(0),
                          }),
                          style: TextStyle(
                              fontSize: 9.5,
                              color: r.yesil,
                              fontWeight: FontWeight.bold),
                        )
                      else
                        Text(
                          'son_odeme_asgari'.trParams({
                            'gun': (item.sonOdemeGunu ?? '-').toString(),
                            'tutar': item.tahminiOdeme.toStringAsFixed(0),
                          }),
                          style: TextStyle(
                              fontSize: 9.5,
                              color: r.morAcik,
                              fontWeight: FontWeight.bold),
                        ),
                    ],
                  ],
                ),
                if (item.tur == 'Kredi Kartı' &&
                    kesimGunuGeldiMi &&
                    !item.ekstreGirildi)
                  TextButton(
                    onPressed: () => _ekstreTutarGirDialog(index, item),
                    child: Text('ekstre_gir'.tr,
                        style: TextStyle(color: r.sari, fontSize: 11.5)),
                  ),
                if (item.tur == 'Fatura' &&
                    item.isDegiskenFatura &&
                    !item.ekstreGirildi)
                  TextButton(
                    onPressed: () => _faturaTutarGirDialog(index, item),
                    child: Text('tutar_gir'.tr,
                        style: TextStyle(color: r.turuncu, fontSize: 11.5)),
                  )
                else if (!isPozitif)
                  IconButton(
                    tooltip: item.tur == 'Kredi Kartı'
                        ? 'kart_odemesi_tooltip'.tr
                        : 'odeme_yap_tooltip'.tr,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: Icon(
                        item.tur == 'Gider' || item.tur == 'Fatura'
                            ? (item.odendi
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded)
                            : Icons.payments_rounded,
                        color: r.yesil,
                        size: 20),
                    onPressed: () => _odemeYapDialog(index, item),
                  ),
                IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: Icon(Icons.edit_rounded, color: r.altMetin, size: 18),
                    onPressed: () {
                      if (item.tur == 'Kredi Kartı') {
                        _krediKartiFormDialog(
                            duzenlenecekIndex: index, mevcutKart: item);
                      } else {
                        _islemFormDialog(
                            duzenlenecekIndex: index, mevcutItem: item);
                      }
                    }),
                IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: Icon(Icons.delete_outline_rounded,
                        color: r.kirmizi, size: 18),
                    onPressed: () => widget.onIslemSil(index)),
              ],
            ),
          ),
          if (hasLimit)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'limit_etiket'.trParams(
                            {'tutar': item.kartLimiti!.toStringAsFixed(0)}),
                        style: TextStyle(fontSize: 11, color: r.altMetin),
                      ),
                      InkWell(
                        onTap: () => _kalanLimitGuncelleDialog(index, item),
                        child: Text(
                          'kalan_limit_duzenle'.trParams(
                              {'tutar': kalanKartLimiti.toStringAsFixed(0)}),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: limitDoluluk > 0.75 ? r.turuncu : r.mavi,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: limitDoluluk,
                      minHeight: 5,
                      backgroundColor: r.kart,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        limitDoluluk > 0.75 ? r.turuncu : r.mavi,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKartLimitKutusu(AppRenkler r,
      {bool icKaydirma = true, bool kompakt = false}) {
    final limitliKartIndexleri = <int>[];
    double toplamLimit = 0;
    double toplamKartBorcu = 0;

    for (int i = 0; i < widget.islemler.length; i++) {
      final f = widget.islemler[i];
      if (f.tur == 'Kredi Kartı') {
        limitliKartIndexleri.add(i);
        if (f.kartLimiti != null && f.kartLimiti! > 0) {
          toplamLimit += f.kartLimiti!;
          if (!f.odendi) {
            toplamKartBorcu += f.kalanMiktar;
          }
        }
      }
    }

    final int genelKartYuzde = toplamLimit > 0
        ? ((toplamKartBorcu / toplamLimit) * 100).clamp(0, 100).round()
        : 0;

    Widget kartListesiWidget() {
      if (limitliKartIndexleri.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              kompakt ? 'kart_yok_kompakt'.tr : 'kart_yok_tam'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: kompakt ? 10.5 : 11.5,
                color: r.altMetin,
              ),
            ),
          ),
        );
      }

      Widget satirOlustur(int idx) {
        final itemIndex = limitliKartIndexleri[idx];
        final k = widget.islemler[itemIndex];
        final limit = k.kartLimiti ?? 0.0;
        final borc = k.odendi ? 0.0 : k.kalanMiktar;
        final kalan = max(0.0, limit - borc);
        final oran = limit > 0 ? (borc / limit).clamp(0.0, 1.0) : 0.0;
        final yuzde = (oran * 100).round();
        final barRenk = oran > 0.75 ? r.turuncu : r.mavi;

        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _kalanLimitGuncelleDialog(itemIndex, k),
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: kompakt ? 6 : 8, vertical: kompakt ? 4 : 6),
            decoration: BoxDecoration(
              color: r.kart.withAlpha(150),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: r.kenarlik),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        k.baslik,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: kompakt ? 10.5 : 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (!kompakt) ...[
                      Text(
                        'kalan_tutar'.trParams({'tutar': kalan.toStringAsFixed(0)}),
                        style: TextStyle(
                          fontSize: 10,
                          color: r.altMetin,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      '%$yuzde',
                      style: TextStyle(
                        fontSize: kompakt ? 10.5 : 11.5,
                        fontWeight: FontWeight.bold,
                        color: barRenk,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: oran,
                    minHeight: kompakt ? 4 : 5,
                    backgroundColor: r.ikincilKart,
                    valueColor: AlwaysStoppedAnimation<Color>(barRenk),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      if (icKaydirma) {
        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: limitliKartIndexleri.length,
          separatorBuilder: (_, __) => SizedBox(height: kompakt ? 4 : 6),
          itemBuilder: (_, idx) => satirOlustur(idx),
        );
      }

      return Column(
        children: List.generate(
          limitliKartIndexleri.length,
          (idx) => Padding(
            padding: EdgeInsets.only(
                bottom: idx == limitliKartIndexleri.length - 1 ? 0 : 6),
            child: satirOlustur(idx),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(kompakt ? 10 : 14),
      decoration: BoxDecoration(
        color: r.ikincilKart,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: r.kenarlik),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'kart_limit_kullanimi'.tr,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: kompakt ? 11 : 12,
                    fontWeight: FontWeight.w700,
                    color: r.altMetin,
                  ),
                ),
              ),
              if (limitliKartIndexleri.isNotEmpty) ...[
                Text(
                  '%$genelKartYuzde',
                  style: TextStyle(
                    fontSize: kompakt ? 11.5 : 12.5,
                    fontWeight: FontWeight.w900,
                    color: genelKartYuzde > 75 ? r.turuncu : r.mavi,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _krediKartiFormDialog(),
                child: Container(
                  width: kompakt ? 22 : 26,
                  height: kompakt ? 22 : 26,
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    shape: BoxShape.circle,
                    border: Border.all(color: r.morAcik.withAlpha(120)),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: kompakt ? 15 : 18,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: kompakt ? 6 : 8),
          if (icKaydirma)
            Expanded(child: kartListesiWidget())
          else
            kartListesiWidget(),
        ],
      ),
    );
  }

  /// Hem Geniş Ekran Sol 2x2 Paneli Hem Telefon Üst 2x2 Özet Grid'i
  Widget _buildSol2x2OzetGrid(AppRenkler r, double seciliBakiye,
      {bool kompakt = false}) {
    final aktifNormalBorclar = widget.islemler
        .where((f) => f.tur == 'Borç' && !f.odendi && f.kalanMiktar > 0)
        .toList();
    final aktifKartBorclari = widget.islemler
        .where((f) => f.tur == 'Kredi Kartı' && !f.odendi && f.kalanMiktar > 0)
        .toList();

    final double toplamNormalBorc =
        aktifNormalBorclar.fold<double>(0.0, (sum, f) => sum + f.kalanMiktar);
    final double toplamKartBorcu =
        aktifKartBorclari.fold<double>(0.0, (sum, f) => sum + f.kalanMiktar);
    final double toplamAktifBorc = toplamNormalBorc + toplamKartBorcu;
    final int toplamBorcKayitSayisi =
        aktifNormalBorclar.length + aktifKartBorclari.length;

    final denge = _hesaplaAylikDenge();
    final aylikGelir = denge['gelir'] ?? 0;
    final aylikGider = denge['gider'] ?? 0;
    final aylikNet = aylikGelir - aylikGider;
    final toplamAkis = aylikGelir + aylikGider;
    final double gelirOrani =
        toplamAkis > 0 ? (aylikGelir / toplamAkis).clamp(0.0, 1.0) : 0.5;

    final double icBosluk = kompakt ? 8 : 10;
    final double kutuPadding = kompakt ? 10 : 14;
    final double baslikFont = kompakt ? 11 : 12;
    final double buyukRakamFont = kompakt ? 21 : 28;

    return Container(
      padding: EdgeInsets.all(kompakt ? 10 : 12),
      decoration: BoxDecoration(
        color: r.kart,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: r.kenarlik, width: 1.2),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    key: _keyNetBakiye,
                    padding: EdgeInsets.all(kutuPadding),
                    decoration: BoxDecoration(
                      color: r.ikincilKart,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: r.kenarlik),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: Text(
                                'tahmini_net_bakiye'.tr,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: baslikFont,
                                  fontWeight: FontWeight.w700,
                                  color: r.altMetin,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              key: _keyBakiyeTarihi,
                              borderRadius: BorderRadius.circular(8),
                              onTap: () async {
                                final secilen = await showDatePicker(
                                  context: context,
                                  initialDate: _bakiyeHesapTarihi,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (secilen != null && mounted) {
                                  setState(() => _bakiyeHesapTarihi = secilen);
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: kompakt ? 6 : 8,
                                    vertical: kompakt ? 3 : 4),
                                decoration: BoxDecoration(
                                  color: r.mor.withAlpha(r.isDark ? 45 : 25),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: r.mor),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit_calendar_rounded,
                                        size: kompakt ? 10.5 : 12,
                                        color: r.morAcik),
                                    const SizedBox(width: 3),
                                    Text(
                                      kompakt
                                          ? '${_bakiyeHesapTarihi.day}.${_bakiyeHesapTarihi.month}'
                                          : '${_bakiyeHesapTarihi.day}.${_bakiyeHesapTarihi.month}.${_bakiyeHesapTarihi.year}',
                                      style: TextStyle(
                                        fontSize: kompakt ? 10 : 11,
                                        fontWeight: FontWeight.bold,
                                        color: r.morAcik,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${seciliBakiye.toStringAsFixed(0)} ₺',
                            style: TextStyle(
                              fontSize: buyukRakamFont,
                              fontWeight: FontWeight.w900,
                              color: seciliBakiye >= 0 ? r.yesil : r.kirmizi,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              seciliBakiye >= 0
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              size: kompakt ? 13 : 16,
                              color: seciliBakiye >= 0 ? r.yesil : r.kirmizi,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                seciliBakiye >= 0
                                    ? 'arti_bakiye'.tr
                                    : 'acik_olusuyor'.tr,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: kompakt ? 10 : 11,
                                  color: r.altMetin,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: icBosluk),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(kutuPadding),
                    decoration: BoxDecoration(
                      color: r.ikincilKart,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: toplamAktifBorc > 0
                            ? r.kirmizi.withAlpha(90)
                            : r.kenarlik,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                'aktif_borc_miktari'.tr,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: baslikFont,
                                  fontWeight: FontWeight.w700,
                                  color: r.altMetin,
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: kompakt ? 5 : 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: (toplamAktifBorc > 0
                                        ? r.kirmizi
                                        : r.yesil)
                                    .withAlpha(30),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$toplamBorcKayitSayisi',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: toplamAktifBorc > 0
                                      ? r.kirmizi
                                      : r.yesil,
                                ),
                              ),
                            ),
                          ],
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${toplamAktifBorc.toStringAsFixed(0)} ₺',
                            style: TextStyle(
                              fontSize: buyukRakamFont,
                              fontWeight: FontWeight.w900,
                              color:
                                  toplamAktifBorc > 0 ? r.kirmizi : r.yesil,
                            ),
                          ),
                        ),
                        Text(
                          toplamAktifBorc == 0
                              ? 'aktif_borc_yok'.tr
                              : 'kart_ve_diger_borc'.trParams({
                                  'kart': toplamKartBorcu.toStringAsFixed(0),
                                  'diger': toplamNormalBorc.toStringAsFixed(0),
                                }),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: kompakt ? 9.5 : 11,
                            color: r.altMetin,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: icBosluk),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildKartLimitKutusu(r,
                      icKaydirma: true, kompakt: kompakt),
                ),
                SizedBox(width: icBosluk),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(kutuPadding),
                    decoration: BoxDecoration(
                      color: r.ikincilKart,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: r.kenarlik),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                'aylik_gelir_gider'.tr,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: baslikFont,
                                  fontWeight: FontWeight.w700,
                                  color: r.altMetin,
                                ),
                              ),
                            ),
                            Text(
                              '${aylikNet >= 0 ? '+' : ''}${aylikNet.toStringAsFixed(0)} ₺',
                              style: TextStyle(
                                fontSize: kompakt ? 11 : 12,
                                fontWeight: FontWeight.w900,
                                color: aylikNet >= 0 ? r.yesil : r.kirmizi,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: gelirOrani,
                                minHeight: kompakt ? 8 : 10,
                                backgroundColor: r.kirmizi,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(r.yesil),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    '+${aylikGelir.toStringAsFixed(0)} ₺',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: kompakt ? 10.5 : 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: r.yesil,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '-${aylikGider.toStringAsFixed(0)} ₺',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: kompakt ? 10.5 : 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: r.kirmizi,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Text(
                          'bu_ayki_denge_alt'.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: kompakt ? 9.5 : 11,
                            color: r.altMetin,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSagIslemlerListesi(
    AppRenkler r,
    int bugunGunu, {
    required bool icKaydirma,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: r.kart,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: r.kenarlik, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'odemeler_kartlar_faturalar'.tr,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: r.ikincilKart,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: r.kenarlik),
                ),
                child: Text(
                  'kayit_sayisi'
                      .trParams({'sayi': widget.islemler.length.toString()}),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: r.altMetin,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (icKaydirma)
            Expanded(
              child: widget.islemler.isEmpty
                  ? Center(
                      child: Text(
                        'finans_hareket_yok'.tr,
                        style: TextStyle(color: r.altMetin),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: widget.islemler.length,
                      itemBuilder: (context, index) =>
                          _buildIslemKarti(r, index, bugunGunu),
                    ),
            )
          else if (widget.islemler.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'finans_hareket_yok'.tr,
                  style: TextStyle(color: r.altMetin),
                ),
              ),
            )
          else
            Column(
              children: List.generate(
                widget.islemler.length,
                (index) => _buildIslemKarti(r, index, bugunGunu),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUstVarlikVeKontroller(AppRenkler r, {required bool genisEkran}) {
    final bool ustEkleButonuGoster =
        _secilenAltSekme == 0 || _secilenAltSekme == 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          key: _keyVarlikKasasi,
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: r.sheet,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => const VarlikKasasiSheet(),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: r.sari,
              backgroundColor: r.kart,
              side: BorderSide(color: r.sari.withAlpha(140), width: 1.2),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            icon: const Icon(Icons.currency_exchange_rounded, size: 18),
            label: Text(
              'canli_varlik_kasasi_btn'.tr,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('finans_kumbara_baslik'.tr,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('finans_kumbara_alt'.tr,
                      style: TextStyle(color: r.altMetin, fontSize: 12)),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                KilavuzYardimButonu(onPressed: _kilavuzuBaslat),
                if (ustEkleButonuGoster) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: IconButton.filled(
                      key: _keyEkleButonu,
                      padding: EdgeInsets.zero,
                      onPressed: () => _islemFormDialog(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon:
                          const Icon(Icons.add, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          key: _keyAltSekmeler,
          width: double.infinity,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: r.kart,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: r.kenarlik, width: 1.2),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _secilenAltSekme = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: _secilenAltSekme == 0
                          ? Colors.deepPurple
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        'sekme_hareketler'.tr,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: _secilenAltSekme == 0 ? Colors.white : r.metin,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _secilenAltSekme = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: _secilenAltSekme == 1
                          ? Colors.deepPurple
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        'sekme_analiz'.tr,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: _secilenAltSekme == 1 ? Colors.white : r.metin,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _secilenAltSekme = 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: _secilenAltSekme == 2
                          ? Colors.deepPurple
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        'sekme_kumbara'.tr,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: _secilenAltSekme == 2 ? Colors.white : r.metin,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = AppRenkler.of(context);
    final seciliBakiye = _hesaplaBakiye(_bakiyeHesapTarihi);
    final bugunGunu = DateTime.now().day;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool genisEkran = constraints.maxWidth >= 600;
        final bool yukseklikSinirli = constraints.hasBoundedHeight;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUstVarlikVeKontroller(r, genisEkran: genisEkran),
              const SizedBox(height: 12),
              if (_secilenAltSekme == 0) ...[
                if (genisEkran) ...[
                  if (yukseklikSinirli)
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 11,
                            child: _buildSol2x2OzetGrid(r, seciliBakiye),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 12,
                            child: _buildSagIslemlerListesi(
                              r,
                              bugunGunu,
                              icKaydirma: true,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 11,
                          child: SizedBox(
                            height: 360,
                            child: _buildSol2x2OzetGrid(r, seciliBakiye),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 12,
                          child: _buildSagIslemlerListesi(
                            r,
                            bugunGunu,
                            icKaydirma: false,
                          ),
                        ),
                      ],
                    ),
                ] else ...[
                  if (yukseklikSinirli)
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            SizedBox(
                              height: 255,
                              child: _buildSol2x2OzetGrid(r, seciliBakiye,
                                  kompakt: true),
                            ),
                            const SizedBox(height: 12),
                            _buildSagIslemlerListesi(
                              r,
                              bugunGunu,
                              icKaydirma: false,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        SizedBox(
                          height: 255,
                          child: _buildSol2x2OzetGrid(r, seciliBakiye,
                              kompakt: true),
                        ),
                        const SizedBox(height: 12),
                        _buildSagIslemlerListesi(
                          r,
                          bugunGunu,
                          icKaydirma: false,
                        ),
                      ],
                    ),
                ],
              ] else if (_secilenAltSekme == 1) ...[
                if (genisEkran) ...[
                  if (yukseklikSinirli)
                    Expanded(child: _buildGenisAnalizGorunumu(r))
                  else
                    SizedBox(height: 360, child: _buildGenisAnalizGorunumu(r)),
                ] else ...[
                  if (yukseklikSinirli)
                    Expanded(child: _buildMobilAnalizGorunumu(r))
                  else
                    _buildMobilAnalizGorunumu(r),
                ],
              ] else ...[
                if (genisEkran) ...[
                  if (yukseklikSinirli)
                    Expanded(child: _buildGenisKumbaraGorunumu(r))
                  else
                    SizedBox(height: 340, child: _buildGenisKumbaraGorunumu(r)),
                ] else ...[
                  if (yukseklikSinirli)
                    Expanded(
                      child: _buildMobilKumbaraGorunumu(r,
                          yukseklikSinirli: true),
                    )
                  else
                    _buildMobilKumbaraGorunumu(r, yukseklikSinirli: false),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}