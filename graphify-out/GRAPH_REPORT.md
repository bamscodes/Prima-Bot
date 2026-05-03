# Graph Report - primabot  (2026-05-03)

## Corpus Check
- 27 files · ~118,167 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 148 nodes · 134 edges · 19 communities detected
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 2 edges (avg confidence: 0.88)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]

## God Nodes (most connected - your core abstractions)
1. `package:flutter/material.dart` - 7 edges
2. `AppDelegate` - 5 edges
3. `Zero-Cost Architecture` - 5 edges
4. `RunnerTests` - 3 edges
5. `package:flutter_dotenv/flutter_dotenv.dart` - 3 edges
6. `MyApp` - 3 edges
7. `ChatScreen` - 3 edges
8. `SQLite Database` - 3 edges
9. `GeneratedPluginRegistrant` - 2 edges
10. `handle_new_rx_page()` - 2 edges

## Surprising Connections (you probably didn't know these)
- `MyApp` --implements--> `Zero-Cost Architecture`  [INFERRED]
  lib/main.dart → skills.md
- `ChatScreen` --implements--> `SQLite Database`  [INFERRED]
  lib/chatbot_rs/screens/chat_screen.dart → skills.md
- `Project Dependencies` --references--> `SQLite Database`  [EXTRACTED]
  pubspec.yaml → skills.md
- `MyApp` --references--> `ChatScreen`  [EXTRACTED]
  lib/main.dart → lib/chatbot_rs/screens/chat_screen.dart
- `MyApp` --references--> `SplashScreen`  [EXTRACTED]
  lib/main.dart → lib/chatbot_rs/screens/splash_screen.dart

## Hyperedges (group relationships)
- **Chatbot AI Pipeline** — skills_md_indobert, skills_md_sqlite, skills_md_openrouter [EXTRACTED 1.00]

## Communities

### Community 0 - "Community 0"
Cohesion: 0.07
Nodes (26): Align, build, _buildInputArea, _buildSuggestions, _buildTypingIndicator, ChatScreen, _ChatScreenState, CircleAvatar (+18 more)

### Community 1 - "Community 1"
Cohesion: 0.12
Nodes (15): chat_history, close, _createDB, DatabaseHelper, jadwal_dokter, KEY, layanan, openDatabase (+7 more)

### Community 2 - "Community 2"
Cohesion: 0.15
Nodes (11): GetBotResponse, ChatMessage, ChatProvider, _initTts, _loadHistory, ../../data/datasources/ai_datasource.dart, ../../data/datasources/local_datasource.dart, ../../data/models/jadwal_model.dart (+3 more)

### Community 3 - "Community 3"
Cohesion: 0.15
Nodes (10): ThemeProvider, toggleTheme, _buildTheme, ChatbotTheme, ThemeData, main, package:flutter/material.dart, package:flutter_test/flutter_test.dart (+2 more)

### Community 4 - "Community 4"
Cohesion: 0.18
Nodes (10): chat_screen.dart, build, ChatbotSplashScreen, _ChatbotSplashScreenState, CircularProgressIndicator, initState, Scaffold, SizedBox (+2 more)

### Community 5 - "Community 5"
Cohesion: 0.18
Nodes (9): AIService, _getHariIndo, _simulateIntent, main, dart:convert, package:flutter_dotenv/flutter_dotenv.dart, package:http/http.dart, package:primabot/chatbot_rs/data/datasources/ai_datasource.dart (+1 more)

### Community 6 - "Community 6"
Cohesion: 0.2
Nodes (9): chatbot_rs/presentation/providers/chat_provider.dart, chatbot_rs/presentation/providers/theme_provider.dart, chatbot_rs/screens/splash_screen.dart, chatbot_rs/theme.dart, build, main, MaterialApp, PrimabotApp (+1 more)

### Community 7 - "Community 7"
Cohesion: 0.22
Nodes (10): ChatScreen, MyApp, Project Dependencies, Zero-Cost Architecture, IndoBERT Intent Classifier, OpenRouter NLG, Product Requirements Document, SQLite Database (+2 more)

### Community 8 - "Community 8"
Cohesion: 0.33
Nodes (3): FlutterAppDelegate, FlutterImplicitEngineDelegate, AppDelegate

### Community 9 - "Community 9"
Cohesion: 0.5
Nodes (2): handle_new_rx_page(), Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.

### Community 10 - "Community 10"
Cohesion: 0.5
Nodes (2): RunnerTests, XCTestCase

### Community 11 - "Community 11"
Cohesion: 0.67
Nodes (1): GeneratedPluginRegistrant

### Community 12 - "Community 12"
Cohesion: 0.67
Nodes (2): GeneratedPluginRegistrant, -registerWithRegistry

### Community 13 - "Community 13"
Cohesion: 0.67
Nodes (2): FlutterSceneDelegate, SceneDelegate

### Community 14 - "Community 14"
Cohesion: 1.0
Nodes (1): MainActivity

### Community 15 - "Community 15"
Cohesion: 1.0
Nodes (1): JadwalModel

### Community 16 - "Community 16"
Cohesion: 1.0
Nodes (1): LayananModel

### Community 22 - "Community 22"
Cohesion: 1.0
Nodes (1): MainActivity

### Community 23 - "Community 23"
Cohesion: 1.0
Nodes (1): AppDelegate

## Knowledge Gaps
- **95 isolated node(s):** `MainActivity`, `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `-registerWithRegistry`, `PrimabotApp`, `main` (+90 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Community 9`** (4 nodes): `handle_new_rx_page()`, `__lldb_init_module()`, `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `flutter_lldb_helper.py`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 10`** (4 nodes): `RunnerTests.swift`, `RunnerTests`, `.testExample()`, `XCTestCase`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 11`** (3 nodes): `GeneratedPluginRegistrant.java`, `GeneratedPluginRegistrant`, `.registerWith()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 12`** (3 nodes): `GeneratedPluginRegistrant.m`, `GeneratedPluginRegistrant`, `-registerWithRegistry`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 13`** (3 nodes): `FlutterSceneDelegate`, `SceneDelegate.swift`, `SceneDelegate`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 14`** (2 nodes): `MainActivity.kt`, `MainActivity`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 15`** (2 nodes): `JadwalModel`, `jadwal_model.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 16`** (2 nodes): `LayananModel`, `layanan_model.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 22`** (1 nodes): `MainActivity`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 23`** (1 nodes): `AppDelegate`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `package:flutter/material.dart` connect `Community 3` to `Community 0`, `Community 2`, `Community 4`, `Community 6`?**
  _High betweenness centrality (0.303) - this node is a cross-community bridge._
- **Why does `package:flutter_dotenv/flutter_dotenv.dart` connect `Community 5` to `Community 6`?**
  _High betweenness centrality (0.184) - this node is a cross-community bridge._
- **Why does `dart:convert` connect `Community 5` to `Community 1`?**
  _High betweenness centrality (0.133) - this node is a cross-community bridge._
- **What connects `MainActivity`, `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `-registerWithRegistry` to the rest of the system?**
  _95 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.07 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.12 - nodes in this community are weakly interconnected._