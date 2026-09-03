import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In id, this message translates to:
  /// **'Prima Bot'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Asisten AI Rumah Sakit'**
  String get appSubtitle;

  /// No description provided for @splashSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Asisten Kesehatan Virtual Anda'**
  String get splashSubtitle;

  /// No description provided for @explorePrima.
  ///
  /// In id, this message translates to:
  /// **'Jelajahi Prima'**
  String get explorePrima;

  /// No description provided for @startChatting.
  ///
  /// In id, this message translates to:
  /// **'Mulai Obrolan'**
  String get startChatting;

  /// No description provided for @letsStartNow.
  ///
  /// In id, this message translates to:
  /// **'Ayo Mulai Sekarang'**
  String get letsStartNow;

  /// No description provided for @poweredBy.
  ///
  /// In id, this message translates to:
  /// **'Didukung oleh informasi rumah sakit'**
  String get poweredBy;

  /// No description provided for @letsChatNow.
  ///
  /// In id, this message translates to:
  /// **'Mulai Percakapan'**
  String get letsChatNow;

  /// No description provided for @meetPrisma.
  ///
  /// In id, this message translates to:
  /// **'Meet Prisma'**
  String get meetPrisma;

  /// No description provided for @your.
  ///
  /// In id, this message translates to:
  /// **'Your'**
  String get your;

  /// No description provided for @hospitalGuide.
  ///
  /// In id, this message translates to:
  /// **'Panduan Rumah Sakit'**
  String get hospitalGuide;

  /// No description provided for @splashDescription.
  ///
  /// In id, this message translates to:
  /// **'Dapatkan jawaban cepat tentang layanan,\ndokter, jadwal, dan\nfasilitas rumah sakit.'**
  String get splashDescription;

  /// No description provided for @hospitalInformation.
  ///
  /// In id, this message translates to:
  /// **'Informasi Rumah Sakit'**
  String get hospitalInformation;

  /// No description provided for @fastAnswers.
  ///
  /// In id, this message translates to:
  /// **'Jawaban Cepat'**
  String get fastAnswers;

  /// No description provided for @easyAccess.
  ///
  /// In id, this message translates to:
  /// **'Akses Mudah'**
  String get easyAccess;

  /// No description provided for @getStarted.
  ///
  /// In id, this message translates to:
  /// **'Mulai'**
  String get getStarted;

  /// No description provided for @typeMessage.
  ///
  /// In id, this message translates to:
  /// **'Ketik pesan...'**
  String get typeMessage;

  /// No description provided for @you.
  ///
  /// In id, this message translates to:
  /// **'Anda'**
  String get you;

  /// No description provided for @prima.
  ///
  /// In id, this message translates to:
  /// **'Prima'**
  String get prima;

  /// No description provided for @send.
  ///
  /// In id, this message translates to:
  /// **'Kirim'**
  String get send;

  /// No description provided for @sendMessage.
  ///
  /// In id, this message translates to:
  /// **'Kirim pesan'**
  String get sendMessage;

  /// No description provided for @goodMorning.
  ///
  /// In id, this message translates to:
  /// **'Selamat Pagi,'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In id, this message translates to:
  /// **'Selamat Siang,'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In id, this message translates to:
  /// **'Selamat Sore,'**
  String get goodEvening;

  /// No description provided for @goodNight.
  ///
  /// In id, this message translates to:
  /// **'Selamat Malam,'**
  String get goodNight;

  /// No description provided for @howAreYou.
  ///
  /// In id, this message translates to:
  /// **'Gimana Kabarmu Hari Ini?\nAda Yang Bisa Prima Bantu'**
  String get howAreYou;

  /// No description provided for @editMessage.
  ///
  /// In id, this message translates to:
  /// **'Edit Pesan'**
  String get editMessage;

  /// No description provided for @copyText.
  ///
  /// In id, this message translates to:
  /// **'Salin Teks'**
  String get copyText;

  /// No description provided for @suggestion1.
  ///
  /// In id, this message translates to:
  /// **'Bagaimana cara daftar rawat jalan?'**
  String get suggestion1;

  /// No description provided for @suggestion2.
  ///
  /// In id, this message translates to:
  /// **'Jadwal dokter spesialis anak'**
  String get suggestion2;

  /// No description provided for @suggestion3.
  ///
  /// In id, this message translates to:
  /// **'Apa saja fasilitas kamar VIP?'**
  String get suggestion3;

  /// No description provided for @newChat.
  ///
  /// In id, this message translates to:
  /// **'Chat Baru'**
  String get newChat;

  /// No description provided for @search.
  ///
  /// In id, this message translates to:
  /// **'Cari'**
  String get search;

  /// No description provided for @history.
  ///
  /// In id, this message translates to:
  /// **'Riwayat'**
  String get history;

  /// No description provided for @noChat.
  ///
  /// In id, this message translates to:
  /// **'Tidak Ada Chat'**
  String get noChat;

  /// No description provided for @deleteChat.
  ///
  /// In id, this message translates to:
  /// **'Hapus Chat?'**
  String get deleteChat;

  /// No description provided for @deleteChatWarning.
  ///
  /// In id, this message translates to:
  /// **'Chat akan dihapus permanen.'**
  String get deleteChatWarning;

  /// No description provided for @regenerate.
  ///
  /// In id, this message translates to:
  /// **'Regenerasi'**
  String get regenerate;

  /// No description provided for @regenerateTooltip.
  ///
  /// In id, this message translates to:
  /// **'Regenerasi jawaban'**
  String get regenerateTooltip;

  /// No description provided for @copy.
  ///
  /// In id, this message translates to:
  /// **'Salin'**
  String get copy;

  /// No description provided for @copyTooltip.
  ///
  /// In id, this message translates to:
  /// **'Salin teks'**
  String get copyTooltip;

  /// No description provided for @textCopied.
  ///
  /// In id, this message translates to:
  /// **'Teks disalin'**
  String get textCopied;

  /// No description provided for @play.
  ///
  /// In id, this message translates to:
  /// **'Putar'**
  String get play;

  /// No description provided for @playTooltip.
  ///
  /// In id, this message translates to:
  /// **'Putar suara'**
  String get playTooltip;

  /// No description provided for @playAudio.
  ///
  /// In id, this message translates to:
  /// **'Putar suara'**
  String get playAudio;

  /// No description provided for @pause.
  ///
  /// In id, this message translates to:
  /// **'Jeda'**
  String get pause;

  /// No description provided for @pauseTooltip.
  ///
  /// In id, this message translates to:
  /// **'Jeda suara'**
  String get pauseTooltip;

  /// No description provided for @pauseAudio.
  ///
  /// In id, this message translates to:
  /// **'Jeda suara'**
  String get pauseAudio;

  /// No description provided for @settings.
  ///
  /// In id, this message translates to:
  /// **'Pengaturan'**
  String get settings;

  /// No description provided for @general.
  ///
  /// In id, this message translates to:
  /// **'UMUM'**
  String get general;

  /// No description provided for @chatSection.
  ///
  /// In id, this message translates to:
  /// **'CHAT'**
  String get chatSection;

  /// No description provided for @aboutSection.
  ///
  /// In id, this message translates to:
  /// **'TENTANG'**
  String get aboutSection;

  /// No description provided for @appTheme.
  ///
  /// In id, this message translates to:
  /// **'Tema Aplikasi'**
  String get appTheme;

  /// No description provided for @appThemeDesc.
  ///
  /// In id, this message translates to:
  /// **'Ubah tema terang atau gelap'**
  String get appThemeDesc;

  /// No description provided for @soundAndAudio.
  ///
  /// In id, this message translates to:
  /// **'Suara'**
  String get soundAndAudio;

  /// No description provided for @soundAndAudioDesc.
  ///
  /// In id, this message translates to:
  /// **'Atur kecepatan, nada, & suara'**
  String get soundAndAudioDesc;

  /// No description provided for @language.
  ///
  /// In id, this message translates to:
  /// **'Bahasa'**
  String get language;

  /// No description provided for @languageDesc.
  ///
  /// In id, this message translates to:
  /// **'Ganti bahasa aplikasi'**
  String get languageDesc;

  /// No description provided for @clearHistory.
  ///
  /// In id, this message translates to:
  /// **'Hapus Riwayat Chat'**
  String get clearHistory;

  /// No description provided for @clearHistoryDesc.
  ///
  /// In id, this message translates to:
  /// **'Hapus semua percakapan AI'**
  String get clearHistoryDesc;

  /// No description provided for @historyCleared.
  ///
  /// In id, this message translates to:
  /// **'Riwayat obrolan dihapus'**
  String get historyCleared;

  /// No description provided for @confirmClearTitle.
  ///
  /// In id, this message translates to:
  /// **'Hapus Riwayat Chat?'**
  String get confirmClearTitle;

  /// No description provided for @confirmClearDesc.
  ///
  /// In id, this message translates to:
  /// **'Semua percakapan Anda akan dihapus secara permanen.'**
  String get confirmClearDesc;

  /// No description provided for @cancel.
  ///
  /// In id, this message translates to:
  /// **'Batal'**
  String get cancel;

  /// No description provided for @clear.
  ///
  /// In id, this message translates to:
  /// **'Hapus'**
  String get clear;

  /// No description provided for @yes.
  ///
  /// In id, this message translates to:
  /// **'Ya'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In id, this message translates to:
  /// **'Tidak'**
  String get no;

  /// No description provided for @aboutPrima.
  ///
  /// In id, this message translates to:
  /// **'Tentang Prima'**
  String get aboutPrima;

  /// No description provided for @developmentTeam.
  ///
  /// In id, this message translates to:
  /// **'Tim Pengembang'**
  String get developmentTeam;

  /// No description provided for @projectSupervisor.
  ///
  /// In id, this message translates to:
  /// **'Supervisor Proyek'**
  String get projectSupervisor;

  /// No description provided for @uiUxDesigner.
  ///
  /// In id, this message translates to:
  /// **'Desainer UI/UX'**
  String get uiUxDesigner;

  /// No description provided for @frontendDeveloper.
  ///
  /// In id, this message translates to:
  /// **'Pengembang Frontend'**
  String get frontendDeveloper;

  /// No description provided for @backendDeveloper.
  ///
  /// In id, this message translates to:
  /// **'Pengembang Backend'**
  String get backendDeveloper;

  /// No description provided for @aiDeveloper.
  ///
  /// In id, this message translates to:
  /// **'Pengembang AI'**
  String get aiDeveloper;

  /// No description provided for @qaTester.
  ///
  /// In id, this message translates to:
  /// **'Penguji QA'**
  String get qaTester;

  /// No description provided for @privacyPolicyTitle.
  ///
  /// In id, this message translates to:
  /// **'Kebijakan Privasi'**
  String get privacyPolicyTitle;

  /// No description provided for @privacyPolicyContent.
  ///
  /// In id, this message translates to:
  /// **'Terakhir diperbarui: Agustus 2026\n\n1. Pendahuluan\nPrima Bot adalah asisten rumah sakit berbasis AI yang dirancang untuk membantu pasien dan pengunjung mengakses informasi layanan, fasilitas, jadwal, prosedur pendaftaran, dan informasi umum rumah sakit lainnya.\n\n2. Pengumpulan Data\nPrima Bot menyimpan riwayat obrolan Anda secara lokal di perangkat Anda. Kami tidak mengirimkan atau mengumpulkan data pribadi sensitif Anda ke server eksternal.\n\n3. Penggunaan Data\nData obrolan murni digunakan agar bot dapat mengingat konteks percakapan dan meningkatkan kualitas respons AI selama sesi Anda.\n\n4. Keamanan Data\nKami berkomitmen untuk melindungi informasi pribadi Anda. Anda memiliki kendali penuh dan dapat menghapus riwayat obrolan kapan saja melalui fitur \'\'Hapus Riwayat Chat\'\'.'**
  String get privacyPolicyContent;

  /// No description provided for @termsOfServiceTitle.
  ///
  /// In id, this message translates to:
  /// **'Syarat & Ketentuan'**
  String get termsOfServiceTitle;

  /// No description provided for @termsOfServiceContent.
  ///
  /// In id, this message translates to:
  /// **'Terakhir diperbarui: Agustus 2026\n\n1. Tentang Prima Bot\nPrima Bot adalah asisten rumah sakit berbasis AI yang dirancang untuk membantu pasien dan pengunjung mengakses informasi umum mengenai layanan, fasilitas, jadwal, prosedur pendaftaran, dan informasi terkait rumah sakit lainnya.\n\n2. Sanggahan Medis (Medical Disclaimer)\nPENTING: Prima Bot hanya memberikan informasi umum rumah sakit dan BUKAN pengganti diagnosis, saran, atau perawatan medis dari dokter profesional. Selalu konsultasikan masalah kesehatan Anda dengan tenaga medis yang berkualifikasi.\n\n3. Batasan Tanggung Jawab\nPihak pengembang dan rumah sakit tidak bertanggung jawab atas tindakan atau keputusan apa pun yang diambil oleh pengguna yang hanya didasarkan pada informasi dari AI.\n\n4. Penggunaan yang Wajar\nPengguna diharapkan menggunakan bot dengan bertanggung jawab. Segala bentuk spam atau eksploitasi terhadap sistem dilarang keras.'**
  String get termsOfServiceContent;

  /// No description provided for @lightTheme.
  ///
  /// In id, this message translates to:
  /// **'Tema Terang'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In id, this message translates to:
  /// **'Tema Gelap'**
  String get darkTheme;

  /// No description provided for @adjustSound.
  ///
  /// In id, this message translates to:
  /// **'Atur Suara'**
  String get adjustSound;

  /// No description provided for @volume.
  ///
  /// In id, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @rate.
  ///
  /// In id, this message translates to:
  /// **'Kecepatan (Rate)'**
  String get rate;

  /// No description provided for @pitch.
  ///
  /// In id, this message translates to:
  /// **'Nada (Pitch)'**
  String get pitch;

  /// No description provided for @preview.
  ///
  /// In id, this message translates to:
  /// **'Pratinjau'**
  String get preview;

  /// No description provided for @chooseLanguage.
  ///
  /// In id, this message translates to:
  /// **'Pilih bahasa untuk antarmuka'**
  String get chooseLanguage;

  /// No description provided for @indonesian.
  ///
  /// In id, this message translates to:
  /// **'Indonesia'**
  String get indonesian;

  /// No description provided for @indonesianDesc.
  ///
  /// In id, this message translates to:
  /// **'Bahasa Indonesia'**
  String get indonesianDesc;

  /// No description provided for @english.
  ///
  /// In id, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @englishDesc.
  ///
  /// In id, this message translates to:
  /// **'English language'**
  String get englishDesc;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
