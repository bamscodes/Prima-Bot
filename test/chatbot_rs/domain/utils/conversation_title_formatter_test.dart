import 'package:flutter_test/flutter_test.dart';
import 'package:primabot/chatbot_rs/domain/utils/conversation_title_formatter.dart';

void main() {
  group('ConversationTitleFormatter.format', () {
    test('removes conversational filler and limits the word count', () {
      final title = ConversationTitleFormatter.format(
        'Halo, saya mau tanya jadwal dokter spesialis anak untuk besok pagi ya?',
      );

      expect(title, 'Jadwal dokter spesialis anak untuk besok pagi');
    });

    test('formats quick actions accurately', () {
      expect(ConversationTitleFormatter.format('Jadwal Poliklinik'), 'Jadwal Poliklinik');
      expect(ConversationTitleFormatter.format('Informasi Kontak'), 'Informasi Kontak');
      expect(ConversationTitleFormatter.format('Lokasi RS'), 'Lokasi RS');
    });

    test('cleans markdown and extra spaces', () {
      final title = ConversationTitleFormatter.format('**Poli apa saja** yang tersedia di RS?');
      expect(title, 'Poli apa saja yang tersedia di RS?');
    });

    test('returns a safe default for an empty message', () {
      final title = ConversationTitleFormatter.format('   ');
      expect(title, 'Percakapan Baru');
    });

    test('normalizes an AI title before it is displayed', () {
      final title = ConversationTitleFormatter.formatGenerated(
        'Judul: "Jadwal Konsultasi Dokter Anak Besok"',
        fallback: 'Halo, saya ingin menanyakan jadwal dokter anak besok.',
      );

      expect(title, 'Jadwal Konsultasi Dokter Anak Besok');
    });

    test('uses the local title when AI returns only whitespace', () {
      final title = ConversationTitleFormatter.formatGenerated(
        '  ',
        fallback: 'Saya ingin tanya tentang lokasi rumah sakit',
      );

      expect(title, 'Lokasi rumah sakit');
    });
  });
}
