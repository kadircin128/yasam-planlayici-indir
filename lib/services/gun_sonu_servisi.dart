import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GunSonuKayit {
  final String id;
  final String metin;
  final String mod;
  final DateTime tarih;
  final List<String> islenenAksiyonlar;
  final String? asistanYaniti;

  GunSonuKayit({
    required this.id,
    required this.metin,
    required this.mod,
    required this.tarih,
    required this.islenenAksiyonlar,
    this.asistanYaniti,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'metin': metin,
        'mod': mod,
        'tarih': tarih.toIso8601String(),
        'islenenAksiyonlar': islenenAksiyonlar,
        'aiYaniti': asistanYaniti,
      };

  factory GunSonuKayit.fromJson(Map<String, dynamic> json) => GunSonuKayit(
        id: json['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        metin: json['metin']?.toString() ?? '',
        mod: json['mod']?.toString() ?? '😊 İyi',
        tarih:
            DateTime.tryParse(json['tarih']?.toString() ?? '') ?? DateTime.now(),
        islenenAksiyonlar:
            List<String>.from(json['islenenAksiyonlar'] ?? const []),
        asistanYaniti: json['aiYaniti']?.toString(),
      );
}

class GunSonuServisi {
  static const String _storageKey = 'gun_sonu_kayitlari_v2';
  static const String _countKey = 'gun_sonu_not_sayisi';

  static final ValueNotifier<List<GunSonuKayit>> kayitlarNotifier =
      ValueNotifier<List<GunSonuKayit>>([]);

  static bool _yuklendi = false;

  static Future<void> yukle({bool zorla = false}) async {
    if (_yuklendi && !zorla) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        kayitlarNotifier.value =
            decoded.map((e) => GunSonuKayit.fromJson(e)).toList();
      }
      _yuklendi = true;
    } catch (e) {
      debugPrint('Gün sonu kayıtları yükleme hatası: $e');
    }
  }

  static Future<void> ekle(GunSonuKayit kayit) async {
    await yukle();
    final guncel = [...kayitlarNotifier.value, kayit];
    kayitlarNotifier.value = guncel;
    await _kaydet(guncel);
  }

  static Future<void> sil(String id) async {
    await yukle();
    final guncel = kayitlarNotifier.value.where((k) => k.id != id).toList();
    kayitlarNotifier.value = guncel;
    await _kaydet(guncel);
  }

  static Future<void> _kaydet(List<GunSonuKayit> liste) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode(liste.map((e) => e.toJson()).toList()),
      );
      await prefs.setInt(_countKey, liste.length);
    } catch (e) {
      debugPrint('Gün sonu kayıtları kaydetme hatası: $e');
    }
  }
}