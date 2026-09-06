import 'package:flutter_test/flutter_test.dart';
import 'package:primabot/chatbot_rs/data/datasources/ai_datasource.dart';
import 'package:primabot/services/hospital_ai.dart';
import 'package:primabot/services/rag_service.dart';

void main() {
  group('Intent classification', () {
    test('keeps general questions out of the schedule flow', () async {
      final result = await AIService.classifyIntent(
        'Apakah rumah sakit menerima BPJS?',
      );

      expect(result['intent'], 'Umum');
    });

    test('detects a doctor schedule request locally', () async {
      final result = await AIService.classifyIntent('besok dokter gigi');

      expect(result['intent'], 'Cari_Jadwal');
      expect(result['entitas'], 'Gigi');
    });
  });

  group('Local RAG answer composer', () {
    test(
      'answers registration questions without unrelated hospital summary',
      () {
        final rag = LayananRag();
        final answer = rag
            .jawabanEkstraktif('pendaftaran di rumah sakit prima gimana', [
              HasilPencarianRag(
                dokumen: DokumenRag(
                  id: 'faq_pendaftaran',
                  kategori: 'faq',
                  konten: 'Cara pendaftaran melalui nomor pendaftaran.',
                  metadata: const {},
                  token: const [],
                ),
                skor: 0.5,
              ),
            ]);

        expect(answer, contains('0815 1100 0600'));
        expect(answer.toLowerCase(), isNot(contains('kata kunci')));
        expect(
          answer.toLowerCase(),
          isNot(contains('poliklinik spesialis anak')),
        );
      },
    );

    test(
      'summarizes doctor schedules from metadata without raw document text',
      () {
        final rag = LayananRag();
        final answer = rag.jawabanEkstraktif(
          'siapa aja dokter yang ada di rumah sakit prima',
          [
            _jadwalResult(
              namaDokter: 'dr. Mintardi, Sp.B',
              spesialisasi: 'Bedah',
              hari: 'Senin',
              jamMulai: '07:00',
              jamSelesai: '08:30',
            ),
            _jadwalResult(
              namaDokter: 'dr. Mintardi, Sp.B',
              spesialisasi: 'Bedah',
              hari: 'Rabu',
              jamMulai: '07:00',
              jamSelesai: '08:30',
            ),
          ],
        );

        expect(answer, contains('dr. Mintardi, Sp.B'));
        expect(answer, contains('Senin 07:00-08:30, Rabu 07:00-08:30'));
        expect(answer, isNot(contains('Jadwal dokter Bedah:')));
      },
    );
  });

  group('HospitalAI Engine - Skenario Percakapan Realistis', () {
    final ai = HospitalAI();

    test('Menjawab sapaan dengan ramah dan bervariasi', () {
      final sapaan1 = ai.jawab('halo');
      expect(sapaan1.tampilan.toLowerCase(), contains('prima'));
      expect(sapaan1.tampilan, isNot(contains('belum tersedia')));

      final sapaan2 = ai.jawab('halo apa kabar prima insan disini');
      expect(sapaan2.tampilan.toLowerCase(), contains('prima'));

      final sapaan3 = ai.jawab('assalamualaikum');
      expect(sapaan3.tampilan.toLowerCase(), contains('waalaikumsalam'));
    });

    test('Menjawab keberadaan dokter yang ada (dr Akil)', () {
      final res = ai.jawab('kalo dr Akil ada ga ta');
      expect(res.tampilan, contains('dr. Akil Baehaqi, Sp.A'));
      expect(res.tampilan, contains('Poliklinik Anak'));
      expect(res.tampilan, contains('0815 1100 0600'));
      expect(res.tampilan, contains('Gedung Utama'));
    });

    test('Menjawab dokter yang tidak ada di RS dengan sopan dan memberi daftar alternatif', () {
      final res = ai.jawab('apakah ada dr Budi di rs prima');
      expect(res.tampilan, contains('dr. Budi'));
      expect(res.tampilan, contains('belum terdaftar'));
      expect(res.tampilan, contains('dr. Akil Baehaqi, Sp.A'));
      expect(res.tampilan, contains('0815 1100 0600'));
    });

    test('Menjawab pertanyaan kontak dan nomor telepon dengan tepat', () {
      final res = ai.jawab('nomer telpon nya berapa informasinya');
      expect(res.tampilan, contains('0815 1100 0600'));
      expect(res.tampilan, contains('0283 847 3333'));
      expect(res.tampilan, contains('0856 4507 7831'));
      expect(res.tampilan, isNot(contains('Poliklinik Bedah')));
    });

    test('Menjawab jadwal hari Senin secara spesifik hanya dokter yang berpraktik Senin', () {
      final res = ai.jawab('jadwal dokter yang hari Senin apa aja');
      expect(res.tampilan, contains('Senin'));
      expect(res.tampilan, contains('dr. Akil Baehaqi, Sp.A'));
      expect(res.tampilan, contains('dr. Mintardi, Sp.B'));
      expect(res.tampilan, contains('dr. Idham Khalid, Sp.PD'));
      expect(res.tampilan, contains('Dokter Umum'));
      expect(res.tampilan, isNot(contains('dr. Amy Cynthia De Meriyenes, Sp.OG')));
    });

    test('Menjawab jam praktik dokter spesifik (dr Akil)', () {
      final res = ai.jawab('dr Akil tuh jam berapa prakteknya');
      expect(res.tampilan, contains('dr. Akil Baehaqi, Sp.A'));
      expect(res.tampilan, contains('10:30–12:30'));
      expect(res.tampilan, contains('0815 1100 0600'));
      expect(res.tampilan, isNot(contains('dr. Mintardi')));
    });

    test('Menjawab pertanyaan BPJS secara informatif', () {
      final res = ai.jawab('saya pengguna bpjs');
      expect(res.tampilan.toLowerCase(), contains('bpjs'));
      expect(res.tampilan, contains('0815 1100 0600'));
      expect(res.tampilan, contains('Call Center'));
    });

    test('Menjawab keluhan sakit perut dan mencret dengan rekomendasi dokter yang tepat', () {
      final res = ai.jawab('aduh ini saya lagi sakit perut mencet saya konsultasi ke dokter mana ya');
      expect(res.tampilan, contains('dr. Idham Khalid, Sp.PD'));
      expect(res.tampilan, contains('Poliklinik Penyakit Dalam'));
      expect(res.tampilan, contains('IGD 24 Jam'));
      expect(res.tampilan, contains('0815 1100 0600'));
    });

    test('Menyediakan tautan Google Maps untuk pertanyaan lokasi lewat chat biasa', () {
      final res = ai.jawab('dimana alamat rumah sakit prima');
      expect(res.tampilan, contains('Jln. Raya Losari Lor'));
      expect(res.tampilan, contains('[Buka di Google Maps]'));
      expect(res.tampilan, contains('https://www.google.com/maps/search/?api=1&query=RS+Prima+Insan+Mulia+Losari+Brebes'));
    });

    test('Menolak pertanyaan di luar rumah sakit dan kesehatan dengan santun (guardrail)', () {
      final res = ai.jawab('siapa presiden indonesia sekarang');
      expect(res.tampilan.toLowerCase(), contains('maaf'));
      expect(res.tampilan.toLowerCase(), contains('prima'));
      expect(res.tampilan, isNot(contains('Joko Widodo')));
      expect(res.tampilan, isNot(contains('Prabowo')));
    });
  });
}

HasilPencarianRag _jadwalResult({
  required String namaDokter,
  required String spesialisasi,
  required String hari,
  required String jamMulai,
  required String jamSelesai,
}) {
  return HasilPencarianRag(
    dokumen: DokumenRag(
      id: 'jadwal_$hari',
      kategori: 'jadwal',
      konten: 'Jadwal dokter $spesialisasi: $namaDokter',
      metadata: {
        'nama_dokter': namaDokter,
        'spesialisasi': spesialisasi,
        'hari': hari,
        'jam_mulai': jamMulai,
        'jam_selesai': jamSelesai,
      },
      token: const [],
    ),
    skor: 0.5,
  );
}
