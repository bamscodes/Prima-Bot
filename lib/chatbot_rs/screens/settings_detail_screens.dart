import 'package:flutter/material.dart';

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
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.people_alt, color: const Color(0xFF16181A), size: 28),
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
                  const SizedBox(width: 48), // Balance for centering
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
                      'Prima Bot Version 1.0.0',
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

class SoundSettingsScreen extends StatefulWidget {
  const SoundSettingsScreen({super.key});

  @override
  State<SoundSettingsScreen> createState() => _SoundSettingsScreenState();
}

class _SoundSettingsScreenState extends State<SoundSettingsScreen> {
  double _volume = 0.7;
  bool _autoPlay = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _BaseDetailScreen(
      title: 'Chat Sound',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: theme.colorScheme.onSurface,
              inactiveTrackColor: const Color(0xFF9D9D9D).withValues(alpha: 0.3),
              thumbColor: theme.colorScheme.onSurface,
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: _volume,
              onChanged: (val) => setState(() => _volume = val),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Auto Play Voice', style: theme.textTheme.bodyMedium),
              Switch(
                value: _autoPlay,
                onChanged: (val) => setState(() => _autoPlay = val),
                activeThumbColor: theme.colorScheme.primary,
                activeTrackColor: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _BaseDetailScreen(
      title: 'Language',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLanguageOption(theme, 'Indonesia', true),
          const SizedBox(height: 16),
          _buildLanguageOption(theme, 'English', false),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(ThemeData theme, String language, bool isSelected) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(language, style: theme.textTheme.bodyMedium),
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: isSelected ? theme.colorScheme.primary : const Color(0xFF9D9D9D), width: 2),
          ),
          child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
        ),
      ],
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
        'Prima Bot is an AI-powered hospital assistant designed to help patients and visitors access hospital information more easily.\n\nDeveloped for [Nama Rumah Sakit]\nUniversitas Catur Insan Cendekia\n\n© 2026 Prima Bot Team',
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
          Text('The people behind Prima Bot.', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 24),
          Text('PROJECT SUPERVISOR\nNama Dosen\nProject Supervisor', style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
          const SizedBox(height: 16),
          Text('Nama\nUI/UX Designer', style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
          const SizedBox(height: 16),
          Text('Nama\nMobile Developer', style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
          const SizedBox(height: 16),
          Text('Nama\nMobile Developer', style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
          const SizedBox(height: 16),
          Text('Nama\nMobile Developer', style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
          const SizedBox(height: 16),
          Text('Nama\nMobile Developer', style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
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
