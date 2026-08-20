import 'dart:developer';
import 'package:flutter/material.dart';
import 'chat_screen.dart';
import '../data/datasources/seeder.dart';

class ChatbotSplashScreen extends StatefulWidget {
  const ChatbotSplashScreen({super.key});

  @override
  State<ChatbotSplashScreen> createState() => _ChatbotSplashScreenState();
}

class _ChatbotSplashScreenState extends State<ChatbotSplashScreen> {
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      await DataSeeder.seedData();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meet Prisma',
                        style: theme.textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Your',
                            style: theme.textTheme.displayLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              'Hospital Guide',
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Get quick answers about services,\ndoctors, schedules, and\nhospital facilities.',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF9D9D9D),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 36),
                
                // Left Bubble
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.only(left: 24, right: 32, top: 20, bottom: 20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(50),
                        bottomRight: Radius.circular(50),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hospital Information', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
                        const SizedBox(height: 4),
                        Text('Fast Answers', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
                        const SizedBox(height: 4),
                        Text('Easy Access', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Right Bubble
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.only(left: 32, right: 24, top: 20, bottom: 20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(50),
                        bottomLeft: Radius.circular(50),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Get Started', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
                        const SizedBox(height: 4),
                        Text('Explore Prima', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
                        const SizedBox(height: 4),
                        Text('Start Chatting', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
                        const SizedBox(height: 4),
                        Text('Let\'s Start Now', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 36),
                
                // Bottom Area
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                  child: Column(
                    children: [
                      Text(
                        'powered by hospital information',
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
                          onPressed: _isInitializing ? null : () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (context) => const ChatScreen()),
                            );
                          },
                          child: _isInitializing 
                              ? const SizedBox(
                                  width: 24, 
                                  height: 24, 
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                )
                              : const Text('Let\'s Chat Now'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ),
      ),
    );
  }
}
