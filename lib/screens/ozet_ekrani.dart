import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/finans_item.dart';
import '../models/etkinlik.dart';
import '../services/akilli_asistan_servisi.dart';
import '../services/dil_servisi.dart';
import '../services/gun_sonu_servisi.dart';
import '../services/varlik_servisi.dart';
import '../widgets/sayfa_kilavuzu.dart';
import '../theme/app_renkler.dart';
import 'finans_ekrani.dart'; // KrediKartiChatYardimcisi için

class OzetEkrani extends StatefulWidget {
  final List<FinansItem> finansIslemleri;
  final List<Etkinlik> etkinlikler;
  final int gunSonuNotSayisi;
  final Function(Etkinlik, DateTime)? onEtkinlikTamamla;
  final Function(Etkinlik)? onEtkinlikSil;
  final Function(FinansItem)? onFinansOdendiToggle;
  final Function(FinansItem)? onFinansSil;
  final VoidCallback? onIsHavuzuAc;
  final Function(FinansItem)? onFinansEkle;
  final Function(Etkinlik)? onEtkinlikEkle;
  final Function(Etkinlik, DateTime)? onEtkinlikTekGunIptal;
  final Function(Etkinlik, DateTime)? onEtkinlikTarihGuncelle;
  final Function(FinansItem, DateTime)? onFinansTarihGuncelle;
  final Function(int, FinansItem)? onIslemDuzenle;
  final VoidCallback? onGunSonuKayitEklendi;
  final Function(FinansItem, DateTime)? onFinansTekGunIptal;

  const OzetEkrani({
    super.key,
    required this.finansIslemleri,
    required this.etkinlikler,
    required this.gunSonuNotSayisi,
    this.onEtkinlikTamamla,
    this.onEtkinlikSil,
    this.onFinansOdendiToggle,
    this.onFinansSil,
    this.onIsHavuzuAc,
    this.onFinansEkle,
    this.onEtkinlikEkle,
    this.onEtkinlikTekGunIptal,
    this.onEtkinlikTarihGuncelle,
    this.onFinansTarihGuncelle,
    this.onIslemDuzenle,
    this.onGunSonuKayitEklendi,
    this.onFinansTekGunIptal,
  });

  @override
  State<OzetEkrani> createState() => _OzetEkraniState();
}

class _OzetEkraniState extends State<OzetEkrani> {
  final GlobalKey _keyGenelDurum = GlobalKey();
  final GlobalKey _keyBugunAkisi = GlobalKey();
  final GlobalKey _keyYaklasanAkis = GlobalKey();
  final TextEditingController _hizliChatController = TextEditingController();

  int _havuzToplamIs = 0;
  int _havuzAcilIs = 0;
  String? _sonHizliMesaj;
  String? _sonHizliYanit;
  List<String> _sonHizliAksiyonlar = [];

  List<KilavuzAdimi> _kilavuzAdimlari() => [
        KilavuzAdimi(
          key: _keyGenelDurum,
          ikon: Icons.dashboard_rounded,
          baslik: 'ozet_kilavuz_butce_baslik'.tr,
          aciklama: 'ozet_kilavuz_butce_aciklama'.tr,
        ),
        KilavuzAdimi(
          key: _keyBugunAkisi,
          ikon: Icons.today_rounded,
          baslik: 'ozet_kilavuz_bugun_baslik'.tr,
          aciklama: 'ozet_kilavuz_bugun_aciklama'.tr,
        ),
        KilavuzAdimi(
          key: _keyYaklasanAkis,
          ikon: Icons.upcoming_rounded,
          baslik: 'ozet_kilavuz_haftalik_baslik'.tr,
          aciklama: 'ozet_kilavuz_haftalik_aciklama'.tr,
        ),
      ];

  void _kilavuzuBaslat() {
    SayfaKilavuzu.goster(
      context: context,
      sayfaId: 'ozet',
      adimlar: _kilavuzAdimlari(),
    );
  }

  @override
  void initState() {
    super.initState();
    VarlikServisi.instance.baslat();
    _havuzVerisiniYukle();
    GunSonuServisi.kayitlarNotifier.addListener(_kayitlarDegisti);
    _sonGunSonuKaydiniYukle();
    SayfaKilavuzu.ilkGirisKontrolEt(
      context: context,
      sayfaId: 'ozet',
      adimlar: _kilavuzAdimlari(),
    );
  }

  @override
  void dispose() {
    GunSonuServisi.kayitlarNotifier.removeListener(_kayitlarDegisti);
    _hizliChatController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OzetEkrani oldWidget) {
    super.didUpdateWidget(oldWidget);
    _havuzVerisiniYukle();
  }

  void _kayitlarDegisti() {
    if (!mounted) return;
    final liste = GunSonuServisi.kayitlarNotifier.value;
    setState(() {
      if (liste.isEmpty) {
        _sonHizliMesaj = null;
        _sonHizliYanit = null;
        _sonHizliAksiyonlar = [];
      } else {
        final last = liste.last;
        _sonHizliMesaj = last.metin;
        _sonHizliYanit = last.asistanYaniti;
        _sonHizliAksiyonlar = List<String>.from(last.islenenAksiyonlar);
      }
    });
  }

  Future<void> _havuzVerisiniYukle() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('tarihsiz_is_havuzu_v1');
    if (raw != null) {
      try {
        final List<dynamic> decoded = jsonDecode(raw);
        int acil = 0;
        for (final item in decoded) {
          if (item is Map && item['acil'] == true) {
            acil++;
          }
        }
        if (mounted) {
          setState(() {
            _havuzToplamIs = decoded.length;
            _havuzAcilIs = acil;
          });
        }
      } catch (_) {}
    } else if (mounted && (_havuzToplamIs != 0 || _havuzAcilIs != 0)) {
      setState(() {
        _havuzToplamIs = 0;
        _havuzAcilIs = 0;
      });
    }
  }

  Future<void> _sonGunSonuKaydiniYukle() async {
    await GunSonuServisi.yukle();
    _kayitlarDegisti();
  }

  Future<void> _hizliMesajGonder() async {
    final hamMetin = _hizliChatController.text.trim();
    if (hamMetin.isEmpty) return;

    _hizliChatController.clear();
    final simdi = DateTime.now();

    final sonuc = AkilliAsistanServisi.mesajIsle(
      hamMetin: hamMetin,
      bazTarih: simdi,
      dilPrefix: 'ozet',
      finansIslemleri: widget.finansIslemleri,
      etkinlikler: widget.etkinlikler,
      kartGuncelleyici: widget.onIslemDuzenle == null
          ? null
          : (cumle) => KrediKartiChatYardimcisi.mesajdanKartGuncelle(
                mesaj: cumle,
                islemler: widget.finansIslemleri,
                onIslemDuzenle: widget.onIslemDuzenle!,
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

    await GunSonuServisi.ekle(
      GunSonuKayit(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        metin: hamMetin,
        mod: '😊 İyi',
        tarih: simdi,
        islenenAksiyonlar: sonuc.aksiyonlar,
        asistanYaniti: sonuc.asistanYaniti,
      ),
    );
    widget.onGunSonuKayitEklendi?.call();
  }

  Widget _buildHizliAsistanKutusu(AppRenkler r) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: r.kart,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: r.mor.withAlpha(r.isDark ? 95 : 75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 17, color: r.morAcik),
              const SizedBox(width: 6),
              Text(
                'ozet_hizli_asistan_baslik'.tr,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: r.metin,
                ),
              ),
              const Spacer(),
              Text(
                'ozet_gun_sonu_senkron'.tr,
                style: TextStyle(fontSize: 10.5, color: r.altMetin),
              ),
            ],
          ),
          if (_sonHizliMesaj != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: r.ikincilKart,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: r.kenarlik),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _sonHizliMesaj!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: r.metin,
                    ),
                  ),
                  if (_sonHizliYanit != null &&
                      _sonHizliYanit!.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      _sonHizliYanit!,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.3,
                        color: r.solukMetin,
                      ),
                    ),
                  ],
                  if (_sonHizliAksiyonlar.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: _sonHizliAksiyonlar
                          .take(3)
                          .map(
                            (aks) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: r.mor.withAlpha(r.isDark ? 45 : 22),
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(
                                    color: r.mor.withAlpha(110), width: 0.8),
                              ),
                              child: Text(
                                aks,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: r.morAcik,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.only(left: 12, right: 4, top: 2, bottom: 2),
            decoration: BoxDecoration(
              color: r.ikincilKart,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: r.kenarlik),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hizliChatController,
                    maxLines: 2,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _hizliMesajGonder(),
                    style: TextStyle(fontSize: 12.5, color: r.metin),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'ozet_hizli_mesaj_hint'.tr,
                      hintStyle: TextStyle(color: r.altMetin, fontSize: 12),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton.filled(
                  onPressed: _hizliMesajGonder,
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    minimumSize: const Size(34, 34),
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.send_rounded,
                      size: 17, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _pozitifMesaj() {
    final saat = DateTime.now().hour;
    if (saat >= 6 && saat < 12) {
      return 'ozet_selam_sabah'.tr;
    } else if (saat >= 12 && saat < 18) {
      return 'ozet_selam_oglen'.tr;
    } else if (saat >= 18 && saat < 23) {
      return 'ozet_selam_aksam'.tr;
    } else {
      return 'ozet_selam_gece'.tr;
    }
  }

  String _bugunkuTarihMetni() {
    final now = DateTime.now();
    final ayAdi = 'ay_${now.month}'.tr;
    final saatStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return '${now.day} $ayAdi ${now.year} • $saatStr';
  }

  String _ayYilEtiketi(DateTime tarih) {
    final ayAdi = 'ay_${tarih.month}'.tr;
    return '$ayAdi ${tarih.year}';
  }

  String _paraFormatla(double tutar, {bool artiGoster = false}) {
    final negatif = tutar < 0;
    final tam = tutar.abs().round().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < tam.length; i++) {
      if (i > 0 && (tam.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(tam[i]);
    }
    final isaret = negatif ? '-' : (artiGoster && tutar > 0 ? '+' : '');
    return '$isaret${buffer.toString()} ₺';
  }

  String _tarihFormatla(DateTime target) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tDate = DateTime(target.year, target.month, target.day);
    final diff = tDate.difference(today).inDays;

    if (diff == 0) return 'bugun'.tr;
    if (diff == 1) return 'yarin'.tr;
    if (diff == -1) return 'dun'.tr;

    if (diff > 1 && diff < 7) {
      return 'hafta_gun_${target.weekday}'.tr;
    }

    final ayAdi = 'ay_${target.month}'.tr;
    return '${target.day} $ayAdi';
  }

  Map<String, double> _hesaplaAylikButceOzeti(DateTime now) {
    double aylikGelir = 0;
    double aylikGider = 0;
    double kartToplam = 0;

    final ayBasi = DateTime(now.year, now.month, 1);
    final aySonu = DateTime(now.year, now.month + 1, 0);

    for (final f in widget.finansIslemleri) {
      if (f.tur == 'Kredi Kartı') {
        if (!f.odendi) {
          kartToplam += f.kalanMiktar;
        }
        final fBaslangic = DateTime(f.tarih.year, f.tarih.month, f.tarih.day);
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
            aylikGider += f.tahminiOdeme;
          } else if (odemeBuAydaMi) {
            aylikGider += odenenTutar;
          }
        } else if (!buAySonOdeme.isBefore(fBaslangic)) {
          aylikGider += f.tahminiOdeme;
        }
        continue;
      }

      int aylikTekrar = 0;
      DateTime temp = ayBasi;
      while (!temp.isAfter(aySonu)) {
        if (f.oGunAktifMi(temp)) {
          aylikTekrar++;
        }
        temp = DateTime(temp.year, temp.month, temp.day + 1);
      }

      if (aylikTekrar == 0) continue;

      final isPozitif = f.tur == 'Gelir' || f.tur == 'Alacak';
      if (isPozitif) {
        aylikGelir += f.miktar * aylikTekrar;
      } else {
        final tutar =
            (f.tur == 'Fatura' && f.isDegiskenFatura && !f.ekstreGirildi)
                ? f.tahminiOdeme
                : f.miktar;
        aylikGider += tutar * aylikTekrar;
      }
    }

    return {
      'gelir': aylikGelir,
      'gider': aylikGider,
      'kart': kartToplam,
      'net': aylikGelir - aylikGider,
    };
  }

  Widget _buildUstKarsilamaSeridi(AppRenkler r) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: r.kart,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: r.kenarlik, width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _pozitifMesaj(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: r.metin,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: r.ikincilKart,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: r.kenarlik),
            ),
            child: Text(
              _bugunkuTarihMetni(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: r.altMetin,
              ),
            ),
          ),
          const SizedBox(width: 8),
          KilavuzYardimButonu(onPressed: _kilavuzuBaslat),
        ],
      ),
    );
  }

  Widget _buildSolButceVeDurumAlani({
    required AppRenkler r,
    required DateTime now,
    required double netBakiye,
    required double aylikGelir,
    required double aylikGider,
    required double kartToplam,
    required int butceYuzde,
    required double butceBarDegeri,
    required String butceDurumMetni,
    required Color butceDurumRengi,
    required int bugunTamamlanan,
    required int bugunToplam,
    required double bugunOran,
    required List<FinansItem> acilFaturalar,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          key: _keyGenelDurum,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: r.isDark
                      ? const [Color(0xFF1A132B), Color(0xFF13111C)]
                      : const [Color(0xFFF6F3FF), Color(0xFFECE6FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: r.mor.withAlpha(r.isDark ? 95 : 75),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'ozet_net_bakiye_etiket'.tr,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: r.altMetin,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: r.mor.withAlpha(r.isDark ? 45 : 28),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _ayYilEtiketi(now),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: r.morAcik,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _paraFormatla(netBakiye),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: netBakiye >= 0 ? r.metin : r.kirmizi,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _miniFinansKutusu(
                          r: r,
                          etiket: 'ozet_gelir'.tr,
                          tutar: _paraFormatla(aylikGelir, artiGoster: true),
                          ikon: Icons.north_east_rounded,
                          renk: r.yesil,
                          arkaPlan: r.isDark
                              ? const Color(0xFF132A24)
                              : const Color(0xFFDCFCE7),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _miniFinansKutusu(
                          r: r,
                          etiket: 'ozet_gider'.tr,
                          tutar: _paraFormatla(-aylikGider),
                          ikon: Icons.south_east_rounded,
                          renk: r.kirmizi,
                          arkaPlan: r.isDark
                              ? const Color(0xFF2B1519)
                              : const Color(0xFFFEE2E2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _miniFinansKutusu(
                          r: r,
                          etiket: 'ozet_kart'.tr,
                          tutar: _paraFormatla(kartToplam),
                          ikon: Icons.credit_card_rounded,
                          renk: r.mavi,
                          arkaPlan: r.isDark
                              ? const Color(0xFF141E33)
                              : const Color(0xFFDBEAFE),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ozet_butce_kullanim'.trParams({'yuzde': '$butceYuzde'}),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: r.solukMetin,
                        ),
                      ),
                      Text(
                        butceDurumMetni,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: butceDurumRengi,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: butceBarDegeri,
                      minHeight: 6,
                      backgroundColor: r.isDark
                          ? Colors.white.withAlpha(20)
                          : Colors.black.withAlpha(18),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(butceDurumRengi),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: r.kart,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: r.kenarlik),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ozet_bugunku_akis'.tr,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: r.altMetin,
                              ),
                            ),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: r.mor.withAlpha(r.isDark ? 55 : 28),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                size: 15,
                                color: r.morAcik,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'ozet_tamamlandi_sayac'.trParams({
                              'tamamlanan': '$bugunTamamlanan',
                              'toplam': '$bugunToplam',
                            }),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: r.metin,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: bugunOran,
                            minHeight: 5,
                            backgroundColor: r.isDark
                                ? Colors.white.withAlpha(18)
                                : Colors.black.withAlpha(16),
                            valueColor: AlwaysStoppedAnimation<Color>(r.mor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      if (widget.onIsHavuzuAc != null) {
                        widget.onIsHavuzuAc!();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            duration: const Duration(seconds: 2),
                            content: Text('ozet_is_havuzu_ipucu'.tr),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: r.kart,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: r.kenarlik),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ozet_is_havuzu'.tr,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: r.altMetin,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _havuzAcilIs > 0
                                      ? r.kirmizi.withAlpha(r.isDark ? 55 : 28)
                                      : r.ikincilKart,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _havuzAcilIs > 0
                                      ? 'ozet_acil_sayi'
                                          .trParams({'sayi': '$_havuzAcilIs'})
                                      : 'ozet_sifir_acil'.tr,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: _havuzAcilIs > 0
                                        ? r.kirmizi
                                        : r.altMetin,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'ozet_bekleyen_is'.trParams(
                                        {'sayi': '$_havuzToplamIs'}),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: r.metin,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 17,
                                color: r.morAcik,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildHizliAsistanKutusu(r),
        if (acilFaturalar.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: r.acilKart,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: r.kirmizi.withAlpha(150)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: r.kirmizi, size: 19),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ozet_acil_faturalar'.tr,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: r.kirmizi,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ...acilFaturalar.map((f) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '• ${f.baslik} ${f.otomatikOdemede ? 'ozet_otomatik_etiket'.tr : ''}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _paraFormatla(f.miktar),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: r.kirmizi,
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAkisBolumKarti({
    required AppRenkler r,
    required GlobalKey bolumKey,
    required String baslik,
    required String bosMesaj,
    required List<_AkisKartData> liste,
    required bool icKaydirma,
  }) {
    return Container(
      key: bolumKey,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: r.kart,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: r.kenarlik, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                baslik,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: r.metin,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: r.ikincilKart,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: r.kenarlik),
                ),
                child: Text(
                  'ozet_kayit_sayisi'.trParams({'sayi': '${liste.length}'}),
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
              child: liste.isEmpty
                  ? Center(
                      child: Text(
                        bosMesaj,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: r.altMetin, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: liste.length,
                      itemBuilder: (context, index) =>
                          _buildAkisKarti(r, liste[index]),
                    ),
            )
          else if (liste.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  bosMesaj,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: r.altMetin, fontSize: 13),
                ),
              ),
            )
          else
            Column(
              children:
                  liste.map((item) => _buildAkisKarti(r, item)).toList(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = AppRenkler.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final ozet = _hesaplaAylikButceOzeti(now);
    final aylikGelir = ozet['gelir'] ?? 0;
    final aylikGider = ozet['gider'] ?? 0;
    final kartToplam = ozet['kart'] ?? 0;
    final netBakiye = ozet['net'] ?? 0;

    final int butceYuzde =
        aylikGelir > 0 ? ((aylikGider / aylikGelir) * 100).round() : 0;
    final double butceBarDegeri =
        aylikGelir > 0 ? (aylikGider / aylikGelir).clamp(0.0, 1.0) : 0.0;

    String butceDurumMetni = 'ozet_durum_iyi'.tr;
    Color butceDurumRengi = r.morAcik;
    if (aylikGelir == 0 && aylikGider == 0) {
      butceDurumMetni = 'ozet_durum_bekleniyor'.tr;
      butceDurumRengi = r.altMetin;
    } else if (butceYuzde > 100) {
      butceDurumMetni = 'ozet_durum_asildi'.tr;
      butceDurumRengi = r.kirmizi;
    } else if (butceYuzde > 80) {
      butceDurumMetni = 'ozet_durum_dikkat'.tr;
      butceDurumRengi = r.turuncu;
    } else if (butceYuzde > 50) {
      butceDurumMetni = 'ozet_durum_dengeli'.tr;
      butceDurumRengi = r.mavi;
    }

    final acilFaturalar = widget.finansIslemleri.where((f) {
      if (f.odendi || (f.tur != 'Fatura' && f.tur != 'Gider')) return false;
      for (int i = 0; i <= 3; i++) {
        if (f.oGunAktifMi(today.add(Duration(days: i)))) return true;
      }
      return false;
    }).toList();

    final List<_AkisKartData> bugununAkisi = [];

    for (var e in widget.etkinlikler) {
      if (e.oGunAktifMi(today)) {
        bugununAkisi.add(_AkisKartData(
          tarih: today,
          baslik: e.baslik,
          altMetin:
              e.saatEtiketi + (e.aciklama.isNotEmpty ? ' • ${e.aciklama}' : ''),
          tarihEtiketi: 'bugun'.tr,
          icon: Icons.event_rounded,
          renk: r.mor,
          isFinans: false,
          etkinlik: e,
        ));
      }
    }

    for (var f in widget.finansIslemleri) {
      if (f.takvimdeOgunMu(today)) {
        final isPozitif = f.tur == 'Gelir' || f.tur == 'Alacak';

        if (f.tur == 'Kredi Kartı') {
          if (f.hesapKesimGunu != null && today.day == f.hesapKesimGunu) {
            bugununAkisi.add(_AkisKartData(
              tarih: today,
              baslik: f.baslik,
              altMetin: 'ozet_kart_kesim_alt'.trParams({
                'durum': f.ekstreGirildi
                    ? '${f.miktar.toStringAsFixed(0)} ₺'
                    : 'ozet_ekstre_bekliyor'.tr,
              }),
              tarihEtiketi: 'ozet_bugun_kesim'.tr,
              icon: Icons.receipt_long_rounded,
              renk: r.mavi,
              isFinans: true,
              miktar: f.miktar,
              isPozitif: false,
            ));
          }
          if (f.sonOdemeGunu != null && today.day == f.sonOdemeGunu) {
            bugununAkisi.add(_AkisKartData(
              tarih: today,
              baslik: f.baslik,
              altMetin: 'ozet_kart_son_odeme_alt'
                  .trParams({'tutar': f.miktar.toStringAsFixed(0)}),
              tarihEtiketi: 'ozet_bugun_son_odeme'.tr,
              icon: Icons.credit_card_rounded,
              renk: r.kirmizi,
              isFinans: true,
              miktar: f.miktar,
              isPozitif: false,
            ));
          }
        } else {
          final durumEki = f.odendi
              ? 'ozet_odendi_parantez'.tr
              : (f.odenenMiktar > 0
                  ? 'ozet_kalan_parantez'
                      .trParams({'tutar': f.kalanMiktar.toStringAsFixed(0)})
                  : '');
          bugununAkisi.add(_AkisKartData(
            tarih: today,
            baslik: f.baslik,
            altMetin: 'ozet_finans_alt'.trParams({
              'tur': f.tur,
              'oto': f.otomatikOdemede ? 'ozet_otomatik_etiket'.tr : '',
              'isaret': isPozitif ? '+' : '-',
              'tutar': f.miktar.toStringAsFixed(0),
              'durum': durumEki,
            }),
            tarihEtiketi: 'bugun'.tr,
            icon: isPozitif ? Icons.arrow_downward_rounded : Icons.receipt_rounded,
            renk: f.odendi ? r.altMetin : (isPozitif ? r.yesil : r.kirmizi),
            isFinans: true,
            finansItem: f,
            miktar: f.miktar,
            isPozitif: isPozitif,
          ));
        }
      }
    }

    final int bugunToplam = bugununAkisi.length;
    final int bugunTamamlanan = bugununAkisi.where((item) {
      if (item.etkinlik != null) {
        return item.etkinlik!.oGunTamamlandiMi(item.tarih);
      }
      return item.finansItem?.odendi ?? false;
    }).length;
    final double bugunOran =
        bugunToplam > 0 ? (bugunTamamlanan / bugunToplam).clamp(0.0, 1.0) : 0.0;

    final List<_AkisKartData> haftalikAkis = [];
    for (int i = 1; i <= 7; i++) {
      final hedefTarih = today.add(Duration(days: i));

      for (var e in widget.etkinlikler) {
        if (!e.oGunTamamlandiMi(hedefTarih) && e.oGunAktifMi(hedefTarih)) {
          haftalikAkis.add(_AkisKartData(
            tarih: hedefTarih,
            baslik: e.baslik,
            altMetin: e.saatEtiketi +
                (e.aciklama.isNotEmpty ? ' • ${e.aciklama}' : ''),
            tarihEtiketi: _tarihFormatla(hedefTarih),
            icon: Icons.stars_rounded,
            renk: r.mor,
            isFinans: false,
            etkinlik: e,
          ));
        }
      }

      for (var f in widget.finansIslemleri) {
        if (f.takvimdeOgunMu(hedefTarih)) {
          final isPozitif = f.tur == 'Gelir' || f.tur == 'Alacak';

          bool isKesimGunu = false;
          bool isSonOdemeGunu = false;

          if (f.tur == 'Kredi Kartı') {
            if (f.hesapKesimGunu != null &&
                hedefTarih.day == f.hesapKesimGunu) {
              isKesimGunu = true;
            }
            if (f.sonOdemeGunu != null && hedefTarih.day == f.sonOdemeGunu) {
              isSonOdemeGunu = true;
            }
          }

          if (isKesimGunu) {
            haftalikAkis.add(_AkisKartData(
              tarih: hedefTarih,
              baslik: f.baslik,
              altMetin: 'ozet_kart_kesim_alt'.trParams({
                'durum': f.ekstreGirildi
                    ? '-${f.miktar.toStringAsFixed(0)} ₺'
                    : 'ozet_ekstre_bekliyor'.tr,
              }),
              tarihEtiketi: 'ozet_tarih_kesim'
                  .trParams({'tarih': _tarihFormatla(hedefTarih)}),
              icon: Icons.receipt_long_rounded,
              renk: r.mavi,
              isFinans: true,
              finansItem: f,
              miktar: f.miktar,
              isPozitif: false,
            ));
          }

          if (isSonOdemeGunu) {
            haftalikAkis.add(_AkisKartData(
              tarih: hedefTarih,
              baslik: f.baslik,
              altMetin: 'ozet_kart_son_odeme_alt'
                  .trParams({'tutar': f.miktar.toStringAsFixed(0)}),
              tarihEtiketi: 'ozet_tarih_son_odeme'
                  .trParams({'tarih': _tarihFormatla(hedefTarih)}),
              icon: Icons.credit_card_rounded,
              renk: r.kirmizi,
              isFinans: true,
              finansItem: f,
              miktar: f.miktar,
              isPozitif: false,
            ));
          }

          if (!isKesimGunu && !isSonOdemeGunu) {
            haftalikAkis.add(_AkisKartData(
              tarih: hedefTarih,
              baslik: f.baslik,
              altMetin: 'ozet_finans_alt'.trParams({
                'tur': f.tur,
                'oto': f.otomatikOdemede ? 'ozet_otomatik_etiket'.tr : '',
                'isaret': isPozitif ? '+' : '-',
                'tutar': f.miktar.toStringAsFixed(0),
                'durum': '',
              }),
              tarihEtiketi: _tarihFormatla(hedefTarih),
              icon:
                  isPozitif ? Icons.arrow_downward_rounded : Icons.receipt_rounded,
              renk: isPozitif ? r.yesil : r.turuncu,
              isFinans: true,
              finansItem: f,
              miktar: f.miktar,
              isPozitif: isPozitif,
            ));
          }
        }
      }
    }

    haftalikAkis.sort((a, b) => a.tarih.compareTo(b.tarih));

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool genisEkran = constraints.maxWidth >= 600;
        final bool yukseklikSinirli = constraints.hasBoundedHeight;

        if (genisEkran) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUstKarsilamaSeridi(r),
                const SizedBox(height: 14),
                if (yukseklikSinirli)
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 11,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: 72),
                            child: _buildSolButceVeDurumAlani(
                              r: r,
                              now: now,
                              netBakiye: netBakiye,
                              aylikGelir: aylikGelir,
                              aylikGider: aylikGider,
                              kartToplam: kartToplam,
                              butceYuzde: butceYuzde,
                              butceBarDegeri: butceBarDegeri,
                              butceDurumMetni: butceDurumMetni,
                              butceDurumRengi: butceDurumRengi,
                              bugunTamamlanan: bugunTamamlanan,
                              bugunToplam: bugunToplam,
                              bugunOran: bugunOran,
                              acilFaturalar: acilFaturalar,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 12,
                          child: Column(
                            children: [
                              Expanded(
                                child: _buildAkisBolumKarti(
                                  r: r,
                                  bolumKey: _keyBugunAkisi,
                                  baslik: 'ozet_bugun_akis_baslik'.tr,
                                  bosMesaj: 'ozet_bugun_bos'.tr,
                                  liste: bugununAkisi,
                                  icKaydirma: true,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: _buildAkisBolumKarti(
                                  r: r,
                                  bolumKey: _keyYaklasanAkis,
                                  baslik: 'ozet_haftalik_akis_baslik'.tr,
                                  bosMesaj: 'ozet_haftalik_bos'.tr,
                                  liste: haftalikAkis,
                                  icKaydirma: true,
                                ),
                              ),
                            ],
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
                        child: _buildSolButceVeDurumAlani(
                          r: r,
                          now: now,
                          netBakiye: netBakiye,
                          aylikGelir: aylikGelir,
                          aylikGider: aylikGider,
                          kartToplam: kartToplam,
                          butceYuzde: butceYuzde,
                          butceBarDegeri: butceBarDegeri,
                          butceDurumMetni: butceDurumMetni,
                          butceDurumRengi: butceDurumRengi,
                          bugunTamamlanan: bugunTamamlanan,
                          bugunToplam: bugunToplam,
                          bugunOran: bugunOran,
                          acilFaturalar: acilFaturalar,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 12,
                        child: Column(
                          children: [
                            _buildAkisBolumKarti(
                              r: r,
                              bolumKey: _keyBugunAkisi,
                              baslik: 'ozet_bugun_akis_baslik'.tr,
                              bosMesaj: 'ozet_bugun_bos'.tr,
                              liste: bugununAkisi,
                              icKaydirma: false,
                            ),
                            const SizedBox(height: 12),
                            _buildAkisBolumKarti(
                              r: r,
                              bolumKey: _keyYaklasanAkis,
                              baslik: 'ozet_haftalik_akis_baslik'.tr,
                              bosMesaj: 'ozet_haftalik_bos'.tr,
                              liste: haftalikAkis,
                              icKaydirma: false,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        }

        // Telefon (Dar Ekran)
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 84),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUstKarsilamaSeridi(r),
              const SizedBox(height: 14),
              _buildSolButceVeDurumAlani(
                r: r,
                now: now,
                netBakiye: netBakiye,
                aylikGelir: aylikGelir,
                aylikGider: aylikGider,
                kartToplam: kartToplam,
                butceYuzde: butceYuzde,
                butceBarDegeri: butceBarDegeri,
                butceDurumMetni: butceDurumMetni,
                butceDurumRengi: butceDurumRengi,
                bugunTamamlanan: bugunTamamlanan,
                bugunToplam: bugunToplam,
                bugunOran: bugunOran,
                acilFaturalar: acilFaturalar,
              ),
              const SizedBox(height: 16),
              Container(
                key: _keyBugunAkisi,
                child: Text(
                  'ozet_bugun_akis_baslik'.tr,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              bugununAkisi.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          'ozet_bugun_bos'.tr,
                          style: TextStyle(color: r.altMetin, fontSize: 13),
                        ),
                      ),
                    )
                  : Column(
                      children: bugununAkisi
                          .map((item) => _buildAkisKarti(r, item))
                          .toList(),
                    ),
              const SizedBox(height: 18),
              Container(
                key: _keyYaklasanAkis,
                child: Text(
                  'ozet_haftalik_akis_baslik'.tr,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              haftalikAkis.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'ozet_haftalik_bos'.tr,
                          style: TextStyle(color: r.altMetin, fontSize: 13),
                        ),
                      ),
                    )
                  : Column(
                      children: haftalikAkis
                          .map((item) => _buildAkisKarti(r, item))
                          .toList(),
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _miniFinansKutusu({
    required AppRenkler r,
    required String etiket,
    required String tutar,
    required IconData ikon,
    required Color renk,
    required Color arkaPlan,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: arkaPlan,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: renk.withAlpha(r.isDark ? 75 : 90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ikon, size: 13, color: renk),
              const SizedBox(width: 4),
              Text(
                etiket,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: renk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              tutar,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: renk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAkisKarti(AppRenkler r, _AkisKartData item) {
    final tamamlandiMi = item.etkinlik != null
        ? item.etkinlik!.oGunTamamlandiMi(item.tarih)
        : (item.finansItem?.odendi ?? false);

    return Card(
      color: item.isFinans
          ? (item.isPozitif == true ? r.gelirKart : r.giderKart)
          : r.ikincilKart,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: r.kenarlik),
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: item.renk.withAlpha(35),
          child: Icon(item.icon, color: item.renk, size: 19),
        ),
        title: Text(
          item.baslik,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13.5,
            decoration: tamamlandiMi ? TextDecoration.lineThrough : null,
            color: tamamlandiMi ? r.altMetin : r.metin,
          ),
        ),
        subtitle: Text(
          item.altMetin,
          style: TextStyle(color: r.altMetin, fontSize: 11.5),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: item.renk.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: item.renk.withAlpha(80)),
              ),
              child: Text(
                item.tarihEtiketi,
                style: TextStyle(
                  fontSize: 10.5,
                  color: item.renk,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (item.etkinlik != null || item.finansItem != null) ...[
              const SizedBox(width: 4),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: item.isFinans
                    ? (tamamlandiMi
                        ? 'ozet_tooltip_odenmedi'.tr
                        : 'ozet_tooltip_odendi'.tr)
                    : (tamamlandiMi
                        ? 'ozet_tooltip_yapilmadi'.tr
                        : 'ozet_tooltip_yapildi'.tr),
                icon: Icon(
                  tamamlandiMi
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: tamamlandiMi ? r.yesil : r.altMetin,
                  size: 19,
                ),
                onPressed: () {
                  if (item.etkinlik != null) {
                    widget.onEtkinlikTamamla?.call(item.etkinlik!, item.tarih);
                  } else if (item.finansItem != null) {
                    widget.onFinansOdendiToggle?.call(item.finansItem!);
                  }
                },
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'sil'.tr,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: r.kirmizi,
                  size: 19,
                ),
                onPressed: () {
                  if (item.etkinlik != null) {
                    final e = item.etkinlik!;
                    if (e.yineleme == 'Tek seferlik') {
                      widget.onEtkinlikSil?.call(e);
                    } else {
                      final bagliFinanslar = widget.finansIslemleri.where((f) {
                        if (f.yineleme == 'Tek seferlik') return false;
                        if (!f.takvimdeOgunMu(item.tarih)) return false;
                        final kokler = AkilliAsistanServisi
                            .anahtarKelimeleriCikar(e.baslik);
                        return AkilliAsistanServisi.mesaiGeliriMi(f) ||
                            AkilliAsistanServisi.metinEslesiyorMu(
                                f.baslik, kokler);
                      }).toList();

                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('ozet_tekrarli_etkinlik_sil_baslik'.tr),
                          content: Text(
                            'ozet_tekrarli_etkinlik_sil_icerik'.trParams({
                              'baslik': e.baslik,
                              'mesaiEk': bagliFinanslar.isNotEmpty
                                  ? 'ozet_bagli_mesai_ek'.tr
                                  : '',
                              'tarih': '${item.tarih.day}.${item.tarih.month}',
                            }),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text('vazgec'.tr),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                widget.onEtkinlikSil?.call(e);
                                for (final f in bagliFinanslar) {
                                  widget.onFinansSil?.call(f);
                                }
                              },
                              child: Text(
                                'tumunu_sil'.tr,
                                style: TextStyle(color: r.kirmizi),
                              ),
                            ),
                            FilledButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                widget.onEtkinlikTekGunIptal
                                    ?.call(e, item.tarih);
                                for (final f in bagliFinanslar) {
                                  widget.onFinansTekGunIptal
                                      ?.call(f, item.tarih);
                                }
                              },
                              child: Text('sadece_o_gunu_sil'.tr),
                            ),
                          ],
                        ),
                      );
                    }
                  } else if (item.finansItem != null) {
                    final f = item.finansItem!;
                    if (f.yineleme == 'Tek seferlik') {
                      widget.onFinansSil?.call(f);
                    } else {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('ozet_tekrarli_finans_sil_baslik'.tr),
                          content: Text(
                            'ozet_tekrarli_finans_sil_icerik'.trParams({
                              'baslik': f.baslik,
                              'tarih': '${item.tarih.day}.${item.tarih.month}',
                            }),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text('vazgec'.tr),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                widget.onFinansSil?.call(f);
                              },
                              child: Text(
                                'tumunu_sil'.tr,
                                style: TextStyle(color: r.kirmizi),
                              ),
                            ),
                            FilledButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                widget.onFinansTekGunIptal
                                    ?.call(f, item.tarih);
                              },
                              child: Text('sadece_o_gunu_sil'.tr),
                            ),
                          ],
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AkisKartData {
  final DateTime tarih;
  final String baslik;
  final String altMetin;
  final String tarihEtiketi;
  final IconData icon;
  final Color renk;
  final bool isFinans;
  final double? miktar;
  final bool? isPozitif;
  final Etkinlik? etkinlik;
  final FinansItem? finansItem;

  _AkisKartData({
    required this.tarih,
    required this.baslik,
    required this.altMetin,
    required this.tarihEtiketi,
    required this.icon,
    required this.renk,
    required this.isFinans,
    this.miktar,
    this.isPozitif,
    this.etkinlik,
    this.finansItem,
  });
}