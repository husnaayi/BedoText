import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart';

void main() {
    runApp(MaterialApp(
      title: 'BedoText',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.brown),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          return MaterialPageRoute(builder: (_) => HomePage());
        } else if (settings.name == '/highlights') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => HighlightsPage(
              highlightedWords: args['highlightedWords'],
              selectedLanguage: args['selectedLanguage'],
            ),
          );
        } else if (settings.name == '/saved') {
          return MaterialPageRoute(builder: (_) => SavedPage());
        }
        return null;
      },
    ));
  }

  /// Maymun arka planını oluşturur.
Widget buildMonkeyBackground() {
  return Center(
    child: Opacity(
      opacity: 0.1,
      child: Text("\ud83d\udc35", style: TextStyle(fontSize: 80)),
    ),
  );
}

/// Vurgulanan kelimeleri göstermek için kullanılan sayfa.
class HighlightsPage extends StatelessWidget {
  final Map<String, int> highlightedWords;
  final String selectedLanguage;

  HighlightsPage({
    Key? key,
    required this.highlightedWords,
    required this.selectedLanguage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Certain Words', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.brown[700],
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          buildMonkeyBackground(),
          ListView(
            padding: EdgeInsets.all(16),
            children: highlightedWords.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${entry.key}: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 18,
                        ),
                      ),
                      TextSpan(
                        text: '${entry.value} kez',
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Kaydedilen konuşmaları göstermek için kullanılan sayfa.
class SavedPage extends StatefulWidget {
  @override
  _SavedPageState createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  List<Map<String, dynamic>> _savedConversations = [];

  @override
  void initState() {
    super.initState();
    _loadSavedConversations();
  }

  Future<void> _loadSavedConversations() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> saved = prefs.getStringList('saved_conversations') ?? [];

    setState(() {
      _savedConversations = saved.map((item) {
        Map<String, dynamic> parsed = json.decode(item);
        return {
          'text': parsed['text'] ?? '',
          'date': parsed['date'] ?? ''
        };
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Saved Conversations', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.brown[700],
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          buildMonkeyBackground(),
          ListView.builder(
            itemCount: _savedConversations.length,
            itemBuilder: (context, index) {
              final item = _savedConversations[index];
              return ListTile(
                title: Text(item['text'] ?? 'No text available'),
                subtitle: Text(item['date'] ?? 'No date available'),
                trailing: IconButton(
                  icon: Icon(Icons.delete, color: Colors.pink),
                  onPressed: () => _deleteConversation(index),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteConversation(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _savedConversations.removeAt(index);
    List<String> updatedList = _savedConversations.map((item) => json.encode({
      'text': item['text'],
      'date': item['date'],
    })).toList();
    await prefs.setStringList('saved_conversations', updatedList);
    setState(() {});
  }
}
class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _lastRecognizedText = '';
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _selectedLanguage = 'tr_TR';
  String _recognizedText = "";
  final Map<String, int> _highlightedWords = {};
  Map<String, dynamic> _keywords = {};
  // Duygu durumunu saklamak için Map
  Map<String, String> _currentEmotion = {
    'tr_TR': 'Bilinmiyor',
    'en_US': 'Unknown',
  };

  String getMessage(String tr, String en) {
    return _selectedLanguage == 'tr_TR' ? tr : en;
  }


  final EmotionAnalysis _emotionAnalysis = EmotionAnalysis();
  Future<void> _createPdfFromText(BuildContext context) async {
    final pdf = pw.Document();
    String fullText = _lastRecognizedText;

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Text(
              fullText,
              style: pw.TextStyle(fontSize: 16),
            ),
          );
        },
      ),
    );

    try {
      final bytes = await pdf.save();

      if (kIsWeb) {
        // Web: PDF indir
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute("download", "konusma.pdf")
          ..click();
        html.Url.revokeObjectUrl(url);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(getMessage("PDF indirildi.", "PDF downloaded."))),
        );
      } else {
        final outputDir = await getApplicationDocumentsDirectory();
        final file = File("${outputDir.path}/konusma.pdf");
        await file.writeAsBytes(bytes);
        await OpenFile.open(file.path);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(getMessage("PDF oluşturuldu: ${file.path}", "PDF created at: ${file.path}"))),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(getMessage("PDF oluşturulamadı: $e", "Failed to create PDF: $e"))),
      );
    }
  }


  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadKeywords();
  }

  Future<void> _loadKeywords() async {
    String jsonString = await rootBundle.loadString('assets/keywords.json');
    final Map<String, dynamic> data = json.decode(jsonString);
    setState(() {
      _keywords = data;
    });
  }

  void _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          final text = result.recognizedWords;
          setState(() {
            _recognizedText = text;
            _extractHighlights();
            _currentEmotion = _emotionAnalysis.analyzeEmotion(text, _selectedLanguage);
          });
        },
        localeId: _selectedLanguage,
      );
    }
  }

  void _stopListening() async {
    setState(() {
      _isListening = false;
      _lastRecognizedText = _recognizedText;
    });
    await _speech.stop();
    await _saveConversation();
  }


  void _extractHighlights() {
    _highlightedWords.clear();
    String cleanedText = cleanWord(_recognizedText.toLowerCase());
    final List<String> allKeywords = [];
    _keywords.forEach((key, value) {
      for (var item in value) {
        if (_selectedLanguage == 'tr_TR') {
          allKeywords.add(item['tr'].toLowerCase());
        } else if (_selectedLanguage == 'en_US') {
          allKeywords.add(item['en'].toLowerCase());
        }
      }
    });
    for (var keyword in allKeywords) {
      String normalizedKeyword = normalizeWord(cleanWord(keyword));
      int count = 0;
      for (var word in cleanedText.split(' ')) {
        String normalizedWord = normalizeWord(word);
        if (normalizedWord == normalizedKeyword) {
          count++;
        }
      }
      if (count > 0) {
        _highlightedWords[keyword] = count;
      }
    }
  }

  Future<void> _saveConversation() async {
    if (_recognizedText.trim().isEmpty) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> savedConversations = prefs.getStringList('saved_conversations') ?? [];

    Map<String, String> conversation = {
      'text': _recognizedText,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
    };

    savedConversations.add(json.encode(conversation));
    await prefs.setStringList('saved_conversations', savedConversations);
  }

  List<TextSpan> _buildHighlightedText() {
    return _recognizedText.split(' ').map((word) {
      final clean = cleanWord(word);
      bool isHighlighted = false;
      for (var keyword in _highlightedWords.keys) {
        if (normalizeWord(clean) == normalizeWord(cleanWord(keyword))) {
          isHighlighted = true;
          break;
        }
      }
      if (isHighlighted) {
        return TextSpan(
          text: '$word ',
          style: TextStyle(
            decoration: TextDecoration.underline,
            backgroundColor: Colors.pinkAccent.withOpacity(0.3),
            fontWeight: FontWeight.bold,
            color: Colors.pink[800],
          ),
        );
      }
      return TextSpan(text: '$word ');
    }).toList();
  }

  String cleanWord(String word) {
    String cleaned = word.trim().replaceAll(RegExp(r'[^a-zA-ZğüşöçıİĞÜŞÖÇ0-9\s]'), '').replaceAll(RegExp(r'\s+'), ' ');
    return _selectedLanguage == 'tr_TR' ? toBeginningOfSentenceCase(cleaned.toLowerCase())!.toLowerCase() : cleaned.toLowerCase();
  }

  String normalizeWord(String word) {
    word = word.toLowerCase().trim();
    List<String> suffixes = [
      'lerim', 'larım', 'ler', 'lar',
      'imiz', 'ımız', 'unuz', 'ünüz', 'miz', 'nız', 'niz',
      'im', 'ım', 'um', 'üm', 'in', 'ın', 'un', 'ün',
      'yi', 'yı', 'yu', 'yü', 'ye', 'ya',
      'de', 'da', 'te', 'ta', 'den', 'dan', 'ten', 'tan', 'le', 'la',
      'mi', 'mı', 'mu', 'mü',
    ];
    for (var suffix in suffixes) {
      if (word.endsWith(suffix)) {
        word = word.substring(0, word.length - suffix.length);
        break;
      }
    }
    return word;
  }

  // Duygu durumuna göre renk döndüren fonksiyon
  Color _getEmotionColor() {
    String emotion = _currentEmotion[_selectedLanguage] ?? 'Bilinmiyor';
    switch (emotion) {
      case "Mutlu":
      case "Happiness":
        return Colors.green.withOpacity(0.3);
      case "Korku":
      case "Fear":
        return Colors.red.withOpacity(0.3);
      case "Kızgınlık":
      case "Anger":
        return Colors.purple.withOpacity(0.3);
      case "Kaygı":
      case "Anxiety":
        return Colors.orange.withOpacity(0.3);
      case "Heyecanlı":
      case "Excited":
        return Colors.yellow.withOpacity(0.3);
      case "Üzgün":
      case "Upset":
        return Colors.blue.withOpacity(0.3);
      case "Şaşkın":
      case "Shocked":
        return Colors.limeAccent.withOpacity(0.3);
      case "Sıkılmış":
      case "Bored":
        return Colors.grey.withOpacity(0.3);
      case "Yorgun":
      case "Tired":
        return Colors.brown.withOpacity(0.3);
      case "Rahatlamış":
      case "Calmness":
        return Colors.pink.withOpacity(0.3);
      case "Memnun":
      case "Pleased":
        return Colors.deepPurple.withOpacity(0.3);
      default:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("BedoText", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.brown[700],
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedLanguage,
              icon: Icon(Icons.language, color: Colors.white),
              dropdownColor: Colors.brown[700],
              onChanged: (String? newValue) {
                setState(() {
                  _selectedLanguage = newValue!;
                  if (_isListening) {
                    _stopListening();
                    _startListening();
                  }
                });
              },
              items: [
                DropdownMenuItem(value: 'tr_TR', child: Text("TR", style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'en_US', child: Text("EN", style: TextStyle(color: Colors.white))),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'highlights') {
                Navigator.pushNamed(context, '/highlights', arguments: {
                  'highlightedWords': _highlightedWords,
                  'selectedLanguage': _selectedLanguage,
                });
              } else if (value == 'saved') {
                Navigator.pushNamed(context, '/saved');
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'highlights',
                child: Row(children: [Icon(LucideIcons.list, color: Colors.brown), SizedBox(width: 8), Text("Highlights")]),
              ),
              PopupMenuItem(
                value: 'saved',
                child: Row(children: [Icon(Icons.history, color: Colors.brown), SizedBox(width: 8), Text("Saved")]),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          buildMonkeyBackground(),
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 8, spreadRadius: 2)
                      ],
                      border: Border.all(
                        color: _getEmotionColor(),
                        width: 4.0,
                      ),
                    ),
                    padding: EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      child: RichText(
                        text: TextSpan(
                          children: _buildHighlightedText(),
                          style: TextStyle(fontSize: 18, color: Colors.black),
                        ),
                      ),
                    ),
                  ),
                ),
                Text(
                  _selectedLanguage == 'tr_TR'
                      ? "Anlık Ruh Hali: ${_currentEmotion['tr_TR'] ?? 'Bilinmiyor'}"
                      : "Current Emotion: ${_currentEmotion['en_US'] ?? 'Unknown'}",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // 🔽 PDF'e Çevir Butonu
          Positioned(
            bottom: 90,
            right: MediaQuery.of(context).size.width / 2 - 85,
            child: ElevatedButton.icon(
              onPressed: () => _createPdfFromText(context),
              icon: Icon(Icons.picture_as_pdf, color: Colors.white),
              label: Text(
                getMessage("PDF'e Çevir", "Convert to PDF"),
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown[700],
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            right: MediaQuery.of(context).size.width / 2 - 30,
            child: FloatingActionButton(
              onPressed: _isListening ? _stopListening : _startListening,
              backgroundColor: Colors.brown[700],
              child: Icon(_isListening ? LucideIcons.stopCircle : LucideIcons.mic, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class EmotionAnalysis {
  final Map<String, String> turkishEmotions = {
    "mutlu": "Mutlu",
    "mutluyum": "Mutlu",
    "sevinçliyim": "Mutlu",
    "keyifliyim": "Mutlu",
    "gülüyorum": "Mutlu",
    "korkuyorum": "Korku",
    "tedirginim": "Korku",
    "sinirliyim": "Kızgınlık",
    "öfkeliyim": "Kızgınlık",
    "gerginim": "Kızgınlık",
    "heyecanlıyım": "Heyecanlı",
    "coşkuluyum": "Heyecanlı",
    "kaygılıyım": "Kaygı",
    "endişeliyim": "Kaygı",
    "üzgünüm": "Üzgün",
    "kederliyim": "Üzgün",
    "mutsuzum": "Üzgün",
    "şaşkınım": "Şaşkın",
    "şaşırdım": "Şaşkın",
    "sıkıldım": "Sıkılmış",
    "yoruldum": "Yorgun",
    "rahatladım": "Rahatlamış",
    "memnunum": "Memnun",
  };
  final Map<String, String> englishEmotions = {
    "happy": "Happiness",
    "glad": "Happiness",
    "joyful": "Happiness",
    "scared": "Fear",
    "worried": "Fear",
    "nervous": "Fear",
    "angry": "Anger",
    "furious": "Anger",
    "tense": "Anger",
    "excited": "Excited",
    "thrilled": "Excited",
    "anxious": "Anxiety",
    "sad": "Upset",
    "sorrowful": "Upset",
    "blue": "Upset",
    "surprised": "Shocked",
    "astonished": "Shocked",
    "bored": "Bored",
    "tired": "Tired",
    "relaxed": "Calmness",
    "pleased": "Pleased",
    "i am happy": "Happiness",
    "i'm happy": "Happiness",
    "i feel happy": "Happiness",
    "i am scared": "Fear",
    "i'm scared": "Fear",
    "i feel scared": "Fear",
    "i am angry": "Anger",
    "i'm angry": "Anger",
    "i feel angry": "Anger",
    "i am excited": "Excited",
    "i'm excited": "Excited",
    "i feel excited": "Excited",
    "i am anxious": "Anxiety",
    "i'm anxious": "Anxiety",
    "i feel anxious": "Anxiety",
    "i am sad": "Upset",
    "i'm sad": "Upset",
    "i feel sad": "Upset",
    "i am surprised": "Shocked",
    "i'm surprised": "Shocked",
    "i feel surprised": "Shocked",
    "i am bored": "Bored",
    "i'm bored": "Bored",
    "i feel bored": "Bored",
    "i am tired": "Tired",
    "i'm tired": "Tired",
    "i feel tired": "Tired",
    "i am relaxed": "Calmness",
    "i'm relaxed": "Calmness",
    "i feel relaxed": "Calmness",
    "i am pleased": "Pleased",
    "i'm pleased": "Pleased",
  };

  Map<String, String> analyzeEmotion(String text, String languageCode) {
    final emotions = languageCode == 'tr_TR'
        ? turkishEmotions
        : englishEmotions;
    final lowerCaseText = text.toLowerCase();
    final words = lowerCaseText.split(RegExp(r'\s+'));

    String detectedEmotion = languageCode == 'tr_TR'
        ? "Bilinmiyor"
        : "Unknown"; // Varsayılan

    for (var emotion in emotions.keys) {
      if (lowerCaseText.contains(emotion)) {
        detectedEmotion = emotions[emotion]!;
        break;
      }
    }

    if (detectedEmotion ==
        (languageCode == 'tr_TR' ? "Bilinmiyor" : "Unknown")) {
      for (var word in words) {
        if (emotions.containsKey(word)) {
          detectedEmotion = emotions[word]!;
          break;
        }
      }
    }

    return {languageCode: detectedEmotion};
  }
}