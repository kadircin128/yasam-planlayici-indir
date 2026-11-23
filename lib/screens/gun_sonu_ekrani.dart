import 'package:flutter/material.dart';
import '../models/etkinlik.dart';
import '../models/finans_item.dart';
import '../services/akilli_asistan_servisi.dart';
import '../services/dil_servisi.dart';
import '../services/gun_sonu_servisi.dart';
import '../widgets/sayfa_kilavuzu.dart';
import '../theme/app_renkler.dart';
import 'finans_ekrani.dart'; // KrediKartiChatYardimcisi için

class GunSonuEkrani extends StatefulWidget {
  final List<FinansItem> islemler;
  final List<Etkinlik> etkinlikler;
  final Function(FinansItem) onFinansEkle;
  final Function(Etkinlik) onEtkinlikEkle;
  final Function(Etkinlik)? onEtkinlikSil;
  final Function(Etkinlik, DateTime)? onEtkinlikTekGunIptal;
  final Function(Etkinlik, DateTime)? onEtkinlikTarihGuncelle;
  final Function(FinansItem)? onFinansSil;
  final Function(FinansItem, DateTime)? onFinansTekGunIptal;
  final Function(FinansItem, DateTime)? onFinansTarihGuncelle;
  final Function(int, FinansItem) onIslemDuzenle;

  const GunSonuEkrani({
    super.key,
    required this.islemler,
    required this.etkinlikler,
    required this.onFinansEkle,
    required this.onEtkinlikEkle,
    required this.onIslemDuzenle,
    this.onEtkinlikSil,
    this.onEtkinlikTekGunIptal,
    this.onEtkinlikTarihGuncelle,
    this.onFinansSil,
    this.onFinansTekGunIptal,
    this.onFinansTarihGuncelle,
  });

  @override
  State<GunSonuEkrani> createState() => _GunSonuEkraniState();
}

class _GunSonuEkraniState extends State<GunSonuEkrani> {
  final TextEditingController _mesajController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _keyTarihSecici = GlobalKey();
  final GlobalKey _keyGunKarnesi = GlobalKey();
  final GlobalKey _keyModSecici = GlobalKey();
  final GlobalKey _keyMesajAlani = GlobalKey();

  List<KilavuzAdimi> _kilavuzAdimlari() => [
        KilavuzAdimi(
          key: _keyTarihSecici,
          ikon: Icons.calendar_today_rounded,
          baslik: 'gs_kilavuz_tarih_baslik'.tr,
          aciklama: 'gs_kilavuz_tarih_aciklama'.tr,
        ),
        KilavuzAdimi(
          key: _keyGunKarnesi,
          ikon: Icons.analytics_outlined,
          baslik: 'gs_kilavuz_karne_baslik'.tr,
          aciklama: 'gs_kilavuz_karne_aciklama'.tr,
        ),
        KilavuzAdimi(
          key: _keyModSecici,
          ikon: Icons.mood_rounded,
          baslik: 'gs_kilavuz_mod_baslik'.tr,
          aciklama: 'gs_kilavuz_mod_aciklama'.tr,
        ),
        KilavuzAdimi(
          key: _keyMesajAlani,
          ikon: Icons.auto_awesome_rounded,
          baslik: 'gs_kilavuz_asistan_baslik'.tr,
          aciklama: 'gs_kilavuz_asistan_aciklama'.tr,
        ),
      ];

  void _kilavuzuBaslat() {
    SayfaKilavuzu.goster(
      context: context,
      sayfaId: 'gun_sonu',
      adimlar: _kilavuzAdimlari(),
    );
  }

  DateTime _secilenTarih = DateTime.now();
  String _secilenMod = '😊 İyi';

  static const List<String> _modSecenekleri = [
    '🔥 Verimli',
    '😊 İyi',
    '😐 Normal',
    '😫 Yorucu',
  ];

  String _modCevir(String hamMod) {
    final parcalar = hamMod.split(' ');
    if (parcalar.length < 2) return hamMod.tr;
    final emoji = parcalar.first;
    final kelime = parcalar.sublist(1).join(' ');
    return '$emoji ${kelime.tr}';
  }

  @override
  void initState() {
    super.initState();
    GunSonuServisi.yukle();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SayfaKilavuzu.ilkGirisKontrolEt(
        context: context,
        sayfaId: 'gun_sonu',
        adimlar: _kilavuzAdimlari(),
      );
    });
  }

  @override
  void dispose() {
    _mesajController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _mesajGonder() async {
    final hamMetin = _mesajController.text.trim();
    if (hamMetin.isEmpty) return;

    _mesajController.clear();

    final kayitTarihi = DateTime(
      _secilenTarih.year,
      _secilenTarih.month,
      _secilenTarih.day,
      DateTime.now().hour,
      DateTime.now().minute,
    );

    final sonuc = AkilliAsistanServisi.mesajIsle(
      hamMetin: hamMetin,
      bazTarih: _secilenTarih,
      dilPrefix: 'gs',
      finansIslemleri: widget.islemler,
      etkinlikler: widget.etkinlikler,
      kartGuncelleyici: (cumle) => KrediKartiChatYardimcisi.mesajdanKartGuncelle(
        mesaj: cumle,
        islemler: widget.islemler,
        onIslemDuzenle: widget.onIslemDuzenle,
      ),
      onFinansEkle: widget.onFinansEkle,
      onFinansSil: widget.onFinansSil,
      onFinansTekGunIptal: widget.onFinansTekGunIptal,
      onFinansTarihGuncelle: widget.onFinansTarihGuncelle,
      onEtkinlikEkle: widget.onEtkinlikEkle,
      onEtkinlikSil: widget.onEtkinlikSil,
      onEtkinlikTekGunIptal: widget.onEtkinlikTekGunIptal,
      onEtkinlikTarihGuncelle: widget.onEtkinlikTarihGuncelle,
    );

    final yeniKayit = GunSonuKayit(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      metin: hamMetin,
      mod: _secilenMod,
      tarih: kayitTarihi,
      islenenAksiyonlar: sonuc.aksiyonlar,
      asistanYaniti: sonuc.asistanYaniti,
    );

    await GunSonuServisi.ekle(yeniKayit);

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _kayitSil(String id) async {
    await GunSonuServisi.sil(id);
  }

  Widget _buildGunKarnesi(AppRenkler r, List<GunSonuKayit> kayitlar) {
    final oGunEtkinlikler = widget.etkinlikler
        .where((e) => e.oGunAktifMi(_secilenTarih))
        .toList();
    final tamamlananSayisi = oGunEtkinlikler
        .where((e) => e.oGunTamamlandiMi(_secilenTarih))
        .length;

    double gunlukGelir = 0;
    double gunlukGider = 0;

    for (final f in widget.islemler) {
      if (!f.oGunAktifMi(_secilenTarih)) continue;
      final isPozitif = f.tur == 'Gelir' || f.tur == 'Alacak';
      if (isPozitif) {
        gunlukGelir += f.miktar;
      } else {
        if (f.tur == 'Kredi Kartı' && (f.odendi || f.odenenMiktar > 0)) {
          gunlukGider += f.odenenMiktar > 0 ? f.odenenMiktar : f.miktar;
        } else {
          gunlukGider += f.tahminiOdeme;
        }
      }
    }

    final simdi = DateTime.now();
    final buAyKayitlar = kayitlar
        .where(
            (k) => k.tarih.year == simdi.year && k.tarih.month == simdi.month)
        .toList();
    final Map<String, int> modSayilari = {};
    for (final k in buAyKayitlar) {
      modSayilari[k.mod] = (modSayilari[k.mod] ?? 0) + 1;
    }

    return Container(
      key: _keyGunKarnesi,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'gs_gunun_karnesi_baslik'.trParams({
                  'tarih':
                      '${_secilenTarih.day}.${_secilenTarih.month}.${_secilenTarih.year}',
                }),
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              if (modSayilari.isNotEmpty)
                Text(
                  modSayilari.entries
                      .map((e) => '${e.key.split(' ').first} ${e.value}')
                      .join(' • '),
                  style: TextStyle(fontSize: 11, color: r.altMetin),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  decoration: BoxDecoration(
                    color: r.ikincilKart,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text('gs_gorevler'.tr,
                          style: TextStyle(fontSize: 11, color: r.altMetin)),
                      const SizedBox(height: 3),
                      Text(
                        oGunEtkinlikler.isEmpty
                            ? 'gs_plan_yok'.tr
                            : '$tamamlananSayisi / ${oGunEtkinlikler.length}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: r.morAcik,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  decoration: BoxDecoration(
                    color: r.ikincilKart,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text('gs_gunluk_gelir'.tr,
                          style: TextStyle(fontSize: 11, color: r.altMetin)),
                      const SizedBox(height: 3),
                      Text(
                        '+${gunlukGelir.toStringAsFixed(0)} ₺',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: r.yesil,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  decoration: BoxDecoration(
                    color: r.ikincilKart,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text('gs_gunluk_gider'.tr,
                          style: TextStyle(fontSize: 11, color: r.altMetin)),
                      const SizedBox(height: 3),
                      Text(
                        '-${gunlukGider.toStringAsFixed(0)} ₺',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: r.kirmizi,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = AppRenkler.of(context);

    return ValueListenableBuilder<List<GunSonuKayit>>(
      valueListenable: GunSonuServisi.kayitlarNotifier,
      builder: (context, kayitlar, _) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('gs_ekran_baslik'.tr,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('gs_ekran_alt'.tr,
                            style: TextStyle(color: r.altMetin, fontSize: 12)),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        key: _keyTarihSecici,
                        onTap: () async {
                          final secilen = await showDatePicker(
                            context: context,
                            initialDate: _secilenTarih,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (secilen != null && mounted) {
                            setState(() => _secilenTarih = secilen);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: r.ikincilKart,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: r.mor),
                          ),
                          child: Text(
                            '📅 ${_secilenTarih.day}.${_secilenTarih.month}.${_secilenTarih.year}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: r.mor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      KilavuzYardimButonu(onPressed: _kilavuzuBaslat),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildGunKarnesi(r, kayitlar),
              const SizedBox(height: 10),
              Expanded(
                child: kayitlar.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_awesome_rounded,
                                size: 42, color: r.mor),
                            const SizedBox(height: 10),
                            Text('gs_bos_baslik'.tr,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text(
                              'gs_bos_alt'.tr,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: r.altMetin, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: kayitlar.length,
                        itemBuilder: (context, index) {
                          final item = kayitlar[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: r.kart,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: r.kenarlik),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: r.mor
                                            .withAlpha(r.isDark ? 65 : 28),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _modCevir(item.mod),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: r.metin,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: r.morAcik.withAlpha(30),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        'gs_akilli_kayit_etiket'.tr,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: r.morAcik,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${item.tarih.day}.${item.tarih.month}.${item.tarih.year} • ${item.tarih.hour.toString().padLeft(2, '0')}:${item.tarih.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                          fontSize: 11, color: r.altMetin),
                                    ),
                                    const Spacer(),
                                    InkWell(
                                      onTap: () => _kayitSil(item.id),
                                      child: Icon(Icons.delete_outline_rounded,
                                          size: 16, color: r.altMetin),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(item.metin,
                                    style: const TextStyle(
                                        fontSize: 14, height: 1.4)),
                                if (item.asistanYaniti != null &&
                                    item.asistanYaniti!.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: r.ikincilKart,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: r.morAcik.withAlpha(85)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.auto_awesome_rounded,
                                            size: 16, color: r.morAcik),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            item.asistanYaniti!,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              height: 1.35,
                                              color: r.solukMetin,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (item.islenenAksiyonlar.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children:
                                        item.islenenAksiyonlar.map((aksiyon) {
                                      final isKart = aksiyon.startsWith('💳');
                                      final isTakvim = aksiyon.startsWith('📅');
                                      final isIptal = aksiyon.startsWith('🗑️');
                                      final isErteleme =
                                          aksiyon.startsWith('🔄');
                                      final isBilgi = aksiyon.startsWith('ℹ️') ||
                                          aksiyon.startsWith('⚠️');

                                      Color temaRenk = r.yesil;
                                      if (isKart) {
                                        temaRenk = r.mavi;
                                      } else if (isTakvim) {
                                        temaRenk = r.mor;
                                      } else if (isIptal) {
                                        temaRenk = r.kirmizi;
                                      } else if (isErteleme) {
                                        temaRenk = r.turuncu;
                                      } else if (isBilgi) {
                                        temaRenk = r.altMetin;
                                      }

                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: temaRenk
                                              .withAlpha(r.isDark ? 45 : 22),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: temaRenk, width: 0.8),
                                        ),
                                        child: Text(
                                          aksiyon,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: temaRenk,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                key: _keyModSecici,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _modSecenekleri.map((mod) {
                    final secili = _secilenMod == mod;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        showCheckmark: false,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                        label: Text(
                          _modCevir(mod),
                          style: TextStyle(
                            fontSize: 12,
                            color: secili ? Colors.white : r.solukMetin,
                            fontWeight:
                                secili ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        selected: secili,
                        selectedColor: Colors.deepPurple,
                        backgroundColor: r.kart,
                        side: BorderSide(
                            color: secili ? Colors.deepPurple : r.kenarlik),
                        onSelected: (_) => setState(() => _secilenMod = mod),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                key: _keyMesajAlani,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: r.kart,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: r.mor.withAlpha(120)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _mesajController,
                        maxLines: 3,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _mesajGonder(),
                        decoration: InputDecoration(
                          hintText: 'gs_mesaj_hint'.tr,
                          hintStyle: TextStyle(color: r.altMetin, fontSize: 13),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton.filled(
                      onPressed: _mesajGonder,
                      style: IconButton.styleFrom(
                          backgroundColor: Colors.deepPurple),
                      icon: const Icon(Icons.send_rounded,
                          size: 20, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}