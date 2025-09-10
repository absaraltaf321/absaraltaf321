// enhanced_mind_map_app.dart
//
// Complete Enhanced Flutter Mind Map Application with Glass Morphism and Improved Layouts
//
// REQUIRED DEPENDENCIES for pubspec.yaml:
//
// dependencies:
//   flutter:
//     sdk: flutter
//   cupertino_icons: ^1.0.6
//   provider: ^6.1.2
//   uuid: ^4.4.0
//   file_picker: ^8.0.3
//   path_provider: ^2.1.3
//   flutter_colorpicker: ^1.1.0
//   pdf: ^3.10.8
//   printing: ^5.12.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() {
  runApp(const MindMapApplication());
}

// ===========================================================================
// GLASSMORPHISM WIDGETS
// ===========================================================================

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final double opacity;
  final Color? color;
  final Border? border;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 12,
    this.blur = 10,
    this.opacity = 0.1,
    this.color,
    this.border,
    this.padding,
    this.margin,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color ?? theme.colorScheme.surface.withOpacity(opacity),
              borderRadius: BorderRadius.circular(borderRadius),
              border: border ?? Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class GlassButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const GlassButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.borderRadius = 8,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(borderRadius),
        child: GlassContainer(
          borderRadius: borderRadius,
          padding: padding,
          color: color ?? theme.colorScheme.primary.withOpacity(0.1),
          child: child,
        ),
      ),
    );
  }
}

// ===========================================================================
// DATA MODELS
// ===========================================================================

class MindMapNode {
  final String id;
  String title;
  String description;
  Offset position;
  Size size;
  Color backgroundColor;
  Color textColor;
  String? parentId;
  List<String> childIds;
  NodeStyle style;
  bool isExpanded;
  DateTime createdAt;
  DateTime updatedAt;
  int level; // For better tree layout

  MindMapNode({
    String? id,
    required this.title,
    this.description = '',
    this.position = Offset.zero,
    this.size = const Size(150, 80),
    this.backgroundColor = Colors.blue,
    this.textColor = Colors.white,
    this.parentId,
    List<String>? childIds,
    this.style = NodeStyle.rounded,
    this.isExpanded = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.level = 0,
  }) : id = id ?? const Uuid().v4(),
        childIds = childIds ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'position': {'x': position.dx, 'y': position.dy},
    'size': {'width': size.width, 'height': size.height},
    'backgroundColor': backgroundColor.value,
    'textColor': textColor.value,
    'parentId': parentId,
    'childIds': childIds,
    'style': style.name,
    'isExpanded': isExpanded,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'level': level,
  };

  factory MindMapNode.fromJson(Map<String, dynamic> json) {
    return MindMapNode(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      position: Offset(
        json['position']['x']?.toDouble() ?? 0.0,
        json['position']['y']?.toDouble() ?? 0.0,
      ),
      size: Size(
        json['size']['width']?.toDouble() ?? 150.0,
        json['size']['height']?.toDouble() ?? 80.0,
      ),
      backgroundColor: Color(json['backgroundColor']),
      textColor: Color(json['textColor']),
      parentId: json['parentId'],
      childIds: List<String>.from(json['childIds'] ?? []),
      style: NodeStyle.values.firstWhere(
            (e) => e.name == json['style'],
        orElse: () => NodeStyle.rounded,
      ),
      isExpanded: json['isExpanded'] ?? true,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      level: json['level'] ?? 0,
    );
  }

  MindMapNode copyWith({
    String? title,
    String? description,
    Offset? position,
    Size? size,
    Color? backgroundColor,
    Color? textColor,
    String? parentId,
    List<String>? childIds,
    NodeStyle? style,
    bool? isExpanded,
    int? level,
  }) {
    return MindMapNode(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      position: position ?? this.position,
      size: size ?? this.size,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      parentId: parentId ?? this.parentId,
      childIds: childIds ?? this.childIds,
      style: style ?? this.style,
      isExpanded: isExpanded ?? this.isExpanded,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      level: level ?? this.level,
    );
  }
}

enum NodeStyle { rounded, rectangle, circle, diamond, hexagon }

class MindMap {
  final String id;
  String name;
  String description;
  Map<String, MindMapNode> nodes;
  String? rootNodeId;
  DateTime createdAt;
  DateTime updatedAt;
  Color backgroundColor;

  MindMap({
    String? id,
    required this.name,
    this.description = '',
    Map<String, MindMapNode>? nodes,
    this.rootNodeId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.backgroundColor = Colors.white,
  }) : id = id ?? const Uuid().v4(),
        nodes = nodes ?? {},
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'nodes': nodes.map((key, value) => MapEntry(key, value.toJson())),
    'rootNodeId': rootNodeId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'backgroundColor': backgroundColor.value,
  };

  factory MindMap.fromJson(Map<String, dynamic> json) {
    return MindMap(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      nodes: (json['nodes'] as Map<String, dynamic>).map(
            (key, value) => MapEntry(key, MindMapNode.fromJson(value)),
      ),
      rootNodeId: json['rootNodeId'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      backgroundColor: Color(json['backgroundColor'] ?? Colors.white.value),
    );
  }
}

// ===========================================================================
// ENHANCED STATE MANAGEMENT
// ===========================================================================

class MindMapState extends ChangeNotifier {
  final Map<String, MindMap> _mindMaps = {};
  String? _currentMindMapId;
  String? _selectedNodeId;
  bool _isDarkMode = false;
  Offset _canvasOffset = Offset.zero;
  double _canvasScale = 1.0;

  // Getters
  Map<String, MindMap> get mindMaps => _mindMaps;
  MindMap? get currentMindMap => _currentMindMapId != null ? _mindMaps[_currentMindMapId] : null;
  String? get selectedNodeId => _selectedNodeId;
  bool get isDarkMode => _isDarkMode;
  Offset get canvasOffset => _canvasOffset;
  double get canvasScale => _canvasScale;

  MindMapState() {
    _initializeWithSampleData();
  }

  void _initializeWithSampleData() {
    final sampleMap = MindMap(name: 'My First Mind Map');
    final rootNode = MindMapNode(
      title: 'Main Topic',
      description: 'This is your central idea',
      position: const Offset(400, 300),
      backgroundColor: Colors.indigo,
      textColor: Colors.white,
      level: 0,
    );

    sampleMap.nodes[rootNode.id] = rootNode;
    sampleMap.rootNodeId = rootNode.id;

    _mindMaps[sampleMap.id] = sampleMap;
    _currentMindMapId = sampleMap.id;
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void updateCanvasTransform(Offset offset, double scale) {
    _canvasOffset = offset;
    _canvasScale = scale;
    notifyListeners();
  }

  // Mind Map operations
  void createNewMindMap({String name = 'New Mind Map'}) {
    final newMap = MindMap(name: name);
    final rootNode = MindMapNode(
      title: 'Main Topic',
      position: const Offset(400, 300),
      backgroundColor: Colors.blue,
      textColor: Colors.white,
      level: 0,
    );

    newMap.nodes[rootNode.id] = rootNode;
    newMap.rootNodeId = rootNode.id;

    _mindMaps[newMap.id] = newMap;
    _currentMindMapId = newMap.id;
    _selectedNodeId = null;
    notifyListeners();
  }

  void switchMindMap(String mindMapId) {
    if (_mindMaps.containsKey(mindMapId)) {
      _currentMindMapId = mindMapId;
      _selectedNodeId = null;
      notifyListeners();
    }
  }

  void deleteMindMap(String mindMapId) {
    if (_mindMaps.length > 1 && _mindMaps.containsKey(mindMapId)) {
      _mindMaps.remove(mindMapId);
      if (_currentMindMapId == mindMapId) {
        _currentMindMapId = _mindMaps.keys.first;
        _selectedNodeId = null;
      }
      notifyListeners();
    }
  }

  void updateMindMapInfo(String name, String description) {
    if (currentMindMap != null) {
      currentMindMap!.name = name;
      currentMindMap!.description = description;
      currentMindMap!.updatedAt = DateTime.now();
      notifyListeners();
    }
  }

  // Enhanced Node operations
  void addNode({
    required String title,
    String description = '',
    String? parentId,
    Offset? position,
  }) {
    if (currentMindMap == null) return;

    final parent = parentId != null ? currentMindMap!.nodes[parentId] : null;
    final nodePosition = position ?? _calculateNewNodePosition(parent);
    final nodeLevel = parent != null ? parent.level + 1 : 0;

    final newNode = MindMapNode(
      title: title,
      description: description,
      position: nodePosition,
      parentId: parentId,
      backgroundColor: _generateNodeColor(parent),
      textColor: Colors.white,
      level: nodeLevel,
    );

    currentMindMap!.nodes[newNode.id] = newNode;

    if (parent != null) {
      parent.childIds.add(newNode.id);
    }

    _selectedNodeId = newNode.id;
    notifyListeners();
  }

  Offset _calculateNewNodePosition(MindMapNode? parent) {
    if (parent == null) {
      return const Offset(400, 300);
    }

    final childCount = parent.childIds.length;
    final angle = (childCount * 45) * (math.pi / 180);
    final distance = 200.0 + (parent.level * 50);

    return parent.position + Offset(
      distance * math.cos(angle),
      distance * math.sin(angle),
    );
  }

  Color _generateNodeColor(MindMapNode? parent) {
    if (parent == null) return Colors.blue;

    final colors = [
      Colors.green, Colors.orange, Colors.purple,
      Colors.teal, Colors.pink, Colors.indigo,
      Colors.amber, Colors.cyan, Colors.lime,
    ];

    return colors[(parent.childIds.length + parent.level) % colors.length];
  }

  void updateNode(String nodeId, MindMapNode updatedNode) {
    if (currentMindMap?.nodes.containsKey(nodeId) ?? false) {
      currentMindMap!.nodes[nodeId] = updatedNode;
      notifyListeners();
    }
  }

  void deleteNode(String nodeId) {
    final mindMap = currentMindMap;
    if (mindMap == null || nodeId == mindMap.rootNodeId) return;

    final node = mindMap.nodes[nodeId];
    if (node == null) return;

    // Remove from parent's children
    if (node.parentId != null) {
      final parent = mindMap.nodes[node.parentId];
      parent?.childIds.remove(nodeId);
    }

    // Delete all descendants
    _deleteNodeRecursively(nodeId);

    if (_selectedNodeId == nodeId) {
      _selectedNodeId = null;
    }

    notifyListeners();
  }

  void _deleteNodeRecursively(String nodeId) {
    final node = currentMindMap?.nodes[nodeId];
    if (node == null) return;

    // Delete all children first
    for (final childId in List.from(node.childIds)) {
      _deleteNodeRecursively(childId);
    }

    // Delete the node itself
    currentMindMap!.nodes.remove(nodeId);
  }

  void selectNode(String? nodeId) {
    _selectedNodeId = nodeId;
    notifyListeners();
  }

  void moveNode(String nodeId, Offset delta) {
    final node = currentMindMap?.nodes[nodeId];
    if (node != null) {
      node.position += delta;
      node.updatedAt = DateTime.now();
      notifyListeners();
    }
  }

  void updateNodeSize(String nodeId, Size size) {
    final node = currentMindMap?.nodes[nodeId];
    if (node != null && node.size != size) {
      node.size = size;
      notifyListeners();
    }
  }

  // ===========================================================================
  // === IMPROVED LAYOUT ALGORITHMS ============================================
  // ===========================================================================

  void applyRadialLayout() {
    final mindMap = currentMindMap;
    if (mindMap?.rootNodeId == null) return;

    final root = mindMap!.nodes[mindMap.rootNodeId!]!;
    root.position = const Offset(400, 300); // Center the root
    _calculateNodeLevels(root, 0);

    _applyRadialLayoutRecursive(root, 0, 360, 250.0);
    notifyListeners();
  }

  void _applyRadialLayoutRecursive(MindMapNode node, double startAngle, double endAngle, double radius) {
    final children = node.childIds
        .map((id) => currentMindMap!.nodes[id])
        .where((child) => child != null)
        .cast<MindMapNode>()
        .toList();

    if (children.isEmpty) return;

    final angleStep = (endAngle - startAngle) / children.length;

    // Increase radius exponentially to give more space to deeper levels
    final childRadius = radius * 1.6;

    for (int i = 0; i < children.length; i++) {
      final child = children[i];
      final angle = (startAngle + i * angleStep + angleStep / 2) * (math.pi / 180);

      child.position = node.position + Offset(
        radius * math.cos(angle),
        radius * math.sin(angle),
      );

      _applyRadialLayoutRecursive(
        child,
        startAngle + i * angleStep,
        startAngle + (i + 1) * angleStep,
        childRadius,
      );
    }
  }

  void applyTreeLayout({bool isVertical = true}) {
    final mindMap = currentMindMap;
    if (mindMap?.rootNodeId == null) return;

    final root = mindMap!.nodes[mindMap.rootNodeId!]!;
    _calculateNodeLevels(root, 0);

    final Map<String, double> subtreeWidths = {};
    _calculateSubtreeWidths(root, subtreeWidths, isVertical);

    if (isVertical) {
      root.position = const Offset(400, 100);
      _applyVerticalTreeLayout(root, root.position, subtreeWidths);
    } else {
      root.position = const Offset(150, 400);
      _applyHorizontalTreeLayout(root, root.position, subtreeWidths);
    }

    notifyListeners();
  }

  void _calculateNodeLevels(MindMapNode node, int level) {
    node.level = level;
    for (final childId in node.childIds) {
      final child = currentMindMap!.nodes[childId];
      if (child != null) {
        _calculateNodeLevels(child, level + 1);
      }
    }
  }

  // 1. First Pass (bottom-up): Calculate the width of each subtree.
  double _calculateSubtreeWidths(MindMapNode node, Map<String, double> widths, bool isVertical) {
    const nodeWidth = 200.0; // Horizontal space per node
    const nodeHeight = 150.0; // Vertical space per node

    double width = 0;
    if (node.childIds.isEmpty) {
      width = isVertical ? nodeWidth : nodeHeight;
    } else {
      for (final childId in node.childIds) {
        final child = currentMindMap!.nodes[childId]!;
        width += _calculateSubtreeWidths(child, widths, isVertical);
      }
    }
    widths[node.id] = width;
    return width;
  }

  // 2. Second Pass (top-down): Position nodes based on subtree widths.
  void _applyVerticalTreeLayout(MindMapNode node, Offset position, Map<String, double> subtreeWidths) {
    node.position = position;

    final children = node.childIds.map((id) => currentMindMap!.nodes[id]!).toList();
    if (children.isEmpty) return;

    const levelHeight = 150.0;
    final totalWidth = subtreeWidths[node.id]!;
    double currentX = position.dx - totalWidth / 2;

    for (final child in children) {
      final childWidth = subtreeWidths[child.id]!;
      final childPosition = Offset(currentX + childWidth / 2, position.dy + levelHeight);
      _applyVerticalTreeLayout(child, childPosition, subtreeWidths);
      currentX += childWidth;
    }
  }

  void _applyHorizontalTreeLayout(MindMapNode node, Offset position, Map<String, double> subtreeWidths) {
    node.position = position;

    final children = node.childIds.map((id) => currentMindMap!.nodes[id]!).toList();
    if (children.isEmpty) return;

    const levelWidth = 250.0;
    final totalHeight = subtreeWidths[node.id]!;
    double currentY = position.dy - totalHeight / 2;

    for (final child in children) {
      final childHeight = subtreeWidths[child.id]!;
      final childPosition = Offset(position.dx + levelWidth, currentY + childHeight / 2);
      _applyHorizontalTreeLayout(child, childPosition, subtreeWidths);
      currentY += childHeight;
    }
  }


  // PDF Export functionality
  Future<void> exportToPDF(GlobalKey canvasKey) async {
    try {
      final boundary = canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      // Capture the canvas as image
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final imageBytes = byteData!.buffer.asUint8List();

      // Create PDF document
      final pdf = pw.Document();
      final pdfImage = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a3.landscape, // Use A3 for better quality
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Container(
                child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
              ),
            );
          },
        ),
      );

      // Save or share the PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: '${currentMindMap?.name ?? 'mindmap'}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      print('PDF Export Error: $e');
    }
  }

  // Import/Export
  Future<void> exportToFile() async {
    try {
      final mindMap = currentMindMap;
      if (mindMap == null) return;

      final json = jsonEncode(mindMap.toJson());
      final fileName = '${mindMap.name.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.json';

      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Mind Map',
        fileName: fileName,
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(json);
      }
    } catch (e) {
      print('Export error: $e');
    }
  }

  Future<void> importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final json = jsonDecode(content);
        final mindMap = MindMap.fromJson(json);

        _mindMaps[mindMap.id] = mindMap;
        _currentMindMapId = mindMap.id;
        _selectedNodeId = null;
        notifyListeners();
      }
    } catch (e) {
      print('Import error: $e');
    }
  }

  String exportToJsonString() {
    final mindMap = currentMindMap;
    if (mindMap == null) return '{}';
    // Use an encoder with indentation for better readability
    return const JsonEncoder.withIndent('  ').convert(mindMap.toJson());
  }

  void importFromJsonString(String jsonString) {
    try {
      final json = jsonDecode(jsonString);
      final mindMap = MindMap.fromJson(json);

      _mindMaps[mindMap.id] = mindMap;
      _currentMindMapId = mindMap.id;
      _selectedNodeId = null;
      notifyListeners();
    } catch (e) {
      print('Import from JSON string error: $e');
    }
  }

  Rect calculateBounds() {
    final mindMap = currentMindMap;
    if (mindMap == null || mindMap.nodes.isEmpty) {
      return const Rect.fromLTWH(0, 0, 800, 600);
    }

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final node in mindMap.nodes.values) {
      minX = math.min(minX, node.position.dx);
      minY = math.min(minY, node.position.dy);
      maxX = math.max(maxX, node.position.dx + node.size.width);
      maxY = math.max(maxY, node.position.dy + node.size.height);
    }

    const padding = 300.0;
    return Rect.fromLTRB(
      minX - padding,
      minY - padding,
      maxX + padding,
      maxY + padding,
    );
  }
}

// ===========================================================================
// MAIN APPLICATION
// ===========================================================================

class MindMapApplication extends StatelessWidget {
  const MindMapApplication({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MindMapState(),
      child: Consumer<MindMapState>(
        builder: (context, state, _) {
          return MaterialApp(
            title: 'Enhanced Mind Map',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.indigo,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.indigo,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
            themeMode: state.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            debugShowCheckedModeBanner: false,
            home: const MindMapHomePage(),
          );
        },
      ),
    );
  }
}

// ===========================================================================
// HOME PAGE
// ===========================================================================

class MindMapHomePage extends StatefulWidget {
  const MindMapHomePage({super.key});

  @override
  State<MindMapHomePage> createState() => _MindMapHomePageState();
}

class _MindMapHomePageState extends State<MindMapHomePage> with TickerProviderStateMixin {
  final TransformationController _transformationController = TransformationController();
  final GlobalKey _canvasKey = GlobalKey();
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );
    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MindMapState>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: state.isDarkMode
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFF5F7FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: GlassContainer(
          borderRadius: 0,
          blur: 20,
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              state.currentMindMap?.name ?? 'Mind Map',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              // Use PopupMenuButton to handle overflow
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  switch (value) {
                    case 'radial':
                      state.applyRadialLayout();
                      break;
                    case 'layouts':
                      _showLayoutOptions(context);
                      break;
                    case 'pdf':
                      state.exportToPDF(_canvasKey);
                      break;
                    case 'import_export':
                      _showImportExportDialog(context);
                      break;
                    case 'theme':
                      state.toggleTheme();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'radial',
                    child: Row(
                      children: [
                        Icon(Icons.hub_outlined),
                        SizedBox(width: 8),
                        Text('Radial Layout'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'layouts',
                    child: Row(
                      children: [
                        Icon(Icons.account_tree_outlined),
                        SizedBox(width: 8),
                        Text('Tree Layouts'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'pdf',
                    child: Row(
                      children: [
                        Icon(Icons.print),
                        SizedBox(width: 8),
                        Text('Export as PDF'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'import_export',
                    child: Row(
                      children: [
                        Icon(Icons.import_export),
                        SizedBox(width: 8),
                        Text('Import/Export'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'theme',
                    child: Row(
                      children: [
                        Icon(state.isDarkMode ? Icons.light_mode : Icons.dark_mode),
                        const SizedBox(width: 8),
                        const Text('Toggle Theme'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
      drawer: const EnhancedMindMapDrawer(),
      body: state.currentMindMap == null
          ? const Center(
        child: Text('No mind map selected'),
      )
          : Stack(
        children: [
          // Main Canvas
          Positioned.fill(
            child: GestureDetector(
              onTap: () => state.selectNode(null),
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: 0.1,
                maxScale: 3.0,
                boundaryMargin: const EdgeInsets.all(200),
                constrained: false,
                onInteractionUpdate: (details) {
                  state.updateCanvasTransform(
                    details.localFocalPoint,
                    details.scale,
                  );
                },
                child: RepaintBoundary(
                  key: _canvasKey,
                  child: const MindMapCanvas(),
                ),
              ),
            ),
          ),
          // Enhanced Floating Action Buttons
          Positioned(
            bottom: 20,
            right: 20,
            child: AnimatedBuilder(
              animation: _fabAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _fabAnimation.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildGlassFAB(
                        icon: Icons.add,
                        onPressed: () => _showAddNodePanel(context),
                        heroTag: "add_node",
                      ),
                      const SizedBox(height: 16),
                      _buildGlassFAB(
                        icon: Icons.center_focus_strong,
                        onPressed: () => _centerCanvas(),
                        heroTag: "center_canvas",
                        size: 40,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Enhanced Node Inspector Panel
          if (state.selectedNodeId != null)
            Positioned(
              right: 20,
              top: 100,
              child: EnhancedNodeInspectorPanel(
                key: ValueKey(state.selectedNodeId),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGlassFAB({
    required IconData icon,
    required VoidCallback onPressed,
    required String heroTag,
    double size = 56,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: FloatingActionButton(
        heroTag: heroTag,
        onPressed: onPressed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: GlassContainer(
          borderRadius: size / 2,
          blur: 15,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                ],
              ),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
      ),
    );
  }

  void _centerCanvas() {
    final state = context.read<MindMapState>();
    final bounds = state.calculateBounds();
    final center = bounds.center;
    final screenSize = MediaQuery.of(context).size;

    final targetTransform = Matrix4.identity()
      ..translate(
        screenSize.width / 2 - center.dx,
        screenSize.height / 2 - center.dy,
      );

    _transformationController.value = targetTransform;
  }

  void _showLayoutOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassContainer(
        borderRadius: 20,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose Layout',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLayoutOption(
                  context,
                  'Vertical Tree',
                  Icons.account_tree,
                      () {
                    context.read<MindMapState>().applyTreeLayout(isVertical: true);
                    Navigator.pop(context);
                  },
                ),
                _buildLayoutOption(
                  context,
                  'Horizontal Tree',
                  Icons.device_hub,
                      () {
                    context.read<MindMapState>().applyTreeLayout(isVertical: false);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayoutOption(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _showAddNodePanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const EnhancedAddNodePanel(),
    );
  }

  void _showImportExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const EnhancedImportExportDialog(),
    );
  }
}

// ===========================================================================
// ENHANCED CANVAS WIDGET
// ===========================================================================

class MindMapCanvas extends StatelessWidget {
  const MindMapCanvas({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MindMapState>();
    final bounds = state.calculateBounds();

    return Container(
      width: bounds.width,
      height: bounds.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: state.isDarkMode
              ? [
            const Color(0xFF0A0A0A),
            const Color(0xFF1A1A2E),
            const Color(0xFF16213E),
          ]
              : [
            const Color(0xFFF5F7FA),
            const Color(0xFFE8F4FD),
            const Color(0xFFDDE7F0),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Grid pattern
          CustomPaint(
            size: Size(bounds.width, bounds.height),
            painter: GridPainter(
              isDarkMode: state.isDarkMode,
              bounds: bounds,
            ),
          ),
          // Connection lines
          CustomPaint(
            size: Size(bounds.width, bounds.height),
            painter: EnhancedConnectionPainter(
              nodes: state.currentMindMap?.nodes ?? {},
              selectedNodeId: state.selectedNodeId,
              bounds: bounds,
              isDarkMode: state.isDarkMode,
            ),
          ),
          // Nodes
          ...state.currentMindMap?.nodes.values.map((node) =>
              EnhancedNodeWidget(
                key: ValueKey(node.id),
                node: node,
                bounds: bounds,
                isSelected: state.selectedNodeId == node.id,
              ),
          ) ?? [],
        ],
      ),
    );
  }
}

// ===========================================================================
// ENHANCED NODE WIDGET
// ===========================================================================

class EnhancedNodeWidget extends StatefulWidget {
  final MindMapNode node;
  final Rect bounds;
  final bool isSelected;

  const EnhancedNodeWidget({
    super.key,
    required this.node,
    required this.bounds,
    required this.isSelected,
  });

  @override
  State<EnhancedNodeWidget> createState() => _EnhancedNodeWidgetState();
}

class _EnhancedNodeWidgetState extends State<EnhancedNodeWidget> with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _glowController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  final GlobalKey _nodeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    if (widget.isSelected) {
      _scaleController.forward();
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(EnhancedNodeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _scaleController.forward();
        _glowController.repeat(reverse: true);
      } else {
        _scaleController.reverse();
        _glowController.stop();
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _updateNodeSize());
  }

  void _updateNodeSize() {
    final renderObject = _nodeKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderObject != null) {
      final size = renderObject.size;
      context.read<MindMapState>().updateNodeSize(widget.node.id, size);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<MindMapState>();
    final adjustedPosition = widget.node.position - widget.bounds.topLeft;

    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _glowAnimation]),
      builder: (context, child) {
        return Positioned(
          left: adjustedPosition.dx,
          top: adjustedPosition.dy,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: GestureDetector(
              onTap: () => state.selectNode(widget.node.id),
              onLongPress: () => _showNodeContextMenu(context),
              onPanUpdate: (details) => state.moveNode(widget.node.id, details.delta),
              child: Container(
                key: _nodeKey,
                constraints: const BoxConstraints(
                  minWidth: 120,
                  maxWidth: 280,
                  minHeight: 60,
                ),
                child: GlassContainer(
                  borderRadius: _getNodeBorderRadius(),
                  blur: 15,
                  padding: const EdgeInsets.all(16),
                  color: widget.node.backgroundColor.withOpacity(0.8),
                  border: Border.all(
                    color: widget.isSelected
                        ? Colors.amber.withOpacity(0.8 + _glowAnimation.value * 0.2)
                        : widget.node.backgroundColor.withOpacity(0.3),
                    width: widget.isSelected ? 2 : 1,
                  ),
                  child: _buildNodeContent(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _getNodeBorderRadius() {
    switch (widget.node.style) {
      case NodeStyle.rounded:
        return 16;
      case NodeStyle.rectangle:
        return 4;
      case NodeStyle.circle:
        return 50;
      case NodeStyle.diamond:
        return 8;
      case NodeStyle.hexagon:
        return 12;
    }
  }

  Widget _buildNodeContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.node.title,
          style: TextStyle(
            color: widget.node.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.3),
                offset: const Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
        if (widget.node.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            widget.node.description,
            style: TextStyle(
              color: widget.node.textColor.withOpacity(0.9),
              fontSize: 12,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.2),
                  offset: const Offset(0.5, 0.5),
                  blurRadius: 1,
                ),
              ],
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  void _showNodeContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => EnhancedNodeContextMenu(nodeId: widget.node.id),
    );
  }
}

// ===========================================================================
// ENHANCED PAINTERS
// ===========================================================================

class GridPainter extends CustomPainter {
  final bool isDarkMode;
  final Rect bounds;

  GridPainter({required this.isDarkMode, required this.bounds});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDarkMode
          ? Colors.white.withOpacity(0.05)
          : Colors.grey.withOpacity(0.1)
      ..strokeWidth = 1;

    const gridSize = 50.0;

    // Draw vertical lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class EnhancedConnectionPainter extends CustomPainter {
  final Map<String, MindMapNode> nodes;
  final String? selectedNodeId;
  final Rect bounds;
  final bool isDarkMode;

  EnhancedConnectionPainter({
    required this.nodes,
    required this.selectedNodeId,
    required this.bounds,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final selectedPaint = Paint()
      ..color = Colors.amber
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    for (final node in nodes.values) {
      if (node.parentId != null) {
        final parent = nodes[node.parentId];
        if (parent != null) {
          final startPoint = (parent.position - bounds.topLeft) +
              Offset(parent.size.width / 2, parent.size.height / 2);
          final endPoint = (node.position - bounds.topLeft) +
              Offset(node.size.width / 2, node.size.height / 2);

          final isHighlighted = selectedNodeId == node.id || selectedNodeId == parent.id;

          // Create gradient colors
          final gradient = LinearGradient(
            colors: [
              parent.backgroundColor.withOpacity(0.8),
              node.backgroundColor.withOpacity(0.8),
            ],
          );

          paint.shader = gradient.createShader(Rect.fromPoints(startPoint, endPoint));

          // Draw curved connection with shadow
          final path = _createCurvedPath(startPoint, endPoint);

          // Draw shadow
          canvas.drawPath(path, shadowPaint);

          // Draw main line
          canvas.drawPath(path, isHighlighted ? selectedPaint : paint);

          // Draw arrow head
          _drawEnhancedArrowHead(canvas, endPoint, startPoint, isHighlighted ? selectedPaint : paint);
        }
      }
    }
  }

  Path _createCurvedPath(Offset start, Offset end) {
    final path = Path();
    path.moveTo(start.dx, start.dy);

    final distance = (end - start).distance;
    final controlOffset = distance * 0.3;

    final controlPoint1 = start + Offset(controlOffset, 0);
    final controlPoint2 = end - Offset(controlOffset, 0);

    path.cubicTo(
      controlPoint1.dx, controlPoint1.dy,
      controlPoint2.dx, controlPoint2.dy,
      end.dx, end.dy,
    );

    return path;
  }

  void _drawEnhancedArrowHead(Canvas canvas, Offset tip, Offset start, Paint paint) {
    const arrowLength = 12.0;
    const arrowAngle = 25 * math.pi / 180;

    final direction = (tip - start).direction;

    final arrowP1 = tip + Offset(
      arrowLength * math.cos(direction + math.pi - arrowAngle),
      arrowLength * math.sin(direction + math.pi - arrowAngle),
    );

    final arrowP2 = tip + Offset(
      arrowLength * math.cos(direction + math.pi + arrowAngle),
      arrowLength * math.sin(direction + math.pi + arrowAngle),
    );

    final arrowPath = Path()
      ..moveTo(arrowP1.dx, arrowP1.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(arrowP2.dx, arrowP2.dy);

    canvas.drawPath(arrowPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Helper painter for creating a dashed border effect.
class DottedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double radius;

  DottedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.gap = 4.0,
    this.radius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(radius)));

    ui.PathMetrics pathMetrics = path.computeMetrics();
    for (ui.PathMetric pathMetric in pathMetrics) {
      double distance = 0.0;
      while (distance < pathMetric.length) {
        canvas.drawPath(
          pathMetric.extractPath(distance, distance + gap),
          paint,
        );
        distance += gap * 2;
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}


// ===========================================================================
// ENHANCED UI COMPONENTS
// ===========================================================================

class EnhancedMindMapDrawer extends StatelessWidget {
  const EnhancedMindMapDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MindMapState>();

    return Drawer(
      backgroundColor: Colors.transparent,
      child: GlassContainer(
        borderRadius: 0,
        blur: 20,
        child: Column(
          children: [
            Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.indigo.withOpacity(0.8),
                    Colors.blue.withOpacity(0.6),
                    Colors.purple.withOpacity(0.4),
                  ],
                ),
              ),
              child: const SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.psychology,
                        size: 50,
                        color: Colors.white,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Mind Maps',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Organize your thoughts',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: state.mindMaps.length,
                itemBuilder: (context, index) {
                  final mindMap = state.mindMaps.values.elementAt(index);
                  final isSelected = mindMap.id == state.currentMindMap?.id;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: GlassContainer(
                      borderRadius: 12,
                      padding: const EdgeInsets.all(12),
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                          : null,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.indigo.withOpacity(0.6),
                                Colors.blue.withOpacity(0.4),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.account_tree,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          mindMap.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          mindMap.description.isEmpty
                              ? '${mindMap.nodes.length} nodes'
                              : mindMap.description,
                        ),
                        onTap: () {
                          state.switchMindMap(mindMap.id);
                          Navigator.pop(context);
                        },
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) {
                            if (value == 'delete' && state.mindMaps.length > 1) {
                              state.deleteMindMap(mindMap.id);
                            } else if (value == 'edit') {
                              _showEditMindMapDialog(context, mindMap);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            if (state.mindMaps.length > 1)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: GlassButton(
                onPressed: () {
                  state.createNewMindMap();
                  Navigator.pop(context);
                },
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add),
                    SizedBox(width: 8),
                    Text('New Mind Map', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditMindMapDialog(BuildContext context, MindMap mindMap) {
    final nameController = TextEditingController(text: mindMap.name);
    final descriptionController = TextEditingController(text: mindMap.description);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Edit Mind Map',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  filled: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GlassButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  GlassButton(
                    onPressed: () {
                      if (nameController.text.isNotEmpty) {
                        context.read<MindMapState>().updateMindMapInfo(
                          nameController.text,
                          descriptionController.text,
                        );
                        Navigator.pop(context);
                      }
                    },
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EnhancedNodeInspectorPanel extends StatefulWidget {
  const EnhancedNodeInspectorPanel({super.key});

  @override
  State<EnhancedNodeInspectorPanel> createState() => _EnhancedNodeInspectorPanelState();
}

class _EnhancedNodeInspectorPanelState extends State<EnhancedNodeInspectorPanel> with TickerProviderStateMixin {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    final state = context.read<MindMapState>();
    final node = state.currentMindMap?.nodes[state.selectedNodeId];
    _titleController = TextEditingController(text: node?.title ?? '');
    _descriptionController = TextEditingController(text: node?.description ?? '');

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeInOut));

    _slideController.forward();
  }

  @override
  void didUpdateWidget(covariant EnhancedNodeInspectorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh text fields if selected node changes
    final state = context.read<MindMapState>();
    final node = state.currentMindMap?.nodes[state.selectedNodeId];
    _titleController.text = node?.title ?? '';
    _descriptionController.text = node?.description ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MindMapState>();
    final node = state.currentMindMap?.nodes[state.selectedNodeId];

    if (node == null) {
      return const SizedBox.shrink();
    }

    return SlideTransition(
      position: _slideAnimation,
      child: GlassContainer(
        width: 320,
        padding: const EdgeInsets.all(20),
        blur: 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary.withOpacity(0.6),
                        Theme.of(context).colorScheme.secondary.withOpacity(0.4),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Edit Node',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                GlassButton(
                  onPressed: () {
                    _slideController.reverse().then((_) {
                      state.selectNode(null);
                    });
                  },
                  child: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.3),
              ),
              onChanged: (value) => _updateNode(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.3),
              ),
              maxLines: 3,
              onChanged: (value) => _updateNode(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('Background Color:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _showColorPicker(context, node),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: node.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<NodeStyle>(
              value: node.style,
              decoration: InputDecoration(
                labelText: 'Style',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.3),
              ),
              items: NodeStyle.values.map((style) => DropdownMenuItem(
                value: style,
                child: Text(style.name.toUpperCase()),
              )).toList(),
              onChanged: (style) {
                if (style != null) {
                  final updatedNode = node.copyWith(style: style);
                  state.updateNode(node.id, updatedNode);
                }
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GlassButton(
                    onPressed: () => _showDeleteConfirmation(context, node.id),
                    color: Colors.red.withOpacity(0.2),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassButton(
                    onPressed: () => _showAddChildDialog(context, node.id),
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add),
                        SizedBox(width: 8),
                        Text('Add Child'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _updateNode() {
    final state = context.read<MindMapState>();
    final node = state.currentMindMap?.nodes[state.selectedNodeId];
    if (node != null) {
      final updatedNode = node.copyWith(
        title: _titleController.text,
        description: _descriptionController.text,
      );
      state.updateNode(node.id, updatedNode);
    }
  }

  void _showColorPicker(BuildContext context, MindMapNode node) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose Color',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              SingleChildScrollView(
                child: ColorPicker(
                  pickerColor: node.backgroundColor,
                  onColorChanged: (color) {
                    final textColor = color.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white;
                    final updatedNode = node.copyWith(
                      backgroundColor: color,
                      textColor: textColor,
                    );
                    context.read<MindMapState>().updateNode(node.id, updatedNode);
                  },
                ),
              ),
              const SizedBox(height: 20),
              GlassButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String nodeId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'Delete Node',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Are you sure you want to delete this node and all its children?',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GlassButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  GlassButton(
                    onPressed: () {
                      context.read<MindMapState>().deleteNode(nodeId);
                      Navigator.pop(context);
                    },
                    color: Colors.red.withOpacity(0.2),
                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddChildDialog(BuildContext context, String parentId) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Child Node',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GlassButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  GlassButton(
                    onPressed: () {
                      if (titleController.text.isNotEmpty) {
                        context.read<MindMapState>().addNode(
                          title: titleController.text,
                          description: descriptionController.text,
                          parentId: parentId,
                        );
                        Navigator.pop(context);
                      }
                    },
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    child: const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EnhancedAddNodePanel extends StatefulWidget {
  const EnhancedAddNodePanel({super.key});

  @override
  State<EnhancedAddNodePanel> createState() => _EnhancedAddNodePanelState();
}

class _EnhancedAddNodePanelState extends State<EnhancedAddNodePanel> with TickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  Color _selectedColor = Colors.blue;
  NodeStyle _selectedStyle = NodeStyle.rounded;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack));

    _slideController.forward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MindMapState>();
    final selectedNode = state.selectedNodeId != null
        ? state.currentMindMap?.nodes[state.selectedNodeId]
        : null;

    return SlideTransition(
      position: _slideAnimation,
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return GlassContainer(
            borderRadius: 20,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary.withOpacity(0.6),
                              Theme.of(context).colorScheme.secondary.withOpacity(0.4),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add_circle, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Add New Node',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                      GlassButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Parent info
                  if (selectedNode != null) ...[
                    GlassContainer(
                      padding: const EdgeInsets.all(16),
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      child: Row(
                        children: [
                          const Icon(Icons.link),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Will be added as child of:',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  selectedNode.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Title field
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Node Title',
                      hintText: 'Enter the main idea',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.3),
                      prefixIcon: const Icon(Icons.title),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 20),

                  // Description field
                  TextField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description (Optional)',
                      hintText: 'Add additional details...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.3),
                      prefixIcon: const Icon(Icons.description),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),

                  // Color selection
                  const Text(
                    'Choose Color',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      Colors.blue, Colors.green, Colors.orange, Colors.purple,
                      Colors.red, Colors.teal, Colors.pink, Colors.indigo,
                      Colors.amber, Colors.cyan,
                    ].map((color) => GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedColor == color ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _selectedColor == color
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Style selection
                  const Text(
                    'Choose Style',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: NodeStyle.values.map((style) => GestureDetector(
                      onTap: () => setState(() => _selectedStyle = style),
                      child: GlassContainer(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        color: _selectedStyle == style
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                            : null,
                        border: Border.all(
                          color: _selectedStyle == style
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                        child: Text(
                          style.name.toUpperCase(),
                          style: TextStyle(
                            fontWeight: _selectedStyle == style
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 32),

                  // Create button
                  SizedBox(
                    width: double.infinity,
                    child: GlassButton(
                      onPressed: () {
                        if (_titleController.text.isNotEmpty) {
                          state.addNode(
                            title: _titleController.text,
                            description: _descriptionController.text,
                            parentId: state.selectedNodeId,
                          );
                          // Update the newly created node with selected properties
                          final newNode = state.currentMindMap!.nodes.values.last;
                          final updatedNode = newNode.copyWith(
                            backgroundColor: _selectedColor,
                            textColor: _selectedColor.computeLuminance() > 0.5
                                ? Colors.black
                                : Colors.white,
                            style: _selectedStyle,
                          );
                          state.updateNode(newNode.id, updatedNode);
                          Navigator.pop(context);
                        }
                      },
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle),
                          SizedBox(width: 12),
                          Text(
                            'Create Node',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class EnhancedNodeContextMenu extends StatelessWidget {
  final String nodeId;

  const EnhancedNodeContextMenu({
    super.key,
    required this.nodeId,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.read<MindMapState>();
    final node = state.currentMindMap?.nodes[nodeId];
    final isRoot = state.currentMindMap?.rootNodeId == nodeId;

    if (node == null) {
      return const SizedBox.shrink();
    }

    return GlassContainer(
      borderRadius: 20,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  node.backgroundColor.withOpacity(0.8),
                  node.backgroundColor.withOpacity(0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.account_tree, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            node.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          if (node.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              node.description,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          _buildMenuOption(
            context,
            'Add Child Node',
            Icons.add_circle_outline,
                () {
              Navigator.pop(context);
              _showAddChildDialog(context, nodeId);
            },
          ),
          _buildMenuOption(
            context,
            'Edit Node',
            Icons.edit,
                () {
              state.selectNode(nodeId);
              Navigator.pop(context);
            },
          ),
          if (!isRoot) ...[
            _buildMenuOption(
              context,
              'Delete Node',
              Icons.delete,
                  () {
                state.deleteNode(nodeId);
                Navigator.pop(context);
              },
              isDestructive: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuOption(
      BuildContext context,
      String title,
      IconData icon,
      VoidCallback onTap, {
        bool isDestructive = false,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GlassButton(
        onPressed: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        color: isDestructive
            ? Colors.red.withOpacity(0.1)
            : Theme.of(context).colorScheme.primary.withOpacity(0.1),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.red : null,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: isDestructive ? Colors.red : null,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddChildDialog(BuildContext context, String parentId) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Child Node',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GlassButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  GlassButton(
                    onPressed: () {
                      if (titleController.text.isNotEmpty) {
                        context.read<MindMapState>().addNode(
                          title: titleController.text,
                          description: descriptionController.text,
                          parentId: parentId,
                        );
                        Navigator.pop(context);
                      }
                    },
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    child: const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EnhancedImportExportDialog extends StatefulWidget {
  const EnhancedImportExportDialog({super.key});

  @override
  State<EnhancedImportExportDialog> createState() => _EnhancedImportExportDialogState();
}

class _EnhancedImportExportDialogState extends State<EnhancedImportExportDialog> with TickerProviderStateMixin {
  final _jsonController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _jsonController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<MindMapState>();
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassContainer(
        width: math.min(screenSize.width * 0.9, 600),
        height: math.min(screenSize.height * 0.8, 700),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.withOpacity(0.6),
                        Colors.purple.withOpacity(0.4),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.import_export, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Import / Export',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                GlassButton(
                  onPressed: () => Navigator.pop(context),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tab bar
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                tabs: const [
                  Tab(text: 'Import', icon: Icon(Icons.file_upload, size: 20)),
                  Tab(text: 'Export', icon: Icon(Icons.file_download, size: 20)),
                ],
              ),
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Import Tab
                  _buildImportTab(state, context),
                  // Export Tab
                  _buildExportTab(state, context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // A more intuitive import tab
  Widget _buildImportTab(MindMapState state, BuildContext dialogContext) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          // "Dropzone" style widget for file import
          GestureDetector(
            onTap: () async {
              await state.importFromFile();
              if (mounted) Navigator.pop(dialogContext);
            },
            child: CustomPaint(
              painter: DottedBorderPainter(
                color: theme.colorScheme.primary.withOpacity(0.6),
                radius: 16,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 50,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Import from File',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Click here to select a .json file from your device. Recommended for transferring maps.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // "OR" separator
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
          ),

          // Import from text section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste JSON Text',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _jsonController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Paste raw JSON content here...',
                  filled: true,
                  fillColor: theme.colorScheme.surface.withOpacity(0.3),
                  contentPadding: const EdgeInsets.all(12),
                ),
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                maxLines: 6,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: GlassButton(
                  onPressed: () {
                    if (_jsonController.text.isNotEmpty) {
                      state.importFromJsonString(_jsonController.text);
                      Navigator.pop(dialogContext);
                    }
                  },
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: Colors.green.withOpacity(0.2),
                  child: const Text('Import from Text'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // A more intuitive export tab
  Widget _buildExportTab(MindMapState state, BuildContext dialogContext) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          // Primary action: Export to file
          Icon(Icons.save_alt, size: 50, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          const Text(
            'Export to File',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Save your current mind map as a .json file. This is the best way to create a backup.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 20),
          GlassButton(
            onPressed: () async {
              await state.exportToFile();
              if (mounted) Navigator.pop(dialogContext);
            },
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            color: theme.colorScheme.primary.withOpacity(0.2),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.file_download, size: 20),
                SizedBox(width: 10),
                Text('Save Mind Map File', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          
          // "OR" separator
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
          ),
          
          // Secondary action: Copy JSON
          GlassContainer(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Copy as JSON Text',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    GlassButton(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: state.exportToJsonString()),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied to clipboard!'),
                            behavior: SnackBarBehavior.floating,
                            width: 200,
                          ),
                        );
                      },
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: const Row(
                        children: [
                          Icon(Icons.copy, size: 16),
                          SizedBox(width: 6),
                          Text('Copy'),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  'For developers or manual backup.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 150,
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      state.exportToJsonString(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
