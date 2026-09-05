import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../presentation/providers/chat_provider.dart';
import 'settings_detail_screens.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showClearChatDialog(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context)!.confirmClearTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.confirmClearDesc,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF9D9D9D),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface,
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.no,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Provider.of<ChatProvider>(
                          context,
                          listen: false,
                        ).clearChat();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalizations.of(context)!.historyCleared)),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.yes,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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
                crossAxisAlignment: CrossAxisAlignment.start,
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
                          radius: 40,
                          backgroundColor: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 60,
                              height: 60,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)!.appTitle,
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
            const SizedBox(height: 20), // Memberi jarak ekstra antara header dan list menu

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                children: [
                  _buildSectionTitle(theme, AppLocalizations.of(context)!.general),
                  _buildSettingsCard(
                    theme,
                    icon: Icons.volume_up_rounded,
                    title: AppLocalizations.of(context)!.soundAndAudio,
                    subtitle: AppLocalizations.of(context)!.soundAndAudioDesc,
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => const SoundSettingsScreen(),
                    ),
                  ),
                  _buildSettingsCard(
                    theme,
                    icon: Icons.language,
                    title: AppLocalizations.of(context)!.language,
                    subtitle: AppLocalizations.of(context)!.languageDesc,
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => const LanguageSettingsScreen(),
                    ),
                  ),
                  _buildSettingsCard(
                    theme,
                    icon: Icons.color_lens_outlined,
                    title: AppLocalizations.of(context)!.appTheme,
                    subtitle: AppLocalizations.of(context)!.appThemeDesc,
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => const ThemeSettingsScreen(),
                    ),
                  ),

                  const SizedBox(height: 24),
                  _buildSectionTitle(theme, AppLocalizations.of(context)!.chatSection),
                  _buildSettingsCard(
                    theme,
                    icon: Icons.delete_outline_rounded,
                    title: AppLocalizations.of(context)!.clearHistory,
                    subtitle: AppLocalizations.of(context)!.clearHistoryDesc,
                    onTap: () => _showClearChatDialog(context),
                  ),

                  const SizedBox(height: 24),
                  _buildSectionTitle(theme, AppLocalizations.of(context)!.aboutSection),
                  _buildSettingsCard(
                    theme,
                    icon: Icons.info_outline_rounded,
                    title: AppLocalizations.of(context)!.aboutPrima,
                    subtitle: AppLocalizations.of(context)!.aboutPrimaDesc,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    ),
                  ),
                  _buildSettingsCard(
                    theme,
                    icon: Icons.code_rounded,
                    title: AppLocalizations.of(context)!.developmentTeam,
                    subtitle: AppLocalizations.of(context)!.developmentTeamDesc,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DeveloperScreen(),
                      ),
                    ),
                  ),
                  _buildSettingsCard(
                    theme,
                    icon: Icons.lock_outline_rounded,
                    title: AppLocalizations.of(context)!.privacyPolicyTitle,
                    subtitle: AppLocalizations.of(context)!.privacyPolicyDesc,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                    ),
                  ),
                  _buildSettingsCard(
                    theme,
                    icon: Icons.description_outlined,
                    title: AppLocalizations.of(context)!.termsOfServiceTitle,
                    subtitle: AppLocalizations.of(context)!.termsOfServiceDesc,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TermsScreen()),
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

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title,
        style: theme.textTheme.labelSmall?.copyWith(
          color: const Color(0xFF9D9D9D),
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 16.0,
            ),
            child: Row(
              children: [
                Icon(icon, color: theme.colorScheme.onSurface, size: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF9D9D9D),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: const Color(0xFF9D9D9D).withValues(alpha: 0.5),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
