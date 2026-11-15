import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:primabot/chatbot_rs/data/datasources/local_datasource.dart';
import 'package:primabot/chatbot_rs/domain/usecases/get_bot_response.dart';
import 'package:primabot/chatbot_rs/presentation/providers/chat_provider.dart';
import 'package:primabot/chatbot_rs/screens/chat_screen.dart';
import 'package:primabot/chatbot_rs/screens/splash_screen.dart';
import 'package:primabot/chatbot_rs/theme.dart';
import 'package:primabot/l10n/app_localizations.dart';
import 'package:primabot/services/hospital_ai.dart';
import 'package:primabot/services/indonesian_text_processor.dart';
import 'package:primabot/services/rag_service.dart';

class _RecordingDb implements Database {
  final Map<String, List<Map<String, Object?>>> chatHistoryBySession;
  final List<Map<String, Object?>> sessions;
  final Map<String, String> updatedTitles = {};
  final List<Object?> recordedHistoryWhereArgs = [];

  _RecordingDb({
    required this.sessions,
    required this.chatHistoryBySession,
  });

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    if (table == 'chat_sessions') return sessions;
    if (table == 'chat_history') {
      recordedHistoryWhereArgs.add(whereArgs);
      if (whereArgs == null || whereArgs.isEmpty) return const [];
      final sid = whereArgs.first as String;
      return chatHistoryBySession[sid] ?? const [];
    }
    return const [];
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    if (table == 'chat_sessions' && whereArgs != null && whereArgs.isNotEmpty) {
      updatedTitles[whereArgs.first as String] = values['title'] as String;
    }
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('DatabaseHelper.sanitizeSessionTitles', () {
    test('binds session_id whereArgs per session and repairs each title', () async {
      final db = _RecordingDb(
        sessions: [
          {'id': 's1', 'title': 'Chat Baru'},
          {'id': 's2', 'title': 'Chat Lama'},
          {'id': 's3', 'title': 'Jadwal Sudah Benar'},
        ],
        chatHistoryBySession: {
          's1': [
            {'text': 'Jadwal poli anak hari ini'},
          ],
          's2': [
            {'text': 'Nomor telepon IGD RS'},
          ],
        },
      );

      await DatabaseHelper.instance.sanitizeSessionTitles(
        (raw) => 'Fixed: $raw',
        dbOverride: db,
      );

      expect(db.recordedHistoryWhereArgs, [
        ['s1'],
        ['s2'],
      ]);
      expect(db.updatedTitles['s1'], 'Fixed: Jadwal poli anak hari ini');
      expect(db.updatedTitles['s2'], 'Fixed: Nomor telepon IGD RS');
      expect(db.updatedTitles.containsKey('s3'), isFalse);
    });
  });

  group('HospitalAI bug fixes and enhancements', () {
    final ai = HospitalAI();

    test('DokterData.cariNama uses word boundaries and avoids substring collisions', () {
      expect(DokterData.cariNama('siapa yang mewakili rs ini?'), isNull);
      expect(DokterData.cariNama('dokter samy ada ga?'), isNull);
      expect(DokterData.cariNama('dr akil jadwalnya kapan')?.poli, 'Anak');
      expect(DokterData.cariNama('jadwal dr. amy')?.poli, 'Kandungan');
    });

    test('Sabotaged greetings with specific questions are not treated as plain greetings', () {
      final dJam = ai.deteksi('pagi besok jam berapa buka?');
      expect(dJam.intent, isNot(IntentAi.sapaan));

      final resGigi = ai.jawab('halo poli gigi ada?');
      expect(resGigi.tampilan.toLowerCase(), contains('belum tercantum'));
      expect(resGigi.tampilan, contains('0815 1100 0600'));
    });

    test('Pediatric symptoms route to Poliklinik Anak before adult digestive rules', () {
      final anakMencret = ai.deteksi('anak saya mencret dan demam sejak kemarin');
      expect(anakMencret.intent, IntentAi.simtom);
      expect(anakMencret.poli, 'Anak');

      final dewasaMencret = ai.deteksi('sakit perut dan mencret');
      expect(dewasaMencret.intent, IntentAi.simtom);
      expect(dewasaMencret.poli, 'Penyakit Dalam');
    });

    test('Handles Jum\'at with apostrophe and cleans TTS time phrasing', () {
      final dJumat = ai.deteksi("jadwal dokter hari jum'at");
      expect(dJumat.hari, 'Jumat');

      final dokterRes = ai.jawab('jadwal dr akil');
      final dokterTtsNorm = IndonesianTextProcessor.normalizeForMalayVoice(dokterRes.tts);
      expect(dokterTtsNorm.toLowerCase(), isNot(contains('jam jam')));

      final vctRes = ai.jawab('klinik vct');
      final vctTtsNorm = IndonesianTextProcessor.normalizeForMalayVoice(vctRes.tts);
      expect(vctTtsNorm.toLowerCase(), isNot(contains('jam jam')));
    });
  });

  group('IndonesianTextProcessor normalization fixes', () {
    test('Expands dotted specialist titles Sp.A, Sp.B, Sp.OG, Sp.PD accurately', () {
      expect(
        IndonesianTextProcessor.normalizeForMalayVoice('dr. Akil Baehaqi, Sp.A'),
        contains('Spesialis Anak'),
      );
      expect(
        IndonesianTextProcessor.normalizeForMalayVoice('dr. Mintardi, Sp.B'),
        contains('Spesialis Bedah'),
      );
      expect(
        IndonesianTextProcessor.normalizeForMalayVoice(
          'dr. Amy Cynthia De Meriyenes, Sp.OG',
        ),
        contains('Spesialis Kandungan'),
      );
      expect(
        IndonesianTextProcessor.normalizeForMalayVoice('dr. Idham Khalid, Sp.PD'),
        contains('Spesialis Penyakit Dalam'),
      );
    });

    test('Formats parentheses gracefully and prevents duplicate time words', () {
      final igd = IndonesianTextProcessor.normalizeForMalayVoice(
        'IGD (Instalasi Gawat Darurat) di Gedung Utama',
      );
      expect(igd.toLowerCase(), isNot(contains('atau')));

      final obsgyn = IndonesianTextProcessor.normalizeForMalayVoice(
        'Poliklinik Kandungan (Obsgyn)',
      );
      expect(
        RegExp('kandungan', caseSensitive: false).allMatches(obsgyn).length,
        1,
      );

      final jam = IndonesianTextProcessor.normalizeForMalayVoice(
        'Senin jam 07:00 sampai 08:30',
      );
      expect(jam.toLowerCase(), contains('jam tujuh'));
      expect(jam.toLowerCase(), isNot(contains('jam jam')));
    });
  });

  group('GetBotResponse anti-hallucination and markdown cleanup', () {
    final usecase = GetBotResponse();

    test('Catches invented doctor names and invented phone numbers while permitting official data', () {
      expect(
        usecase.hasHallucination('Silakan temui dr. Budi pukul 09:00.'),
        isTrue,
      );
      expect(
        usecase.hasHallucination('Silakan konsultasi dengan dr. Akil Baehaqi, Sp.A.'),
        isFalse,
      );
      expect(
        usecase.hasHallucination(
          'Pendaftaran di 0815 1100 0600, IGD di 0856 4507 7831, dan Call Center 0283 847 3333.',
        ),
        isFalse,
      );
      expect(
        usecase.hasHallucination('Hubungi nomor 0812 3456 7890 untuk info.'),
        isTrue,
      );
    });

    test('cleanRawResponse preserves paragraph newlines and bullet formatting', () {
      final cleaned = usecase.cleanRawResponse(
        'Paragraf pertama.\r\n\r\n- Item 1\r\n- Item 2',
      );
      expect(cleaned, contains('\n\n- Item 1\n- Item 2'));
    });
  });

  group('LayananRag tokenization', () {
    test('Extracts numeric time tokens without literal regex group strings', () {
      final tokens = LayananRag().tokenizeForTest('Praktek 10:30 sampai 12:30');
      expect(tokens, containsAll(['1030', '10', '30', '1230', '12']));
      expect(tokens, isNot(contains(r'$1')));
      expect(tokens, isNot(contains(r'$2')));
    });
  });

  group('Chat UI fixes', () {
    test('TypewriterMarkdownBody allows https, http, tel, mailto only', () {
      expect(
        TypewriterMarkdownBody.isSupportedLinkScheme(Uri.parse('tel:081511000600')),
        isTrue,
      );
      expect(
        TypewriterMarkdownBody.isSupportedLinkScheme(
          Uri.parse('mailto:primainsan2021@gmail.com'),
        ),
        isTrue,
      );
      expect(
        TypewriterMarkdownBody.isSupportedLinkScheme(
          Uri.parse('https://www.google.com/maps'),
        ),
        isTrue,
      );
      expect(
        TypewriterMarkdownBody.isSupportedLinkScheme(
          Uri.parse('javascript:alert(1)'),
        ),
        isFalse,
      );
      expect(TypewriterMarkdownBody.isSupportedLinkScheme(null), isFalse);
    });

    testWidgets('Edit mode Cancel button has readable dark text on light mode surface', (
      tester,
    ) async {
      final provider = ChatProvider.forPreview(
        messages: [
          ChatMessage(
            text: 'Jadwal poli anak kapan?',
            isBot: false,
            time: DateTime(2026, 11, 15, 9, 0),
            isAnimated: false,
          ),
        ],
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<ChatProvider>.value(
          value: provider,
          child: MaterialApp(
            theme: ChatbotTheme.lightTheme,
            locale: const Locale('id'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ChatScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Jadwal poli anak kapan?'));
      await tester.pumpAndSettle();

      final editButton = find.byIcon(Icons.edit_rounded);
      expect(editButton, findsOneWidget);
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      final cancelFinder = find.widgetWithText(TextButton, 'Batal');
      expect(cancelFinder, findsOneWidget);
      final TextButton btn = tester.widget(cancelFinder);
      final fgColor = btn.style?.foregroundColor?.resolve({});
      expect(fgColor, isNotNull);
      // Light mode card background is pure white; foreground must have low luminance.
      expect(fgColor!.computeLuminance(), lessThan(0.4));
    });

    testWidgets('ChatbotSplashScreen renders in Indonesian on 390px phone without RenderFlex overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: ChatbotTheme.lightTheme,
          locale: const Locale('id'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ChatbotSplashScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));

      expect(tester.takeException(), isNull);
    });
  });
}
