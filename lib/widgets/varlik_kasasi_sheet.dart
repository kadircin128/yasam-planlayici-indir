import 'dart:async';
import 'package:flutter/material.dart';
import '../services/dil_servisi.dart';
import '../services/varlik_servisi.dart';
import '../theme/app_renkler.dart';

class VarlikKasasiSheet extends StatefulWidget {
  const VarlikKasasiSheet({super.key});

  @override
  State<VarlikKasasiSheet> createState() => _VarlikKasasiSheetState();
}

class _VarlikKasasiSheetState extends State<VarlikKasasiSheet> {
  final VarlikServisi _servis = VarlikServisi.instance;
  final TextEditingController _miktarController = TextEditingController();
  final TextEditingController _alisKuruController = TextEditingController();

  String _secilenSembol = 'USD';

  @override
  void initState() {
    super.initState();
    _servis.baslat();
  }

  @override
  void dispose() {
    _miktarController.dispose();
    _alisKuruController.dispose();
    super.dispose();
  }

  Color _tanimRenkGetir(AppRenkler r, String sembol, String kategori) {
    switch (sembol) {
      case 'USD':
        return r.yesil;
      case 'EUR':
        return r.acikMavi;
      case 'GBP':
        return r.mavi;
      case 'GRAM_ALTIN':
      case 'CEYREK_ALTIN':
      case 'YARIM_ALTIN':
      case 'TAM_ALTIN':
      case 'CUMHURIYET_ALTIN':
      case 'BILEZIK_22':
        return r.sari;
      case 'BTC':
        return r.isDark ? Colors.deepOrangeAccent : const Color(0xFFC2410C);
      case 'ETH':
        return r.morAcik;
      case 'SOL':
        return r.turkuaz;
    }

    switch (kategori) {
      case 'doviz':
        return r.yesil;
      case 'altin':
        return r.sari;
      case 'kripto':
        return r.morAcik;
      case 'hisse':
        return r.mavi;
      default:
        return r.yesil;
    }
  }

  String _kategoriEtiketi(String kategori) {
    switch (kategori) {
      case 'doviz':
        return 'varlik_kat_doviz'.tr;
      case 'altin':
        return 'varlik_kat_altin'.tr;
      case 'kripto':
        return 'varlik_kat_kripto'.tr;
      case 'hisse':
        return DilServisi.instance.dilKodu == 'tr' ? 'Hisse' : 'Stock';
      default:
        return kategori;
    }
  }

  Future<void> _varlikSeciciAc(AppRenkler r) async {
    final secilen = await showModalBottomSheet<VarlikTanim>(
      context: context,
      isScrollControlled: true,
      backgroundColor: r.dialog,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _VarlikSeciciModal(
        renkler: r,
        seciliSembol: _secilenSembol,
      ),
    );

    if (secilen != null && mounted) {
      setState(() {
        _secilenSembol = secilen.sembol;
      });
      if (_servis.kurGetir(secilen.sembol) <= 0 &&
          secilen.kategori == 'hisse') {
        final fiyat = await _servis.hisseFiyatiGetir(secilen.sembol);
        if (fiyat > 0 && mounted) {
          _servis.canliKurlariGuncelle();
        }
      }
    }
  }

  void _varlikEkle() {
    final miktar =
        double.tryParse(_miktarController.text.trim().replaceAll(',', '.')) ??
            0;
    if (miktar <= 0) return;

    final guncelKur = _servis.kurGetir(_secilenSembol);
    final girilenAlis = double.tryParse(
          _alisKuruController.text.trim().replaceAll(',', '.'),
        ) ??
        guncelKur;

    if (girilenAlis <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('varlik_kur_bekleniyor_snackbar'.tr),
        ),
      );
      return;
    }

    _servis.varlikEkle(
      sembol: _secilenSembol,
      miktar: miktar,
      alisFiyatiTl: girilenAlis,
    );

    _miktarController.clear();
    _alisKuruController.clear();
  }

  String _paraFormatla(double tutar, {bool sifirGizle = false}) {
    if (sifirGizle && tutar <= 0) return '...';
    if (tutar.abs() >= 1000) {
      return '${tutar.toStringAsFixed(0)} ₺';
    }
    if (tutar.abs() < 1 && tutar > 0) {
      return '${tutar.toStringAsFixed(4)} ₺';
    }
    return '${tutar.toStringAsFixed(2)} ₺';
  }

  @override
  Widget build(BuildContext context) {
    final r = AppRenkler.of(context);
    final altBosluk = MediaQuery.of(context).viewInsets.bottom;

    return ValueListenableBuilder<int>(
      valueListenable: _servis.degisimNotifier,
      builder: (context, _, __) {
        final varliklar = _servis.varliklar;
        final seciliTanim = _servis.tanimGetir(_secilenSembol);
        final seciliKur = _servis.kurGetir(_secilenSembol);

        double toplamGuncelDeger = 0;
        double toplamMaliyet = 0;

        for (final v in varliklar) {
          final canli = _servis.kurGetir(v.sembol);
          final kur = canli > 0 ? canli : v.alisFiyatiTl;
          toplamGuncelDeger += v.miktar * kur;
          toplamMaliyet += v.miktar * v.alisFiyatiTl;
        }

        final toplamKarZarar = toplamGuncelDeger - toplamMaliyet;
        final karZararYuzde =
            toplamMaliyet > 0 ? (toplamKarZarar / toplamMaliyet) * 100 : 0.0;
        final kardaMi = toplamKarZarar >= 0;

        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + altBosluk),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.86,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: r.altMetin.withAlpha(110),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'varlik_kasasi_baslik'.tr,
                            style: const TextStyle(
                                fontSize: 19, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'varlik_kasasi_alt_baslik'.tr,
                            style: TextStyle(fontSize: 11.5, color: r.altMetin),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        if (_servis.yukleniyor) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              duration: const Duration(seconds: 1),
                              content: Text('varlik_kurlar_guncelleniyor'.tr),
                            ),
                          );
                          return;
                        }
                        _servis.canliKurlariGuncelle();
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: _servis.yukleniyor
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(
                        _servis.yukleniyor
                            ? 'varlik_cekiliyor'.tr
                            : 'varlik_yenile'.tr,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: r.isDark
                          ? const [Color(0xFF1F2A24), Color(0xFF1A1E29)]
                          : const [Color(0xFFE9F7EF), Color(0xFFEEF2FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (_servis.baglantiHatasi ? r.turuncu : r.yesil)
                          .withAlpha(90),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'varlik_toplam_deger'.tr,
                            style: TextStyle(fontSize: 12, color: r.altMetin),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  (_servis.baglantiHatasi ? r.turuncu : r.yesil)
                                      .withAlpha(30),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _servis.sonGuncelleme,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _servis.baglantiHatasi
                                    ? r.turuncu
                                    : r.yesil,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _paraFormatla(toplamGuncelDeger),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: r.metin,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (kardaMi ? r.yesil : r.kirmizi)
                                  .withAlpha(r.isDark ? 50 : 28),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${kardaMi ? '+' : ''}${_paraFormatla(toplamKarZarar)} (${kardaMi ? '+' : ''}%${karZararYuzde.toStringAsFixed(1)})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: kardaMi ? r.yesil : r.kirmizi,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'varlik_maliyet_etiket'.trParams(
                                {'tutar': _paraFormatla(toplamMaliyet)}),
                            style: TextStyle(fontSize: 12, color: r.altMetin),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final kod in [
                        'USD',
                        'EUR',
                        'GRAM_ALTIN',
                        'CEYREK_ALTIN',
                        'BTC',
                        'ETH',
                        'THYAO.IS',
                        'NVDA',
                      ])
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: r.kart,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: r.kenarlik),
                          ),
                          child: Row(
                            children: [
                              Text(
                                kod == 'GRAM_ALTIN'
                                    ? 'varlik_kisa_gram'.tr
                                    : kod == 'CEYREK_ALTIN'
                                        ? 'varlik_kisa_ceyrek'.tr
                                        : kod.replaceAll('.IS', ''),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _tanimRenkGetir(
                                    r,
                                    kod,
                                    _servis.tanimGetir(kod).kategori,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _paraFormatla(
                                  _servis.kurGetir(kod),
                                  sifirGizle: true,
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: r.kart,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: r.kenarlik),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: InkWell(
                              onTap: () => _varlikSeciciAc(r),
                              borderRadius: BorderRadius.circular(8),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'varlik_turu_etiket'.tr,
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                  suffixIcon: const Icon(
                                    Icons.search_rounded,
                                    size: 18,
                                  ),
                                ),
                                child: Text(
                                  '${seciliTanim.gorunenAd} (${seciliTanim.birim})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _miktarController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: 'varlik_miktar_etiket'
                                    .trParams({'birim': seciliTanim.birim}),
                                isDense: true,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _alisKuruController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: 'varlik_alis_kuru_etiket'.tr,
                                hintText: seciliKur > 0
                                    ? 'varlik_alis_kuru_hint'.trParams({
                                        'kur': seciliKur.toStringAsFixed(2),
                                      })
                                    : 'varlik_kur_bekleniyor_hint'.tr,
                                hintStyle: const TextStyle(fontSize: 11),
                                isDense: true,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _varlikEkle,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            icon: const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            label: Text(
                              'varlik_kasaya_ekle'.tr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: varliklar.isEmpty
                      ? Center(
                          child: Text(
                            'varlik_kasa_bos'.tr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: r.altMetin,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: varliklar.length,
                          itemBuilder: (context, index) {
                            final item = varliklar[index];
                            final tanim = _servis.tanimGetir(item.sembol);
                            final tanimRenk = _tanimRenkGetir(
                                r, item.sembol, tanim.kategori);
                            final canli = _servis.kurGetir(item.sembol);
                            final guncelKur =
                                canli > 0 ? canli : item.alisFiyatiTl;
                            final guncelToplam = item.miktar * guncelKur;
                            final maliyetToplam =
                                item.miktar * item.alisFiyatiTl;
                            final fark = guncelToplam - maliyetToplam;
                            final itemKarda = fark >= 0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: r.kart,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: tanimRenk.withAlpha(80),
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: tanimRenk.withAlpha(35),
                                    child: Text(
                                      tanim.birim.length > 4
                                          ? tanim.birim.substring(0, 4)
                                          : tanim.birim,
                                      style: TextStyle(
                                        color: tanimRenk,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                '${tanim.gorunenAd} • ${item.miktar} ${tanim.birim}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 5,
                                                vertical: 1,
                                              ),
                                              decoration: BoxDecoration(
                                                color:
                                                    tanimRenk.withAlpha(30),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                _kategoriEtiketi(
                                                    tanim.kategori),
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: tanimRenk,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'varlik_alis_guncel_alt'.trParams({
                                            'alis': _paraFormatla(
                                                item.alisFiyatiTl),
                                            'guncel': _paraFormatla(guncelKur),
                                          }),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: r.altMetin,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        _paraFormatla(guncelToplam),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        '${itemKarda ? '+' : ''}${_paraFormatla(fark)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              itemKarda ? r.yesil : r.kirmizi,
                                        ),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: r.altMetin,
                                    ),
                                    onPressed: () => _servis.varlikSil(index),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VarlikSeciciModal extends StatefulWidget {
  final AppRenkler renkler;
  final String seciliSembol;

  const _VarlikSeciciModal({
    required this.renkler,
    required this.seciliSembol,
  });

  @override
  State<_VarlikSeciciModal> createState() => _VarlikSeciciModalState();
}

class _VarlikSeciciModalState extends State<_VarlikSeciciModal> {
  final VarlikServisi _servis = VarlikServisi.instance;
  final TextEditingController _aramaController = TextEditingController();
  Timer? _debounce;

  String _seciliKategori = 'tumu';
  String _aramaMetni = '';
  bool _canliAraniyor = false;
  List<VarlikTanim> _canliSonuclar = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _aramaController.dispose();
    super.dispose();
  }

  void _aramaDegisti(String val) {
    setState(() {
      _aramaMetni = val;
    });

    _debounce?.cancel();
    if (val.trim().length < 2) {
      setState(() {
        _canliAraniyor = false;
        _canliSonuclar = [];
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted) return;
      setState(() => _canliAraniyor = true);
      final bulunanlar = await _servis.canliVarlikAra(val);
      if (!mounted) return;
      setState(() {
        _canliAraniyor = false;
        _canliSonuclar = bulunanlar;
      });
    });
  }

  String _normalize(String metin) {
    return metin
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .toLowerCase()
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u');
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.renkler;
    final altBosluk = MediaQuery.of(context).viewInsets.bottom;
    final trDil = DilServisi.instance.dilKodu == 'tr';

    final kategoriler = [
      {'kod': 'tumu', 'ad': trDil ? 'Tümü' : 'All'},
      {'kod': 'doviz', 'ad': 'varlik_kat_doviz'.tr},
      {'kod': 'altin', 'ad': 'varlik_kat_altin'.tr},
      {'kod': 'kripto', 'ad': 'varlik_kat_kripto'.tr},
      {'kod': 'hisse', 'ad': trDil ? 'Hisse' : 'Stock'},
    ];

    final q = _normalize(_aramaMetni.trim());
    final Map<String, VarlikTanim> birlesik = {};
    for (final t in _servis.tumTanimlar) {
      birlesik[t.sembol] = t;
    }
    for (final t in _canliSonuclar) {
      birlesik.putIfAbsent(t.sembol, () => t);
    }

    final filtrelenmis = birlesik.values.where((t) {
      if (_seciliKategori != 'tumu' && t.kategori != _seciliKategori) {
        return false;
      }
      if (q.isEmpty) return true;
      final hedef = _normalize(
        '${t.sembol} ${t.gorunenAd} ${t.ad} ${t.aramaAnahtarlari ?? ''}',
      );
      return hedef.contains(q);
    }).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + altBosluk),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: Column(
          children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: r.altMetin.withAlpha(110),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            TextField(
              controller: _aramaController,
              autofocus: true,
              onChanged: _aramaDegisti,
              decoration: InputDecoration(
                hintText: trDil
                    ? 'Döviz, altın, kripto veya hisse ara (Örn: USD, BTC, THYAO, NVDA)...'
                    : 'Search FX, gold, crypto or stock...',
                hintStyle: const TextStyle(fontSize: 12.5),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _aramaMetni.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _aramaController.clear();
                          _aramaDegisti('');
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: kategoriler.map((k) {
                  final secili = _seciliKategori == k['kod'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      showCheckmark: false,
                      label: Text(
                        k['ad']!,
                        style: TextStyle(
                          fontSize: 12,
                          color: secili ? Colors.white : r.solukMetin,
                          fontWeight:
                              secili ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: secili,
                      selectedColor: Colors.green,
                      backgroundColor: r.kart,
                      onSelected: (_) =>
                          setState(() => _seciliKategori = k['kod']!),
                    ),
                  );
                }).toList(),
              ),
            ),
            if (_canliAraniyor)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            const SizedBox(height: 6),
            Expanded(
              child: filtrelenmis.isEmpty
                  ? Center(
                      child: Text(
                        trDil
                            ? 'Sonuç bulunamadı. Farklı bir sembol veya isim deneyin.'
                            : 'No results found.',
                        style: TextStyle(color: r.altMetin, fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtrelenmis.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: r.kenarlik),
                      itemBuilder: (context, index) {
                        final t = filtrelenmis[index];
                        final kur = _servis.kurGetir(t.sembol);
                        final secili = t.sembol == widget.seciliSembol;

                        return ListTile(
                          dense: true,
                          selected: secili,
                          title: Text(
                            t.gorunenAd,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            '${t.sembol} • ${t.birim}',
                            style: TextStyle(fontSize: 11, color: r.altMetin),
                          ),
                          trailing: Text(
                            kur > 0
                                ? (kur >= 1000
                                    ? '${kur.toStringAsFixed(0)} ₺'
                                    : '${kur.toStringAsFixed(2)} ₺')
                                : '-',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: kur > 0 ? r.yesil : r.altMetin,
                            ),
                          ),
                          onTap: () => Navigator.pop(context, t),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}