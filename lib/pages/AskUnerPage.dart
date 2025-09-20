import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

class AskUnerPage extends StatefulWidget {
  const AskUnerPage({super.key});

  @override
  State<AskUnerPage> createState() => _AskUnerPageState();
}

class _AskUnerPageState extends State<AskUnerPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isMuted = false;
  String _currentResponse = "";
  Timer? _streamingTimer;
  String _sessionId = "";

  @override
  void initState() {
    super.initState();
    _initSession();
    _initTts();
    _addWelcomeMessage();
  }

  Future<void> _initSession() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionId = prefs.getString("session_id") ?? const Uuid().v4();
    await prefs.setString("session_id", _sessionId);
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.48);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.1);

    try {
      final voices = await _flutterTts.getVoices;
      final femaleVoices = voices.where((v) =>
          v['locale'].toString().contains('en') &&
          (v['name'].toString().toLowerCase().contains('female') ||
           v['name'].toString().toLowerCase().contains('samantha') ||
           v['name'].toString().toLowerCase().contains('alexa'))).toList();

      if (femaleVoices.isNotEmpty) {
        await _flutterTts.setVoice(femaleVoices.first);
      } else {
        await _flutterTts.setVoice({"name": "en-us-x-sfg#female_1-local", "locale": "en-US"});
      }
    } catch (e) {
      debugPrint("Voice selection error: $e");
    }
  }

  void _addWelcomeMessage() {
    const welcomeMsg =
        "Hello! I'm AskUner, your AI assistant for the University of Energy and Natural Resources. "
        "I can help you with information about programs, courses, staff, admissions, and more. "
        "What would you like to know about UENR today?";
    _addMessage(welcomeMsg, isUser: false);
    _speakResponse(welcomeMsg);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _streamingTimer?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;
    _flutterTts.stop();
    _messageController.clear();
    _addMessage(text, isUser: true);
    _scrollToBottom();
    _generateAIResponse(text);
  }

  void _addMessage(String text, {required bool isUser}) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: isUser,
        timestamp: DateTime.now(),
      ));
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _generateAIResponse(String query) async {
    _startStreamingResponse();
    try {
      const baseURL = 'http://127.0.0.1:8000';
      final response = await http.post(
        Uri.parse('$baseURL/ask/uenr/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'question': query, 'session_id': _sessionId}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final aiResponse = responseData['answer'] ?? "I'm sorry, I couldn't process that request.";
        _simulateStreaming(aiResponse, () => _speakResponse(aiResponse));
      } else {
        throw Exception('Failed to get response from server');
      }
    } catch (e) {
      debugPrint('Error fetching AI response: $e');
      const errorResponse = "I’m having trouble connecting to the server. Please try again.";
      _simulateStreaming(errorResponse, () => _speakResponse(errorResponse));
    }
  }

  Future<void> _speakResponse(String text) async {
    if (_isMuted || text.isEmpty) return;
    try {
      await _flutterTts.stop();
      final formattedText = text.replaceAllMapped(
        RegExp(r'[.!?]'),
        (match) => '${match.group(0)} ',
      );
      await _flutterTts.speak(formattedText);
    } catch (e) {
      debugPrint('TTS error: $e');
    }
  }

  void _startStreamingResponse() {
    setState(() {
      _currentResponse = "";
      _messages.add(ChatMessage(
        text: "",
        isUser: false,
        timestamp: DateTime.now(),
        isStreaming: true,
      ));
    });
  }

  void _simulateStreaming(String fullText, VoidCallback onComplete) {
    final words = fullText.split(' ');
    int wordIndex = 0;

    _streamingTimer?.cancel();
    _streamingTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      if (wordIndex < words.length) {
        setState(() {
          _currentResponse += '${words[wordIndex]} ';
          _messages.last = ChatMessage(
            text: _currentResponse,
            isUser: false,
            timestamp: DateTime.now(),
            isStreaming: wordIndex < words.length - 1,
          );
          wordIndex++;
        });
        _scrollToBottom();
      } else {
        timer.cancel();
        onComplete();
      }
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      if (_isMuted) _flutterTts.stop();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isMuted ? 'Sound muted' : 'Sound enabled'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _clearConversation() {
    setState(() {
      _messages.clear();
      _flutterTts.stop();
    });
    _addWelcomeMessage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/uenr_logo.png', height: 30),
            const SizedBox(width: 10),
            const Text('AskUner', style: TextStyle(color: Color(0xFF1A4D2B), fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: const Color(0xFF1A4D2B)),
            onPressed: _toggleMute,
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Color(0xFF1A4D2B)),
            onPressed: _clearConversation,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF1A4D2B)),
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF8F9FA), Color(0xFFE8F5E9)],
                ),
              ),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                itemCount: _messages.length,
                itemBuilder: (context, index) => ChatBubble(message: _messages[index]),
              ),
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: 'Ask me anything about UENR...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: _handleSubmitted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFF1A4D2B),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: () => _handleSubmitted(_messageController.text),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------- Models -----------------
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isStreaming;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isStreaming = false,
  });
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser)
            Container(
              margin: const EdgeInsets.only(right: 8, top: 4),
              child: const CircleAvatar(
                radius: 14,
                backgroundColor: Color(0xFF1A4D2B),
                child: Icon(Icons.school, size: 14, color: Colors.white),
              ),
            ),
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: message.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message copied to clipboard'), duration: Duration(seconds: 1)),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: message.isUser ? const Color(0xFF1A4D2B) : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(message.isUser ? 20 : 4),
                    bottomRight: Radius.circular(message.isUser ? 4 : 20),
                  ),
                ),
                child: SelectableText(
                  message.text,
                  style: TextStyle(
                    fontSize: 14,
                    color: message.isUser ? Colors.white : Colors.black87,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
          if (message.isUser)
            Container(
              margin: const EdgeInsets.only(left: 8, top: 4),
              child: const CircleAvatar(
                radius: 14,
                backgroundColor: Color(0xFF1A4D2B),
                child: Icon(Icons.person, size: 14, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
