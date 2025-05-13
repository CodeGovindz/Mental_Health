import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VideoQuestionnairePage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback toggleTheme;

  const VideoQuestionnairePage({
    super.key,
    required this.isDarkMode,
    required this.toggleTheme,
  });

  @override
  State<VideoQuestionnairePage> createState() => _VideoQuestionnairePageState();
}

class _VideoQuestionnairePageState extends State<VideoQuestionnairePage> {
  List<String> questions = [
    "How are you feeling today?",
    "Can you describe your current mood?",
    "What made you feel this way?",
  ];

  int currentIndex = 0;
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  Timer? _timer;
  List<File> capturedImages = [];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      _controller = CameraController(frontCamera, ResolutionPreset.medium);
      await _controller!.initialize();
      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Camera permission is required.")),
      );
    }
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() => _isRecording = true);

    _timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final path = await _takePicture();
        if (path != null) {
          capturedImages.add(File(path));
        }
      } catch (e) {
        debugPrint("Capture error: $e");
      }
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    setState(() => _isRecording = false);

    final question = questions[currentIndex].replaceAll(" ", "_");
    final timestamp = DateTime.now().toIso8601String().replaceAll(":", "-");
    final folderName = "$question-$timestamp";

    await _uploadImagesToSupabase(folderName, capturedImages);

    capturedImages.clear();
    setState(() => currentIndex++);
  }

  Future<String?> _takePicture() async {
    if (!_controller!.value.isInitialized) return null;

    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final filePath = p.join(directory.path, 'image_$timestamp.jpg');

    try {
      await _controller!.takePicture().then((XFile file) async {
        final savedImage = await File(file.path).copy(filePath);
        return savedImage.path;
      });
      return filePath;
    } catch (e) {
      debugPrint("Take picture failed: $e");
      return null;
    }
  }

  Future<void> _uploadImagesToSupabase(
    String folderName,
    List<File> files,
  ) async {
    final supabase = Supabase.instance.client;

    for (var file in files) {
      final fileName = p.basename(file.path);
      final storagePath = '$folderName/$fileName';

      try {
        await supabase.storage
            .from('interview-images') // your bucket name
            .upload(storagePath, file);
      } catch (e) {
        debugPrint('Upload failed for $fileName: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Upload failed for $fileName")));
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Images uploaded successfully.")),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLastQuestion = currentIndex >= questions.length;
    final themeColor = widget.isDarkMode ? Colors.black : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: themeColor,
      appBar: AppBar(
        title: const Text("Mental Health Interview"),
        actions: [
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder:
                  (child, animation) =>
                      RotationTransition(turns: animation, child: child),
              child:
                  widget.isDarkMode
                      ? const Icon(Icons.dark_mode, key: ValueKey('dark'))
                      : const Icon(Icons.wb_sunny, key: ValueKey('light')),
            ),
            onPressed: widget.toggleTheme,
          ),
        ],
      ),
      body:
          _isCameraInitialized
              ? Column(
                children: [
                  if (!isLastQuestion)
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  widget.isDarkMode
                                      ? Colors.grey[800]
                                      : Colors.green[100],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              questions[currentIndex],
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                            ),
                          ),
                          Expanded(child: CameraPreview(_controller!)),
                        ],
                      ),
                    )
                  else
                    Expanded(
                      child: Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.analytics),
                          label: const Text("View Result"),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(200, 50),
                            backgroundColor: Colors.teal,
                          ),
                          onPressed: () {
                            // Navigator.push(context, MaterialPageRoute(
                            //   builder: (_) => const ResultPage(),
                            // ));
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (!isLastQuestion)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton.icon(
                        icon: Icon(
                          _isRecording ? Icons.stop : Icons.fiber_manual_record,
                        ),
                        label: Text(
                          _isRecording ? "Stop Recording" : "Start Recording",
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isRecording ? Colors.red : Colors.green,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        onPressed:
                            _isRecording ? _stopRecording : _startRecording,
                      ),
                    ),
                ],
              )
              : const Center(child: CircularProgressIndicator()),
    );
  }
}
