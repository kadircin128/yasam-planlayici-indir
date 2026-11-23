import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/dil_servisi.dart';
import '../theme/app_renkler.dart';

class KilavuzAdimi {
  final GlobalKey key;
  final String baslik;
  final String aciklama;
  final IconData ikon;

  const KilavuzAdimi({
    required this.key,
    required this.baslik,
    required this.aciklama,
    this.ikon = Icons.lightbulb_outline_rounded,
  });
}

class KilavuzYardimButonu extends StatelessWidget {
  final VoidCallback onPressed;

  const KilavuzYardimButonu({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final r = AppRenkler.of(context);

    return Tooltip(
      message: 'kilavuz_tooltip'.tr,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: r.ikincilKart,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: r.mor.withAlpha(160),
            ),
          ),
          child: Center(
            child: Text(
              '?',
              style: TextStyle(
                color: r.mor,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SayfaKilavuzu {
  static OverlayEntry? _aktifOverlay;

  static void kapat() {
    _aktifOverlay?.remove();
    _aktifOverlay = null;
  }

  /// Sayfaya ilk defa girildiğinde kılavuzu otomatik başlatır
  static Future<void> ilkGirisKontrolEt({
    required BuildContext context,
    required String sayfaId,
    required List<KilavuzAdimi> adimlar,
  }) async {
    await Future.delayed(const Duration(milliseconds: 450));
    if (!context.mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final goruldu = prefs.getBool('kilavuz_goruldu_$sayfaId') ?? false;
    if (goruldu || !context.mounted) return;

    goster(
      context: context,
      sayfaId: sayfaId,
      adimlar: adimlar,
    );
  }

  /// Sağ üstteki '?' butonuna basıldığında kılavuzu manuel açar
  static void goster({
    required BuildContext context,
    required String sayfaId,
    required List<KilavuzAdimi> adimlar,
  }) {
    kapat();

    final gecerliAdimlar =
        adimlar.where((a) => a.key.currentContext != null).toList();
    if (gecerliAdimlar.isEmpty) return;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _aktifOverlay = OverlayEntry(
      builder: (_) => _KilavuzOverlayWidget(
        sayfaId: sayfaId,
        adimlar: gecerliAdimlar,
        onKapat: kapat,
      ),
    );

    overlay.insert(_aktifOverlay!);
  }
}

class _KilavuzOverlayWidget extends StatefulWidget {
  final String sayfaId;
  final List<KilavuzAdimi> adimlar;
  final VoidCallback onKapat;

  const _KilavuzOverlayWidget({
    required this.sayfaId,
    required this.adimlar,
    required this.onKapat,
  });

  @override
  State<_KilavuzOverlayWidget> createState() => _KilavuzOverlayWidgetState();
}

class _KilavuzOverlayWidgetState extends State<_KilavuzOverlayWidget> {
  final GlobalKey _kartKey = GlobalKey();
  int _aktifIndex = 0;
  Rect? _hedefRect;
  Rect? _kartRect;

  @override
  void initState() {
    super.initState();
    _adimiHazirla();
  }

  Future<void> _adimiHazirla() async {
    if (!mounted) return;
    final adim = widget.adimlar[_aktifIndex];
    final targetCtx = adim.key.currentContext;

    if (targetCtx == null) {
      _sonrakiAdim();
      return;
    }

    try {
      await Scrollable.ensureVisible(
        targetCtx,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        alignment: 0.3,
      );
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 60));
    if (!mounted) return;

    final renderBox = targetCtx.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final pos = renderBox.localToGlobal(Offset.zero);
      setState(() {
        _hedefRect = (pos & renderBox.size).inflate(6.0);
        _kartRect = null;
      });
      _kartKonumunuOlc();
    } else {
      setState(() {
        _hedefRect = null;
        _kartRect = null;
      });
    }
  }

  void _kartKonumunuOlc() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final kartBox = _kartKey.currentContext?.findRenderObject() as RenderBox?;
      if (kartBox != null && kartBox.hasSize) {
        final pos = kartBox.localToGlobal(Offset.zero);
        setState(() {
          _kartRect = pos & kartBox.size;
        });
      }
    });
  }

  Future<void> _tamamlaVeKapat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('kilavuz_goruldu_${widget.sayfaId}', true);
    widget.onKapat();
  }

  void _sonrakiAdim() {
    if (_aktifIndex + 1 < widget.adimlar.length) {
      setState(() {
        _aktifIndex++;
      });
      _adimiHazirla();
    } else {
      _tamamlaVeKapat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = AppRenkler.of(context);
    final media = MediaQuery.of(context);
    final screenW = media.size.width;
    final screenH = media.size.height;
    final topPad = media.padding.top;
    final bottomPad = media.padding.bottom;

    final adim = widget.adimlar[_aktifIndex];
    final sonAdimMi = _aktifIndex == widget.adimlar.length - 1;

    final bool ustteGoster =
        _hedefRect != null && _hedefRect!.center.dy > screenH * 0.52;

    final double cardW = min(screenW - 32.0, 340.0);
    final double cardLeft = _hedefRect != null
        ? (_hedefRect!.center.dx - cardW / 2).clamp(16.0, screenW - cardW - 16.0)
        : (screenW - cardW) / 2;

    Offset? okBaslangic;
    Offset? okBitis;

    if (_hedefRect != null && _kartRect != null) {
      final hedefX = _hedefRect!.center.dx.clamp(24.0, screenW - 24.0);
      if (ustteGoster) {
        okBaslangic = Offset(_kartRect!.center.dx, _kartRect!.bottom + 2);
        okBitis = Offset(hedefX, _hedefRect!.top - 4);
      } else {
        okBaslangic = Offset(_kartRect!.center.dx, _kartRect!.top - 2);
        okBitis = Offset(hedefX, _hedefRect!.bottom + 4);
      }
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _SpotlightPainter(hedefRect: _hedefRect),
              ),
            ),
          ),
          if (okBaslangic != null && okBitis != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _OkPainter(
                    baslangic: okBaslangic,
                    bitis: okBitis,
                  ),
                ),
              ),
            ),
          Positioned(
            left: cardLeft,
            width: cardW,
            top: _hedefRect == null
                ? screenH * 0.35
                : (!ustteGoster
                    ? (_hedefRect!.bottom + 34.0)
                        .clamp(topPad + 16.0, screenH - bottomPad - 210.0)
                    : null),
            bottom: (_hedefRect != null && ustteGoster)
                ? (screenH - _hedefRect!.top + 34.0)
                    .clamp(bottomPad + 16.0, screenH - topPad - 210.0)
                : null,
            child: Container(
              key: _kartKey,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: r.isDark ? const Color(0xFF1E1E24) : r.dialog,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: r.mor,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(r.isDark ? 180 : 70),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: r.mor.withAlpha(r.isDark ? 80 : 28),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          adim.ikon,
                          color: r.sari,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          adim.baslik,
                          style: TextStyle(
                            color: r.metin,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: r.ikincilKart,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'kilavuz_adim_sayac'.trParams({
                            'aktif': '${_aktifIndex + 1}',
                            'toplam': '${widget.adimlar.length}',
                          }),
                          style: TextStyle(
                            color: r.altMetin,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    adim.aciklama,
                    style: TextStyle(
                      color: r.solukMetin,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: _tamamlaVeKapat,
                        style: TextButton.styleFrom(
                          foregroundColor: r.altMetin,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: Text(
                          'kilavuz_atla'.tr,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _sonrakiAdim,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        child: Text(
                          sonAdimMi
                              ? 'kilavuz_anladim'.tr
                              : 'kilavuz_sonraki'.tr,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? hedefRect;

  _SpotlightPainter({required this.hedefRect});

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Offset.zero & size;
    canvas.saveLayer(fullRect, Paint());

    canvas.drawRect(
      fullRect,
      Paint()..color = Colors.black.withAlpha(205),
    );

    if (hedefRect != null) {
      final rrect = RRect.fromRectAndRadius(
        hedefRect!,
        const Radius.circular(12),
      );

      canvas.drawRRect(
        rrect,
        Paint()..blendMode = BlendMode.clear,
      );

      canvas.restore();

      canvas.drawRRect(
        rrect,
        Paint()
          ..color = Colors.deepPurpleAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    } else {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.hedefRect != hedefRect;
  }
}

class _OkPainter extends CustomPainter {
  final Offset baslangic;
  final Offset bitis;

  _OkPainter({required this.baslangic, required this.bitis});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.amberAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;

    final midY = (baslangic.dy + bitis.dy) / 2;
    final path = Path()
      ..moveTo(baslangic.dx, baslangic.dy)
      ..cubicTo(
        baslangic.dx,
        midY,
        bitis.dx,
        midY,
        bitis.dx,
        bitis.dy,
      );

    canvas.drawPath(path, paint);

    final angle = atan2(bitis.dy - midY, 0);
    const okBoyu = 10.0;
    const aci = 0.55;

    final p1 = Offset(
      bitis.dx - okBoyu * cos(angle - aci),
      bitis.dy - okBoyu * sin(angle - aci),
    );
    final p2 = Offset(
      bitis.dx - okBoyu * cos(angle + aci),
      bitis.dy - okBoyu * sin(angle + aci),
    );

    final headPath = Path()
      ..moveTo(bitis.dx, bitis.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();

    canvas.drawPath(
      headPath,
      Paint()
        ..color = Colors.amberAccent
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _OkPainter oldDelegate) {
    return oldDelegate.baslangic != baslangic || oldDelegate.bitis != bitis;
  }
}