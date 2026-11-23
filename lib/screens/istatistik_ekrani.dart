import 'package:flutter/material.dart';
import '../models/finans_item.dart';
import '../models/etkinlik.dart';
import '../services/dil_servisi.dart';

class IstatistikEkrani extends StatelessWidget {
  final List<FinansItem> finansIslemleri;
  final List<Etkinlik> etkinlikler;

  const IstatistikEkrani({
    super.key,
    required this.finansIslemleri,
    required this.etkinlikler,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Finansal Hesaplamalar
    double toplamGelir = 0;
    double toplamGider = 0;
    double kartGideri = 0;
    double faturaGideri = 0;
    double rutinGider = 0;
    double borcGideri = 0;

    for (var f in finansIslemleri) {
      final isPozitif = f.tur == 'Gelir' || f.tur == 'Alacak';

      if (isPozitif) {
        toplamGelir += f.miktar;
      } else {
        final tutar = f.tahminiOdeme;
        toplamGider += tutar;

        if (f.tur == 'Kredi Kartı') {
          kartGideri += tutar;
        } else if (f.tur == 'Fatura') {
          faturaGideri += tutar;
        } else if (f.tur == 'Borç') {
          borcGideri += tutar;
        } else {
          rutinGider += tutar;
        }
      }
    }

    final double netFark = toplamGelir - toplamGider;
    final double toplamAkis = toplamGelir + toplamGider;
    final double gelirOrani = toplamAkis > 0 ? (toplamGelir / toplamAkis) : 0.5;

    // 2. Etkinlik Tamamlanma Oranı
    final int toplamEtkinlik = etkinlikler.length;
    final int tamamlananEtkinlik = etkinlikler.where((e) => e.katildim).length;
    final double etkinlikBasariOrani =
        toplamEtkinlik > 0 ? (tamamlananEtkinlik / toplamEtkinlik) : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Colors.deepPurpleAccent,
                child: Icon(Icons.bar_chart_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ist_ekran_baslik'.tr,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('ist_ekran_alt'.tr,
                      style:
                          TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // --- GELİR / GİDER DENGESİ ÇUBUĞU ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ist_gelir_gider_dengesi'.tr,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: gelirOrani,
                    minHeight: 14,
                    backgroundColor: Colors.redAccent.shade700,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ist_gelir_tutar'
                          .trParams({'tutar': toplamGelir.toStringAsFixed(0)}),
                      style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                    Text(
                      'ist_gider_tutar'
                          .trParams({'tutar': toplamGider.toStringAsFixed(0)}),
                      style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ],
                ),
                const Divider(height: 20, color: Colors.white10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ist_net_durum'.tr,
                        style: const TextStyle(color: Colors.grey)),
                    Text(
                      '${netFark >= 0 ? '+' : ''}${netFark.toStringAsFixed(0)} ₺',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: netFark >= 0
                            ? Colors.greenAccent
                            : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // --- HARCAMA TÜRÜ KIRILIMI ---
          Text('ist_harcama_kirilimi'.tr,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          _buildKategoriBar('ist_kat_kredi_kartlari'.tr, kartGideri,
              toplamGider, Colors.blueAccent, Icons.credit_card_rounded),
          _buildKategoriBar('ist_kat_faturalar'.tr, faturaGideri, toplamGider,
              Colors.orangeAccent, Icons.receipt_long_rounded),
          _buildKategoriBar('ist_kat_rutin_giderler'.tr, rutinGider,
              toplamGider, Colors.purpleAccent, Icons.shopping_bag_rounded),
          _buildKategoriBar('ist_kat_borc_odemeleri'.tr, borcGideri,
              toplamGider, Colors.redAccent, Icons.handshake_rounded),

          const SizedBox(height: 20),

          // --- AJANDA & ETKİNLİK BAŞARIM ORANI ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ist_gorev_tamamlama'.tr,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    Text('%${(etkinlikBasariOrani * 100).toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurpleAccent)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: etkinlikBasariOrani,
                    minHeight: 10,
                    backgroundColor: const Color(0xFF2A2A2A),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.deepPurpleAccent),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'ist_etkinlik_ozet'.trParams({
                    'toplam': toplamEtkinlik.toString(),
                    'tamamlanan': tamamlananEtkinlik.toString(),
                  }),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKategoriBar(String baslik, double tutar, double toplamGider,
      Color renk, IconData icon) {
    final double oran = toplamGider > 0 ? (tutar / toplamGider) : 0.0;
    final int yuzde = (oran * 100).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: renk, size: 18),
              const SizedBox(width: 8),
              Text(baslik,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              Text('${tutar.toStringAsFixed(0)} ₺ (%$yuzde)',
                  style: TextStyle(
                      color: renk, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: oran,
              minHeight: 6,
              backgroundColor: const Color(0xFF2A2A2A),
              valueColor: AlwaysStoppedAnimation<Color>(renk),
            ),
          ),
        ],
      ),
    );
  }
}