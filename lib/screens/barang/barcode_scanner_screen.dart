import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  // Optimasi: Matikan deteksi otomatis sampai kamera benar-benar siap
  late MobileScannerController cameraController;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    cameraController = MobileScannerController(
      // Low-End Fix: Kurangi resolusi deteksi agar CPU tidak panas
      detectionSpeed: DetectionSpeed.normal, 
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture barcodeCapture) {
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = barcodeCapture.barcodes;
    if (barcodes.isNotEmpty) {
      final String code = barcodes.first.rawValue ?? '';
      if (code.isNotEmpty) {
        _isProcessing = true;
        // Gunakan Future.microtask agar pop tidak mengganggu frame kamera
        Future.microtask(() => Navigator.pop(context, code));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // AppBar simpel tanpa elevasi
      appBar: AppBar(
        title: const Text('Scan Barcode', style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, size: 20),
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch, size: 20),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Scanner Utama
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),
          
          // 2. Overlay Low-End (Tanpa CustomPainter/Canvas)
          // Menggunakan Container biasa jauh lebih ringan daripada menghitung Path.combine
          _buildLowEndOverlay(),

          // 3. Instruksi Minimalis
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 50),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Arahkan ke Barcode',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Pengganti CustomPainter: Lebih ramah RAM & GPU
  Widget _buildLowEndOverlay() {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            color: Colors.transparent,
            // Border tipis saja tanpa efek glow/blur
            border: Border.all(color: Colors.green, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}