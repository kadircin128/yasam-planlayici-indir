import 'package:flutter/material.dart';
import '../models/etkinlik.dart';
import '../models/finans_item.dart';
import '../models/gun_notu.dart';
import '../services/akilli_asistan_servisi.dart';
import '../services/dil_servisi.dart';
import '../widgets/sayfa_kilavuzu.dart';
import '../theme/app_renkler.dart';

class TakvimEkrani extends StatefulWidget {
  final List<Etkinlik> etkinlikler;
  final List<FinansItem> finansIslemleri;
  final List<GunNotu> gunNotlari;
  final Function(Etkinlik) onEtkinlikEkle;
  final Function(int, Etkinlik) onEtkinlikDuzenle;
  final Function(int) onEtkinlikSil;
  final Function(Etkinlik, DateTime)? onEtkinlikTekGunIptal;
  final Function(int, DateTime) onDurumDegistir;
  final Function(GunNotu) onGunNotuEkle;
  final Function(FinansItem)? onFinansEkle;
  final Function(FinansItem)? onFinansOdendiToggle;
  final Function(FinansItem)? onFinansSil;
  final Function(FinansItem, DateTime)? onFinansTekGunIptal;

  const TakvimEkrani({
    super.key,
    required this.etkinlikler,
    required this.finansIslemleri,
    required this.gunNotlari,
    required this.onEtkinlikEkle,
    required this.onEtkinlikDuzenle,
    required this.onEtkinlikSil,
    this.onEtkinlikTekGunIptal,
    required this.onDurumDegistir,
    required this.onGunNotuEkle,
    this.onFinansEkle,
    this.onFinansOdendiToggle,
    this.onFinansSil,
    this.onFinansTekGunIptal,
  });

  @override
  State<TakvimEkrani> createState() => _TakvimEkraniState();
}

class _OzelGunInfo {
  final String ad;
  final String ikon;
  final Color renk;
  final Color? arkaPlan;

  _OzelGunInfo({
    required this.ad,
    required this.ikon,
    required this.renk,
    this.arkaPlan,
  });
}

class _FinansTakvimStil {
  final IconData ikon;
  final Color renk;
  final String etiket;

  _FinansTakvimStil({
    required this.ikon,
    required this.renk,
    required this.etiket,
  });
}

class _TakvimEkraniState extends State<TakvimEkrani> {
  DateTime _secilenTarih = DateTime.now();
  DateTime _gosterilenAy = DateTime.now();

  final GlobalKey _keyEtkinlikEkle = GlobalKey();
  final GlobalKey _keyTakvimAlani = GlobalKey();
  final GlobalKey _keyGunNotu = GlobalKey();
  final GlobalKey _keyGunAkisi = GlobalKey();

  final TextEditingController _baslikController = TextEditingController();
  final TextEditingController _aciklamaController = TextEditingController();
  final TextEditingController _notController = TextEditingController();

  String _baslangicSaat = '09';
  String _baslangicDakika = '00';
  String _bitisSaat = '10';
  String _bitisDakika = '00';
  String _secilenYineleme = 'Tek seferlik';
  List<int> _seciliGunler = [5, 6, 7];

  final List<String> _saatler =
      List.generate(24, (i) => i.toString().padLeft(2, '0'));
  final List<String> _dakikalar =
      List.generate(12, (i) => (i * 5).toString().padLeft(2, '0'));

  final List<String> _yinelemeSecenekleri = [
    'Tek seferlik',
    'Her gün',
    'Hafta içi',
    'Hafta sonu',
    'Haftanın Günleri',
    'Haftada bir',
    'Ayda bir',
    'Yılda bir (Doğum Günü / Özel Gün)',
    'Her ayın ilk günü',
    'Her ayın son günü',
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
          key: _keyTakvimAlani,
          ikon: Icons.calendar_month_rounded,
          baslik: 'takvim_kilavuz_takvim_baslik'.tr,
          aciklama: 'takvim_kilavuz_takvim_aciklama'.tr,
        ),
        KilavuzAdimi(
          key: _keyEtkinlikEkle,
          ikon: Icons.add_task_rounded,
          baslik: 'takvim_kilavuz_ekle_baslik'.tr,
          aciklama: 'takvim_kilavuz_ekle_aciklama'.tr,
        ),
        KilavuzAdimi(
          key: _keyGunNotu,
          ikon: Icons.edit_note_rounded,
          baslik: 'takvim_kilavuz_not_baslik'.tr,
          aciklama: 'takvim_kilavuz_not_aciklama'.tr,
        ),
        KilavuzAdimi(
          key: _keyGunAkisi,
          ikon: Icons.checklist_rounded,
          baslik: 'takvim_kilavuz_akis_baslik'.tr,
          aciklama: 'takvim_kilavuz_akis_aciklama'.tr,
        ),
      ];

  void _kilavuzuBaslat() {
    SayfaKilavuzu.goster(
      context: context,
      sayfaId: 'takvim',
      adimlar: _kilavuzAdimlari(),
    );
  }

  @override
  void initState() {
    super.initState();
    SayfaKilavuzu.ilkGirisKontrolEt(
      context: context,
      sayfaId: 'takvim',
      adimlar: _kilavuzAdimlari(),
    );
  }

  @override
  void dispose() {
    _baslikController.dispose();
    _aciklamaController.dispose();
    _notController.dispose();
    super.dispose();
  }

  _OzelGunInfo? _ozelGunKontrol(AppRenkler r, DateTime tarih) {
    final int m = tarih.month;
    final int d = tarih.day;

    if (m == 10 && d == 29) {
      return _OzelGunInfo(
        ad: 'ozel_gun_29_ekim'.tr,
        ikon: '🇹🇷',
        renk: r.kirmizi,
        arkaPlan: r.isDark ? const Color(0xFF4A0E0E) : const Color(0xFFFEE2E2),
      );
    }
    if (m == 11 && d == 10) {
      return _OzelGunInfo(
        ad: 'ozel_gun_10_kasim'.tr,
        ikon: '🖤',
        renk: r.isDark ? Colors.grey.shade400 : Colors.grey.shade800,
        arkaPlan: r.isDark ? const Color(0xFF151515) : const Color(0xFFE5E7EB),
      );
    }
    if (m == 4 && d == 23) {
      return _OzelGunInfo(
        ad: 'ozel_gun_23_nisan'.tr,
        ikon: '🎈',
        renk: r.kirmizi,
        arkaPlan: r.isDark ? const Color(0xFF3B1515) : const Color(0xFFFEE2E2),
      );
    }
    if (m == 5 && d == 19) {
      return _OzelGunInfo(
        ad: 'ozel_gun_19_mayis'.tr,
        ikon: '🏃',
        renk: r.kirmizi,
        arkaPlan: r.isDark ? const Color(0xFF3B1515) : const Color(0xFFFEE2E2),
      );
    }
    if (m == 8 && d == 30) {
      return _OzelGunInfo(
        ad: 'ozel_gun_30_agustos'.tr,
        ikon: '🎖️',
        renk: r.kirmizi,
        arkaPlan: r.isDark ? const Color(0xFF3B1515) : const Color(0xFFFEE2E2),
      );
    }
    if (m == 7 && d == 15) {
      return _OzelGunInfo(
        ad: 'ozel_gun_15_temmuz'.tr,
        ikon: '🇹🇷',
        renk: r.kirmizi,
      );
    }
    if (m == 1 && d == 1) {
      return _OzelGunInfo(
        ad: 'ozel_gun_yilbasi'.tr,
        ikon: '🎆',
        renk: r.sari,
      );
    }
    return null;
  }

  bool _tarihlerAyniMi(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  _FinansTakvimStil _finansStilGetir(
      AppRenkler r, FinansItem f, DateTime hedefTarih) {
    final fTarih = DateTime(f.tarih.year, f.tarih.month, f.tarih.day);
    final hedef = DateTime(hedefTarih.year, hedefTarih.month, hedefTarih.day);

    if (f.tur == 'Kredi Kartı') {
      final kesimMi = f.hesapKesimGunu != null && hedef.day == f.hesapKesimGunu;
      final sonOdemeMi = f.sonOdemeGunu != null && hedef.day == f.sonOdemeGunu;
      final odemeGunuMu =
          (f.odendi || f.odenenMiktar > 0) && _tarihlerAyniMi(fTarih, hedef);

      if (odemeGunuMu && !kesimMi && !sonOdemeMi) {
        return _FinansTakvimStil(
          ikon: Icons.check_circle_rounded,
          renk: r.yesil,
          etiket: 'takvim_kart_odendi'.tr,
        );
      }
      if (sonOdemeMi) {
        return _FinansTakvimStil(
          ikon: Icons.credit_card_rounded,
          renk: r.mavi,
          etiket: (f.odendi || f.odenenMiktar > 0)
              ? 'takvim_son_odeme_odendi'.tr
              : 'takvim_son_odeme_asgari'.tr,
        );
      }
      return _FinansTakvimStil(
        ikon: Icons.credit_score_rounded,
        renk: r.acikMavi,
        etiket: 'takvim_ekstre_kesim'.tr,
      );
    }

    switch (f.tur) {
      case 'Gelir':
        return _FinansTakvimStil(
          ikon: Icons.trending_up_rounded,
          renk: r.yesil,
          etiket: 'finans_tur_gelir'.tr,
        );
      case 'Alacak':
        return _FinansTakvimStil(
          ikon: Icons.account_balance_wallet_rounded,
          renk: r.turkuaz,
          etiket: 'finans_tur_alacak'.tr,
        );
      case 'Fatura':
        return _FinansTakvimStil(
          ikon: Icons.receipt_long_rounded,
          renk: r.turuncu,
          etiket: f.otomatikOdemede
              ? 'takvim_fatura_otomatik'.tr
              : 'finans_tur_fatura'.tr,
        );
      case 'Borç':
        return _FinansTakvimStil(
          ikon: Icons.handshake_rounded,
          renk: r.pembe,
          etiket: 'finans_tur_borc'.tr,
        );
      case 'Gider':
      default:
        return _FinansTakvimStil(
          ikon: Icons.shopping_bag_rounded,
          renk: r.kirmizi,
          etiket: 'finans_tur_gider'.tr,
        );
    }
  }

  void _notEkleDialog() {
    final r = AppRenkler.of(context);
    GunNotu? mevcutNot;
    try {
      mevcutNot = widget.gunNotlari
          .firstWhere((n) => _tarihlerAyniMi(n.tarih, _secilenTarih));
      _notController.text = mevcutNot.metin;
    } catch (_) {
      _notController.clear();
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: r.dialog,
          title: Text('takvim_not_dialog_baslik'.trParams({
            'tarih':
                '${_secilenTarih.day}.${_secilenTarih.month}.${_secilenTarih.year}',
          })),
          content: TextField(
            controller: _notController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'takvim_not_hint'.tr,
              filled: true,
              fillColor: r.ikincilKart,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('iptal'.tr, style: TextStyle(color: r.altMetin))),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
              onPressed: () {
                if (_notController.text.isNotEmpty) {
                  widget.onGunNotuEkle(GunNotu(
                      id: DateTime.now().toString(),
                      metin: _notController.text,
                      tarih: _secilenTarih));
                  Navigator.pop(context);
                }
              },
              child:
                  Text('kaydet'.tr, style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _etkinlikFormDialog({int? duzenlenecekIndex, Etkinlik? mevcutEtkinlik}) {
    final r = AppRenkler.of(context);
    final duzenlemeModu = mevcutEtkinlik != null && duzenlenecekIndex != null;

    DateTime etkinlikTarihi =
        duzenlemeModu ? mevcutEtkinlik.tarih : _secilenTarih;
    DateTime? yinelemeBitisTarihi =
        duzenlemeModu ? mevcutEtkinlik.yinelemeBitis : null;

    _baslikController.text = duzenlemeModu ? mevcutEtkinlik.baslik : '';
    _aciklamaController.text = duzenlemeModu ? mevcutEtkinlik.aciklama : '';

    final TextEditingController mesaiGeliriController = TextEditingController();
    bool mesaiGeliriEkle = false;
    bool saatEkle = duzenlemeModu
        ? (mevcutEtkinlik.saat != 'Tüm Gün' &&
            mevcutEtkinlik.saat != 'tum_gun'.tr)
        : false;
    bool kaydediliyor = false;

    if (duzenlemeModu && mevcutEtkinlik.saat.contains(' - ')) {
      final parcalar = mevcutEtkinlik.saat.split(' - ');
      final bas = parcalar[0].split(':');
      final bit = parcalar[1].split(':');
      if (bas.length == 2 && bit.length == 2) {
        _baslangicSaat = bas[0];
        _baslangicDakika = bas[1];
        _bitisSaat = bit[0];
        _bitisDakika = bit[1];
      }
    }

    if (duzenlemeModu &&
        mevcutEtkinlik.yineleme.startsWith('Haftanın Günleri')) {
      _secilenYineleme = 'Haftanın Günleri';
      _seciliGunler = _gunKisaAdlar.entries
          .where((e) => mevcutEtkinlik.yineleme.contains(e.value))
          .map((e) => e.key)
          .toList();
      if (_seciliGunler.isEmpty) {
        _seciliGunler = [5, 6, 7];
      }
    } else {
      _secilenYineleme =
          duzenlemeModu ? mevcutEtkinlik.yineleme : 'Tek seferlik';
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: r.dialog,
              title: Text(duzenlemeModu
                  ? 'takvim_etkinlik_duzenle_baslik'.tr
                  : 'takvim_etkinlik_ekle_baslik'.tr),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () async {
                        final secilen = await showDatePicker(
                            context: context,
                            initialDate: etkinlikTarihi,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030));
                        if (secilen != null) {
                          setDialogState(() => etkinlikTarihi = secilen);
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
                                'takvim_baslangic_tarihi'.trParams({
                                  'tarih':
                                      '${etkinlikTarihi.day}.${etkinlikTarihi.month}.${etkinlikTarihi.year}',
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
                            labelText: 'takvim_baslik_etiket'.tr,
                            hintText: 'takvim_baslik_hint'.tr)),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _aciklamaController,
                        maxLines: 2,
                        decoration: InputDecoration(
                            labelText: 'takvim_aciklama_etiket'.tr,
                            hintText: 'takvim_aciklama_hint'.tr)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _yinelemeSecenekleri.contains(_secilenYineleme)
                          ? _secilenYineleme
                          : 'Tek seferlik',
                      isExpanded: true,
                      dropdownColor: r.dialog,
                      decoration: InputDecoration(
                          labelText: 'yineleme_tekrar'.tr,
                          prefixIcon: Icon(Icons.repeat_rounded, color: r.mor)),
                      items: _yinelemeSecenekleri
                          .map((y) =>
                              DropdownMenuItem(value: y, child: Text(y.tr)))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => _secilenYineleme = v!),
                    ),
                    if (_secilenYineleme == 'Haftanın Günleri') ...[
                      const SizedBox(height: 10),
                      Text('tekrar_gun_sec'.tr,
                          style: TextStyle(fontSize: 12, color: r.altMetin)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [1, 2, 3, 4, 5, 6, 7].map((g) {
                          final secili = _seciliGunler.contains(g);
                          return FilterChip(
                            label: Text(_gunKisaAdlar[g]!,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: secili ? Colors.white : r.altMetin,
                                    fontWeight: secili
                                        ? FontWeight.bold
                                        : FontWeight.normal)),
                            selected: secili,
                            selectedColor: Colors.deepPurple,
                            backgroundColor: r.ikincilKart,
                            onSelected: (val) {
                              setDialogState(() {
                                if (val) {
                                  _seciliGunler.add(g);
                                } else if (_seciliGunler.length > 1) {
                                  _seciliGunler.remove(g);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('takvim_saat_ekle'.tr,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          saatEkle
                              ? 'takvim_saat_araligi_acik'.tr
                              : 'takvim_tum_gun_acik'.tr,
                          style: TextStyle(color: r.altMetin, fontSize: 12)),
                      value: saatEkle,
                      activeColor: r.mor,
                      onChanged: (val) => setDialogState(() => saatEkle = val),
                    ),
                    if (saatEkle) ...[
                      const SizedBox(height: 8),
                      Text('takvim_baslangic_zamani'.tr,
                          style: TextStyle(color: r.altMetin, fontSize: 13)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                              child: DropdownButtonFormField<String>(
                                  value: _baslangicSaat,
                                  dropdownColor: r.dialog,
                                  decoration:
                                      InputDecoration(labelText: 'saat'.tr),
                                  items: _saatler
                                      .map((s) => DropdownMenuItem(
                                          value: s, child: Text(s)))
                                      .toList(),
                                  onChanged: (v) =>
                                      setDialogState(() => _baslangicSaat = v!))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: DropdownButtonFormField<String>(
                                  value: _baslangicDakika,
                                  dropdownColor: r.dialog,
                                  decoration:
                                      InputDecoration(labelText: 'dakika'.tr),
                                  items: _dakikalar
                                      .map((d) => DropdownMenuItem(
                                          value: d, child: Text(d)))
                                      .toList(),
                                  onChanged: (v) => setDialogState(
                                      () => _baslangicDakika = v!))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('takvim_bitis_zamani'.tr,
                          style: TextStyle(color: r.altMetin, fontSize: 13)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                              child: DropdownButtonFormField<String>(
                                  value: _bitisSaat,
                                  dropdownColor: r.dialog,
                                  decoration:
                                      InputDecoration(labelText: 'saat'.tr),
                                  items: _saatler
                                      .map((s) => DropdownMenuItem(
                                          value: s, child: Text(s)))
                                      .toList(),
                                  onChanged: (v) =>
                                      setDialogState(() => _bitisSaat = v!))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: DropdownButtonFormField<String>(
                                  value: _bitisDakika,
                                  dropdownColor: r.dialog,
                                  decoration:
                                      InputDecoration(labelText: 'dakika'.tr),
                                  items: _dakikalar
                                      .map((d) => DropdownMenuItem(
                                          value: d, child: Text(d)))
                                      .toList(),
                                  onChanged: (v) =>
                                      setDialogState(() => _bitisDakika = v!))),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('takvim_mesai_geliri_ekle'.tr,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: Text('takvim_mesai_geliri_aciklama'.tr,
                          style: TextStyle(color: r.altMetin, fontSize: 12)),
                      value: mesaiGeliriEkle,
                      activeColor: r.yesil,
                      onChanged: (val) =>
                          setDialogState(() => mesaiGeliriEkle = val),
                    ),
                    if (mesaiGeliriEkle) ...[
                      TextField(
                        controller: mesaiGeliriController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'takvim_mesai_ucreti_etiket'.tr,
                          hintText: 'takvim_mesai_ucreti_hint'.tr,
                          prefixIcon:
                              Icon(Icons.attach_money_rounded, color: r.yesil),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('iptal'.tr, style: TextStyle(color: r.altMetin))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple),
                  onPressed: () {
                    if (kaydediliyor) return;
                    if (_baslikController.text.isNotEmpty) {
                      kaydediliyor = true;
                      final saatAraligi = saatEkle
                          ? '$_baslangicSaat:$_baslangicDakika - $_bitisSaat:$_bitisDakika'
                          : 'tum_gun'.tr;

                      String yinelemeMetni = _secilenYineleme;
                      if (_secilenYineleme == 'Haftanın Günleri') {
                        _seciliGunler.sort();
                        final seciliAdlar = _seciliGunler
                            .map((g) => _gunKisaAdlar[g])
                            .join(', ');
                        yinelemeMetni = 'Haftanın Günleri ($seciliAdlar)';
                      }

                      final yeniEtkinlik = Etkinlik(
                        id: duzenlemeModu
                            ? mevcutEtkinlik.id
                            : DateTime.now().toString(),
                        baslik: _baslikController.text,
                        aciklama: _aciklamaController.text,
                        saat: saatAraligi,
                        tarih: etkinlikTarihi,
                        yineleme: yinelemeMetni,
                        yinelemeBitis: yinelemeBitisTarihi,
                        iptalTarihler: duzenlemeModu
                            ? mevcutEtkinlik.iptalTarihler
                            : const [],
                        tamamlananTarihler: duzenlemeModu
                            ? mevcutEtkinlik.tamamlananTarihler
                            : const [],
                        katildim:
                            duzenlemeModu ? mevcutEtkinlik.katildim : false,
                      );

                      if (duzenlemeModu) {
                        widget.onEtkinlikDuzenle(
                            duzenlenecekIndex, yeniEtkinlik);
                      } else {
                        widget.onEtkinlikEkle(yeniEtkinlik);
                      }

                      if (mesaiGeliriEkle && widget.onFinansEkle != null) {
                        final ucret = double.tryParse(
                            mesaiGeliriController.text.replaceAll(',', '.'));
                        if (ucret != null && ucret > 0) {
                          widget.onFinansEkle!(
                            FinansItem(
                              id: '${DateTime.now().microsecondsSinceEpoch}_${etkinlikTarihi.millisecondsSinceEpoch}',
                              baslik: 'takvim_mesai_geliri_baslik'
                                  .trParams({'baslik': _baslikController.text}),
                              miktar: ucret,
                              tur: 'Gelir',
                              tarih: etkinlikTarihi,
                              yineleme: yinelemeMetni,
                            ),
                          );
                        }
                      }

                      _baslikController.clear();
                      _aciklamaController.clear();
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

  void _finansSilOnayi(AppRenkler r, FinansItem f, DateTime gun) {
    if (f.yineleme == 'Tek seferlik') {
      widget.onFinansSil?.call(f);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: r.dialog,
        title: Text('takvim_tekrarli_finans_sil_baslik'.tr),
        content: Text(
          'takvim_tekrarli_finans_sil_icerik'.trParams({
            'baslik': f.baslik,
            'tarih': '${gun.day}.${gun.month}',
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('vazgec'.tr, style: TextStyle(color: r.altMetin)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onFinansSil?.call(f);
            },
            child: Text('tumunu_sil'.tr, style: TextStyle(color: r.kirmizi)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (widget.onFinansTekGunIptal != null) {
                widget.onFinansTekGunIptal!(f, gun);
              } else {
                widget.onFinansSil?.call(f);
              }
            },
            child: Text('sadece_bu_gunu_sil'.tr),
          ),
        ],
      ),
    );
  }

  void _etkinlikSilOnayi(AppRenkler r, Etkinlik e, int index, DateTime gun) {
    if (e.yineleme == 'Tek seferlik') {
      widget.onEtkinlikSil(index);
      return;
    }

    final bagliFinanslar = widget.finansIslemleri.where((f) {
      if (f.yineleme == 'Tek seferlik') return false;
      if (!f.takvimdeOgunMu(gun)) return false;
      final baslikNorm = e.baslik.toLowerCase().trim();
      final finansNorm = f.baslik.toLowerCase().trim();
      return finansNorm.contains('mesai geliri') ||
          finansNorm.contains('yevmiye') ||
          finansNorm.contains('mesai') ||
          (baslikNorm.isNotEmpty && finansNorm.contains(baslikNorm));
    }).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: r.dialog,
        title: Text('takvim_tekrarli_etkinlik_sil_baslik'.tr),
        content: Text(
          'takvim_tekrarli_etkinlik_sil_icerik'.trParams({
            'baslik': e.baslik,
            'mesaiEk': bagliFinanslar.isNotEmpty
                ? 'takvim_bagli_mesai_ek'.tr
                : '',
            'tarih': '${gun.day}.${gun.month}',
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('vazgec'.tr, style: TextStyle(color: r.altMetin)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onEtkinlikSil(index);
            },
            child: Text('tumunu_sil'.tr, style: TextStyle(color: r.kirmizi)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (widget.onEtkinlikTekGunIptal != null) {
                widget.onEtkinlikTekGunIptal!(e, gun);
                for (final f in bagliFinanslar) {
                  widget.onFinansTekGunIptal?.call(f, gun);
                }
              } else {
                widget.onEtkinlikSil(index);
              }
            },
            child: Text('sadece_bu_gunu_sil'.tr),
          ),
        ],
      ),
    );
  }

  Widget _buildNoktaliTakvim(
    AppRenkler r, {
    required double alanGenisligi,
    required bool genisEkran,
  }) {
    final bugun = DateTime.now();
    final ilkGun = DateTime(_gosterilenAy.year, _gosterilenAy.month, 1);
    final ayinGunSayisi =
        DateTime(_gosterilenAy.year, _gosterilenAy.month + 1, 0).day;
    final baslangicBoslugu = ilkGun.weekday - 1;

    final ayAdi = 'ay_${_gosterilenAy.month}'.tr;

    final double icPadding = genisEkran ? 14.0 : 10.0;
    final double hucreAralik = genisEkran ? 6.0 : 4.0;
    final double netGenislik =
        (alanGenisligi - (icPadding * 2) - (hucreAralik * 6))
            .clamp(180.0, 1200.0);
    final double hucreGenislik = netGenislik / 7.0;
    final double hedefHucreYuksekligi = genisEkran ? 44.0 : 33.0;
    final double dinamikOran =
        (hucreGenislik / hedefHucreYuksekligi).clamp(1.25, 2.6);

    final bool bugunSeciliMi = _tarihlerAyniMi(_secilenTarih, bugun) &&
        _gosterilenAy.year == bugun.year &&
        _gosterilenAy.month == bugun.month;

    return Container(
      key: _keyTakvimAlani,
      padding: EdgeInsets.all(icPadding),
      decoration: BoxDecoration(
        color: r.kart,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: r.kenarlik, width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _gosterilenAy =
                    DateTime(_gosterilenAy.year, _gosterilenAy.month - 1)),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.chevron_left_rounded,
                      size: genisEkran ? 24 : 20),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$ayAdi ${_gosterilenAy.year}',
                    style: TextStyle(
                      fontSize: genisEkran ? 17 : 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!bugunSeciliMi) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() {
                        _secilenTarih = DateTime.now();
                        _gosterilenAy = DateTime.now();
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: r.mor.withAlpha(r.isDark ? 45 : 25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: r.mor),
                        ),
                        child: Text(
                          'bugun'.tr,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: r.morAcik,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _gosterilenAy =
                    DateTime(_gosterilenAy.year, _gosterilenAy.month + 1)),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.chevron_right_rounded,
                      size: genisEkran ? 24 : 20),
                ),
              ),
            ],
          ),
          SizedBox(height: genisEkran ? 10 : 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [1, 2, 3, 4, 5, 6, 7]
                .map((g) => Expanded(
                      child: Text(
                        'gun_kisa_$g'.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: r.altMetin,
                          fontSize: genisEkran ? 12 : 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ))
                .toList(),
          ),
          SizedBox(height: genisEkran ? 8 : 5),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: baslangicBoslugu + ayinGunSayisi,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: hucreAralik,
              crossAxisSpacing: hucreAralik,
              childAspectRatio: dinamikOran,
            ),
            itemBuilder: (context, index) {
              if (index < baslangicBoslugu) return const SizedBox();

              final gunSayisi = index - baslangicBoslugu + 1;
              final oGun =
                  DateTime(_gosterilenAy.year, _gosterilenAy.month, gunSayisi);
              final seciliMi = _tarihlerAyniMi(oGun, _secilenTarih);
              final bugunMu = _tarihlerAyniMi(oGun, bugun);
              final ozelGun = _ozelGunKontrol(r, oGun);

              final varEtkinlik =
                  widget.etkinlikler.any((e) => e.oGunAktifMi(oGun));
              final varNot =
                  widget.gunNotlari.any((n) => _tarihlerAyniMi(n.tarih, oGun));
              final gununFinanslari = widget.finansIslemleri
                  .where((f) => f.takvimdeOgunMu(oGun))
                  .toList();

              final varGelir = gununFinanslari
                  .any((f) => f.tur == 'Gelir' || f.tur == 'Alacak');
              final varFaturaVeyaKart = gununFinanslari
                  .any((f) => f.tur == 'Fatura' || f.tur == 'Kredi Kartı');
              final varGider = gununFinanslari
                  .any((f) => f.tur == 'Gider' || f.tur == 'Borç');

              Color kutuRengi = seciliMi ? Colors.deepPurple : r.takvimKutu;
              if (!seciliMi && ozelGun?.arkaPlan != null) {
                kutuRengi = ozelGun!.arkaPlan!;
              }

              final double ikonBoyutu = genisEkran ? 10.0 : 8.5;

              return InkWell(
                onTap: () => setState(() => _secilenTarih = oGun),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: kutuRengi,
                    borderRadius: BorderRadius.circular(8),
                    border: seciliMi
                        ? Border.all(color: r.mor, width: 1.8)
                        : (bugunMu
                            ? Border.all(color: r.morAcik, width: 1.4)
                            : (ozelGun != null
                                ? Border.all(
                                    color: ozelGun.renk.withAlpha(120),
                                    width: 1)
                                : Border.all(color: r.kenarlik, width: 0.7))),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$gunSayisi',
                            style: TextStyle(
                              fontSize: genisEkran ? 13 : 12,
                              height: 1.05,
                              fontWeight: (seciliMi || bugunMu || ozelGun != null)
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: seciliMi
                                  ? Colors.white
                                  : (ozelGun != null
                                      ? ozelGun.renk
                                      : r.solukMetin),
                            ),
                          ),
                          if (ozelGun != null) ...[
                            const SizedBox(width: 2),
                            Text(
                              ozelGun.ikon,
                              style: TextStyle(fontSize: genisEkran ? 9 : 8),
                            ),
                          ],
                        ],
                      ),
                      if (varNot ||
                          varEtkinlik ||
                          varGelir ||
                          varFaturaVeyaKart ||
                          varGider) ...[
                        const SizedBox(height: 1.5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (varNot)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 0.5),
                                child: Icon(Icons.edit_note_rounded,
                                    size: ikonBoyutu, color: r.morAcik),
                              ),
                            if (varEtkinlik)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 0.5),
                                child: Icon(Icons.event_rounded,
                                    size: ikonBoyutu - 0.5, color: r.camgobegi),
                              ),
                            if (varGelir)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 0.5),
                                child: Icon(Icons.trending_up_rounded,
                                    size: ikonBoyutu, color: r.yesil),
                              ),
                            if (varFaturaVeyaKart)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 0.5),
                                child: Icon(Icons.receipt_long_rounded,
                                    size: ikonBoyutu - 0.5, color: r.turuncu),
                              ),
                            if (varGider)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 0.5),
                                child: Icon(Icons.trending_down_rounded,
                                    size: ikonBoyutu, color: r.kirmizi),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGunAkisiListesi({
    required AppRenkler r,
    required List<Etkinlik> gununEtkinlikleri,
    required List<FinansItem> gununFinanslari,
    required _OzelGunInfo? seciliOzelGun,
    required GunNotu? gununNotu,
    required bool kaydirilabilir,
    bool kutuCerveli = false,
  }) {
    final bugunMu = _tarihlerAyniMi(_secilenTarih, DateTime.now());

    final ogeler = <Widget>[
      if (seciliOzelGun != null) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: seciliOzelGun.arkaPlan ?? r.acilKart,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: seciliOzelGun.renk.withAlpha(180)),
          ),
          child: Row(
            children: [
              Text(seciliOzelGun.ikon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  seciliOzelGun.ad,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: seciliOzelGun.renk),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
      Card(
        key: _keyGunNotu,
        color: r.notKart,
        margin: EdgeInsets.zero,
        elevation: r.isDark ? 1 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: r.kenarlik),
        ),
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: CircleAvatar(
              radius: 17,
              backgroundColor: r.morAcik,
              child: const Icon(Icons.edit_note_rounded,
                  color: Colors.white, size: 19)),
          title: Text(
              gununNotu != null
                  ? 'takvim_gunun_notu'.tr
                  : 'takvim_not_ekle_hatirlatici'.tr,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text(
              gununNotu?.metin ?? 'takvim_not_alt_bos'.tr,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  color: gununNotu != null ? r.solukMetin : r.altMetin)),
          trailing: IconButton(
              icon: Icon(
                  gununNotu != null ? Icons.edit : Icons.add_circle_outline,
                  color: r.morAcik,
                  size: 20),
              onPressed: _notEkleDialog),
        ),
      ),
      const SizedBox(height: 12),
      Container(
        key: _keyGunAkisi,
        child: Row(
          children: [
            Expanded(
              child: Text(
                'takvim_gun_akisi_baslik'.trParams({
                  'tarih':
                      '${_secilenTarih.day}.${_secilenTarih.month}.${_secilenTarih.year}',
                }),
                style:
                    const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
              ),
            ),
            if (bugunMu)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: r.mor.withAlpha(r.isDark ? 45 : 25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: r.mor),
                ),
                child: Text(
                  'bugun_buyuk'.tr,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: r.morAcik,
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      if (gununEtkinlikleri.isEmpty && gununFinanslari.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text(
              'takvim_gun_bos'.tr,
              style: TextStyle(color: r.altMetin, fontSize: 13),
            ),
          ),
        )
      else ...[
        ...gununFinanslari.map((f) {
          final stil = _finansStilGetir(r, f, _secilenTarih);
          final isPozitif = f.tur == 'Gelir' || f.tur == 'Alacak';
          final isKartKesim = f.tur == 'Kredi Kartı' &&
              f.hesapKesimGunu != null &&
              _secilenTarih.day == f.hesapKesimGunu;

          String tutarYazisi = '';
          if (f.tur == 'Kredi Kartı') {
            if (isKartKesim && !f.ekstreGirildi) {
              tutarYazisi = 'takvim_kesim_etiket'.tr;
            } else if (f.odendi || f.odenenMiktar > 0) {
              tutarYazisi =
                  '-${(f.odenenMiktar > 0 ? f.odenenMiktar : f.miktar).toStringAsFixed(0)} ₺';
            } else {
              tutarYazisi = 'takvim_asgari_tutar'.trParams(
                  {'tutar': f.tahminiOdeme.toStringAsFixed(0)});
            }
          } else if (f.tur == 'Fatura' &&
              f.isDegiskenFatura &&
              !f.ekstreGirildi) {
            tutarYazisi = 'takvim_tahmini_tutar'.trParams(
                {'tutar': f.tahminiOdeme.toStringAsFixed(0)});
          } else {
            tutarYazisi =
                '${isPozitif ? '+' : '-'}${f.miktar.toStringAsFixed(0)} ₺';
          }

          return Card(
            color: kutuCerveli ? r.ikincilKart : r.kart,
            elevation: r.isDark ? 1 : 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: stil.renk.withAlpha(80)),
            ),
            child: ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: stil.renk.withAlpha(30),
                child: Icon(stil.ikon, color: stil.renk, size: 20),
              ),
              title: Text(
                f.baslik,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  decoration: f.odendi ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: Text(
                '${stil.etiket}${f.odendi ? 'takvim_odendi_ek'.tr : ''}',
                style: TextStyle(color: r.altMetin, fontSize: 11.5),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tutarYazisi,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: stil.renk,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    icon: Icon(
                      f.odendi
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: f.odendi ? r.yesil : r.altMetin,
                      size: 19,
                    ),
                    onPressed: () => widget.onFinansOdendiToggle?.call(f),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: r.kirmizi,
                      size: 19,
                    ),
                    onPressed: () => _finansSilOnayi(r, f, _secilenTarih),
                  ),
                ],
              ),
            ),
          );
        }),
        ...gununEtkinlikleri.map((item) {
          final index = widget.etkinlikler.indexOf(item);
          final oGunTamamlandi = item.oGunTamamlandiMi(_secilenTarih);

          String detayMetni = item.saatEtiketi;
          if (item.yineleme != 'Tek seferlik') {
            detayMetni += ' • 🔄 ${item.yinelemeEtiketi}';
          }
          if (item.aciklama.isNotEmpty) {
            detayMetni +=
                '\n${'takvim_not_onek'.trParams({'not': item.aciklama})}';
          }

          return Card(
            color: kutuCerveli ? r.ikincilKart : r.kart,
            elevation: r.isDark ? 1 : 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: r.kenarlik),
            ),
            child: ListTile(
              dense: true,
              leading: const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.deepPurple,
                child: Icon(Icons.event_rounded, color: Colors.white, size: 18),
              ),
              title: Text(
                item.baslik,
                style: TextStyle(
                  fontSize: 13.5,
                  decoration:
                      oGunTamamlandi ? TextDecoration.lineThrough : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(detayMetni,
                  style: TextStyle(color: r.altMetin, fontSize: 11.5)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: Icon(Icons.edit_rounded, color: r.altMetin, size: 19),
                    onPressed: () => _etkinlikFormDialog(
                        duzenlenecekIndex: index, mevcutEtkinlik: item),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: Icon(Icons.delete_outline_rounded,
                        color: r.kirmizi, size: 19),
                    onPressed: () =>
                        _etkinlikSilOnayi(r, item, index, _secilenTarih),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: Icon(
                      oGunTamamlandi
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: oGunTamamlandi ? r.yesil : r.altMetin,
                      size: 19,
                    ),
                    onPressed: () => widget.onDurumDegistir(index, _secilenTarih),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
      const SizedBox(height: 16),
    ];

    final icerik = kaydirilabilir
        ? ListView(
            padding: EdgeInsets.zero,
            children: ogeler,
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: ogeler,
          );

    if (!kutuCerveli) return icerik;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: r.kart,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        border: Border.all(color: r.kenarlik, width: 1.2),
      ),
      child: icerik,
    );
  }

  Widget _buildUstBaslik(AppRenkler r, bool genisEkran) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'takvim_baslik'.tr,
                style: TextStyle(
                  fontSize: genisEkran ? 22 : 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'takvim_alt_baslik'.tr,
                style: TextStyle(
                  color: r.altMetin,
                  fontSize: genisEkran ? 13 : 11.5,
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KilavuzYardimButonu(onPressed: _kilavuzuBaslat),
            const SizedBox(width: 8),
            SizedBox(
              width: 36,
              height: 36,
              child: IconButton.filled(
                key: _keyEtkinlikEkle,
                padding: EdgeInsets.zero,
                onPressed: () => _etkinlikFormDialog(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = AppRenkler.of(context);
    final gununEtkinlikleri = widget.etkinlikler
        .where((e) => e.oGunAktifMi(_secilenTarih))
        .toList();
    final gununFinanslari = widget.finansIslemleri
        .where((f) => f.takvimdeOgunMu(_secilenTarih))
        .toList();
    final seciliOzelGun = _ozelGunKontrol(r, _secilenTarih);

    GunNotu? gununNotu;
    try {
      gununNotu = widget.gunNotlari
          .firstWhere((n) => _tarihlerAyniMi(n.tarih, _secilenTarih));
    } catch (_) {}

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool genisEkran = constraints.maxWidth >= 600;
        final bool yukseklikSinirli = constraints.hasBoundedHeight;
        final double disPadding = genisEkran ? 16.0 : 12.0;
        final double icerikGenisligi = constraints.maxWidth - (disPadding * 2);

        if (genisEkran) {
          final double solGenislik = (icerikGenisligi - 16.0) * (11 / 23);

          return Padding(
            padding: EdgeInsets.all(disPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUstBaslik(r, true),
                const SizedBox(height: 14),
                if (yukseklikSinirli)
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 11,
                          child: SingleChildScrollView(
                            child: _buildNoktaliTakvim(
                              r,
                              alanGenisligi: solGenislik,
                              genisEkran: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 12,
                          child: _buildGunAkisiListesi(
                            r: r,
                            gununEtkinlikleri: gununEtkinlikleri,
                            gununFinanslari: gununFinanslari,
                            seciliOzelGun: seciliOzelGun,
                            gununNotu: gununNotu,
                            kaydirilabilir: true,
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
                        child: _buildNoktaliTakvim(
                          r,
                          alanGenisligi: solGenislik,
                          genisEkran: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 12,
                        child: _buildGunAkisiListesi(
                          r: r,
                          gununEtkinlikleri: gununEtkinlikleri,
                          gununFinanslari: gununFinanslari,
                          seciliOzelGun: seciliOzelGun,
                          gununNotu: gununNotu,
                          kaydirilabilir: false,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(disPadding, disPadding, disPadding, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUstBaslik(r, false),
              const SizedBox(height: 10),
              _buildNoktaliTakvim(
                r,
                alanGenisligi: icerikGenisligi,
                genisEkran: false,
              ),
              const SizedBox(height: 10),
              if (yukseklikSinirli)
                Expanded(
                  child: _buildGunAkisiListesi(
                    r: r,
                    gununEtkinlikleri: gununEtkinlikleri,
                    gununFinanslari: gununFinanslari,
                    seciliOzelGun: seciliOzelGun,
                    gununNotu: gununNotu,
                    kaydirilabilir: true,
                    kutuCerveli: true,
                  ),
                )
              else
                _buildGunAkisiListesi(
                  r: r,
                  gununEtkinlikleri: gununEtkinlikleri,
                  gununFinanslari: gununFinanslari,
                  seciliOzelGun: seciliOzelGun,
                  gununNotu: gununNotu,
                  kaydirilabilir: false,
                  kutuCerveli: true,
                ),
            ],
          ),
        );
      },
    );
  }
}