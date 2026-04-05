import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/customer_id.dart';
import '../providers/id_provider.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

class IDScannerScreen extends StatefulWidget {
  const IDScannerScreen({super.key});

  @override
  State<IDScannerScreen> createState() => _IDScannerScreenState();
}

class _IDScannerScreenState extends State<IDScannerScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitializing = true;
  bool _isCapturing = false;
  bool _isAnalyzing = false;

  String? _frontFilePath;
  String? _backFilePath;

  bool _isFrontScan = true; // Phase 1: Front, Phase 2: Back
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  DateTime? _extractedBirthDate;

  bool _showForm = true; // First collect name/surname or SKIP to scan

  int _countdown = 3;
  Timer? _countdownTimer;
  bool _isAutoCapturing = false;

  final TextRecognizer _textRecognizer = TextRecognizer();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      _controller = CameraController(
        _cameras![0],
        ResolutionPreset.high,
        enableAudio: false,
      );

      try {
        await _controller!.initialize();
        if (mounted) {
          setState(() => _isInitializing = false);
          _startCountdown();
        }
      } catch (e) {
        print("Camera init error: $e");
      }
    }
  }

  void _startCountdown() {
    setState(() {
      _isAutoCapturing = true;
      _countdown = 3;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (_countdown > 1) {
          setState(() => _countdown--);
        } else {
          timer.cancel();
          _capture();
        }
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _controller?.dispose();
    _nameController.dispose();
    _surnameController.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing)
      return;

    setState(() {
      _isCapturing = true;
      _isAutoCapturing = false;
    });

    try {
      final XFile photo = await _controller!.takePicture();
      final directory = await getApplicationDocumentsDirectory();
      final String fileName = '${const Uuid().v4()}.jpg';
      final String path = '${directory.path}/$fileName';
      await photo.saveTo(path);

      if (mounted) {
        if (_isFrontScan) {
          _frontFilePath = path;
          await _analyzeImage(path);
        } else {
          _backFilePath = path;
        }

        setState(() {
          _isCapturing = false;
          _showConfirmationDialog(path);
        });
      }
    } catch (e) {
      print("Capture error: $e");
      setState(() => _isCapturing = false);
    }
  }

  DateTime? _parseDate(String dobStr) {
    try {
      DateFormat format = DateFormat("dd.MM.yyyy");
      // Replace any common OCR errors like / or - with .
      dobStr = dobStr.replaceAll('/', '.').replaceAll('-', '.');
      return format.parse(dobStr);
    } catch (e) {
      print("Date Parse error: $e");
      return null;
    }
  }

  Future<void> _analyzeImage(String path) async {
    setState(() => _isAnalyzing = true);

    try {
      final inputImage = InputImage.fromFilePath(path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      String text = recognizedText.text;
      print("Scanned text: $text");

      // Turkish ID Parsing Logic (Simplified Example)
      // Look for Surname, Name, Birth Date patterns
      // Typically:
      // Soyadı / Surname
      // [SURNAME]
      // Adı / Given Name(s)
      // [NAME]
      // Doğum Tarihi / Date of Birth
      // DD.MM.YYYY

      List<String> lines = text.split('\n');
      for (int i = 0; i < lines.length; i++) {
        String line = lines[i].trim().toUpperCase();
        String cleanLine = line
            .replaceAll('İ', 'I')
            .replaceAll('Ğ', 'G')
            .replaceAll('Ş', 'S')
            .replaceAll('Ç', 'C')
            .replaceAll('Ö', 'O')
            .replaceAll('Ü', 'U');

        // 1. Doğum Tarihi (DD.MM.YYYY)
        final dobRegex = RegExp(
          r"(\d{2})[\.\/\-\s,]{1,2}(\d{2})[\.\/\-\s,]{1,2}(\d{4})",
        );
        if (cleanLine.contains("DOGUM") ||
            cleanLine.contains("BIRTH") ||
            cleanLine.contains("DATE OF")) {
          for (int j = 0; j <= 2; j++) {
            if (i + j < lines.length) {
              String targetLine = lines[i + j].trim().toUpperCase();
              if (dobRegex.hasMatch(targetLine)) {
                final match = dobRegex.firstMatch(targetLine);
                String dobMatch = match!.group(0)!;
                dobMatch = dobMatch.replaceAll(RegExp(r"[\.\/\-\s,]+"), ".");
                _extractedBirthDate = _parseDate(dobMatch);
                if (_extractedBirthDate != null) break;
              }
            }
          }
        }

        // 2. Surname
        if (cleanLine.contains("SOYADI") ||
            cleanLine.contains("SURNAME") ||
            cleanLine.contains("SOYAD")) {
          for (int j = 1; j <= 2; j++) {
            if (i + j < lines.length) {
              String potential = lines[i + j].trim().toUpperCase();
              if (potential.length > 2 &&
                  !potential.contains("/") &&
                  !potential.contains(":")) {
                _surnameController.text = potential;
                break;
              }
            }
          }
        }

        // 3. Name
        if (cleanLine.contains("ADI") ||
            cleanLine.contains("GIVEN NAME") ||
            cleanLine.contains("AD /")) {
          for (int j = 1; j <= 2; j++) {
            if (i + j < lines.length) {
              String potential = lines[i + j].trim().toUpperCase();
              if (potential.length > 2 &&
                  !potential.contains("/") &&
                  !potential.contains(":")) {
                _nameController.text = potential;
                break;
              }
            }
          }
        }
      }
      // Fallback: If DOB not found by label, look for ANY reasonable DOB in the entire text
      if (_extractedBirthDate == null) {
        final allDatesRegex = RegExp(
          r"(\d{2})[\.\/\-\s,]{1,2}(\d{2})[\.\/\-\s,]{1,2}(\d{4})",
        );
        final matches = allDatesRegex.allMatches(text);
        for (var match in matches) {
          String dateStr = match
              .group(0)!
              .replaceAll(RegExp(r"[\.\/\-\s,]+"), ".");
          DateTime? parsed = _parseDate(dateStr);
          if (parsed != null) {
            int age = DateTime.now().year - parsed.year;
            if (age >= 7 && age <= 100) {
              _extractedBirthDate = parsed;
              break; // Found a reasonable DOB
            }
          }
        }
      }
    } catch (e) {
      print("Analysis error: $e");
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _showConfirmationDialog(String path) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_isFrontScan ? 'Ön Yüz Onayı' : 'Arka Yüz Onayı'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(path),
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                if (_isFrontScan) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Analiz Edilen Bilgiler:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'İsim',
                      isDense: true,
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  TextField(
                    controller: _surnameController,
                    decoration: const InputDecoration(
                      labelText: 'Soyisim',
                      isDense: true,
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _extractedBirthDate ?? DateTime(2000),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() => _extractedBirthDate = picked);
                        setState(() => _extractedBirthDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.cake_outlined,
                            size: 20,
                            color: AppTheme.ttBlue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _extractedBirthDate != null
                                ? DateFormat(
                                    'dd.MM.yyyy',
                                  ).format(_extractedBirthDate!)
                                : 'Doğum Tarihi Seçilmedi',
                            style: TextStyle(
                              color: _extractedBirthDate != null
                                  ? Colors.black
                                  : Colors.red,
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.edit, size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Fotoğraf net mi? Değilse tekrar çekebilirsiniz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _startCountdown();
              },
              child: const Text('TEKRAR ÇEK'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_isFrontScan &&
                    (_nameController.text.isEmpty ||
                        _surnameController.text.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Lütfen isim ve soyisim bilgilerini doğrulayın.',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(context);
                if (_isFrontScan) {
                  setState(() => _isFrontScan = false);
                  _startCountdown();
                } else {
                  _saveFinalResult();
                }
              },
              child: const Text('DEVAM ET'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveFinalResult() {
    if (_frontFilePath != null && _backFilePath != null) {
      final newID = CustomerID(
        id: const Uuid().v4(),
        name: _nameController.text.toUpperCase(),
        surname: _surnameController.text.toUpperCase(),
        birthDate: _extractedBirthDate,
        frontImagePath: _frontFilePath!,
        backImagePath: _backFilePath!,
        createdAt: DateTime.now(),
      );

      context.read<IDProvider>().addCustomerID(newID);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kimlik başarıyla kaydedildi')),
      );

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showForm) {
      return _buildForm();
    }

    if (_isInitializing || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.ttMagenta),
              SizedBox(height: 20),
              Text(
                'Kamera Hazırlanıyor...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),

          // ID Card Overlay
          CustomPaint(painter: IDOverlayPainter()),

          // Instructions & Countdown
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _isFrontScan
                          ? 'KİMLİĞİN ÖN YÜZÜNÜ ALANIN İÇİNE GETİRİN'
                          : 'KİMLİĞİN ARKA YÜZÜNÜ ALANIN İÇİNE GETİRİN',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                if (_isAutoCapturing)
                  Container(
                    width: 70,
                    height: 70,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.ttMagenta.withOpacity(0.8),
                    ),
                    child: Text(
                      '$_countdown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    children: [
                      if (_isCapturing)
                        const Column(
                          children: [
                            CircularProgressIndicator(
                              color: AppTheme.ttMagenta,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'İşleniyor...',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'İptal',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni Kimlik Kaydı')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Müşteri Bilgileri',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Kimlik bilgilerini manuel girebilir veya doğrudan tarama yaparak otomatik doldurabilirsiniz.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'İsim (Opsiyonel)',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _surnameController,
              decoration: const InputDecoration(
                labelText: 'Soyisim (Opsiyonel)',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() => _showForm = false);
                  _initializeCamera(); // Start camera and countdown here
                },
                icon: const Icon(Icons.camera_alt),
                label: const Text('KİMLİK TARA VE ANALİZ ET'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.ttBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IDOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = Colors.black.withOpacity(0.7);

    // Calculate ID card rect (standard ID ratio is ~1.58)
    const cardRatio = 1.58;
    final cardWidth = size.width * 0.85;
    final cardHeight = cardWidth / cardRatio;

    final cardRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: cardWidth,
      height: cardHeight,
    );

    // Draw background with hole
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(
          RRect.fromRectAndRadius(cardRect, const Radius.circular(20)),
        ),
      ),
      backgroundPaint,
    );

    // Draw card border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(
      RRect.fromRectAndRadius(cardRect, const Radius.circular(20)),
      borderPaint,
    );

    // Draw corner indicators
    final cornerLength = cardWidth * 0.1;
    final cornerPaint = Paint()
      ..color = AppTheme.ttMagenta
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    // Top Left
    canvas.drawPath(
      Path()
        ..moveTo(cardRect.left, cardRect.top + cornerLength)
        ..lineTo(cardRect.left, cardRect.top)
        ..lineTo(cardRect.left + cornerLength, cardRect.top),
      cornerPaint,
    );

    // Top Right
    canvas.drawPath(
      Path()
        ..moveTo(cardRect.right - cornerLength, cardRect.top)
        ..lineTo(cardRect.right, cardRect.top)
        ..lineTo(cardRect.right, cardRect.top + cornerLength),
      cornerPaint,
    );

    // Bottom Left
    canvas.drawPath(
      Path()
        ..moveTo(cardRect.left, cardRect.bottom - cornerLength)
        ..lineTo(cardRect.left, cardRect.bottom)
        ..lineTo(cardRect.left + cornerLength, cardRect.bottom),
      cornerPaint,
    );

    // Bottom Right
    canvas.drawPath(
      Path()
        ..moveTo(cardRect.right - cornerLength, cardRect.bottom)
        ..lineTo(cardRect.right, cardRect.bottom)
        ..lineTo(cardRect.right, cardRect.bottom - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
