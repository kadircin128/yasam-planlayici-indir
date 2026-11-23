import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/dil_servisi.dart';
import '../theme/app_renkler.dart';

class SuruklenebilirIsHavuzu extends StatefulWidget {
  final VoidCallback onTap;

  const SuruklenebilirIsHavuzu({
    super.key,
    required this.onTap,
  });

  @override
  State<SuruklenebilirIsHavuzu> createState() => _SuruklenebilirIsHavuzuState();
}

class _SuruklenebilirIsHavuzuState extends State<SuruklenebilirIsHavuzu> {
  double? _x;
  double? _y;
  bool _surukleniyor = false;

  @override
  void initState() {
    super.initState();
    _konumuYukle();
  }

  Future<void> _konumuYukle() async {
    final prefs = await SharedPreferences.getInstance();
    final kayitliX = prefs.getDouble('is_havuzu_pos_x');
    final kayitliY = prefs.getDouble('is_havuzu_pos_y');

    if (kayitliX != null && kayitliY != null && mounted) {
      setState(() {
        _x = kayitliX;
        _y = kayitliY;
      });
    }
  }

  Future<void> _konumuKaydet() async {
    if (_x == null || _y == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('is_havuzu_pos_x', _x!);
    await prefs.setDouble('is_havuzu_pos_y', _y!);
  }

  @override
  Widget build(BuildContext context) {
    final r = AppRenkler.of(context);
    final ekran = MediaQuery.of(context).size;
    final ustBosluk = MediaQuery.of(context).padding.top + 60;
    final altSinir = ekran.height - MediaQuery.of(context).padding.bottom - 145;
    final sagSinir = ekran.width - 135;

    final aktifX = (_x ?? sagSinir).clamp(12.0, sagSinir);
    final aktifY = (_y ?? altSinir).clamp(ustBosluk, altSinir);

    return Positioned(
      left: aktifX,
      top: aktifY,
      child: GestureDetector(
        onTap: widget.onTap,
        onPanStart: (_) {
          setState(() => _surukleniyor = true);
        },
        onPanUpdate: (detay) {
          setState(() {
            _x = (aktifX + detay.delta.dx).clamp(12.0, sagSinir);
            _y = (aktifY + detay.delta.dy).clamp(ustBosluk, altSinir);
          });
        },
        onPanEnd: (_) {
          setState(() => _surukleniyor = false);
          _konumuKaydet();
        },
        child: AnimatedScale(
          scale: _surukleniyor ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFF6C47FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _surukleniyor
                    ? Colors.white.withAlpha(180)
                    : (r.isDark
                        ? Colors.white.withAlpha(40)
                        : Colors.black.withAlpha(20)),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C47FF)
                      .withAlpha(_surukleniyor ? 160 : (r.isDark ? 95 : 75)),
                  blurRadius: _surukleniyor ? 18 : 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.inbox_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 7),
                Text(
                  'havuz_buton_etiket'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}