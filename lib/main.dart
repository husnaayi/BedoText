import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:intl/intl.dart';
// bu satır yedekleme testi için
void main() {
  runApp(MaterialApp(
    title: 'BedoText',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      primarySwatch: Colors.brown,
    ),
    initialRoute: '/',
    routes: {
      '/': (context) => HomePage(),
      '/highlights': (context) => HighlightsPage(),
      '/saved': (context) => SavedPage(),
    },
  ));
}

Widget buildMonkeyBackground() {
  return Center(
    child: Opacity(
      opacity: 0.1,
      child: Text(
        "🐵",
        style: TextStyle(fontSize: 80),
      ),
    ),
  );
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _selectedLanguage = 'tr_TR';
  String _recognizedText = "";
  final Map<String, int> _highlightedWords = {};
  Map<String, dynamic> _keywords = {};

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
          });
        },
        localeId: _selectedLanguage,
      );
    }
  }

  void _stopListening() async {
    setState(() => _isListening = false);
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
    savedConversations.add(_recognizedText.trim());
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
    String cleaned = word.trim()
        .replaceAll(RegExp(r'[^a-zA-ZğüşöçıİĞÜŞÖÇ0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');

    if (_selectedLanguage == 'tr_TR') {
      return toBeginningOfSentenceCase(cleaned.toLowerCase())!.toLowerCase();
    } else {
      return cleaned.toLowerCase();
    }
  }

  String normalizeWord(String word) {
    word = word.toLowerCase().trim();

    List<String> suffixes = [
      'lerim', 'larım', 'ler', 'lar',
      'imiz', 'ımız', 'unuz', 'ünüz', 'miz', 'nız', 'niz',
      'im', 'ım', 'um', 'üm',
      'in', 'ın', 'un', 'ün',
      'yi', 'yı', 'yu', 'yü',
      'ye', 'ya',
      'de', 'da', 'te', 'ta',
      'den', 'dan', 'ten', 'tan',
      'le', 'la',
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
                Navigator.pushNamed(context, '/highlights', arguments: _highlightedWords);
              } else if (value == 'saved') {
                Navigator.pushNamed(context, '/saved');
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'highlights',
                child: Row(
                  children: [
                    Icon(LucideIcons.list, color: Colors.brown),
                    SizedBox(width: 8),
                    Text("Highlights"),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'saved',
                child: Row(
                  children: [
                    Icon(Icons.history, color: Colors.brown),
                    SizedBox(width: 8),
                    Text("Saved"),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: Opacity(
              opacity: 0.15,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text("🐵", style: TextStyle(fontSize: 150)),
                )),
              ),
            ),
          ),
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
                        BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 8, spreadRadius: 2),
                      ],
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
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            right: MediaQuery.of(context).size.width / 2 - 30,
            child: FloatingActionButton(
              onPressed: _isListening ? _stopListening : _startListening,
              backgroundColor: Colors.brown[700],
              child: Icon(
                _isListening ? LucideIcons.stopCircle : LucideIcons.mic,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HighlightsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Map<String, int> highlightedWords =
    ModalRoute.of(context)!.settings.arguments as Map<String, int>;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Certain Words',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.brown[700],
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          buildMonkeyBackground(),
          ListView(
            children: highlightedWords.entries.map((entry) {
              return ListTile(
                title: Text('${entry.key}'),
                trailing: Text('${entry.value} X'),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class SavedPage extends StatefulWidget {
  @override
  _SavedPageState createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  List<String> _savedConversations = [];

  @override
  void initState() {
    super.initState();
    _loadSavedConversations();
  }

  Future<void> _loadSavedConversations() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> saved = prefs.getStringList('saved_conversations') ?? [];
    setState(() {
      _savedConversations = saved;
    });
  }

  Future<void> _deleteConversation(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedConversations.removeAt(index);
    });
    await prefs.setStringList('saved_conversations', _savedConversations);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Saved Conversations',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.brown[700],
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          buildMonkeyBackground(),
          ListView.builder(
            itemCount: _savedConversations.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(_savedConversations[index]),
                trailing: IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteConversation(index),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}