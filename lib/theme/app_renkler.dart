import 'package:flutter/material.dart';

class AppRenkler {
  final bool isDark;

  const AppRenkler._(this.isDark);

  factory AppRenkler.of(BuildContext context) {
    return AppRenkler._(Theme.of(context).brightness == Brightness.dark);
  }

  // Arka Planlar
  Color get arkaPlan => isDark ? const Color(0xFF121212) : const Color(0xFFF3F5F9);
  Color get kart => isDark ? const Color(0xFF1E1E1E) : Colors.white;
  Color get ikincilKart => isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE9EDF5);
  Color get takvimKutu => isDark ? const Color(0xFF252525) : const Color(0xFFF7F8FC);
  Color get dialog => isDark ? const Color(0xFF1E1E1E) : Colors.white;
  Color get sheet => isDark ? const Color(0xFF161616) : Colors.white;

  // Özel Durum Kartları
  Color get tamamlananKart => isDark ? const Color(0xFF1B241E) : const Color(0xFFE8F7EE);
  Color get gelirKart => isDark ? const Color(0xFF1A251E) : const Color(0xFFECF9F0);
  Color get giderKart => isDark ? const Color(0xFF251A1A) : const Color(0xFFFDF0F0);
  Color get notKart => isDark ? const Color(0xFF231C2E) : const Color(0xFFF3EEFA);
  Color get acilKart => isDark ? const Color(0xFF331414) : const Color(0xFFFEECEC);

  // Metin & Kenarlık
  Color get metin => isDark ? Colors.white : const Color(0xFF181A20);
  Color get altMetin => isDark ? Colors.grey : const Color(0xFF5E6573);
  Color get solukMetin => isDark ? Colors.white70 : const Color(0xFF374151);
  Color get kenarlik => isDark ? Colors.white10 : const Color(0xFFDDE2EC);

  // Vurgu Renkleri (Light modda beyaz üstünde net okunması için kontrast ayarlı)
  Color get yesil => isDark ? Colors.greenAccent : const Color(0xFF15803D);
  Color get kirmizi => isDark ? Colors.redAccent : const Color(0xFFDC2626);
  Color get turuncu => isDark ? Colors.orangeAccent : const Color(0xFFD97706);
  Color get sari => isDark ? Colors.amberAccent : const Color(0xFFB45309);
  Color get mavi => isDark ? Colors.blueAccent : const Color(0xFF1D4ED8);
  Color get acikMavi => isDark ? Colors.lightBlueAccent : const Color(0xFF0284C7);
  Color get turkuaz => isDark ? Colors.tealAccent : const Color(0xFF0F766E);
  Color get camgobegi => isDark ? Colors.cyanAccent : const Color(0xFF0E7490);
  Color get pembe => isDark ? Colors.pinkAccent : const Color(0xFFBE185D);
  Color get mor => isDark ? Colors.deepPurpleAccent : const Color(0xFF5B21B6);
  Color get morAcik => isDark ? Colors.purpleAccent : const Color(0xFF7E22CE);
}