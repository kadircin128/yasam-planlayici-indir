import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/etkinlik.dart';
import '../services/dil_servisi.dart';
import '../theme/app_renkler.dart';

class _HavuzIs {
  final String id;
  final String baslik;
  final int sureDakika;
  final bool acil;
  final DateTime eklenmeTarihi;

  _HavuzIs({
    required this.id,
    required this.baslik,
    required this.sureDakika,
    required this.acil,
    required this.eklenmeTarihi,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'baslik': baslik,
        'sureDakika': sureDakika,
        'acil': acil,
        'eklenmeTarihi': eklenmeTarihi.toIso8601String(),
      };

  factory _HavuzIs.fromJson(Map<String, dynamic> json) => _HavuzIs(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        baslik: json['baslik'] ?? '',
        sureDakika: (json['sureDakika'] as num?)?.toInt() ?? 60,
        acil: json['acil'] ?? false,
        eklenmeTarihi:
            DateTime.tryParse(json['eklenmeTarihi'] ?? '') ?? DateTime.now(),
      );
}

class _BosZamanDilimi {
  final DateTime tarih;
  final int baslangicDakika;
  final int bitisDakika;
  final int toplamBoslukDakika;

  _BosZamanDilimi({
    required this.tarih,
    required this.baslangicDakika,
    required this.bitisDakika,
    required this.toplamBoslukDakika,
  });

  String _dakikaToSaat(int dk) {
    final s = (dk ~/ 60).toString().padLeft(2, '0');
    final d = (dk % 60).toString().padLeft(2, '0');
    return '$s:$d';
  }

  String get saatAraligi =>
      '${_dakikaToSaat(baslangicDakika)} - ${_dakikaToSaat(bitisDakika)}';
}

class IsHavuzuSheet extends StatefulWidget {
  final List<Etkinlik> etkinlikler;
  final Function(Etkinlik) onEtkinlikEkle;

  const IsHavuzuSheet({
    super.key,
    required this.etkinlikler,
    required this.onEtkinlikEkle,
  });

  @override
  State<IsHavuzuSheet> createState() => _IsHavuzuSheetState();
}

class _IsHavuzuSheetState extends State<IsHavuzuSheet> {
  final TextEditingController _isController = TextEditingController();
  List<_HavuzIs> _isler = [];
  int _secilenSure = 60;
  bool _acilMi = false;
  String? _aktifIsId;

  static const Map<int, String> _gunKisaAdlar = {
    1: 'Pzt',
    2: 'Sal',
    3: 'Çrş',
    4: 'Pş',
    5: 'Cu',
    6: 'Ct',
    7: 'Pz',
  };

  @override
  void initState() {
    super.initState();
    _isleriYukle();
  }

  @override
  void dispose() {
    _isController.dispose();
    super.dispose();
  }

  Future<void> _isleriYukle() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('tarihsiz_is_havuzu_v1');
    if (raw != null) {
      final List<dynamic> decoded = jsonDecode(raw);
      setState(() {
        _isler = decoded.map((e) => _HavuzIs.fromJson(e)).toList();
        _siralaIsler();
        if (_isler.isNotEmpty) {
          _aktifIsId = _isler.first.id;
        }
      });
    }
  }

  Future<void> _isleriKaydet() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_isler.map((e) => e.toJson()).toList());
    await prefs.setString('tarihsiz_is_havuzu_v1', encoded);
  }

  void _siralaIsler() {
    _isler.sort((a, b) {
      if (a.acil != b.acil) return a.acil ? -1 : 1;
      return a.eklenmeTarihi.compareTo(b.eklenmeTarihi);
    });
  }

  bool _etkinlikOgunMu(Etkinlik e, DateTime hedefTarih) {
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
        return eTarih.year == hedef.year &&
            eTarih.month == hedef.month &&
            eTarih.day == hedef.day;
    }
  }

  List<_BosZamanDilimi> _bosluklariBul(int istenenSureDakika) {
    final List<_BosZamanDilimi> oneriler = [];
    final simdi = DateTime.now();

    const int gunBaslangic = 9 * 60;
    const int gunBitis = 22 * 60;

    for (int gunFarki = 0; gunFarki < 7; gunFarki++) {
      if (oneriler.length >= 5) break;

      final gun = DateTime(simdi.year, simdi.month, simdi.day + gunFarki);
      int aktifBaslangic = gunBaslangic;

      if (gunFarki == 0) {
        final suAnDakika = simdi.hour * 60 + simdi.minute + 15;
        final yuvarlanmis = ((suAnDakika + 14) ~/ 15) * 15;
        aktifBaslangic = max(gunBaslangic, yuvarlanmis);
      }

      if (aktifBaslangic + istenenSureDakika > gunBitis) continue;

      final List<List<int>> mesgulAraliklar = [];
      for (final e in widget.etkinlikler) {
        if (!_etkinlikOgunMu(e, gun)) continue;
        if (e.saat == 'Tüm Gün' ||
            e.saat == 'tum_gun'.tr ||
            !e.saat.contains(':')) {
          continue;
        }

        final parcalar = e.saat.split('-');
        final basParca = parcalar.first.trim().split(':');
        if (basParca.length != 2) continue;

        final basSaat = int.tryParse(basParca[0]) ?? 0;
        final basDk = int.tryParse(basParca[1]) ?? 0;
        final basToplam = basSaat * 60 + basDk;

        int bitToplam = basToplam + 60;
        if (parcalar.length > 1) {
          final bitParca = parcalar[1].trim().split(':');
          if (bitParca.length == 2) {
            final bitSaat = int.tryParse(bitParca[0]) ?? basSaat + 1;
            final bitDk = int.tryParse(bitParca[1]) ?? 0;
            bitToplam = bitSaat * 60 + bitDk;
            if (bitToplam <= basToplam) bitToplam = basToplam + 60;
          }
        }

        final clampedBas = max(aktifBaslangic, basToplam);
        final clampedBit = min(gunBitis, bitToplam);
        if (clampedBit > clampedBas) {
          mesgulAraliklar.add([clampedBas, clampedBit]);
        }
      }

      mesgulAraliklar.sort((a, b) => a[0].compareTo(b[0]));
      final List<List<int>> birlesik = [];
      for (final aralik in mesgulAraliklar) {
        if (birlesik.isEmpty || aralik[0] > birlesik.last[1]) {
          birlesik.add([aralik[0], aralik[1]]);
        } else {
          birlesik.last[1] = max(birlesik.last[1], aralik[1]);
        }
      }

      int imlec = aktifBaslangic;
      for (final m in birlesik) {
        if (m[0] - imlec >= istenenSureDakika) {
          oneriler.add(
            _BosZamanDilimi(
              tarih: gun,
              baslangicDakika: imlec,
              bitisDakika: imlec + istenenSureDakika,
              toplamBoslukDakika: m[0] - imlec,
            ),
          );
          if (oneriler.length >= 5) break;
        }
        imlec = max(imlec, m[1]);
      }

      if (oneriler.length < 5 && gunBitis - imlec >= istenenSureDakika) {
        oneriler.add(
          _BosZamanDilimi(
            tarih: gun,
            baslangicDakika: imlec,
            bitisDakika: imlec + istenenSureDakika,
            toplamBoslukDakika: gunBitis - imlec,
          ),
        );
      }
    }

    return oneriler;
  }

  String _gunEtiketi(DateTime tarih) {
    final simdi = DateTime.now();
    final bugun = DateTime(simdi.year, simdi.month, simdi.day);
    final hedef = DateTime(tarih.year, tarih.month, tarih.day);
    final fark = hedef.difference(bugun).inDays;

    if (fark == 0) return 'bugun'.tr;
    if (fark == 1) return 'yarin'.tr;
    return '${tarih.day}.${tarih.month} ${'hafta_gun_${tarih.weekday}'.tr}';
  }

  String _sureFormatla(int dk) {
    if (dk < 60) return 'havuz_dk_kisa'.trParams({'dk': '$dk'});
    final saat = dk ~/ 60;
    final kalanDk = dk % 60;
    return kalanDk == 0
        ? 'havuz_saat_tam'.trParams({'saat': '$saat'})
        : 'havuz_saat_dk'.trParams({'saat': '$saat', 'dk': '$kalanDk'});
  }

  void _havuzIsEkle() {
    final metin = _isController.text.trim();
    if (metin.isEmpty) return;

    final yeni = _HavuzIs(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      baslik: metin[0].toUpperCase() + metin.substring(1),
      sureDakika: _secilenSure,
      acil: _acilMi,
      eklenmeTarihi: DateTime.now(),
    );

    setState(() {
      _isler.add(yeni);
      _siralaIsler();
      _aktifIsId = yeni.id;
      _acilMi = false;
    });
    _isleriKaydet();
    _isController.clear();
  }

  void _takvimeOturt(_HavuzIs isItem, _BosZamanDilimi dilim) {
    final yeniEtkinlik = Etkinlik(
      id: '${DateTime.now().millisecondsSinceEpoch}_havuz',
      baslik: isItem.baslik,
      aciklama: 'havuz_etkinlik_aciklama'.tr,
      saat: dilim.saatAraligi,
      tarih: dilim.tarih,
      yineleme: 'Tek seferlik',
      yinelemeBitis: null,
      katildim: false,
    );

    widget.onEtkinlikEkle(yeniEtkinlik);

    setState(() {
      _isler.removeWhere((e) => e.id == isItem.id);
      _aktifIsId = _isler.isNotEmpty ? _isler.first.id : null;
    });
    _isleriKaydet();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.deepPurple,
        content: Text(
          'havuz_takvime_eklendi_snackbar'.trParams({
            'baslik': isItem.baslik,
            'gun': _gunEtiketi(dilim.tarih),
            'saat': dilim.saatAraligi,
          }),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = AppRenkler.of(context);
    final altBosluk = MediaQuery.of(context).viewInsets.bottom;
    _HavuzIs? aktifIs;
    if (_isler.isNotEmpty) {
      aktifIs = _isler.firstWhere(
        (e) => e.id == _aktifIsId,
        orElse: () => _isler.first,
      );
    }

    final bosluklar =
        aktifIs != null ? _bosluklariBul(aktifIs.sureDakika) : <_BosZamanDilimi>[];

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + altBosluk),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: r.altMetin.withAlpha(110),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'havuz_baslik'.tr,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'havuz_alt_baslik'.tr,
                      style: TextStyle(fontSize: 12, color: r.altMetin),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: r.mor.withAlpha(r.isDark ? 60 : 24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'havuz_bekleyen_sayac'.trParams({'sayi': '${_isler.length}'}),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: r.morAcik,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Yeni Tarihsiz İş Ekleme Kutusu
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: r.kart,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: r.mor.withAlpha(90)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _isController,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _havuzIsEkle(),
                          decoration: InputDecoration(
                            hintText: 'havuz_is_hint'.tr,
                            hintStyle:
                                TextStyle(color: r.altMetin, fontSize: 13),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton.filled(
                        onPressed: _havuzIsEkle,
                        style: IconButton.styleFrom(
                            backgroundColor: Colors.deepPurple),
                        icon: const Icon(Icons.add_rounded,
                            size: 20, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final dk in [30, 60, 90, 120])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(
                                _sureFormatla(dk),
                                style: const TextStyle(fontSize: 11),
                              ),
                              selected: _secilenSure == dk,
                              selectedColor: Colors.deepPurple,
                              backgroundColor: r.ikincilKart,
                              side: BorderSide(
                                color: _secilenSure == dk
                                    ? Colors.deepPurple
                                    : r.kenarlik,
                              ),
                              labelStyle: TextStyle(
                                color: _secilenSure == dk
                                    ? Colors.white
                                    : r.solukMetin,
                                fontWeight: _secilenSure == dk
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              onSelected: (_) =>
                                  setState(() => _secilenSure = dk),
                            ),
                          ),
                        FilterChip(
                          label: Text('havuz_acil_chip'.tr,
                              style: const TextStyle(fontSize: 11)),
                          selected: _acilMi,
                          selectedColor:
                              r.kirmizi.withAlpha(r.isDark ? 180 : 35),
                          checkmarkColor: r.isDark ? Colors.white : r.kirmizi,
                          backgroundColor: r.ikincilKart,
                          side: BorderSide(
                            color: _acilMi ? r.kirmizi : r.kenarlik,
                          ),
                          labelStyle: TextStyle(
                            color: _acilMi
                                ? (r.isDark ? Colors.white : r.kirmizi)
                                : r.solukMetin,
                            fontWeight:
                                _acilMi ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (v) => setState(() => _acilMi = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Bekleyen İşler ve Akıllı Boşluk Önerileri
            Expanded(
              child: _isler.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_available_rounded,
                            size: 44,
                            color: r.mor,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'havuz_bos_baslik'.tr,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'havuz_bos_alt'.tr,
                            style: TextStyle(color: r.altMetin, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      children: [
                        Text(
                          'havuz_bekleyen_liste_baslik'.tr,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: r.altMetin,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._isler.map((item) {
                          final secili = aktifIs?.id == item.id;
                          return GestureDetector(
                            onTap: () => setState(() => _aktifIsId = item.id),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: secili
                                    ? r.mor.withAlpha(r.isDark ? 55 : 22)
                                    : r.kart,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: secili ? r.mor : r.kenarlik,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    item.acil
                                        ? Icons.local_fire_department_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: item.acil ? r.kirmizi : r.morAcik,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.baslik,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          'havuz_tahmini_sure_alt'.trParams({
                                            'sure': _sureFormatla(item.sureDakika),
                                            'oncelik': item.acil
                                                ? 'havuz_oncelikli_ek'.tr
                                                : '',
                                          }),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: r.altMetin,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: r.altMetin,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isler
                                            .removeWhere((e) => e.id == item.id);
                                        if (_aktifIsId == item.id) {
                                          _aktifIsId = _isler.isNotEmpty
                                              ? _isler.first.id
                                              : null;
                                        }
                                      });
                                      _isleriKaydet();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        if (aktifIs != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            'havuz_bosluk_baslik'
                                .trParams({'baslik': aktifIs.baslik}),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: r.sari,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (bosluklar.isEmpty)
                            Text(
                              'havuz_bosluk_yok'.tr,
                              style: TextStyle(color: r.altMetin, fontSize: 12),
                            )
                          else
                            ...bosluklar.map((dilim) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: r.tamamlananKart,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: r.yesil.withAlpha(90),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.auto_awesome_rounded,
                                      color: r.yesil,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${_gunEtiketi(dilim.tarih)} • ${dilim.saatAraligi}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            'havuz_bosluk_aciklama'.trParams({
                                              'sure': _sureFormatla(
                                                  dilim.toplamBoslukDakika),
                                            }),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: r.altMetin,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                      ),
                                      onPressed: () =>
                                          _takvimeOturt(aktifIs!, dilim),
                                      child: Text(
                                        'havuz_takvime_oturt'.tr,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}