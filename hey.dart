// main.dart
//
// This single file contains the complete Flutter Mind Map application.
//
// REQUIRED DEPENDENCIES for pubspec.yaml:
//
// dependencies:
//   flutter:
//     sdk: flutter
//   provider: ^6.1.2         # For state management
//   file_picker: ^8.0.3      # For importing/exporting JSON files
//   path_provider: ^2.1.3    # To find the correct local path for saving files
//   pdf: ^3.10.8             # For creating PDF documents
//   printing: ^5.12.0        # For saving/sharing the generated PDF
//   uuid: ^4.4.0             # For generating unique IDs for nodes and maps
//   flutter_colorpicker: ^1.1.0 # For a user-friendly color picker in the editor
//   cupertino_icons: ^1.0.6

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

const Uuid uuid = Uuid();

// ===========================================================================
// 1. DATA MODELS
// ===========================================================================

enum NodeShape { rectangle, roundedRectangle }

class NodeData {
  final String id;
  String parentId;
  String title;
  String content;
  Offset position;
  Color color;
  NodeShape shape;
  Size size; // Cache the size for layout and painting

  NodeData({
    required this.id,
    this.parentId = '',
    required this.title,
    this.content = '',
    required this.position,
    required this.color,
    this.shape = NodeShape.roundedRectangle,
    this.size = const Size(150, 80), // Default initial size
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'parentId': parentId,
        'title': title,
        'content': content,
        'x': position.dx,
        'y': position.dy,
        'color': color.value,
        'shape': shape.name,
      };

  factory NodeData.fromJson(Map<String, dynamic> json) {
    return NodeData(
      id: json['id'],
      parentId: json['parentId'] ?? '',
      title: json['title'],
      content: json['content'] ?? '',
      position: Offset(json['x']?.toDouble() ?? 0.0, json['y']?.toDouble() ?? 0.0),
      color: Color(json['color']),
      shape: NodeShape.values.firstWhere(
        (e) => e.name == json['shape'],
        orElse: () => NodeShape.roundedRectangle,
      ),
    );
  }
}

class MindMapData {
  String id;
  String name;
  List<NodeData> nodes;
  String? rootNodeId;

  MindMapData({
    required this.id,
    required this.name,
    required this.nodes,
    this.rootNodeId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rootNodeId': rootNodeId,
        'nodes': nodes.map((node) => node.toJson()).toList(),
      };

  factory MindMapData.fromJson(Map<String, dynamic> json) {
    var nodesList = (json['nodes'] as List).map((nodeJson) => NodeData.fromJson(nodeJson)).toList();
    return MindMapData(
      id: json['id'],
      name: json['name'],
      nodes: nodesList,
      rootNodeId: json['rootNodeId'],
    );
  }
}

class MindMapCollection {
  List<MindMapData> maps;

  MindMapCollection({required this.maps});

  Map<String, dynamic> toJson() => {
        'maps': maps.map((map) => map.toJson()).toList(),
      };

  factory MindMapCollection.fromJson(Map<String, dynamic> json) {
    return MindMapCollection(
      maps: (json['maps'] as List).map((mapJson) => MindMapData.fromJson(mapJson)).toList(),
    );
  }
}

// ===========================================================================
// 2. STATE MANAGEMENT (CONTROLLER)
// ===========================================================================

class MindMapController with ChangeNotifier {
  MindMapCollection _collection = MindMapCollection(maps: []);
  String? _activeMapId;
  String? _selectedNodeId;
  ThemeMode _themeMode = ThemeMode.system;

  MindMapCollection get collection => _collection;
  String? get activeMapId => _activeMapId;
  MindMapData? get activeMap => _activeMapId == null ? null : _collection.maps.firstWhere((map) => map.id == _activeMapId);
  String? get selectedNodeId => _selectedNodeId;
  ThemeMode get themeMode => _themeMode;

  MindMapController() {
    _createNewMap(isInitial: true);
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  // --- Map Management ---

  void _createNewMap({bool isInitial = false}) {
    String newId = uuid.v4();
    final newMap = MindMapData(
      id: newId,
      name: 'Untitled Map',
      nodes: [],
      rootNodeId: null,
    );
    _collection.maps.add(newMap);
    _activeMapId = newId;
    addNode(parentId: null, title: 'Main Topic');

    if (!isInitial) {
      notifyListeners();
    }
  }

  void createNewMap() => _createNewMap();

  void switchActiveMap(String mapId) {
    if (_activeMapId != mapId) {
      _activeMapId = mapId;
      _selectedNodeId = null;
      notifyListeners();
    }
  }

  void deleteMap(String mapId) {
    if (_collection.maps.length <= 1) return; // Don't delete the last map
    _collection.maps.removeWhere((map) => map.id == mapId);
    if (_activeMapId == mapId) {
      _activeMapId = _collection.maps.first.id;
      _selectedNodeId = null;
    }
    notifyListeners();
  }

  void updateMapName(String newName) {
    if (activeMap != null) {
      activeMap!.name = newName;
      notifyListeners();
    }
  }

  // --- Node Management ---

  void addNode({String? parentId, required String title}) {
    final map = activeMap;
    if (map == null) return;

    final parentNode = parentId == null ? null : map.nodes.firstWhere((n) => n.id == parentId);
    Offset position;

    // MODIFIED LOGIC BLOCK
    if (parentNode != null) {
      // Position new node near its parent
      position = parentNode.position + const Offset(200, 0);
    } else {
      // This is the first node (root), place it in the center of the large canvas
      position = const Offset(_MindMapScreenState.canvasSize / 2, _MindMapScreenState.canvasSize / 2);
    }

    final newNode = NodeData(
      id: uuid.v4(),
      parentId: parentId ?? '',
      title: title,
      position: position,
      color: Colors.blue.shade200,
    );

    map.nodes.add(newNode);
    if (map.rootNodeId == null) {
      map.rootNodeId = newNode.id;
      map.name = title; // Sync map name with root node title on creation
    }

    _selectedNodeId = newNode.id;
    notifyListeners();
  }

  void updateNode(NodeData updatedNode) {
    final map = activeMap;
    if (map == null) return;
    int index = map.nodes.indexWhere((n) => n.id == updatedNode.id);
    if (index != -1) {
      map.nodes[index] = updatedNode;
      // If root node title changed, update map name
      if (map.rootNodeId == updatedNode.id && map.name != updatedNode.title) {
        map.name = updatedNode.title;
      }
      notifyListeners();
    }
  }

  void deleteNode(String nodeId) {
    final map = activeMap;
    if (map == null || map.rootNodeId == nodeId) return; // Cannot delete root

    List<String> nodesToDelete = [nodeId];
    List<String> queue = [nodeId];

    while (queue.isNotEmpty) {
      String currentId = queue.removeAt(0);
      var children = map.nodes.where((n) => n.parentId == currentId);
      for (var child in children) {
        if (!nodesToDelete.contains(child.id)) {
          nodesToDelete.add(child.id);
          queue.add(child.id);
        }
      }
    }

    map.nodes.removeWhere((n) => nodesToDelete.contains(n.id));

    if (_selectedNodeId == nodeId) {
      _selectedNodeId = null;
    }
    notifyListeners();
  }

  void updateNodePosition(String nodeId, Offset delta) {
    final node = activeMap?.nodes.firstWhere((n) => n.id == nodeId);
    if (node != null) {
      node.position += delta;
      notifyListeners();
    }
  }

  void updateNodeSize(String nodeId, Size newSize) {
    final node = activeMap?.nodes.firstWhere((n) => n.id == nodeId);
    if (node != null && node.size != newSize) {
      node.size = newSize;
      // No need to notifyListeners here as this is typically called during build phase.
    }
  }

  void selectNode(String? nodeId) {
    if (_selectedNodeId != nodeId) {
      _selectedNodeId = nodeId;
      notifyListeners();
    }
  }

  // --- Layout Algorithms ---

  void applyTreeLayout({bool isVertical = false}) {
    final map = activeMap;
    if (map == null || map.rootNodeId == null) return;

    Map<String, List<String>> hierarchy = {};
    for (var node in map.nodes) {
      hierarchy.putIfAbsent(node.parentId, () => []).add(node.id);
    }

    // A simple recursive layout function
    void positionNodeAndChildren(String nodeId, Offset position) {
      final node = map.nodes.firstWhere((n) => n.id == nodeId);
      node.position = position;

      final children = hierarchy[nodeId] ?? [];
      if (children.isEmpty) return;
      
      final double totalSpan = (children.length - 1) * (isVertical ? 200.0 : 120.0);
      double currentOffset = -totalSpan / 2.0;

      for (var childId in children) {
        final childNode = map.nodes.firstWhere((n) => n.id == childId);
        final childPosition = isVertical
            ? Offset(position.dx + currentOffset, position.dy + 120.0)
            : Offset(position.dx + 200.0, position.dy + currentOffset);
        
        positionNodeAndChildren(childId, childPosition);

        currentOffset += isVertical ? 200.0 : 120.0;
      }
    }
    
    final rootPosition = map.nodes.firstWhere((n) => n.id == map.rootNodeId).position;
    positionNodeAndChildren(map.rootNodeId!, rootPosition);

    notifyListeners();
  }

  // --- Import / Export ---

  String getJsonFormatSample() {
    return '''
{
  "maps": [
    {
      "id": "unique-map-id",
      "name": "My First Mind Map",
      "rootNodeId": "unique-root-node-id",
      "nodes": [
        {
          "id": "unique-root-node-id",
          "parentId": "",
          "title": "Main Topic",
          "content": "This is the central idea.",
          "x": 4000.0,
          "y": 4000.0,
          "color": 4282228196,
          "shape": "roundedRectangle"
        }
      ]
    }
  ]
}''';
  }

  Future<String?> importFromJson() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final json = jsonDecode(content);

        _collection = MindMapCollection.fromJson(json);
        _activeMapId = _collection.maps.isNotEmpty ? _collection.maps.first.id : null;
        _selectedNodeId = null;

        notifyListeners();
        return null; // Success
      }
    } catch (e) {
      return "Error importing file: ${e.toString()}";
    }
    return "Import cancelled.";
  }

  Future<String?> importFromPastedJson(String content) async {
    try {
      final json = jsonDecode(content);
      _collection = MindMapCollection.fromJson(json);
      _activeMapId = _collection.maps.isNotEmpty ? _collection.maps.first.id : null;
      _selectedNodeId = null;

      notifyListeners();
      return null; // Success
    } catch (e) {
      return "Invalid JSON format: ${e.toString()}";
    }
  }

  Future<String?> exportToJson() async {
    try {
      final jsonString = jsonEncode(_collection.toJson());

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Please select an output file:',
        fileName: 'mindmap_export.json',
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(jsonString);
        return "Exported successfully to $outputFile";
      }
    } catch (e) {
      return "Error exporting file: ${e.toString()}";
    }
    return "Export cancelled.";
  }
}

// ===========================================================================
// 3. MAIN APPLICATION WIDGET
// ===========================================================================

void main() {
  runApp(const MindMapApp());
}

class MindMapApp extends StatelessWidget {
  const MindMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MindMapController(),
      child: Consumer<MindMapController>(
        builder: (context, controller, child) {
          return MaterialApp(
            title: 'Flutter Mind Map',
            theme: ThemeData.light(useMaterial3: true),
            darkTheme: ThemeData.dark(useMaterial3: true),
            themeMode: controller.themeMode,
            debugShowCheckedModeBanner: false,
            home: const MindMapScreen(),
          );
        },
      ),
    );
  }
}

// ===========================================================================
// 4. UI - MAIN SCREEN
// ===========================================================================

class MindMapScreen extends StatefulWidget {
  const MindMapScreen({super.key});

  @override
  State<MindMapScreen> createState() => _MindMapScreenState();
}

class _MindMapScreenState extends State<MindMapScreen> {
  final TransformationController _transformationController = TransformationController();
  final GlobalKey _canvasKey = GlobalKey();
  static const double canvasSize = 8000.0;

  @override
  void initState() {
    super.initState();
    // Center the view on our large canvas when the app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;

      _transformationController.value = Matrix4.identity()
        ..translate(
          -(canvasSize / 2) + (screenWidth / 2),
          -(canvasSize / 2) + (screenHeight / 2),
        );
    });
  }

  Future<void> _exportToPdf() async {
    try {
      final boundary = _canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      final pdf = pw.Document();
      final pdfImage = pw.MemoryImage(pngBytes);

      pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(pdfImage),
            );
          }));

      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to export PDF: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MindMapController>();
    final activeMap = controller.activeMap;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(activeMap?.name ?? 'Mind Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Map',
            onPressed: () => controller.createNewMap(),
          ),
          IconButton(
            icon: const Icon(Icons.device_hub),
            tooltip: 'Horizontal Layout',
            onPressed: () => controller.applyTreeLayout(isVertical: false),
          ),
          IconButton(
            icon: const Icon(Icons.call_split),
            tooltip: 'Vertical Layout',
            onPressed: () => controller.applyTreeLayout(isVertical: true),
          ),
          IconButton(
            icon: const Icon(Icons.import_export),
            tooltip: 'Import / Export JSON',
            onPressed: () => _showImportExportDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export as PDF',
            onPressed: _exportToPdf,
          ),
          IconButton(
            icon: Icon(controller.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Toggle Theme',
            onPressed: () => controller.toggleTheme(),
          ),
        ],
      ),
      drawer: Drawer(child: _buildDrawer(context, controller)),
      body: activeMap == null
          ? const Center(child: Text("Create a new map to get started."))
          : GestureDetector(
              onTap: () => controller.selectNode(null),
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: 0.1,
                maxScale: 4.0,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                child: RepaintBoundary(
                  key: _canvasKey,
                  child: Stack(
                    children: [
                      // Large background container to define canvas size
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Container(
                          width: canvasSize,
                          height: canvasSize,
                          color: theme.scaffoldBackgroundColor,
                        ),
                      ),
                      // Connections Painter
                      CustomPaint(
                        painter: ConnectionsPainter(
                          nodes: activeMap.nodes,
                          selectedNodeId: controller.selectedNodeId,
                          theme: theme,
                        ),
                        size: const Size(canvasSize, canvasSize),
                      ),
                      // Node Widgets
                      ...activeMap.nodes.map((node) => NodeWidget(
                            key: ValueKey(node.id),
                            node: node,
                            isSelected: controller.selectedNodeId == node.id,
                          )),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildDrawer(BuildContext context, MindMapController controller) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
          ),
          child: Text(
            'My Mind Maps',
            style: TextStyle(color: Colors.white, fontSize: 24),
          ),
        ),
        for (var map in controller.collection.maps)
          ListTile(
            title: Text(map.name),
            selected: map.id == controller.activeMapId,
            onTap: () {
              controller.switchActiveMap(map.id);
              Navigator.pop(context);
            },
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                if (controller.collection.maps.length > 1) {
                  controller.deleteMap(map.id);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Cannot delete the last map."),
                  ));
                }
              },
            ),
          ),
      ],
    );
  }
}

// ===========================================================================
// 5. UI - NODE AND CONNECTION WIDGETS
// ===========================================================================

class NodeWidget extends StatefulWidget {
  final NodeData node;
  final bool isSelected;

  const NodeWidget({super.key, required this.node, required this.isSelected});

  @override
  State<NodeWidget> createState() => _NodeWidgetState();
}

class _NodeWidgetState extends State<NodeWidget> {
  final GlobalKey _widgetKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateSize());
  }

  @override
  void didUpdateWidget(covariant NodeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.node.title != oldWidget.node.title || widget.node.content != oldWidget.node.content) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateSize());
    }
  }

  void _updateSize() {
    final context = _widgetKey.currentContext;
    if (context != null) {
      final size = context.size;
      if (size != null) {
        context.read<MindMapController>().updateNodeSize(widget.node.id, size);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.read<MindMapController>();
    final theme = Theme.of(context);

    // Determine text color based on background color luminance
    final textColor = widget.node.color.computeLuminance() > 0.5 ? Colors.black : Colors.white;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      left: widget.node.position.dx,
      top: widget.node.position.dy,
      child: GestureDetector(
        onPanUpdate: (details) => controller.updateNodePosition(widget.node.id, details.delta),
        onTap: () => controller.selectNode(widget.node.id),
        onLongPress: () => _showActionModal(context, widget.node),
        child: Container(
          key: _widgetKey,
          constraints: const BoxConstraints(minWidth: 120, maxWidth: 220),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.node.color,
            borderRadius: widget.node.shape == NodeShape.roundedRectangle ? BorderRadius.circular(12) : BorderRadius.zero,
            border: Border.all(
              color: widget.isSelected ? theme.primaryColor : Colors.black45,
              width: widget.isSelected ? 3 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.node.title,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: textColor),
              ),
              if (widget.node.content.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  widget.node.content,
                  style: theme.textTheme.bodySmall?.copyWith(color: textColor.withOpacity(0.8)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ConnectionsPainter extends CustomPainter {
  final List<NodeData> nodes;
  final String? selectedNodeId;
  final ThemeData theme;

  ConnectionsPainter({required this.nodes, required this.selectedNodeId, required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final selectedPaint = Paint()
      ..color = theme.primaryColor
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    for (var node in nodes) {
      if (node.parentId.isNotEmpty) {
        final parent = nodes.firstWhere((p) => p.id == node.parentId, orElse: () => node);
        if (parent.id != node.id) {
          final startPoint = parent.position + Offset(parent.size.width / 2, parent.size.height / 2);
          final endPoint = node.position + Offset(node.size.width / 2, node.size.height / 2);

          bool isSelectedPath = selectedNodeId == node.id || selectedNodeId == parent.id;

          final path = Path();
          path.moveTo(startPoint.dx, startPoint.dy);
          path.cubicTo(
            startPoint.dx + 50, startPoint.dy, // Control point 1
            endPoint.dx - 50, endPoint.dy, // Control point 2
            endPoint.dx, endPoint.dy, // End point
          );

          paint.color = theme.brightness == Brightness.dark ? Colors.grey.shade600 : Colors.grey.shade400;
          canvas.drawPath(path, isSelectedPath ? selectedPaint : paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ===========================================================================
// 6. UI - DIALOGS AND MODALS
// ===========================================================================

// --- Action Modal (from long press) ---
void _showActionModal(BuildContext context, NodeData node) {
  final controller = context.read<MindMapController>();
  final isRoot = controller.activeMap?.rootNodeId == node.id;

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, anim1, anim2) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(node.title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.add_circle_outline),
                  title: const Text('Add Child Node'),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditNodeDialog(context, parentId: node.id);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit Node'),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditNodeDialog(context, nodeToEdit: node);
                  },
                ),
                if (!isRoot)
                  ListTile(
                    leading: Icon(Icons.delete, color: Colors.red.shade400),
                    title: Text('Delete Node', style: TextStyle(color: Colors.red.shade400)),
                    onTap: () {
                      controller.deleteNode(node.id);
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

// --- Node Editor Dialog ---
void _showEditNodeDialog(BuildContext context, {String? parentId, NodeData? nodeToEdit}) {
  final controller = context.read<MindMapController>();
  final isEditing = nodeToEdit != null;
  final _titleController = TextEditingController(text: nodeToEdit?.title ?? '');
  final _contentController = TextEditingController(text: nodeToEdit?.content ?? '');
  Color _currentColor = nodeToEdit?.color ?? Colors.blue.shade200;
  NodeShape _currentShape = nodeToEdit?.shape ?? NodeShape.roundedRectangle;

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(isEditing ? 'Edit Node' : 'Add New Node'),
        content: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _contentController,
                    decoration: const InputDecoration(labelText: 'Content (Optional)', border: OutlineInputBorder()),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<NodeShape>(
                    value: _currentShape,
                    decoration: const InputDecoration(labelText: 'Shape', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: NodeShape.rectangle, child: Text('Rectangle')),
                      DropdownMenuItem(value: NodeShape.roundedRectangle, child: Text('Rounded Rectangle')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _currentShape = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Node Color'),
                    trailing: Container(width: 30, height: 30, color: _currentColor),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Pick a color'),
                          content: SingleChildScrollView(
                            child: ColorPicker(
                              pickerColor: _currentColor,
                              onColorChanged: (color) => setState(() => _currentColor = color),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Done'),
                            )
                          ],
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (_titleController.text.isNotEmpty) {
                if (isEditing) {
                  nodeToEdit.title = _titleController.text;
                  nodeToEdit.content = _contentController.text;
                  nodeToEdit.color = _currentColor;
                  nodeToEdit.shape = _currentShape;
                  controller.updateNode(nodeToEdit);
                } else {
                  controller.addNode(
                    parentId: parentId,
                    title: _titleController.text,
                  );
                  final newNode = controller.activeMap!.nodes.last;
                  newNode.content = _contentController.text;
                  newNode.color = _currentColor;
                  newNode.shape = _currentShape;
                  controller.updateNode(newNode);
                }
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
}

// --- Import/Export Dialog ---
void _showImportExportDialog(BuildContext context) {
  final controller = context.read<MindMapController>();
  final jsonTextController = TextEditingController();

  showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Import / Export JSON'),
          content: DefaultTabController(
              length: 2,
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const TabBar(tabs: [Tab(text: 'Import'), Tab(text: 'Export')]),
                    SizedBox(
                      height: 350,
                      child: TabBarView(
                        children: [
                          // Import Tab
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.file_upload),
                                  label: const Text('Import from File'),
                                  onPressed: () async {
                                    final result = await controller.importFromJson();
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result ?? 'Import successful!')));
                                    }
                                  },
                                ),
                                const SizedBox(height: 16),
                                const Text('Or paste JSON content here:'),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: jsonTextController,
                                  maxLines: 5,
                                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Paste JSON...'),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  child: const Text('Import from Text'),
                                  onPressed: () async {
                                    final result = await controller.importFromPastedJson(jsonTextController.text);
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result ?? 'Import successful!')));
                                    }
                                  },
                                )
                              ],
                            ),
                          ),
                          // Export Tab
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.file_download),
                                  label: const Text('Export to JSON File'),
                                  onPressed: () async {
                                    final result = await controller.exportToJson();
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result ?? 'Export successful!')));
                                    }
                                  },
                                ),
                                const SizedBox(height: 24),
                                const Text('JSON Format:', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  color: Theme.of(context).colorScheme.surfaceVariant,
                                  child: SelectableText(controller.getJsonFormatSample(), style: const TextStyle(fontFamily: 'monospace', fontSize: 10)),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        );
      });
}
