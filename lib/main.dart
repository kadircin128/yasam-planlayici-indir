import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/finans_item.dart';
import 'models/etkinlik.dart';
import 'models/gun_notu.dart';
import 'screens/ozet_ekrani.dart';
import 'screens/finans_ekrani.dart';
import 'screens/takvim_ekrani.dart';
import 'screens/gun_sonu_ekrani.dart';
import 'services/bildirim_servisi.dart';
import 'services/dil_servisi.dart';
import 'widgets/is_havuzu_sheet.dart';
import 'widgets/suruklenebilir_is_havuzu.dart';
import 'widgets/sayfa_kilavuzu.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DilServisi.instance.baslat();
  await BildirimServisi.baslat();
  runApp(const LifeSyncApp());
}

class LifeSyncApp extends StatefulWidget {
  const LifeSyncApp({super.key});

  @override
  State<LifeSyncApp> createState() => _LifeSyncAppState();
}

class _LifeSyncAppState extends State<LifeSyncApp> {
  bool _isDarkMode = true;

  @override
  void initState() {
    super.initState();
    _temaYukle();
  }

  Future<void> _temaYukle() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isDarkMode = prefs.getBool('is_dark_mode') ?? true;
    });
  }

  Future<void> _temaDegistir(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', isDark);
    if (!mounted) return;
    setState(() {
      _isDarkMode = isDark;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dilServisi = DilServisi.instance;

    return ListenableBuilder(
      listenable: dilServisi,
      builder: (context, _) {
        return MaterialApp(
          title: 'app_title'.tr,
          debugShowCheckedModeBanner: false,
          locale: dilServisi.locale,
          supportedLocales: dilServisi.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            return AnimatedOpacity(
              opacity: dilServisi.gecisOpakligi,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOut,
              child: child ?? const SizedBox.shrink(),
            );
          },
          themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
          darkTheme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardColor: const Color(0xFF1E1E1E),
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
          theme: ThemeData.light().copyWith(
            scaffoldBackgroundColor: const Color(0xFFF3F5F9),
            cardColor: Colors.white,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.light,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              foregroundColor: Color(0xFF181A20),
              elevation: 0,
            ),
          ),
          home: MainScreen(
            isDarkMode: _isDarkMode,
            onTemaDegistir: _temaDegistir,
          ),
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onTemaDegistir;

  const MainScreen({
    super.key,
    required this.isDarkMode,
    required this.onTemaDegistir,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  List<FinansItem> _finansIslemleri = [];
  List<Etkinlik> _etkinlikler = [];
  List<GunNotu> _gunNotlari = [];
  int _gunSonuNotSayisi = 0;

  String _kullaniciAd = 'varsayilan_kullanici'.tr;
  String _kullaniciEposta = '';

  @override
  void initState() {
    super.initState();
    _verileriYukle();
  }

  Future<void> _bildirimYanitiniIsle(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    final parcalar = payload.split('|');
    final tur = parcalar.first;

    if (tur == 'etkinlik_onay' && parcalar.length >= 4) {
      if (response.actionId != BildirimServisi.actionEvvet) return;

      final etkinlikId = parcalar[2];
      final tarihParca = parcalar[3].split('-');
      if (tarihParca.length != 3) return;

      final yil = int.tryParse(tarihParca[0]);
      final ay = int.tryParse(tarihParca[1]);
      final gun = int.tryParse(tarihParca[2]);
      if (yil == null || ay == null || gun == null) return;

      final hedefGun = DateTime(yil, ay, gun);
      final idx = _etkinlikler.indexWhere((e) => e.id == etkinlikId);
      if (idx == -1 || !mounted) return;

      setState(() {
        final e = _etkinlikler[idx];
        final yeniTamamlanan = List<DateTime>.from(e.tamamlananTarihler);
        final varMi = yeniTamamlanan.any((t) =>
            t.year == hedefGun.year &&
            t.month == hedefGun.month &&
            t.day == hedefGun.day);
        if (!varMi) {
          yeniTamamlanan.add(hedefGun);
        }
        _etkinlikler[idx] = e.copyWith(
          katildim: e.yineleme == 'Tek seferlik' ? true : e.katildim,
          tamamlananTarihler: yeniTamamlanan,
        );
      });
      await _verileriKaydet();
    } else if (tur == 'ekstre' && parcalar.length >= 3) {
      final kartId = parcalar[2];
      final hamGiris = response.input?.trim() ?? '';
      if (hamGiris.isEmpty) return;

      final temizSayi = hamGiris
          .replaceAll('₺', '')
          .replaceAll(RegExp(r'[^\d,.]'), '')
          .replaceAll('.', '')
          .replaceAll(',', '.');
      final tutar = double.tryParse(temizSayi);
      if (tutar == null || tutar <= 0) return;

      final idx = _finansIslemleri.indexWhere((f) => f.id == kartId);
      if (idx == -1 || !mounted) return;

      setState(() {
        final kart = _finansIslemleri[idx];
        _finansIslemleri[idx] = kart.copyWith(
          miktar: tutar,
          odenenMiktar: 0.0,
          odendi: false,
          ekstreGirildi: true,
        );
      });
      await _verileriKaydet();
    } else if (tur == 'gun_sonu' && mounted) {
      setState(() {
        _currentIndex = 3;
      });
    }
  }

  Future<void> _verileriYukle() async {
    final prefs = await SharedPreferences.getInstance();

    final finansStringList = prefs.getStringList('finans_islemleri');
    if (finansStringList != null) {
      _finansIslemleri = finansStringList
          .map((item) => FinansItem.fromJson(jsonDecode(item)))
          .toList();
    } else {
      _finansIslemleri = [];
    }

    final etkinlikStringList = prefs.getStringList('etkinlikler');
    if (etkinlikStringList != null) {
      _etkinlikler = etkinlikStringList
          .map((item) => Etkinlik.fromJson(jsonDecode(item)))
          .toList();
    } else {
      _etkinlikler = [];
    }

    final gunNotuStringList = prefs.getStringList('gun_notlari');
    if (gunNotuStringList != null) {
      _gunNotlari = gunNotuStringList
          .map((item) => GunNotu.fromJson(jsonDecode(item)))
          .toList();
    } else {
      _gunNotlari = [];
    }

    _gunSonuNotSayisi = prefs.getInt('gun_sonu_not_sayisi') ?? 0;
    _kullaniciAd = prefs.getString('profil_ad') ?? 'varsayilan_kullanici'.tr;
    _kullaniciEposta = prefs.getString('profil_eposta') ?? '';

    if (!mounted) return;
    setState(() {});

    await BildirimServisi.baslat(onYanit: _bildirimYanitiniIsle);
    await BildirimServisi.tumBildirimleriGuncelle(
      _finansIslemleri,
      _etkinlikler,
    );
  }

  Future<void> _verileriKaydet() async {
    final prefs = await SharedPreferences.getInstance();

    final finansJson =
        _finansIslemleri.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('finans_islemleri', finansJson);

    final etkinlikJson =
        _etkinlikler.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('etkinlikler', etkinlikJson);

    final gunNotuJson =
        _gunNotlari.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('gun_notlari', gunNotuJson);

    await prefs.setInt('gun_sonu_not_sayisi', _gunSonuNotSayisi);

    await BildirimServisi.tumBildirimleriGuncelle(
        _finansIslemleri, _etkinlikler);
  }

  Future<void> _profilKaydet(String ad, String eposta) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profil_ad', ad);
    await prefs.setString('profil_eposta', eposta);
    if (!mounted) return;
    setState(() {
      _kullaniciAd = ad;
      _kullaniciEposta = eposta;
    });
  }

  int _finansIndexBul(FinansItem islem) {
    final exactIdx = _finansIslemleri.indexWhere((e) => identical(e, islem));
    if (exactIdx != -1) return exactIdx;
    return _finansIslemleri.indexWhere(
      (e) => e.id == islem.id && _ayniGunMu(e.tarih, islem.tarih),
    );
  }

  int _etkinlikIndexBul(Etkinlik etkinlik) {
    final exactIdx = _etkinlikler.indexWhere((e) => identical(e, etkinlik));
    if (exactIdx != -1) return exactIdx;
    return _etkinlikler.indexWhere((e) => e.id == etkinlik.id);
  }

  void _finansEkle(FinansItem item) {
    final ayniVarMi = _finansIslemleri.any((f) =>
        f.id == item.id ||
        (f.baslik == item.baslik &&
            f.miktar == item.miktar &&
            _ayniGunMu(f.tarih, item.tarih)));

    if (ayniVarMi) return;

    setState(() {
      _finansIslemleri.insert(0, item);
    });
    _verileriKaydet();
  }

  void _finansDuzenle(int index, FinansItem yeniItem) {
    setState(() {
      _finansIslemleri[index] = yeniItem;
    });
    _verileriKaydet();
  }

  void _finansSil(int index) {
    setState(() {
      _finansIslemleri.removeAt(index);
    });
    _verileriKaydet();
  }

  void _finansOdendiDegistir(FinansItem islem) {
    final idx = _finansIndexBul(islem);
    if (idx == -1) return;

    final yeniDurum = !islem.odendi;
    setState(() {
      _finansIslemleri[idx] = islem.copyWith(
        odendi: yeniDurum,
        odenenMiktar: yeniDurum ? islem.miktar : 0.0,
      );
    });
    _verileriKaydet();
  }

  bool _ayniGunMu(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _etkinlikEkle(Etkinlik item) {
    setState(() {
      _etkinlikler.insert(0, item);
    });
    _verileriKaydet();
  }

  void _etkinlikDuzenle(int index, Etkinlik yeniEtkinlik) {
    setState(() {
      _etkinlikler[index] = yeniEtkinlik;
    });
    _verileriKaydet();
  }

  void _etkinlikSil(int index) {
    final silinen = _etkinlikler[index];

    setState(() {
      _etkinlikler.removeAt(index);

      _finansIslemleri.removeWhere((islem) {
        final mesaiKaydiMi = islem.baslik.contains('Mesai Geliri') ||
            islem.baslik.contains('Yevmiye');
        if (!mesaiKaydiMi) return false;
        if (silinen.yineleme != 'Tek seferlik') {
          return islem.baslik.startsWith(silinen.baslik);
        }
        return _ayniGunMu(islem.tarih, silinen.tarih);
      });
    });

    _verileriKaydet();
  }

  void _etkinlikTekGunIptalKaydet(Etkinlik etkinlik, DateTime iptalTarihi) {
    final idx = _etkinlikIndexBul(etkinlik);
    if (idx != -1) {
      final mevcut = _etkinlikler[idx];
      final guncelIptaller = List<DateTime>.from(mevcut.iptalTarihler);
      if (!mevcut.oGunIptalMi(iptalTarihi)) {
        guncelIptaller.add(
          DateTime(iptalTarihi.year, iptalTarihi.month, iptalTarihi.day),
        );
      }
      setState(() {
        _etkinlikler[idx] = mevcut.copyWith(
          iptalTarihler: guncelIptaller,
        );
      });
      _verileriKaydet();
    }
  }

  void _finansTekGunIptalKaydet(FinansItem finansItem, DateTime iptalTarihi) {
    final idx = _finansIndexBul(finansItem);
    if (idx != -1) {
      final mevcut = _finansIslemleri[idx];
      final guncelIptaller = List<DateTime>.from(mevcut.iptalTarihler);
      if (!mevcut.oGunIptalMi(iptalTarihi)) {
        guncelIptaller.add(
          DateTime(iptalTarihi.year, iptalTarihi.month, iptalTarihi.day),
        );
      }
      setState(() {
        _finansIslemleri[idx] = mevcut.copyWith(
          iptalTarihler: guncelIptaller,
        );
      });
      _verileriKaydet();
    }
  }

  void _gunNotuEkle(GunNotu not) {
    setState(() {
      _gunNotlari.removeWhere((n) => _ayniGunMu(n.tarih, not.tarih));
      _gunNotlari.add(not);
    });
    _verileriKaydet();
  }

  void _profilPopupGoster(BuildContext context) {
    final adController = TextEditingController(text: _kullaniciAd);
    final epostaController = TextEditingController(text: _kullaniciEposta);
    bool geciciDark = widget.isDarkMode;
    String? seciliSehir;
    TimeOfDay gunSonuSaati = const TimeOfDay(hour: 21, minute: 30);
    bool ayarlarYuklendi = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return ListenableBuilder(
          listenable: DilServisi.instance,
          builder: (context, _) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                if (!ayarlarYuklendi) {
                  ayarlarYuklendi = true;
                  Future.microtask(() async {
                    final kayitliSehir = await BildirimServisi.sehirGetir();
                    final kayitliSaat =
                        await BildirimServisi.gunSonuSaatiGetir();
                    if (context.mounted) {
                      setDialogState(() {
                        seciliSehir = kayitliSehir;
                        gunSonuSaati = TimeOfDay(
                          hour: kayitliSaat.saat,
                          minute: kayitliSaat.dakika,
                        );
                      });
                    }
                  });
                }

                return AlertDialog(
                  backgroundColor:
                      geciciDark ? const Color(0xFF1E1E1E) : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: [
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.deepPurple,
                        child: Icon(Icons.settings_rounded,
                            size: 18, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'ayarlar_gorunum'.tr,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: geciciDark
                                ? Colors.white
                                : const Color(0xFF181A20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: adController,
                          decoration: InputDecoration(
                            labelText: 'ad_soyad'.tr,
                            prefixIcon: const Icon(Icons.badge_rounded,
                                color: Colors.deepPurpleAccent),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: epostaController,
                          decoration: InputDecoration(
                            labelText: 'eposta_adresi'.tr,
                            prefixIcon: const Icon(Icons.email_rounded,
                                color: Colors.deepPurpleAccent),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: BildirimServisi.turkiyeIlleri
                                  .any((s) => s.ad == seciliSehir)
                              ? seciliSehir
                              : null,
                          hint: Text(
                            'sehir_seciniz'.tr,
                            style: TextStyle(
                              color:
                                  geciciDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                          decoration: InputDecoration(
                            labelText: 'sehir_etiket'.tr,
                            prefixIcon: const Icon(Icons.location_city_rounded,
                                color: Colors.deepPurpleAccent),
                          ),
                          dropdownColor: geciciDark
                              ? const Color(0xFF262626)
                              : Colors.white,
                          items: BildirimServisi.turkiyeIlleri
                              .map(
                                (sehir) => DropdownMenuItem<String>(
                                  value: sehir.ad,
                                  child: Text(
                                    sehir.ad,
                                    style: TextStyle(
                                      color: geciciDark
                                          ? Colors.white
                                          : const Color(0xFF181A20),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            setDialogState(() => seciliSehir = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: DilServisi.instance.dilKodu,
                          decoration: InputDecoration(
                            labelText: 'dil_secimi'.tr,
                            prefixIcon: const Icon(Icons.language_rounded,
                                color: Colors.deepPurpleAccent),
                          ),
                          dropdownColor: geciciDark
                              ? const Color(0xFF262626)
                              : Colors.white,
                          items: DilServisi.desteklenenDiller
                              .map(
                                (dil) => DropdownMenuItem<String>(
                                  value: dil.kod,
                                  child: Text(
                                    '${dil.bayrak}  ${dil.ad}',
                                    style: TextStyle(
                                      color: geciciDark
                                          ? Colors.white
                                          : const Color(0xFF181A20),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (yeniDil) {
                            if (yeniDil != null) {
                              DilServisi.instance.dilDegistir(yeniDil);
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.nights_stay_rounded,
                              color: Colors.deepPurpleAccent),
                          title: Text(
                            'gun_sonu_saati'.tr,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: geciciDark
                                  ? Colors.white
                                  : const Color(0xFF181A20),
                            ),
                          ),
                          trailing: Text(
                            '${gunSonuSaati.hour.toString().padLeft(2, '0')}:${gunSonuSaati.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurpleAccent,
                            ),
                          ),
                          onTap: () async {
                            final secilen = await showTimePicker(
                              context: context,
                              initialTime: gunSonuSaati,
                            );
                            if (secilen != null) {
                              setDialogState(() => gunSonuSaati = secilen);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary: Icon(
                            geciciDark
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            color: geciciDark
                                ? Colors.amberAccent
                                : Colors.deepPurple,
                          ),
                          title: Text(
                            geciciDark
                                ? 'karanlik_mod'.tr
                                : 'aydinlik_mod'.tr,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: geciciDark
                                  ? Colors.white
                                  : const Color(0xFF181A20),
                            ),
                          ),
                          subtitle: Text(
                            geciciDark
                                ? 'karanlik_mod_alt'.tr
                                : 'aydinlik_mod_alt'.tr,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                          value: geciciDark,
                          activeThumbColor: Colors.deepPurpleAccent,
                          onChanged: (val) {
                            setDialogState(() => geciciDark = val);
                            widget.onTemaDegistir(val);
                          },
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(
                        'kapat'.tr,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple),
                      onPressed: () {
                        final ad = adController.text.trim().isEmpty
                            ? 'varsayilan_kullanici'.tr
                            : adController.text.trim();
                        final eposta = epostaController.text.trim();
                        final kaydedilecekSehir = seciliSehir;
                        final kaydedilecekSaat = gunSonuSaati;

                        Navigator.of(dialogContext).pop();

                        Future.microtask(() async {
                          await _profilKaydet(ad, eposta);
                          await BildirimServisi.sehirKaydet(kaydedilecekSehir);
                          await BildirimServisi.gunSonuSaatiKaydet(
                            kaydedilecekSaat.hour,
                            kaydedilecekSaat.minute,
                          );
                          await BildirimServisi.tumBildirimleriGuncelle(
                            _finansIslemleri,
                            _etkinlikler,
                          );
                        });

                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'ayarlar_kaydedildi'.trParams({
                                'sehir':
                                    kaydedilecekSehir ?? 'sehir_secilmedi'.tr,
                                'saat':
                                    '${kaydedilecekSaat.hour.toString().padLeft(2, '0')}:${kaydedilecekSaat.minute.toString().padLeft(2, '0')}',
                              }),
                            ),
                          ),
                        );
                      },
                      child: Text(
                        'kaydet'.tr,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    ).whenComplete(() {
      adController.dispose();
      epostaController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      // 1. SIRADA: ÖZET (Index 0)
      OzetEkrani(
        finansIslemleri: _finansIslemleri,
        etkinlikler: _etkinlikler,
        gunSonuNotSayisi: _gunSonuNotSayisi,
        onEtkinlikTamamla: (etkinlik, gun) {
          final idx = _etkinlikler.indexWhere((e) => e.id == etkinlik.id);
          if (idx == -1) return;

          setState(() {
            final e = _etkinlikler[idx];
            final temizGun = DateTime(gun.year, gun.month, gun.day);
            final yeniTamamlanan = List<DateTime>.from(e.tamamlananTarihler);

            final varMi = yeniTamamlanan.any((t) =>
                t.year == temizGun.year &&
                t.month == temizGun.month &&
                t.day == temizGun.day);

            if (varMi) {
              yeniTamamlanan.removeWhere((t) =>
                  t.year == temizGun.year &&
                  t.month == temizGun.month &&
                  t.day == temizGun.day);
            } else {
              yeniTamamlanan.add(temizGun);
            }

            _etkinlikler[idx] = e.copyWith(
              katildim: e.yineleme == 'Tek seferlik' ? !varMi : e.katildim,
              tamamlananTarihler: yeniTamamlanan,
            );
          });
          _verileriKaydet();
        },
        onEtkinlikSil: (etkinlik) {
          final idx = _etkinlikIndexBul(etkinlik);
          if (idx != -1) _etkinlikSil(idx);
        },
        onFinansOdendiToggle: _finansOdendiDegistir,
        onFinansSil: (islem) {
          final idx = _finansIndexBul(islem);
          if (idx != -1) _finansSil(idx);
        },
        onFinansEkle: _finansEkle,
        onEtkinlikEkle: _etkinlikEkle,
        onIslemDuzenle: _finansDuzenle,
        onEtkinlikTekGunIptal: _etkinlikTekGunIptalKaydet,
        onFinansTekGunIptal: _finansTekGunIptalKaydet,
        onEtkinlikTarihGuncelle: (etkinlik, yeniTarih) {
          final idx = _etkinlikIndexBul(etkinlik);
          if (idx != -1) {
            setState(() {
              _etkinlikler[idx] = _etkinlikler[idx].copyWith(
                tarih: yeniTarih,
              );
            });
            _verileriKaydet();
          }
        },
        onFinansTarihGuncelle: (islem, yeniTarih) {
          final idx = _finansIndexBul(islem);
          if (idx != -1) {
            setState(() {
              _finansIslemleri[idx] = _finansIslemleri[idx].copyWith(
                tarih: yeniTarih,
              );
            });
            _verileriKaydet();
          }
        },
        onGunSonuKayitEklendi: () async {
          final prefs = await SharedPreferences.getInstance();
          if (!mounted) return;
          setState(() {
            _gunSonuNotSayisi = prefs.getInt('gun_sonu_not_sayisi') ??
                (_gunSonuNotSayisi + 1);
          });
        },
      ),

      // 2. SIRADA: FİNANS (Index 1)
      FinansEkrani(
        islemler: _finansIslemleri,
        onIslemEkle: _finansEkle,
        onIslemDuzenle: _finansDuzenle,
        onIslemSil: _finansSil,
      ),

      // 3. SIRADA: TAKVİM (Index 2)
      TakvimEkrani(
        etkinlikler: _etkinlikler,
        finansIslemleri: _finansIslemleri,
        gunNotlari: _gunNotlari,
        onEtkinlikEkle: _etkinlikEkle,
        onEtkinlikDuzenle: _etkinlikDuzenle,
        onEtkinlikSil: _etkinlikSil,
        onEtkinlikTekGunIptal: _etkinlikTekGunIptalKaydet,
        onDurumDegistir: (index, gun) {
          setState(() {
            final e = _etkinlikler[index];
            final temizGun = DateTime(gun.year, gun.month, gun.day);

            if (e.yineleme == 'Tek seferlik') {
              final yeniDurum = !e.katildim;
              final yeniTamamlanan = List<DateTime>.from(e.tamamlananTarihler);
              if (yeniDurum) {
                if (!yeniTamamlanan.any((t) =>
                    t.year == temizGun.year &&
                    t.month == temizGun.month &&
                    t.day == temizGun.day)) {
                  yeniTamamlanan.add(temizGun);
                }
              } else {
                yeniTamamlanan.removeWhere((t) =>
                    t.year == temizGun.year &&
                    t.month == temizGun.month &&
                    t.day == temizGun.day);
              }
              _etkinlikler[index] = e.copyWith(
                katildim: yeniDurum,
                tamamlananTarihler: yeniTamamlanan,
              );
            } else {
              final yeniTamamlanan = List<DateTime>.from(e.tamamlananTarihler);
              final varMi = yeniTamamlanan.any((t) =>
                  t.year == temizGun.year &&
                  t.month == temizGun.month &&
                  t.day == temizGun.day);

              if (varMi) {
                yeniTamamlanan.removeWhere((t) =>
                    t.year == temizGun.year &&
                    t.month == temizGun.month &&
                    t.day == temizGun.day);
              } else {
                yeniTamamlanan.add(temizGun);
              }

              _etkinlikler[index] = e.copyWith(
                tamamlananTarihler: yeniTamamlanan,
              );
            }
          });
          _verileriKaydet();
        },
        onGunNotuEkle: _gunNotuEkle,
        onFinansEkle: _finansEkle,
        onFinansOdendiToggle: _finansOdendiDegistir,
        onFinansSil: (islem) {
          final idx = _finansIndexBul(islem);
          if (idx != -1) _finansSil(idx);
        },
        onFinansTekGunIptal: _finansTekGunIptalKaydet,
      ),

      // 4. SIRADA: GÜN SONU (Index 3)
      GunSonuEkrani(
        islemler: _finansIslemleri,
        onIslemDuzenle: _finansDuzenle,
        etkinlikler: _etkinlikler,
        onFinansEkle: _finansEkle,
        onEtkinlikEkle: _etkinlikEkle,
        onEtkinlikSil: (etkinlik) {
          final idx = _etkinlikIndexBul(etkinlik);
          if (idx != -1) _etkinlikSil(idx);
        },
        onEtkinlikTekGunIptal: _etkinlikTekGunIptalKaydet,
        onEtkinlikTarihGuncelle: (etkinlik, yeniTarih) {
          final idx = _etkinlikIndexBul(etkinlik);
          if (idx != -1) {
            setState(() {
              _etkinlikler[idx] = _etkinlikler[idx].copyWith(
                tarih: yeniTarih,
              );
            });
            _verileriKaydet();
          }
        },
        onFinansSil: (islem) {
          final idx = _finansIndexBul(islem);
          if (idx != -1) _finansSil(idx);
        },
        onFinansTarihGuncelle: (islem, yeniTarih) {
          final idx = _finansIndexBul(islem);
          if (idx != -1) {
            setState(() {
              _finansIslemleri[idx] = _finansIslemleri[idx].copyWith(
                tarih: yeniTarih,
              );
            });
            _verileriKaydet();
          }
        },
      ),
    ];

    return ListenableBuilder(
      listenable: DilServisi.instance,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text('yasam_planlayici'.tr),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const CircleAvatar(
                  radius: 15,
                  backgroundColor: Colors.deepPurple,
                  child: Icon(
                    Icons.settings_rounded,
                    size: 17,
                    color: Colors.white,
                  ),
                ),
                tooltip: 'ayarlar'.tr,
                onPressed: () => _profilPopupGoster(context),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Stack(
            children: [
              pages[_currentIndex],
              SuruklenebilirIsHavuzu(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: widget.isDarkMode
                        ? const Color(0xFF161616)
                        : Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (_) => IsHavuzuSheet(
                      etkinlikler: _etkinlikler,
                      onEtkinlikEkle: _etkinlikEkle,
                    ),
                  );
                },
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              SayfaKilavuzu.kapat();
              setState(() {
                _currentIndex = index;
              });
            },
            destinations: [
              NavigationDestination(
                  icon: const Icon(Icons.dashboard_rounded),
                  label: 'nav_ozet'.tr),
              NavigationDestination(
                  icon: const Icon(Icons.account_balance_wallet_rounded),
                  label: 'nav_finans'.tr),
              NavigationDestination(
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: 'nav_takvim'.tr),
              NavigationDestination(
                  icon: const Icon(Icons.bedtime_rounded),
                  label: 'nav_gun_sonu'.tr),
            ],
          ),
        );
      },
    );
  }
}