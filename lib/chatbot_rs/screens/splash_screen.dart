import 'dart:developer';
import 'package:flutter/material.dart';
import 'chat_screen.dart';
import '../data/datasources/seeder.dart';
import '../../services/rag_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/app_localizations.dart';

class ChatbotSplashScreen extends StatefulWidget {
  const ChatbotSplashScreen({super.key});

  @override
  State<ChatbotSplashScreen> createState() => _ChatbotSplashScreenState();
}

class _ChatbotSplashScreenState extends State<ChatbotSplashScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _isInitializing = true;
  late final AnimationController _introController;
  late final AnimationController _floatingTextController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..forward();
    _floatingTextController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    )..repeat(reverse: true);
    _initializeData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _introController.dispose();
    _floatingTextController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _floatingTextController.stop();
    } else if (state == AppLifecycleState.resumed) {
      if (!_floatingTextController.isAnimating) {
        _floatingTextController.repeat(reverse: true);
      }
    }
  }

  Future<void> _initializeData() async {
    try {
      // Seed database lokal terlebih dahulu
      await DataSeeder.seedData();
      // Inisialisasi indeks RAG enterprise (TF-IDF) di background
      // Proses ini membaca assets/data_rs.json dan membangun vektor pencarian
      try {
        await LayananRag().inisialisasi();
        log('Indeks RAG berhasil diinisialisasi: ${LayananRag().jumlahDokumen} dokumen');
      } catch (errorRag) {
        log('Inisialisasi RAG gagal (akan dicoba ulang saat chat): $errorRag');
      }
    } catch (e) {
      log('Seeding failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Widget _introItem({
    required Widget child,
    required double start,
    required double end,
    Offset beginOffset = const Offset(0, 0.08),
  }) {
    final animation = CurvedAnimation(
      parent: _introController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: beginOffset,
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return CustomScrollView(
              physics: const ClampingScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _introItem(
                              start: 0,
                              end: 0.38,
                              child: Text(
                                AppLocalizations.of(context)!.meetPrisma,
                                style: theme.textTheme.displayLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                  height: 1.15,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _introItem(
                              start: 0.12,
                              end: 0.52,
                              child: Row(
                                children: [
                                  Text(
                                    AppLocalizations.of(context)!.your,
                                    style: theme.textTheme.displayLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  AnimatedBuilder(
                                    animation: _floatingTextController,
                                    builder: (context, child) => Transform.translate(
                                      offset: Offset(
                                        0,
                                        -4 + (_floatingTextController.value * 8),
                                      ),
                                      child: child,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.brightness == Brightness.light
                                            ? theme.colorScheme.primary
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: Text(
                                        AppLocalizations.of(context)!.hospitalGuide,
                                        style: theme.textTheme.displaySmall?.copyWith(
                                          color: theme.brightness == Brightness.light
                                              ? Colors.white
                                              : theme.colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _introItem(
                              start: 0.28,
                              end: 0.62,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  AppLocalizations.of(context)!.splashDescription,
                                  textAlign: TextAlign.right,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF9D9D9D),
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Left Bubble
                      _introItem(
                        start: 0.42,
                        end: 0.72,
                        beginOffset: const Offset(-0.12, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.only(
                              left: 24,
                              right: 32,
                              top: 20,
                              bottom: 20,
                            ),
                            decoration: BoxDecoration(
                              color: theme.brightness == Brightness.light
                                  ? theme.colorScheme.primary
                                  : Colors.white,
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(50),
                                bottomRight: Radius.circular(50),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.hospitalInformation,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.brightness == Brightness.light
                                        ? Colors.white
                                        : theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  AppLocalizations.of(context)!.fastAnswers,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.brightness == Brightness.light
                                        ? Colors.white
                                        : theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  AppLocalizations.of(context)!.easyAccess,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.brightness == Brightness.light
                                        ? Colors.white
                                        : theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Right Bubble
                      _introItem(
                        start: 0.52,
                        end: 0.8,
                        beginOffset: const Offset(0.12, 0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.only(
                              left: 32,
                              right: 24,
                              top: 20,
                              bottom: 20,
                            ),
                            decoration: BoxDecoration(
                              color: theme.brightness == Brightness.light
                                  ? theme.colorScheme.primary
                                  : Colors.white,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(50),
                                bottomLeft: Radius.circular(50),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.getStarted,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.brightness == Brightness.light
                                        ? Colors.white
                                        : theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  AppLocalizations.of(context)!.explorePrima,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.brightness == Brightness.light
                                        ? Colors.white
                                        : theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  AppLocalizations.of(context)!.startChatting,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.brightness == Brightness.light
                                        ? Colors.white
                                        : theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  AppLocalizations.of(context)!.letsStartNow,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.brightness == Brightness.light
                                        ? Colors.white
                                        : theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Bottom Area (Pinned to Bottom)
                      _introItem(
                        start: 0.68,
                        end: 1,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppLocalizations.of(context)!.poweredBy,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF9D9D9D),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isInitializing
                                      ? null
                                      : () async {
                                          final prefs = await SharedPreferences.getInstance();
                                          await prefs.setBool('is_first_time', false);
                                          
                                          if (context.mounted) {
                                            Navigator.of(context).pushReplacement(
                                              MaterialPageRoute(
                                                builder: (context) => const ChatScreen(),
                                              ),
                                            );
                                          }
                                        },
                                  child: _isInitializing
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(AppLocalizations.of(context)!.letsChatNow),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
