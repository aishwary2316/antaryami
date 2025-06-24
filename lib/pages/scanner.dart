import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';

class ScanCodePage extends StatefulWidget {
  const ScanCodePage({super.key});

  @override
  State<ScanCodePage> createState() => _ScanCodePageState();
}

class _ScanCodePageState extends State<ScanCodePage> with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _animationController;
  final ImagePicker _picker = ImagePicker();
  double _zoom = 0.0;
  bool isFlashOn = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      returnImage: true,
      autoZoom: true, // automatic zooming on detection
      facing: CameraFacing.back,
    );
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> toggleFlash() async {
    await _controller.toggleTorch();
    setState(() {
      isFlashOn = !isFlashOn;
    });
  }

  Future<void> _pickImageAndScan() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final result = await _controller.analyzeImage(pickedFile.path);
      if (result != null && result.barcodes.isNotEmpty) {
        final scannedValue = result.barcodes.first.rawValue ?? "No value found";
        await _showResultDialog(scannedValue, File(pickedFile.path));
      } else {
        _showMessage("No QR code/barcode detected in the selected image.");
      }
    }
  }

  Future<void> _showResultDialog(String scannedValue, [File? imageFile]) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Scan Result"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageFile != null) Image.file(imageFile, height: 200),
            Text(scannedValue),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _controller.start(); // reset scanner
            },
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(scannedValue);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleBarcodeDetection(BarcodeCapture capture) async {
    final barcodes = capture.barcodes;
    final image = capture.image;
    if (barcodes.isNotEmpty && image != null) {
      final scannedValue = barcodes.first.rawValue ?? "";
      await _showResultDialog(scannedValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scanner"),
        actions: [
          IconButton(
            onPressed: _pickImageAndScan,
            icon: const Icon(Icons.photo_library),
          ),
          IconButton(
            onPressed: toggleFlash,
            icon: Icon(isFlashOn ? Icons.flashlight_on_outlined : Icons.flashlight_off_outlined),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: GestureDetector(
        onScaleUpdate: (details) {
          _zoom += details.scale - 1;
          _zoom = _zoom.clamp(0.0, 1.0);
          _controller.setZoomScale(_zoom);
        },
        child: Stack(
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _handleBarcodeDetection,
            ),
            _buildFrostedOverlay(), // Optional, for blur/tint/glowing corners
          ],
        ),
      ),
    );
  }

  Widget _buildFrostedOverlay() {
    final double scanBoxSize = MediaQuery.of(context).size.width * 0.8;
    return Stack(
      children: [
        Positioned.fill(
          child: ClipPath(
            clipper: _HoleClipper(scanBoxSize),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withAlpha(100),
              ),
            ),
          ),
        ),
        _buildCorners(scanBoxSize),
        Center(
          child: SizedBox(
            width: scanBoxSize,
            height: scanBoxSize,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _ScannerLinePainter(_animationController.value),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCorners(double size) {
    const double cornerSize = 50;
    const double strokeWidth = 7;
    const Color glowColor = Colors.cyanAccent;

    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            _corner(Alignment.topLeft, cornerSize, strokeWidth, glowColor),
            _corner(Alignment.topRight, cornerSize, strokeWidth, glowColor),
            _corner(Alignment.bottomLeft, cornerSize, strokeWidth, glowColor),
            _corner(Alignment.bottomRight, cornerSize, strokeWidth, glowColor),
          ],
        ),
      ),
    );
  }

  Widget _corner(Alignment alignment, double size, double strokeWidth, Color color) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border(
            top: alignment.y < 0 ? BorderSide(color: color, width: strokeWidth) : BorderSide.none,
            bottom: alignment.y > 0 ? BorderSide(color: color, width: strokeWidth) : BorderSide.none,
            left: alignment.x < 0 ? BorderSide(color: color, width: strokeWidth) : BorderSide.none,
            right: alignment.x > 0 ? BorderSide(color: color, width: strokeWidth) : BorderSide.none,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(180),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _HoleClipper extends CustomClipper<Path> {
  final double scanBoxSize;
  _HoleClipper(this.scanBoxSize);

  @override
  Path getClip(Size size) {
    final fullRect = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final hole = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: scanBoxSize,
      height: scanBoxSize,
    );
    return Path.combine(PathOperation.difference, fullRect, Path()..addRect(hole));
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
class _ScannerLinePainter extends CustomPainter {
  final double progress;
  _ScannerLinePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 5;

    final y = size.height * progress;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
