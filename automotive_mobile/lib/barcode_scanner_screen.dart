import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final String title;
  final String hint;
  const BarcodeScannerScreen({
    super.key,
    String? title,
    String? hint,
  }) : title = title ?? 'Scan Barcode / QR Code',
       hint = hint ?? 'Point camera at barcode or QR code';

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  static const _red = Color(0xFFE8001C);
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: _red,
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_scanned) return;
              final barcode = capture.barcodes.firstOrNull;
              if (barcode?.rawValue != null) {
                _scanned = true;
                Navigator.pop(context, barcode!.rawValue);
              }
            },
          ),
          // Scan overlay
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: _red, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(children: [
                // Corner decorations
                Positioned(top: 0, left: 0, child: _corner()),
                Positioned(top: 0, right: 0, child: Transform.rotate(angle: 1.5708, child: _corner())),
                Positioned(bottom: 0, left: 0, child: Transform.rotate(angle: -1.5708, child: _corner())),
                Positioned(bottom: 0, right: 0, child: Transform.rotate(angle: 3.1416, child: _corner())),
              ]),
            ),
          ),
          // Hint text
          Positioned(
            bottom: 80,
            left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                child: Text(widget.hint,
                  style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _corner() {
    return Container(
      width: 24, height: 24,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _red, width: 4), left: BorderSide(color: _red, width: 4)),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(4)),
      ),
    );
  }
}
