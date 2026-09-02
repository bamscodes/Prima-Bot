import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../presentation/providers/theme_provider.dart';
import '../../services/piper_tts_service.dart';

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

  String _kodeBahasa = 'id';
  String _gayaSuara = 'F1';
  bool _sedangPratinjau = false;
  bool _sedangMemuat = true;
  bool _sedangMenggantiModel = false;
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
        _kodeBahasa = _layananTts.kodeBahasa;
        _gayaSuara = _layananTts.gayaSuara;
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

  Future<void> _ubahBahasa(String kode) async {
    if (_sedangMenggantiModel || _kodeBahasa == kode) return;
    setState(() {
      _sedangMenggantiModel = true;
      _pesanErrorModel = null;
    });
    try {
      await _layananTts.setBahasa(kode);
      if (!mounted) return;
      setState(() {
        _kodeBahasa = _layananTts.kodeBahasa;
        _gayaSuara = _layananTts.gayaSuara;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _pesanErrorModel = 'Gagal memuat model $kode: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat model suara: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _kodeBahasa = _layananTts.kodeBahasa;
          _gayaSuara = _layananTts.gayaSuara;
          _sedangMenggantiModel = false;
        });
      }
    }
  }

  Future<void> _ubahGaya(String gaya) async {
    // Indonesia tidak punya varian — cegah error diam
    if (!_layananTts.supportsVoiceStyle) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bahasa Indonesia hanya satu suara Piper News')),
        );
      }
      return;
    }
    if (_sedangMenggantiModel || _gayaSuara == gaya) return;
    setState(() {
      _sedangMenggantiModel = true;
      _pesanErrorModel = null;
    });
    try {
      await _layananTts.setGayaSuara(gaya);
      if (!mounted) return;
      setState(() => _gayaSuara = _layananTts.gayaSuara);
    } catch (e) {
      if (mounted) {
        setState(() => _pesanErrorModel = 'Gagal memuat gaya $gaya: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat model suara: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _gayaSuara = _layananTts.gayaSuara;
          _sedangMenggantiModel = false;
        });
      }
    }
  }

  Future<void> _pratinjau() async {
    if (_sedangPratinjau || _sedangMenggantiModel) return;
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
              // Bahasa
              Text(
                'Bahasa',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _opsiBahasa(
                      theme,
                      'Indonesia',
                      'id',
                      Icons.language,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _opsiBahasa(theme, 'English', 'en', Icons.public),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_kodeBahasa == 'en') ...[
                Text(
                  'Jenis Suara',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _opsiSuara(theme, 'Laki-laki', 'M1', Icons.man),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _opsiSuara(theme, 'Perempuan', 'F1', Icons.woman),
                    ),
                  ],
                ),
              ] else
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
                          !_sedangPratinjau &&
                          !_sedangMenggantiModel
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
                  _kodeBahasa == 'id'
                      ? 'Pratinjau: Halo, saya Prima'
                      : (_gayaSuara.startsWith('M')
                            ? 'Preview: Hello, I am Prima male'
                            : 'Preview: Hello, I am Prima female'),
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

  Widget _opsiBahasa(
    ThemeData theme,
    String label,
    String kode,
    IconData ikon,
  ) {
    final bool terpilih = _kodeBahasa == kode;
    return InkWell(
      onTap: () => _ubahBahasa(kode),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
        child: Column(
          children: [
            Icon(
              ikon,
              color: terpilih
                  ? theme.colorScheme.primary
                  : const Color(0xFF9D9D9D),
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: terpilih ? FontWeight.bold : FontWeight.w500,
                color: terpilih
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              kode,
              style: theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xFF9D9D9D),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _opsiSuara(ThemeData theme, String label, String gaya, IconData ikon) {
    final bool terpilih = _gayaSuara == gaya;
    return InkWell(
      onTap: () => _ubahGaya(gaya),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
        child: Column(
          children: [
            Icon(
              ikon,
              color: terpilih
                  ? theme.colorScheme.primary
                  : const Color(0xFF9D9D9D),
              size: 32,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: terpilih ? FontWeight.bold : FontWeight.w500,
                color: terpilih
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              gaya,
              style: theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xFF9D9D9D),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  final PiperTtsService _layananTts = PiperTtsService();
  String _kodeTerpilih = 'id';
  bool _memuat = true;
  bool _sedangMengganti = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _layananTts.stop();
    super.dispose();
  }

  Future<void> _muat() async {
    try {
      await _layananTts.loadSettingsOnly();
    } catch (e) {
      _error = e.toString();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Model suara belum siap: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _kodeTerpilih = _layananTts.kodeBahasa;
          _memuat = false;
        });
      }
    }
  }

  Future<void> _pilihBahasa(String kode) async {
    if (_kodeTerpilih == kode || _sedangMengganti) return;
    setState(() {
      _sedangMengganti = true;
      _error = null;
    });
    try {
      await _layananTts.setBahasa(kode);
    } catch (e) {
      _error = e.toString();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat model suara: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _kodeTerpilih = _layananTts.kodeBahasa;
          _sedangMengganti = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_memuat) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: theme.colorScheme.surface,
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }
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
                  'Bahasa',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Pilih bahasa untuk TTS dan antarmuka',
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF9D9D9D),
                fontSize: 11,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.red, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            _opsiBahasa(
              theme,
              'Indonesia',
              'id',
              Icons.language,
              'Bahasa Indonesia',
            ),
            const SizedBox(height: 12),
            _opsiBahasa(
              theme,
              'English',
              'en',
              Icons.public,
              'English language',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _layananTts.modelSiap
                    ? () async => _layananTts.pratinjauSuara()
                    : null,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Pratinjau'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  side: BorderSide(color: theme.colorScheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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
    ThemeData theme,
    String label,
    String kode,
    IconData ikon,
    String deskripsi,
  ) {
    final bool terpilih = _kodeTerpilih == kode;
    return InkWell(
      onTap: () => _pilihBahasa(kode),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: terpilih
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : theme.colorScheme.secondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: terpilih ? theme.colorScheme.primary : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              ikon,
              color: terpilih
                  ? theme.colorScheme.primary
                  : const Color(0xFF9D9D9D),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: terpilih ? FontWeight.bold : FontWeight.w500,
                      color: terpilih
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    deskripsi,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF9D9D9D),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (terpilih)
              Icon(
                Icons.check_circle,
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
    final theme = Theme.of(context);
    return _BaseDetailScreen(
      title: 'Development Team',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The people behind Prima Bot.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Text(
            'PROJECT SUPERVISOR\nBambang Sugiarto, S.Kom., M.Kom.\nPetrus Sokibi, S. Kom., M. Kom.\nRidho Taufiq Subagio, M.Kom.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 16),
          Text(
            'UI/UX DESIGNER\nKharis Destian Maulana',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 16),
          Text(
            'FRONTEND DEVELOPER\nNanda Putra Hartono',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 16),
          Text(
            'BACKEND DEVELOPER\nRadhitya Hafif',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 16),
          Text(
            'AI DEVELOPER\nMuhammad Arif Triyana',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 16),
          Text(
            'QA TESTER\nAndra Oktoriza Ramadhan',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _BaseDetailScreen(
      title: 'Privacy Policy',
      content: Text(
        'Last updated: August 2026\n\n1. Introduction\nPrima Bot is an AI-powered hospital assistant designed to help patients and visitors access information about hospital services, facilities, schedules, registration procedures, and other general hospital information.\n\nWe respect your privacy and are committed to protecting your personal information when you use Prima Bot.',
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
      title: 'Terms of Service',
      content: Text(
        'Last updated: August 2026\n\n1. About Prima Bot\nPrima Bot is an AI-powered hospital assistant designed to help patients and visitors access general information about hospital services, facilities, schedules, registration procedures, and other hospital-related information.',
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
