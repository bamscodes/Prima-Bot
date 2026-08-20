abstract final class ConversationTitleFormatter {
  static const int maxLength = 48;
  static const int maxWords = 7;

  /// Format judul percakapan secara 100% lokal dan deterministik dari pesan pengguna.
  static String format(String userMessage) {
    var title = userMessage
        .replaceAll(RegExp(r'https?://\S+', caseSensitive: false), '')
        .replaceAll(RegExp(r'[*_`#>\[\]()]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Hapus kata sapaan/filler umum di awal kalimat dengan word boundary (\b)
    // agar tidak memakan kata seperti 'Informasi' atau 'Pemeriksaan'
    final fillerPattern = RegExp(
      r'^(?:(?:halo|hai|hey|permisi|assalamu\s*alaikum|selamat\s+(?:pagi|siang|sore|malam)|bismillah)\b\s*[,!.]?\s*)?'
      r'(?:saya\b\s+)?'
      r'(?:(?:mau|ingin|bisa|tolong)\b\s+)?'
      r'(?:(?:tanya|bertanya|menanyakan|minta\s+info|minta\s+informasi|cek|lihat)\b\s+)?'
      r'(?:(?:tentang|mengenai|soal|jadwal\s+dong|dong)\b\s*)?'
      r'[,.:;?-]*\s*',
      caseSensitive: false,
    );

    final stripped = title.replaceFirst(fillerPattern, '').trim();

    // Gunakan hasil strip jika tidak kosong, atau kembali ke title awal jika kosong
    if (stripped.isNotEmpty) {
      title = stripped;
    }

    if (title.isEmpty) {
      final fallbackClean = userMessage.trim().replaceAll(RegExp(r'[*_`#>\[\]()]'), '');
      if (fallbackClean.isNotEmpty) {
        return _capitalize(fallbackClean);
      }
      return 'Percakapan Baru';
    }

    title = _limitWords(title);
    title = _truncate(title);
    return _capitalize(title);
  }

  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    return '${text[0].toUpperCase()}${text.substring(1)}';
  }

  static String _limitWords(String value) {
    final words = value.split(' ');
    if (words.length <= maxWords) return value;
    return words.take(maxWords).join(' ');
  }

  static String _truncate(String value) {
    if (value.length <= maxLength) return value;

    final shortened = value.substring(0, maxLength);
    final lastSpace = shortened.lastIndexOf(' ');
    if (lastSpace > 15) {
      return shortened.substring(0, lastSpace).trimRight();
    }
    return shortened.trimRight();
  }
}
