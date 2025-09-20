import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

class AskUnerPage extends StatefulWidget {
  const AskUnerPage({super.key});

  @override
  State<AskUnerPage> createState() => _AskUnerPageState();
}

class _AskUnerPageState extends State<AskUnerPage> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isListening = false;
  bool _isMuted = false;
  bool _isThinking = false;
  bool _isSpeaking = false;

  String _currentResponse = "";
  Timer? _streamingTimer;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _initTts();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _addWelcomeMessage();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      setState(() => _isSpeaking = true);
    });

    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
        _isThinking = false;
      });
      _animationController.stop();
    });

    _flutterTts.setErrorHandler((msg) {
      setState(() {
        _isSpeaking = false;
        _isThinking = false;
      });
      _animationController.stop();
      debugPrint("TTS Error: $msg");
    });
  }

  void _addWelcomeMessage() {
    const welcomeMsg = "Hello! I'm AskUner, AI assistant for the University Of Energy And Natural Resources. How can I help you today?";
    setState(() {
      _messages.add(ChatMessage(
        text: welcomeMsg,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    _speakResponse(welcomeMsg);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _streamingTimer?.cancel();
    _animationController.dispose();
    _audioPlayer.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;

    _messageController.clear();
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isThinking = true;
    });

    _scrollToBottom();
    _generateAIResponse(text);
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
        body: jsonEncode({'question': query}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final aiResponse = responseData['answer'] ?? "I couldn't process that request.";
        _simulateStreaming(aiResponse, () => _speakResponse(aiResponse));
      } else {
        throw Exception('Failed to get response from server');
      }
    } catch (e) {
      debugPrint('Error fetching AI response: $e');
      const errorResponse = "Sorry, I'm having trouble connecting to the server.";
      _simulateStreaming(errorResponse, () => _speakResponse(errorResponse));
    }
  }

  Future<void> _speakResponse(String text) async {
    if (_isMuted || text.isEmpty) {
      setState(() => _isThinking = false);
      return;
    }

    try {
      _animationController.repeat(reverse: true);
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('Error in speech synthesis: $e');
      setState(() => _isThinking = false);
      _animationController.stop();
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

    _streamingTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
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
      if (_isMuted) {
        _flutterTts.stop();
        _animationController.stop();
        setState(() {
          _isSpeaking = false;
          _isThinking = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/uenr_logo.png', height: 30, fit: BoxFit.contain),
            const SizedBox(width: 10),
            const Text(
              'AskUner',
              style: TextStyle(
                color: Color(0xFF1A4D2B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
            onPressed: _toggleMute,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // 👇 Logout goes back to login
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildAvatarSection(),
          Expanded(
            child: Container(
              color: const Color(0xFFF5F5F5),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                itemCount: _messages.length,
                itemBuilder: (context, index) => ChatBubble(
                  message: _messages[index],
                  isUser: _messages[index].isUser,
                  isStreaming: _messages[index].isStreaming,
                ),
              ),
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      color: Colors.white,
      child: Center(
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE8F5E9),
                border: Border.all(color: const Color(0xFF1A4D2B), width: 2),
              ),
              child: Center(
                child: (_isThinking || _isSpeaking)
                    ? _buildThinkingAnimation()
                    : const Icon(Icons.smart_toy, size: 40, color: Color(0xFF1A4D2B)),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(_isListening ? Icons.mic_off : Icons.mic, color: const Color(0xFF1A4D2B)),
            onPressed: () => setState(() => _isListening = !_isListening),
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Ask me anything about UENR...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFFEEEEEE),
              ),
              onSubmitted: _handleSubmitted,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Color(0xFF1A4D2B)),
            onPressed: () => _handleSubmitted(_messageController.text),
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingAnimation() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ScaleTransition(
            scale: DelayTween(begin: 0.4, end: 1.2, delay: index * 0.2).animate(_animationController),
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(color: Color(0xFF1A4D2B), shape: BoxShape.circle),
            ),
          ),
        );
      }),
    );
  }
}

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
  final bool isUser;
  final bool isStreaming;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            const CircleAvatar(
              radius: 12,
              backgroundColor: Color(0xFF1A4D2B),
              child: Icon(Icons.smart_toy, size: 12, color: Colors.white),
            ),
          Flexible(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFFD4EDDA) : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: isStreaming ? const TypingIndicator() : Text(message.text),
            ),
          ),
          if (isUser)
            const CircleAvatar(
              radius: 12,
              backgroundColor: Color(0xFF1A4D2B),
              child: Icon(Icons.person, size: 12, color: Colors.white),
            ),
        ],
      ),
    );
  }
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this)
      ..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: ScaleTransition(
            scale: _animation,
            child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF1A4D2B), shape: BoxShape.circle)),
          ),
        ),
      ),
    );
  }
}

class DelayTween extends Tween<double> {
  DelayTween({double? begin, double? end, required this.delay}) : super(begin: begin, end: end);

  final double delay;

  @override
  double lerp(double t) => super.lerp((t - delay).clamp(0.0, 1.0));

  @override
  double evaluate(Animation<double> animation) => lerp(animation.value);
}
