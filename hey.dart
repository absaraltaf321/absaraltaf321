import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const FlashcardApp());
}

// Data Models
enum StudyItemType { card, note }

class StudyItem {
  final String id;
  final String category;
  final String question; // For notes, this is the title
  final String answer; // For notes, this is the content
  final StudyItemType type;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? imagePath; // New: For note images
  final String? audioPath; // New: For note audio

  StudyItem({
    String? id,
    required this.category,
    required this.question,
    required this.answer,
    required this.type,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.imagePath,
    this.audioPath,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  StudyItem copyWith({
    String? category,
    String? question,
    String? answer,
    StudyItemType? type,
    String? imagePath,
    String? audioPath,
  }) {
    return StudyItem(
      id: id,
      category: category ?? this.category,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      type: type ?? this.type,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      imagePath: imagePath ?? this.imagePath,
      audioPath: audioPath ?? this.audioPath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'question': question,
      'answer': answer,
      'type': type.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'imagePath': imagePath,
      'audioPath': audioPath,
    };
  }

  factory StudyItem.fromMap(Map<String, dynamic> map) {
    return StudyItem(
      id: map['id'],
      category: map['category'],
      question: map['question'],
      answer: map['answer'],
      type: StudyItemType.values.firstWhere(
            (e) => e.name == map['type'],
        orElse: () => StudyItemType.card,
      ),
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      imagePath: map['imagePath'],
      audioPath: map['audioPath'],
    );
  }

  String toJson() => json.encode(toMap());
  factory StudyItem.fromJson(String source) => StudyItem.fromMap(json.decode(source));
}

// App Theme
class AppTheme {
  static const Color primaryColor = Color(0xFF6C5CE7);
  static const Color secondaryColor = Color(0xFFA29BFE);
  static const Color backgroundColor = Color(0xFF0F0F23);
  static const Color cardColor = Color(0xFF1A1A2E);
  static const Color noteColor = Color(0xFF0A7189);
  static const Color noteSecondaryColor = Color(0xFF3D9DB5);
  static const Color maroonColor = Color(0xFF9F2B2B);
  static const Color maroonSecondaryColor = Color(0xFFC75D5D);

  static final ThemeData theme = ThemeData(
    primarySwatch: Colors.deepPurple,
    scaffoldBackgroundColor: backgroundColor,
    textTheme: GoogleFonts.workSansTextTheme(
      ThemeData.dark().textTheme.copyWith(
        headlineSmall: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        bodyLarge: const TextStyle(fontSize: 16),
        bodyMedium: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
      ),
    ),
  );

  static BoxDecoration get maroonSolidCardDecoration => BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [maroonColor, maroonSecondaryColor],
    ),
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: maroonColor.withOpacity(0.4),
        blurRadius: 12,
        offset: const Offset(0, 6),
      ),
    ],
  );

  static BoxDecoration get maroonGlassCardDecoration => BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          maroonSecondaryColor.withOpacity(0.2),
          maroonColor.withOpacity(0.15),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.2), width: 1));

  static BoxDecoration get solidCardDecoration => BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF6C5CE7), Color(0xFF897DEC)],
    ),
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF6C5CE7).withOpacity(0.4),
        blurRadius: 12,
        offset: const Offset(0, 6),
      ),
    ],
  );

  static BoxDecoration get glassCardDecoration => BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.15),
          Colors.white.withOpacity(0.05),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.2), width: 1));

  static BoxDecoration get noteSolidCardDecoration => BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [noteColor, noteSecondaryColor],
    ),
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: noteColor.withOpacity(0.4),
        blurRadius: 12,
        offset: const Offset(0, 6),
      ),
    ],
  );

  static BoxDecoration get noteGlassCardDecoration => BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          noteSecondaryColor.withOpacity(0.25),
          noteColor.withOpacity(0.15),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.2), width: 1));


  static BoxDecoration get dialogGlassDecoration => BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF883344).withOpacity(0.3),
          const Color(0xFF883344).withOpacity(0.1),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.2), width: 1));

  static BoxDecoration get solidPracticeCardDecoration => BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF487E95), Color(0xFF61A0AF)],
    ),
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF487E95).withOpacity(0.4),
        blurRadius: 12,
        offset: const Offset(0, 6),
      ),
    ],
  );

  static BoxDecoration get glassPracticeCardDecoration => BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF61A0AF).withOpacity(0.25),
          const Color(0xFF61A0AF).withOpacity(0.1),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.2), width: 1));
}

// Storage Service
class StorageService {
  static const String _storageKey = 'study_items';

  static Future<List<StudyItem>> loadItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);

      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString);
        return jsonList.map((json) => StudyItem.fromMap(json)).toList();
      }
    } catch (e) {
      debugPrint('Error loading items: $e');
    }
    return [];
  }

  static Future<void> saveItems(List<StudyItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(items.map((item) => item.toMap()).toList());
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      debugPrint('Error saving items: $e');
    }
  }
}

// Main App
class FlashcardApp extends StatelessWidget {
  const FlashcardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ABS FLASHCARDS',
      theme: AppTheme.theme,
      home: const IntroScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Intro Screen
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.backgroundColor, Color(0xFF1A1A2E)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: const Icon(
                    Icons.school_outlined,
                    size: 100,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Text(
                      'ABS FLASHCARDS',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 28,color:Colors.white),

                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Text(
                      'Create, study, and master ',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 3),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const HomeScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Get Started',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 1),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    'Created by ABSAR ALTAF',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
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


// Home Screen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  List<StudyItem> _items = [];
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _loadItems();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final items = await StorageService.loadItems();
    if (mounted) {
      setState(() {
        _items = items;
      });
      _fadeController.forward(from: 0);
    }
  }

  List<String> get _categories {
    return _items.map((item) => item.category).toSet().toList()..sort();
  }

  String _truncateCategoryName(String name) {
    var words = name.split(' ');
    if (words.length > 2) {
      return '${words.take(2).join(' ')}...';
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.backgroundColor, Color(0xFF1A1A2E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildCategoryGrid()),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Text(
            ' ABS FLASHCARDS',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 22,color:Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            '${_items.length} items in ${_categories.length} categories',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
    if (_categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No items yet',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to create your first item',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _fadeController,
      builder: (context, child) {
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            final categoryItems = _items.where((item) => item.category == category).toList();
            final delay = index * 100;

            return TweenAnimationBuilder(
              duration: Duration(milliseconds: 500 + delay),
              tween: Tween<double>(begin: 0.0, end: 1.0),
              builder: (context, double value, child) {
                return Transform.translate(
                  offset: Offset(0, 50 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: _buildCategoryCard(category, categoryItems.length),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryCard(String category, int count) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FlashcardScreen(
              category: category,
              onUpdate: _loadItems,
            ),
          ),
        ).then((_) => _loadItems());
      },
      child: Stack(
        children: [
          Transform.translate(
            offset: const Offset(4, 4),
            child: Container(decoration: AppTheme.maroonSolidCardDecoration),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: AppTheme.maroonGlassCardDecoration,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        color: Colors.white.withOpacity(0.8),
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _truncateCategoryName(category),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$count items',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: () => _showMainControls(),
      backgroundColor: AppTheme.primaryColor,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  void _showMainControls() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => MainControlsBottomSheet(
        items: _items,
        onUpdate: (items) {
          if (mounted) {
            setState(() {
              _items = items;
            });
          }
          StorageService.saveItems(items);
        },
      ),
    );
  }
}


// Main Controls Bottom Sheet
class MainControlsBottomSheet extends StatefulWidget {
  final List<StudyItem> items;
  final Function(List<StudyItem>) onUpdate;
  final String? initialCategory;

  const MainControlsBottomSheet({
    super.key,
    required this.items,
    required this.onUpdate,
    this.initialCategory,
  });

  @override
  State<MainControlsBottomSheet> createState() => _MainControlsBottomSheetState();
}

class _MainControlsBottomSheetState extends State<MainControlsBottomSheet> with TickerProviderStateMixin {
  late TabController _tabController;
  final _categoryController = TextEditingController();
  final _questionController = TextEditingController();
  final _answerController = TextEditingController();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  bool _isDragOverAnswer = false;
  bool _isDragOverContent = false;

  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  File? _pickedImage;
  String? _audioPath;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.initialCategory != null) {
      _categoryController.text = widget.initialCategory!;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _categoryController.dispose();
    _questionController.dispose();
    _answerController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _pickedImage = File(image.path);
      });
    }
  }

  Future<void> _toggleRecording() async {
    if (await Permission.microphone.request().isGranted) {
      if (_isRecording) {
        final path = await _audioRecorder.stop();
        setState(() {
          _isRecording = false;
          _audioPath = path;
        });
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() {
          _isRecording = true;
          _audioPath = null;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required to record audio.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const double moveFactor = 0.8;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight * moveFactor),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: AppTheme.cardColor.withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                _buildHandle(),
                _buildTabBar(),
                Expanded(child: _buildTabBarView()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      indicatorColor: AppTheme.primaryColor,
      tabs: const [
        Tab(text: 'Create', icon: Icon(Icons.add)),
        Tab(text: 'Import', icon: Icon(Icons.download)),
        Tab(text: 'Export', icon: Icon(Icons.upload)),
      ],
    );
  }

  Widget _buildTabBarView() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildCreateTab(),
        _buildImportTab(),
        _buildExportTab(),
      ],
    );
  }

  Widget _buildCreateTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Flashcard'),
              Tab(text: 'Note'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildFlashcardForm(),
                _buildNoteForm(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlashcardForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTextField(
            _categoryController,
            'Category',
            Icons.folder,
            isEnabled: widget.initialCategory == null,
          ),
          const SizedBox(height: 16),
          _buildTextField(_questionController, 'Question', Icons.help_outline, maxLines: 3),
          const SizedBox(height: 16),
          DropRegion(
            formats: const [Formats.plainText, Formats.uri, Formats.htmlText],
            hitTestBehavior: HitTestBehavior.opaque,
            onDropOver: (event) {
              if (event.session.allowedOperations.contains(DropOperation.copy)) {
                return DropOperation.copy;
              }
              return DropOperation.none;
            },
            onDropEnter: (event) => setState(() => _isDragOverAnswer = true),
            onDropLeave: (event) => setState(() => _isDragOverAnswer = false),
            onPerformDrop: (event) async {
              print('onPerformDrop called in _buildFlashcardForm!');
              setState(() => _isDragOverAnswer = false);
              final item = event.session.items.first;

              final reader = item.dataReader!;

              print('Checking for plainText...');
              if (item.canProvide(Formats.plainText)) {
                print('Can provide plainText. Getting value...');
                reader.getValue<String>(Formats.plainText, (text) {
                  print('Received plainText value: ${text?.substring(0, min(text.length, 50))}...');
                  if (text != null) {
                    setState(() {
                      _answerController.text += text;
                    });
                  }
                }, onError: (error) {
                  print('Error reading plain text value: $error');
                });
              }

              print('Checking for uri...');
              if (item.canProvide(Formats.uri)) {
                print('Can provide uri. Getting value...');
                reader.getValue<NamedUri>(Formats.uri, (namedUri) {
                  print('Received uri value: ${namedUri?.uri}');
                  if (namedUri != null) {
                    setState(() {
                      _answerController.text += namedUri.uri.toString();
                    });
                  }
                }, onError: (error) {
                  print('Error reading uri value: $error');
                });
              }

              print('Checking for htmlText...');
              if (item.canProvide(Formats.htmlText)) {
                print('Can provide htmlText. Getting value...');
                reader.getValue<String>(Formats.htmlText, (html) {
                  print('Received htmlText value: ${html?.substring(0, min(html.length, 50))}...');
                  if (html != null) {
                    setState(() {
                      _answerController.text += html;
                    });
                  }
                }, onError: (error) {
                  print('Error reading html value: $error');
                });
              }
              print('onPerformDrop in _buildFlashcardForm finished.');
            },
            child: _buildTextField(_answerController, 'Answer (Drop text here)', Icons.lightbulb_outline, maxLines: 5, isDragOver: _isDragOverAnswer),
          ),
          const SizedBox(height: 24),
          _buildActionButton('Create Card', Icons.add, () => _createFlashcard()),
        ],
      ),
    );
  }

  Widget _buildNoteForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTextField(
            _categoryController,
            'Category',
            Icons.folder,
            isEnabled: widget.initialCategory == null,
          ),
          const SizedBox(height: 16),
          _buildTextField(_titleController, 'Title', Icons.title),
          const SizedBox(height: 16),
          DropRegion(
            formats: const [Formats.plainText, Formats.uri, Formats.htmlText],
            hitTestBehavior: HitTestBehavior.opaque,
            onDropOver: (event) {
              if (event.session.allowedOperations.contains(DropOperation.copy)) {
                return DropOperation.copy;
              }
              return DropOperation.none;
            },
            onDropEnter: (event) => setState(() => _isDragOverContent = true),
            onDropLeave: (event) => setState(() => _isDragOverContent = false),
            onPerformDrop: (event) async {
              print('onPerformDrop called in _buildNoteForm!');
              setState(() => _isDragOverContent = false);
              final item = event.session.items.first;

              final reader = item.dataReader!;

              print('Checking for plainText...');
              if (item.canProvide(Formats.plainText)) {
                print('Can provide plainText. Getting value...');
                reader.getValue<String>(Formats.plainText, (text) {
                  print('Received plainText value: ${text?.substring(0, min(text.length, 50))}...');
                  if (text != null) {
                    setState(() {
                      _contentController.text += text;
                    });
                  }
                }, onError: (error) {
                  print('Error reading plain text value: $error');
                });
              }

              print('Checking for uri...');
              if (item.canProvide(Formats.uri)) {
                print('Can provide uri. Getting value...');
                reader.getValue<NamedUri>(Formats.uri, (namedUri) {
                  print('Received uri value: ${namedUri?.uri}');
                  if (namedUri != null) {
                    setState(() {
                      _contentController.text += namedUri.uri.toString();
                    });
                  }
                }, onError: (error) {
                  print('Error reading uri value: $error');
                });
              }

              print('Checking for htmlText...');
              if (item.canProvide(Formats.htmlText)) {
                print('Can provide htmlText. Getting value...');
                reader.getValue<String>(Formats.htmlText, (html) {
                  print('Received htmlText value: ${html?.substring(0, min(html.length, 50))}...');
                  if (html != null) {
                    setState(() {
                      _contentController.text += html;
                    });
                  }
                }, onError: (error) {
                  print('Error reading html value: $error');
                });
              }
              print('onPerformDrop in _buildNoteForm finished.');
            },
            child: _buildTextField(_contentController, 'Content (Drop text here)', Icons.note, maxLines: 5, isDragOver: _isDragOverContent),
          ),
          const SizedBox(height: 24),

          if (_pickedImage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_pickedImage!, height: 150, fit: BoxFit.cover)),
            ),
          if (_audioPath != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(children: [
                const Icon(Icons.audiotrack, color: Colors.white70),
                const SizedBox(width: 8),
                Expanded(child: Text('Audio recorded', style: TextStyle(color: Colors.white70), overflow: TextOverflow.ellipsis)),
              ]),
            ),

          Row(
            children: [
              Expanded(
                child: _buildMediaButton('Add Image', Icons.image, _pickImage),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMediaButton(
                  _isRecording ? 'Stop' : 'Record Audio',
                  _isRecording ? Icons.stop : Icons.mic,
                  _toggleRecording,
                  isActive: _isRecording,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildActionButton('Create Note', Icons.add, () => _createNote()),
        ],
      ),
    );
  }

  Widget _buildMediaButton(String text, IconData icon, VoidCallback onPressed, {bool isActive = false}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Colors.redAccent : AppTheme.secondaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildImportTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon( Icons.download, size: 64, color: AppTheme.primaryColor),
          const SizedBox(height: 16),
          Text('Import Items', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 8),
          Text('Select a JSON file to import items', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          _buildActionButton('Select File', Icons.file_open, _importCards),
        ],
      ),
    );
  }

  Future<void> _importCards() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();
        final Map<String, dynamic> data = json.decode(jsonString);

        if (data['items'] != null) {
          final List<StudyItem> importedItems = (data['items'] as List)
              .map((json) => StudyItem.fromMap(json))
              .toList();

          final updatedItems = [...widget.items, ...importedItems];
          widget.onUpdate(updatedItems);

          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Imported ${importedItems.length} items')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing items: $e')),
      );
    }
  }


  Widget _buildExportTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.upload, size: 64, color: AppTheme.primaryColor),
          const SizedBox(height: 16),
          Text('Export Items', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 8),
          Text('Save all items as a JSON file', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          _buildActionButton('Export All', Icons.save_alt, _exportCards),
        ],
      ),
    );
  }

  Future<void> _exportCards() async {
    try {
      final data = {
        'version': '1.0',
        'exported_at': DateTime.now().toIso8601String(),
        'items': widget.items.map((item) => item.toMap()).toList(),
      };

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/flashcards_export.json');
      await file.writeAsString(json.encode(data));

      await Share.shareXFiles([XFile(file.path)], text: 'Flashcards Export');

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting items: $e')),
      );
    }
  }


  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1, bool isEnabled = true, bool isDragOver = false}) {
    return TextField(
      controller: controller, maxLines: maxLines, enabled: isEnabled,
      style: TextStyle(color: isEnabled ? Colors.white : Colors.white54),
      decoration: InputDecoration(
        labelText: label, labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: AppTheme.primaryColor),
        filled: true, fillColor: Colors.black.withOpacity(0.2),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDragOver ? AppTheme.primaryColor : Colors.white.withOpacity(0.3))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryColor)),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
    );
  }

  Widget _buildActionButton(String text, IconData icon, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity, height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed, icon: Icon(icon), label: Text(text),
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
    );
  }

  void _createFlashcard() {
    if (_categoryController.text.trim().isEmpty || _questionController.text.trim().isEmpty || _answerController.text.trim().isEmpty) return;
    final item = StudyItem(category: _categoryController.text.trim(), question: _questionController.text.trim(), answer: _answerController.text.trim(), type: StudyItemType.card);
    final updatedItems = [...widget.items, item];
    widget.onUpdate(updatedItems);
    _clearControllers();
    Navigator.pop(context);
  }

  void _createNote() async {
    if (_categoryController.text.trim().isEmpty || _titleController.text.trim().isEmpty || _contentController.text.trim().isEmpty) return;

    String? finalImagePath;
    if (_pickedImage != null) {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final newImage = await _pickedImage!.copy('${directory.path}/$fileName');
      finalImagePath = newImage.path;
    }

    final item = StudyItem(
      category: _categoryController.text.trim(),
      question: _titleController.text.trim(),
      answer: _contentController.text.trim(),
      type: StudyItemType.note,
      imagePath: finalImagePath,
      audioPath: _audioPath,
    );
    final updatedItems = [...widget.items, item];
    widget.onUpdate(updatedItems);
    _clearControllers();
    Navigator.pop(context);
  }

  void _clearControllers() {
    if (widget.initialCategory == null) _categoryController.clear();
    _questionController.clear();
    _answerController.clear();
    _titleController.clear();
    _contentController.clear();
    setState(() {
      _pickedImage = null;
      _audioPath = null;
      _isRecording = false;
    });
  }
}


// Flashcard Screen
class FlashcardScreen extends StatefulWidget {
  final String category;
  final VoidCallback onUpdate;

  const FlashcardScreen({super.key, required this.category, required this.onUpdate});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> with TickerProviderStateMixin {
  List<StudyItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategoryItems();
  }

  Future<void> _loadCategoryItems() async {
    final allItems = await StorageService.loadItems();
    if (mounted) {
      setState(() {
        _items = allItems.where((item) => item.category == widget.category).toList();
        _isLoading = false;
      });
    }
  }

  void _showAddCardDialog() async {
    final allItems = await StorageService.loadItems();
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (context) => MainControlsBottomSheet(
        items: allItems, initialCategory: widget.category,
        onUpdate: (updatedItems) {
          StorageService.saveItems(updatedItems);
          _loadCategoryItems();
          widget.onUpdate();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppTheme.backgroundColor, Color(0xFF1A1A2E)]),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildFlashcardList(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(heroTag: 'add_in_category', onPressed: _showAddCardDialog, backgroundColor: AppTheme.secondaryColor, mini: true, child: const Icon(Icons.add, color: Colors.white)),
          const SizedBox(height: 16),
          FloatingActionButton(heroTag: 'practice', onPressed: () => _startPracticeMode(), backgroundColor: AppTheme.primaryColor, child: const Icon(Icons.play_arrow, color: Colors.white)),
          const SizedBox(height: 16),
          FloatingActionButton(heroTag: 'shuffle', onPressed: () => _shuffleCards(), backgroundColor: AppTheme.primaryColor, child: const Icon(Icons.shuffle, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.white)),
          Expanded(
            child: Column(
              children: [
                Text(widget.category, style: Theme.of(context).textTheme.headlineSmall, overflow: TextOverflow.ellipsis),
                Text('${_items.length} items', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildFlashcardList() {
    if (_items.isEmpty) return const Center(child: Text('No items in this category', style: TextStyle(color: Colors.white70)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: FlashcardWidget(
            item: _items[index],
            onEdit: (updatedItem) => _editCard(index, updatedItem),
            onDelete: () => _deleteCard(index),
          ),
        );
      },
    );
  }

  void _startPracticeMode() {
    final practiceCards = _items.where((item) => item.type == StudyItemType.card).toList();
    if (practiceCards.isNotEmpty) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => PracticeScreen(items: practiceCards)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("There are no flashcards in this category to practice.")),
      );
    }
  }

  void _shuffleCards() { setState(() => _items.shuffle(Random())); }

  void _editCard(int index, StudyItem updatedItem) async {
    final allItems = await StorageService.loadItems();
    final itemIndexInAll = allItems.indexWhere((item) => item.id == updatedItem.id);
    if (itemIndexInAll != -1) {
      allItems[itemIndexInAll] = updatedItem;
      await StorageService.saveItems(allItems);
    }
    _loadCategoryItems();
    widget.onUpdate();
  }

  void _deleteCard(int index) async {
    final itemToDelete = _items[index];
    final allItems = await StorageService.loadItems();
    allItems.removeWhere((item) => item.id == itemToDelete.id);
    await StorageService.saveItems(allItems);
    _loadCategoryItems();
    widget.onUpdate();
  }
}


// Flashcard / Note Widget
class FlashcardWidget extends StatefulWidget {
  final StudyItem item;
  final Function(StudyItem) onEdit;
  final VoidCallback onDelete;

  const FlashcardWidget({super.key, required this.item, required this.onEdit, required this.onDelete});

  @override
  State<FlashcardWidget> createState() => _FlashcardWidgetState();
}

class _FlashcardWidgetState extends State<FlashcardWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.item.type == StudyItemType.note) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => NoteDetailScreen(note: widget.item)));
    } else {
      _flip();
    }
  }

  void _flip() {
    if (_controller.isAnimating) return;
    setState(() => _isFlipped = !_isFlipped);
    if (_isFlipped) _controller.forward(); else _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final bool isNote = widget.item.type == StudyItemType.note;
    final solidDecoration = isNote ? AppTheme.noteSolidCardDecoration : AppTheme.solidCardDecoration;
    final glassDecoration = isNote ? AppTheme.noteGlassCardDecoration : AppTheme.glassCardDecoration;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          Transform.translate(offset: const Offset(4, 4), child: Container(decoration: solidDecoration)),
          GestureDetector(
            onTap: _handleTap,
            child: isNote
                ? _buildFront(glassDecoration) // Notes don't flip
                : AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final angle = _controller.value * pi;
                final isFront = _controller.value < 0.5;
                return Transform(
                  transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(angle),
                  alignment: Alignment.center,
                  child: isFront
                      ? _buildFront(glassDecoration)
                      : Transform(transform: Matrix4.identity()..rotateY(pi), alignment: Alignment.center, child: _buildBack(solidDecoration)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFront(BoxDecoration decoration) {
    final isNote = widget.item.type == StudyItemType.note;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: decoration,
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(isNote ? Icons.note_alt_outlined : Icons.help_outline, color: Colors.white.withOpacity(0.8), size: 28),
                  Row(
                    children: [
                      IconButton(onPressed: () => _showEditDialog(), icon: const Icon(Icons.edit, color: Colors.white70, size: 20)),
                      IconButton(onPressed: () => _showDeleteDialog(), icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20)),
                    ],
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Text(
                      widget.item.question,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              Center(
                child: Text(isNote ? 'Tap to open' : 'Tap to flip',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBack(BoxDecoration decoration) {
    return Container(
      decoration: decoration,
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(alignment: Alignment.topLeft, child: Icon(Icons.lightbulb_outline, color: Colors.white.withOpacity(0.8), size: 28)),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Text(
                  widget.item.answer,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => EditCardDialog(
        item: widget.item,
        onEdit: widget.onEdit,
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Delete Card', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this card?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.onDelete();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// New: Note Detail Screen
class NoteDetailScreen extends StatefulWidget {
  final StudyItem note;
  const NoteDetailScreen({super.key, required this.note});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playAudio() async {
    if (widget.note.audioPath != null) {
      if (_isPlaying) {
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
      } else {
        await _audioPlayer.play(DeviceFileSource(widget.note.audioPath!));
        setState(() => _isPlaying = true);
        _audioPlayer.onPlayerComplete.listen((event) {
          if (mounted) setState(() => _isPlaying = false);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: AppTheme.cardColor,
              pinned: true,
              expandedHeight: 250,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  widget.note.question,
                  style: GoogleFonts.workSans(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                background: widget.note.imagePath != null
                    ? Image.file(
                  File(widget.note.imagePath!),
                  fit: BoxFit.cover,
                  color: Colors.black.withOpacity(0.4),
                  colorBlendMode: BlendMode.darken,
                )
                    : Container(color: AppTheme.noteColor),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (widget.note.audioPath != null) ...[
                    ElevatedButton.icon(
                      onPressed: _playAudio,
                      icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                      label: Text(_isPlaying ? 'Pause Audio' : 'Play Audio'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.noteSecondaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Text(
                    'Note Content',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.noteSecondaryColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.note.answer,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5, fontSize: 18),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// Edit Card Dialog
class EditCardDialog extends StatefulWidget {
  final StudyItem item;
  final Function(StudyItem) onEdit;

  const EditCardDialog({super.key, required this.item, required this.onEdit});

  @override
  State<EditCardDialog> createState() => _EditCardDialogState();
}

class _EditCardDialogState extends State<EditCardDialog> {
  late TextEditingController categoryController;
  late TextEditingController questionController;
  late TextEditingController answerController;
  bool _isDragOver = false;

  @override
  void initState() {
    super.initState();
    categoryController = TextEditingController(text: widget.item.category);
    questionController = TextEditingController(text: widget.item.question);
    answerController = TextEditingController(text: widget.item.answer);
  }

  @override
  void dispose() {
    categoryController.dispose();
    questionController.dispose();
    answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double moveFactor = 0.8;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardHeight * moveFactor),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.dialogGlassDecoration,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Edit Item', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 24),
                    _buildTextField(categoryController, 'Category', Icons.folder),
                    const SizedBox(height: 16),
                    _buildTextField(questionController, widget.item.type == StudyItemType.note ? 'Title' : 'Question', Icons.help_outline, maxLines: 3),
                    const SizedBox(height: 16),
                    DropRegion(
                      formats: const [Formats.plainText, Formats.uri, Formats.htmlText],
                      hitTestBehavior: HitTestBehavior.opaque,
                      onDropOver: (event) {
                        if (event.session.allowedOperations.contains(DropOperation.copy)) {
                          return DropOperation.copy;
                        }
                        return DropOperation.none;
                      },
                      onDropEnter: (event) => setState(() => _isDragOver = true),
                      onDropLeave: (event) => setState(() => _isDragOver = false),
                      onPerformDrop: (event) async {
                        print('onPerformDrop called in EditCardDialog!');
                        setState(() => _isDragOver = false);
                        final item = event.session.items.first;

                        final reader = item.dataReader!;

                        print('Checking for plainText...');
                        if (item.canProvide(Formats.plainText)) {
                          print('Can provide plainText. Getting value...');
                          reader.getValue<String>(Formats.plainText, (text) {
                            print('Received plainText value: ${text?.substring(0, min(text.length, 50))}...');
                            if (text != null) {
                              setState(() {
                                answerController.text += text;
                              });
                            }
                          }, onError: (error) {
                            print('Error reading plain text value: $error');
                          });
                        }

                        print('Checking for uri...');
                        if (item.canProvide(Formats.uri)) {
                          print('Can provide uri. Getting value...');
                          reader.getValue<NamedUri>(Formats.uri, (namedUri) {
                            print('Received uri value: ${namedUri?.uri}');
                            if (namedUri != null) {
                              setState(() {
                                answerController.text += namedUri.uri.toString();
                              });
                            }
                          }, onError: (error) {
                            print('Error reading uri value: $error');
                          });
                        }

                        print('Checking for htmlText...');
                        if (item.canProvide(Formats.htmlText)) {
                          print('Can provide htmlText. Getting value...');
                          reader.getValue<String>(Formats.htmlText, (html) {
                            print('Received htmlText value: ${html?.substring(0, min(html.length, 50))}...');
                            if (html != null) {
                              setState(() {
                                answerController.text += html;
                              });
                            }
                          }, onError: (error) {
                            print('Error reading html value: $error');
                          });
                        }
                        print('onPerformDrop in EditCardDialog finished.');
                      },
                      child: _buildTextField(answerController, widget.item.type == StudyItemType.note ? 'Content (Drop text here)' : 'Answer (Drop text here)', Icons.lightbulb_outline, maxLines: 5, isDragOver: _isDragOver),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final updatedItem = widget.item.copyWith(
                              category: categoryController.text.trim(),
                              question: questionController.text.trim(),
                              answer: answerController.text.trim(),
                            );
                            widget.onEdit(updatedItem);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                          child: const Text('Save', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1, bool isDragOver = false}) {
    return TextField(controller: controller, maxLines: maxLines, style: const TextStyle(color: Colors.white), decoration: InputDecoration(
        labelText: label, labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: AppTheme.primaryColor), filled: true, fillColor: Colors.black.withOpacity(0.2),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDragOver ? AppTheme.primaryColor : Colors.white.withOpacity(0.3))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryColor))),
    );
  }
}

// Practice Screen
class PracticeScreen extends StatefulWidget {
  final List<StudyItem> items;

  const PracticeScreen({super.key, required this.items});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> with TickerProviderStateMixin {
  late List<StudyItem> _cards;
  int _currentIndex = 0;
  bool _isFlipped = false;
  late AnimationController _flipController;
  late AnimationController _dragController;
  late Animation<Offset> _cardOffset;
  Offset _dragPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _cards = List.from(widget.items)..shuffle();
    _flipController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _dragController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _cardOffset = Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(CurvedAnimation(parent: _dragController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _flipController.dispose();
    _dragController.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_flipController.isAnimating) return;
    setState(() => _isFlipped = !_isFlipped);
    if (_isFlipped) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragPosition += details.delta;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (_dragPosition.dx.abs() > screenWidth * 0.4 ||
        details.velocity.pixelsPerSecond.dx.abs() > 500) {
      final endOffset = _dragPosition.dx > 0
          ? Offset(screenWidth * 1.2, _dragPosition.dy)
          : Offset(-screenWidth * 1.2, _dragPosition.dy);

      _cardOffset = Tween<Offset>(begin: _dragPosition, end: endOffset)
          .animate(CurvedAnimation(parent: _dragController, curve: Curves.easeIn));
      _dragController.forward().then((_) => _nextCard());
    } else {
      // Animate back to center
      _cardOffset = Tween<Offset>(begin: _dragPosition, end: Offset.zero)
          .animate(CurvedAnimation(parent: _dragController, curve: Curves.easeOut));
      _dragController.forward(from: 0).whenComplete(() {
        if(mounted) setState(() => _dragPosition = Offset.zero);
      });
    }
  }

  void _nextCard() {
    if (_currentIndex < _cards.length - 1) {
      setState(() {
        _currentIndex++;
        _isFlipped = false;
        _dragPosition = Offset.zero;
        _flipController.reset();
        _dragController.reset();
        _cardOffset = Tween<Offset>(begin: Offset.zero, end: Offset.zero)
            .animate(_dragController);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You've completed all cards!")),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.backgroundColor, Color(0xFF1A1A2E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              _buildProgress(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: GestureDetector(
                    onTap: _flipCard,
                    onPanUpdate: _onDragUpdate,
                    onPanEnd: _onDragEnd,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_dragController, _flipController]),
                      builder: (context, child) {
                        final cardPosition = _dragController.isAnimating
                            ? _cardOffset.value
                            : _dragPosition;
                        final angle = cardPosition.dx / MediaQuery.of(context).size.width * 0.4;

                        return Transform.translate(
                          offset: cardPosition,
                          child: Transform.rotate(
                            angle: angle,
                            child: _buildCardStack(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              _buildControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardStack() {
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Stack(
        children: [
          // Static background
          Transform.translate(
            offset: const Offset(4, 4),
            child: Container(decoration: AppTheme.solidPracticeCardDecoration),
          ),
          // Flippable foreground
          AnimatedBuilder(
            animation: _flipController,
            builder: (context, child) {
              final isFront = _flipController.value < 0.5;
              final transform = Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(_flipController.value * pi);

              return Transform(
                transform: transform,
                alignment: Alignment.center,
                child: isFront
                    ? _buildPracticeCardFace(isFront: true)
                    : Transform(
                  transform: Matrix4.identity()..rotateY(pi),
                  alignment: Alignment.center,
                  child: _buildPracticeCardFace(isFront: false),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeCardFace({required bool isFront}) {
    final item = _cards[_currentIndex];
    final textContent = isFront ? item.question : item.answer;

    BoxDecoration decoration;
    if (isFront) {
      decoration = AppTheme.glassPracticeCardDecoration;
    } else {
      decoration = AppTheme.solidPracticeCardDecoration;
    }

    Widget cardFace = Container(
      decoration: decoration,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: SingleChildScrollView(
            child: Text(
              textContent,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 22),
            ),
          ),
        ),
      ),
    );

    if (isFront) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: cardFace,
        ),
      );
    } else {
      return cardFace;
    }
  }


  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Text(
            "Practice Mode",
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(width: 48), // for balance
        ],
      ),
    );
  }

  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentIndex + 1) / _cards.length,
            backgroundColor: AppTheme.cardColor,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
          const SizedBox(height: 8),
          Text(
            '${_currentIndex + 1} / ${_cards.length}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ElevatedButton(
            onPressed: _flipCard,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Flip", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
