import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:open_filex/open_filex.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const ExamToPdfApp());
}

class ExamToPdfApp extends StatelessWidget {
  const ExamToPdfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Exam to PDF',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String extractedText = '';
  String translatedText = '';
  String targetLang = 'en'; // default English

  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  late OnDeviceTranslator translatorHiToEn;
  late OnDeviceTranslator translatorEnToHi;

  @override
  void initState() {
    super.initState();
    translatorHiToEn = OnDeviceTranslator(
        sourceLanguage: TranslateLanguage.hindi,
        targetLanguage: TranslateLanguage.english);
    translatorEnToHi = OnDeviceTranslator(
        sourceLanguage: TranslateLanguage.english,
        targetLanguage: TranslateLanguage.hindi);
  }

  @override
  void dispose() {
    translatorHiToEn.close();
    translatorEnToHi.close();
    textRecognizer.close();
    super.dispose();
  }

  Future<void> pickAndRecognizeText() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      final path = result.files.single.path!;
      final inputImage = InputImage.fromFilePath(path);
      final recognized = await textRecognizer.processImage(inputImage);

      setState(() {
        extractedText = recognized.text;
        translatedText = '';
      });
    }
  }

  Future<void> translateText() async {
    if (extractedText.isEmpty) return;

    if (targetLang == 'en') {
      translatedText = await translatorHiToEn.translateText(extractedText);
    } else {
      translatedText = await translatorEnToHi.translateText(extractedText);
    }

    setState(() {});
  }

  Future<void> generatePdf() async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.courierPrimeRegular();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(translatedText.isNotEmpty ? translatedText : extractedText,
              style: pw.TextStyle(font: font, fontSize: 14))
        ],
      ),
    );

    final dir = await getExternalStorageDirectory();
    final file = File('${dir!.path}/exam_output.pdf');
    await file.writeAsBytes(await pdf.save());

    await OpenFilex.open(file.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exam to Typed PDF')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: pickAndRecognizeText,
                icon: const Icon(Icons.image),
                label: const Text("📷 Pick Exam Paper Image"),
              ),
              const SizedBox(height: 12),
              Text("Extracted Text:", style: Theme.of(context).textTheme.titleLarge),
              Text(extractedText),
              const Divider(),
              DropdownButton<String>(
                value: targetLang,
                items: const [
                  DropdownMenuItem(value: 'en', child: Text("Translate to English")),
                  DropdownMenuItem(value: 'hi', child: Text("Translate to Hindi")),
                ],
                onChanged: (val) {
                  setState(() => targetLang = val!);
                },
              ),
              ElevatedButton.icon(
                onPressed: translateText,
                icon: const Icon(Icons.translate),
                label: const Text("🌐 Translate"),
              ),
              const SizedBox(height: 12),
              Text("Translated Text:", style: Theme.of(context).textTheme.titleLarge),
              Text(translatedText),
              const Divider(),
              ElevatedButton.icon(
                onPressed: generatePdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text("📝 Generate PDF (Typewriter Style)"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
