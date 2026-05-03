import '../../data/datasources/ai_datasource.dart';
import '../../data/datasources/local_datasource.dart';
import '../../data/models/jadwal_model.dart';

class GetBotResponse {
  final dbHelper = DatabaseHelper.instance;

  Future<String> execute(String userInput, List<Map<String, String>> history) async {
    // 1. Analyze Intent
    final intentData = await AIService.classifyIntent(userInput);
    final intent = intentData['intent'];

    if (intent == 'Cari_Jadwal') {
      final String? spesialisasi = intentData['entitas'];
      final String? hari = intentData['hari'];

      // 2. Query Local Database
      List<JadwalModel> jadwal;
      if (spesialisasi != null) {
        jadwal = await dbHelper.queryJadwal(spesialisasi, hari);
      } else {
        // Special case: if specialization is missing, try to ask AI but fallback to generic if error
        try {
          return await AIService.generateResponse([
            ...history,
            {'role': 'user', 'content': '$userInput (Sistem: Tanyakan spesialisasi apa yang dicari)'}
          ]).timeout(const Duration(seconds: 15));
        } catch (_) {
          return 'Tentu, spesialisasi dokter apa yang ingin Anda cari? (Contoh: Gigi atau Anak)';
        }
      }

      // 3. Construct Context
      String dataContext;
      if (jadwal.isEmpty) {
        dataContext = 'Mohon maaf, jadwal dokter $spesialisasi${hari != null ? ' pada hari $hari' : ''} tidak ditemukan.';
      } else {
        dataContext = 'Berikut jadwal dokter $spesialisasi yang tersedia: \n';
        for (var j in jadwal) {
          dataContext += '- **${j.namaDokter}** (${j.hari}, ${j.jamMulai}-${j.jamSelesai})\n';
        }
      }

      // 4. Try AI for natural response, fallback to raw data if offline
      try {
        final promptText = 'Pertanyaan Pasien: "$userInput". \nDATA RUMAH SAKIT: \n$dataContext \nInstruksi: Jawab dengan ramah berdasarkan data tersebut.';
        final currentMessages = [
          ...history,
          {'role': 'user', 'content': promptText}
        ];
        return await AIService.generateResponse(currentMessages).timeout(const Duration(seconds: 20));
      } catch (e) {
        // Offline Fallback
        return '$dataContext\n\n*(Catatan: Anda sedang dalam mode offline/koneksi lambat, informasi terbatas pada jadwal lokal)*';
      }
    }

    // Default for General Intent
    try {
      final currentMessages = [
        ...history,
        {'role': 'user', 'content': userInput}
      ];
      return await AIService.generateResponse(currentMessages).timeout(const Duration(seconds: 20));
    } catch (e) {
      return 'Maaf, saya sedang mengalami kendala koneksi. Saat ini saya hanya bisa melayani pertanyaan seputar jadwal dokter yang tersimpan secara lokal.';
    }
  }
}
