import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../presentation/providers/chat_provider.dart';
import 'settings_detail_screens.dart';

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
                  'Clear Chat History?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'All of your conversations will be permanently deleted.',
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
                      child: const Text(
                        'No',
                        style: TextStyle(fontWeight: FontWeight.bold),
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
                          const SnackBar(content: Text('Chat history cleared')),
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
                      child: const Text(
                        'Yes',
                        style: TextStyle(fontWeight: FontWeight.bold),
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
                          backgroundColor: theme.colorScheme.onSurface,
                          child: Icon(
                            Icons.people_alt,
                            color: theme.colorScheme.surface,
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
                  const SizedBox(width: 48), // Balance for centering
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  children: [
                    _buildSectionTitle(theme, 'GENERAL'),
                    _buildSettingsCard(
                      theme,
                      icon: Icons.volume_up_rounded,
                      title: 'Sound',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SoundSettingsScreen(),
                        ),
                      ),
                    ),
                    _buildSettingsCard(
                      theme,
                      icon: Icons.language,
                      title: 'Language',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LanguageSettingsScreen(),
                        ),
                      ),
                    ),
                    _buildSettingsCard(
                      theme,
                      icon: Icons.color_lens_outlined,
                      title: 'App Theme',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ThemeSettingsScreen(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    _buildSectionTitle(theme, 'CHAT'),
                    _buildSettingsCard(
                      theme,
                      icon: Icons.delete_outline_rounded,
                      title: 'Clear Chat History',
                      onTap: () => _showClearChatDialog(context),
                    ),

                    const SizedBox(height: 24),
                    _buildSectionTitle(theme, 'ABOUT'),
                    _buildSettingsCard(
                      theme,
                      icon: Icons.info_outline_rounded,
                      title: 'About Prima',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      ),
                    ),
                    _buildSettingsCard(
                      theme,
                      icon: Icons.code_rounded,
                      title: 'Development Team',
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
                      title: 'Privacy Policy',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacyScreen(),
                        ),
                      ),
                    ),
                    _buildSettingsCard(
                      theme,
                      icon: Icons.description_outlined,
                      title: 'Terms of Service',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TermsScreen()),
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
                Icon(icon, color: theme.colorScheme.onSurface, size: 20),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
