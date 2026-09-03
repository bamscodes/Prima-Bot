import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../presentation/providers/theme_provider.dart';
import '../presentation/providers/locale_provider.dart';
import '../../services/piper_tts_service.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';

class _BaseDetailScreen extends StatelessWidget {
  final String title;
  final Widget content;

  const _BaseDetailScreen({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Header Area
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 20.0,
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: theme.colorScheme.onSurface,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.people_alt,
                            color: const Color(0xFF16181A),
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Prima',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        content,
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: Text(
                      'Prima Bot Version 1.0.4',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF9D9D9D),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pengaturan suara berbasis Piper TTS.
/// Mendukung pemilihan bahasa (Indonesia/English), jenis suara (Laki-laki/Perempuan),
/// dan pratinjau langsung.
class SoundSettingsScreen extends StatefulWidget {
  const SoundSettingsScreen({super.key});

  @override
  State<SoundSettingsScreen> createState() => _SoundSettingsScreenState();
}

class _SoundSettingsScreenState extends State<SoundSettingsScreen> {
  final PiperTtsService _layananTts = PiperTtsService();

  bool _sedangPratinjau = false;
  bool _sedangMemuat = true;
  String? _pesanErrorModel;

  @override
  void initState() {
    super.initState();
    _muatPengaturan();
  }

  @override
  void dispose() {
    // Hentikan preview jika dialog ditutup saat masih memutar
    _layananTts.stop();
    super.dispose();
  }

  Future<void> _muatPengaturan() async {
    try {
      await _layananTts.loadSettingsOnly();
      if (!mounted) return;
      setState(() {
        _pesanErrorModel = _layananTts.lastError != null ? 'Error: ${_layananTts.lastError}' : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pesanErrorModel = 'Model Piper belum siap: $error';
      });
    } finally {
      if (mounted) setState(() => _sedangMemuat = false);
    }
  }


  Future<void> _pratinjau() async {
    if (_sedangPratinjau) return;
    if (!_layananTts.modelSiap) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_pesanErrorModel ?? 'Model belum siap, tunggu sebentar')),
        );
      }
      // Coba init ulang
      await _layananTts.init();
      return;
    }
    setState(() => _sedangPratinjau = true);
    try {
      await _layananTts.pratinjauSuara();
    } catch (e) {
      if (mounted) {
        setState(() => _pesanErrorModel = 'Gagal pratinjau: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal pratinjau suara: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sedangPratinjau = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_sedangMemuat) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: theme.colorScheme.surface,
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.volume_up_outlined,
                    color: theme.colorScheme.onSurface,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pengaturan Suara',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Piper TTS • On-device, ringan & tidak robotik',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF9D9D9D),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 20),
              // Status model - Piper langsung siap karena bundle, tidak perlu download
              if (!_layananTts.modelSiap)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      _pesanErrorModel == null
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.error_outline,
                              size: 18,
                              color: Colors.orange.shade800,
                            ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _pesanErrorModel ?? 'Model Piper sedang disiapkan...',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.orange.shade800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!_layananTts.modelSiap) const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.record_voice_over_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Bahasa Indonesia menggunakan satu suara Piper resmi: News TTS.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Tombol Pratinjau
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed:
                      _layananTts.modelSiap &&
                          !_sedangPratinjau
                      ? _pratinjau
                      : null,
                  icon: _sedangPratinjau
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                        ),
                  label: Text(
                    _sedangPratinjau ? 'Memutar...' : 'Pratinjau Suara',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    disabledBackgroundColor: const Color(
                      0xFF9D9D9D,
                    ).withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Pratinjau: Halo, saya Prima',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF9D9D9D),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


}

class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localeProvider = Provider.of<LocaleProvider>(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.translate, color: theme.colorScheme.onSurface),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.language,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.chooseLanguage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF9D9D9D),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 24),
            _opsiBahasa(
              context,
              theme,
              localeProvider,
              AppLocalizations.of(context)!.indonesian,
              'id',
              Icons.language,
              AppLocalizations.of(context)!.indonesianDesc,
            ),
            const SizedBox(height: 16),
            _opsiBahasa(
              context,
              theme,
              localeProvider,
              AppLocalizations.of(context)!.english,
              'en',
              Icons.language,
              AppLocalizations.of(context)!.englishDesc,
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  AppLocalizations.of(context)!.cancel,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _opsiBahasa(
    BuildContext context,
    ThemeData theme,
    LocaleProvider provider,
    String label,
    String kode,
    IconData ikon,
    String deskripsi,
  ) {
    final bool terpilih = provider.locale.languageCode == kode;

    return InkWell(
      onTap: () {
        provider.setLocale(Locale(kode));
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: terpilih
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : theme.colorScheme.secondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: terpilih ? theme.colorScheme.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              ikon,
              color: terpilih ? theme.colorScheme.primary : const Color(0xFF9D9D9D),
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: terpilih ? FontWeight.bold : FontWeight.w500,
                      color: terpilih ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    deskripsi,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF9D9D9D),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (terpilih)
              Icon(
                Icons.check_circle_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              )
            else
              const Icon(
                Icons.circle_outlined,
                color: Color(0xFF9D9D9D),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _BaseDetailScreen(
      title: 'About Prima',
      content: Text(
        'Prima Bot adalah asisten rumah sakit berbasis kecerdasan buatan (AI) yang dirancang secara khusus untuk membantu pasien dan pengunjung dalam mengakses berbagai informasi dan layanan medis dengan lebih mudah, akurat, dan interaktif.\n\nDikembangkan untuk:\nRumah Sakit Prima Insan Mulia\nUniversitas Catur Insan Cendekia\n\n© 2026 Prima Bot Team',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
      ),
    );
  }
}

class DeveloperScreen extends StatelessWidget {
  const DeveloperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _BaseDetailScreen(
      title: l10n.developmentTeam,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTeamMember(
            context,
            l10n.projectSupervisor,
            'Bambang Sugiarto, S.Kom., M.Kom.\nPetrus Sokibi, S. Kom., M. Kom.\nRidho Taufiq Subagio, M.Kom.',
            'assets/icons/supervisor.svg',
          ),
          _buildTeamMember(
            context,
            l10n.uiUxDesigner,
            'Kharis Destian Maulana',
            'assets/icons/designer.svg',
          ),
          _buildTeamMember(
            context,
            l10n.frontendDeveloper,
            'Nanda Putra Hartono',
            'assets/icons/frontend.svg',
          ),
          _buildTeamMember(
            context,
            l10n.backendDeveloper,
            'Radhitya Hafif',
            'assets/icons/backend.svg',
          ),
          _buildTeamMember(
            context,
            l10n.aiDeveloper,
            'Muhammad Arif Triyana',
            'assets/icons/ai.svg',
          ),
          _buildTeamMember(
            context,
            l10n.qaTester,
            'Andra Oktoriza Ramadhan',
            'assets/icons/qa.svg',
          ),
        ],
      ),
    );
  }

  Widget _buildTeamMember(BuildContext context, String role, String name, String iconPath) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.secondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SvgPicture.asset(
                iconPath,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  theme.colorScheme.primary,
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _BaseDetailScreen(
      title: AppLocalizations.of(context)!.privacyPolicyTitle,
      content: Text(
        AppLocalizations.of(context)!.privacyPolicyContent,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
      ),
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _BaseDetailScreen(
      title: AppLocalizations.of(context)!.termsOfServiceTitle,
      content: Text(
        AppLocalizations.of(context)!.termsOfServiceContent,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
      ),
    );
  }
}

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.color_lens_outlined,
                  color: theme.colorScheme.onSurface,
                ),
                const SizedBox(width: 8),
                Text(
                  'App Theme',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildThemeOption(
              theme: theme,
              title: 'System Default',
              isSelected: themeProvider.themeMode == ThemeMode.system,
              onTap: () => themeProvider.setThemeMode(ThemeMode.system),
            ),
            const SizedBox(height: 16),
            _buildThemeOption(
              theme: theme,
              title: 'Light Mode',
              isSelected: themeProvider.themeMode == ThemeMode.light,
              onTap: () => themeProvider.setThemeMode(ThemeMode.light),
            ),
            const SizedBox(height: 16),
            _buildThemeOption(
              theme: theme,
              title: 'Dark Mode',
              isSelected: themeProvider.themeMode == ThemeMode.dark,
              onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required ThemeData theme,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: theme.textTheme.bodyMedium),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : const Color(0xFF9D9D9D),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
