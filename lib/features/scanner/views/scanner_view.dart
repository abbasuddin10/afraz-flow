import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/feedback.dart';

/// A shared scanner used by POS and Inventory.
///
/// Pops with the scanned code as a `String` result. Camera capture is used on
/// Android, iOS, macOS and the web; Windows and Linux fall back to an explicit
/// manual-entry panel because the scanner plugin has no camera backend there.
class ScannerView extends StatefulWidget {
  const ScannerView({super.key});

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView> {
  MobileScannerController? _controller;
  final TextEditingController _manual = TextEditingController();
  final FocusNode _manualFocus = FocusNode();

  bool _handled = false;
  String? _lastError;

  bool get _cameraSupported {
    if (kIsWeb) return true;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS => true,
      _ => false,
    };
  }

  @override
  void initState() {
    super.initState();
    if (_cameraSupported) {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: [BarcodeFormat.all],
        autoStart: true,
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _manual.dispose();
    _manualFocus.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        _submit(value);
        return;
      }
    }
  }

  Future<void> _submit(String value) async {
    final code = value.trim();
    if (code.isEmpty) {
      showAppMessage('Enter or scan a code first.', error: true);
      return;
    }
    if (_handled) return;
    _handled = true;
    try {
      await _controller?.stop();
    } catch (_) {
      // The camera may already be stopped or unavailable.
    }
    if (!mounted) return;
    Get.back<String>(result: code);
  }

  Future<void> _enterManually() async {
    final code = await showDialog<String>(
      context: context,
      builder: (context) => _ManualCodeDialog(initial: _manual.text),
    );
    if (code != null && code.trim().isNotEmpty) {
      await _submit(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan a code'.tr),
        actions: [
          if (_cameraSupported && _controller != null) ...[
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller!,
              builder: (context, state, _) {
                final torchOn = state.torchState == TorchState.on;
                return IconButton(
                  tooltip: torchOn ? 'Turn torch off' : 'Turn torch on',
                  onPressed: state.torchState == TorchState.unavailable
                      ? null
                      : () => _controller!.toggleTorch(),
                  icon: Icon(
                    torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  ),
                );
              },
            ),
            IconButton(
              tooltip: 'Switch camera',
              onPressed: () => _controller!.switchCamera(),
              icon: const Icon(Icons.cameraswitch_outlined),
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: _cameraSupported && _controller != null
          ? _buildCameraBody()
          : _buildManualBody(),
    );
  }

  Widget _buildCameraBody() {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, error) {
            _lastError = error.errorDetails?.message;
            return _buildCameraError();
          },
        ),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x99000000),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0xCC000000),
                ],
                stops: [0, 0.22, 0.62, 1],
              ),
            ),
          ),
        ),
        Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxSize = constraints.biggest.shortestSide;
              final size = (maxSize * 0.7).clamp(200.0, 320.0);
              return _ScanFrame(size: size);
            },
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Point the camera at a barcode or QR code',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Product SKUs, invoice codes and courier tracking numbers.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _enterManually,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    icon: const Icon(Icons.keyboard_alt_outlined, size: 18),
                    label: Text('Enter code manually'.tr),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraError() {
    return ColoredBox(
      color: AppColors.navyDeep,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.no_photography_outlined,
                  color: AppColors.amber,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Camera unavailable',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _lastError?.isNotEmpty == true
                    ? _lastError!
                    : 'Allow camera access for Afraz Flow in your device '
                          'settings, or enter the code manually to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _enterManually,
                icon: const Icon(Icons.keyboard_alt_outlined, size: 18),
                label: Text('Enter code manually'.tr),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManualBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AppCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: AppColors.teal,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manual code entry',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            'Camera scanning is available on Android, iOS, '
                            'macOS and the web.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _manual,
                  focusNode: _manualFocus,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _submit,
                  decoration: const InputDecoration(
                    labelText: 'Barcode, SKU or tracking number',
                    prefixIcon: Icon(Icons.tag_rounded, size: 20),
                    hintText: 'e.g. 8901234567890',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _submit(_manual.text),
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: Text('Use this code'.tr),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tip: a USB barcode scanner types the code and presses Enter, '
                  'so you can scan straight into this field.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
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

class _ManualCodeDialog extends StatefulWidget {
  const _ManualCodeDialog({this.initial = ''});

  final String initial;

  @override
  State<_ManualCodeDialog> createState() => _ManualCodeDialogState();
}

class _ManualCodeDialogState extends State<_ManualCodeDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(
        Icons.keyboard_alt_outlined,
        color: AppColors.teal,
        size: 30,
      ),
      title: Text('Enter a code'.tr),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(
          labelText: 'Barcode, SKU or tracking number',
          prefixIcon: Icon(Icons.tag_rounded, size: 20),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'.tr),
        ),
        FilledButton(onPressed: _submit, child: Text('Use code'.tr)),
      ],
    );
  }
}

/// A rounded viewfinder with corner accents and a gently travelling scan line.
class _ScanFrame extends StatefulWidget {
  const _ScanFrame({required this.size});

  final double size;

  @override
  State<_ScanFrame> createState() => _ScanFrameState();
}

class _ScanFrameState extends State<_ScanFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _FramePainter()),
          ),
          AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              final top = 14 + (widget.size - 28) * _animation.value;
              return Positioned(
                top: top,
                left: 16,
                right: 16,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.teal.withValues(alpha: 0),
                        AppColors.teal,
                        AppColors.teal.withValues(alpha: 0),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.teal.withValues(alpha: 0.5),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final frame = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final corner = Paint()
      ..color = AppColors.teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(22),
    );
    canvas.drawRRect(rect, frame);

    const length = 26.0;
    final r = rect.outerRect;
    final path = Path()
      ..moveTo(r.left, r.top + length)
      ..lineTo(r.left, r.top + 6)
      ..quadraticBezierTo(r.left, r.top, r.left + 6, r.top)
      ..lineTo(r.left + length, r.top)
      ..moveTo(r.right - length, r.top)
      ..lineTo(r.right - 6, r.top)
      ..quadraticBezierTo(r.right, r.top, r.right, r.top + 6)
      ..lineTo(r.right, r.top + length)
      ..moveTo(r.right, r.bottom - length)
      ..lineTo(r.right, r.bottom - 6)
      ..quadraticBezierTo(r.right, r.bottom, r.right - 6, r.bottom)
      ..lineTo(r.right - length, r.bottom)
      ..moveTo(r.left + length, r.bottom)
      ..lineTo(r.left + 6, r.bottom)
      ..quadraticBezierTo(r.left, r.bottom, r.left, r.bottom - 6)
      ..lineTo(r.left, r.bottom - length);

    canvas.drawPath(path, corner);
  }

  @override
  bool shouldRepaint(covariant _FramePainter oldDelegate) => false;
}
