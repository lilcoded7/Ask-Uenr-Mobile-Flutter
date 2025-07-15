import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';

void main() {
  runApp(const AskUnerApp());
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
}

class AskUnerApp extends StatelessWidget {
  const AskUnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AskUner - UENR Virtual Assistant',
      debugShowCheckedModeBanner: false,
      theme: _buildAppTheme(),
      home: const AskUnerHomePage(),
    );
  }

  ThemeData _buildAppTheme() {
    return ThemeData(
      primarySwatch: Colors.green,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: Color(0xFF1A4D2B)),
      ),
    );
  }
}

class AskUnerHomePage extends StatefulWidget {
  const AskUnerHomePage({super.key});

  @override
  State<AskUnerHomePage> createState() => _AskUnerHomePageState();
}

class _AskUnerHomePageState extends State<AskUnerHomePage> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final FlutterTts _flutterTts = FlutterTts();
  
  bool _isListening = false;
  bool _isMuted = false;
  bool _isTyping = false;
  bool _isSpeaking = false;
  
  String _currentResponse = "";
  Timer? _typingTimer;
  Timer? _streamingTimer;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _initTextToSpeech();
    _addWelcomeMessage();
  }

  Future<void> _initTextToSpeech() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
    
    _flutterTts.setStartHandler(() => setState(() => _isSpeaking = true));
    _flutterTts.setCompletionHandler(() => setState(() => _isSpeaking = false));
    _flutterTts.setErrorHandler((msg) {
      setState(() => _isSpeaking = false);
      debugPrint("TTS Error: $msg");
    });
  }

  void _addWelcomeMessage() {
    const welcomeMsg = "Hello! I'm AskUner, your UENR virtual assistant. How can I help you today?";
    setState(() => _messages.add(ChatMessage(
      text: welcomeMsg,
      isUser: false,
      timestamp: DateTime.now(),
    )));
    _speak(welcomeMsg);
  }

  Future<void> _speak(String text) async {
    if (_isMuted || text.isEmpty) return;
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _streamingTimer?.cancel();
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
      _isTyping = true;
    });

    _scrollToBottom();
    _typingTimer = Timer(const Duration(seconds: 1), () => _generateAIResponse(text));
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
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/ask/uenr/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'question': query}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final aiResponse = responseData['answer'] ?? "I couldn't process that request. Please try again.";
        _simulateTyping(aiResponse, () => _speak(aiResponse));
      } else {
        throw Exception('Failed to get response from server');
      }
    } catch (e) {
      debugPrint('Error fetching AI response: $e');
      const errorResponse = "Sorry, I'm having trouble connecting to the server. Please try again later.";
      _simulateTyping(errorResponse, () => _speak(errorResponse));
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

  void _simulateTyping(String fullText, VoidCallback onComplete) {
    final words = fullText.split(' ');
    int wordIndex = 0;
    
    _streamingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
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
        setState(() => _isTyping = false);
        onComplete();
      }
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      if (_isMuted && _isSpeaking) {
        _flutterTts.stop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildAvatarSection(),
          _buildChatMessages(),
          _buildInputSection(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/uenr_logo.png',
            height: 30,
            fit: BoxFit.contain,
          ),
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
          icon: const Icon(Icons.menu),
          onPressed: () => _showMenuDrawer(context),
        ),
      ],
    );
  }

  Widget _buildAvatarSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: Colors.white,
      child: Center(
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(60),
            border: Border.all(
              color: const Color(0xFF1A4D2B),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(60),
            child: _isTyping || _isSpeaking
                ? const Center(child: TypingIndicator())
                : const Center(
                    child: Icon(Icons.person, size: 40, color: Color(0xFF1A4D2B)),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatMessages() {
    return Expanded(
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
    );
  }

  Widget _buildInputSection() {
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
            icon: Icon(
              _isListening ? Icons.mic_off : Icons.mic,
              color: const Color(0xFF1A4D2B),
            ),
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
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

  void _showMenuDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'UENR Services',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A4D2B),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildMenuOption(Icons.school, 'Admissions'),
            _buildMenuOption(Icons.menu_book, 'Courses & Programs'),
            _buildMenuOption(Icons.account_balance, 'Departments'),
            _buildMenuOption(Icons.attach_money, 'Fees & Payments'),
            _buildMenuOption(Icons.contact_page, 'Contacts'),
            const Divider(height: 30),
            const Text(
              'User Profile',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A4D2B),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                _buildProfileChip('Prospective Student', true),
                _buildProfileChip('Current Student', false),
                _buildProfileChip('Staff', false),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  ChoiceChip _buildProfileChip(String label, bool selected) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFFD4EDDA),
      onSelected: (selected) {},
    );
  }

  ListTile _buildMenuOption(IconData icon, String text) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF1A4D2B)),
      title: Text(text),
      onTap: () {},
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
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) _buildBotAvatar(),
          Flexible(child: _buildMessageBubble()),
          if (isUser) _buildUserAvatar(),
        ],
      ),
    );
  }

  Widget _buildBotAvatar() {
    return const CircleAvatar(
      radius: 12,
      backgroundColor: Color(0xFF1A4D2B),
      child: Icon(Icons.smart_toy, size: 12, color: Colors.white),
    );
  }

  Widget _buildUserAvatar() {
    return const CircleAvatar(
      radius: 12,
      backgroundColor: Color(0xFF1A4D2B),
      child: Icon(Icons.person, size: 12, color: Colors.white),
    );
  }

  Widget _buildMessageBubble() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isUser ? const Color(0xFFD4EDDA) : const Color(0xFFE8F5E9),
        borderRadius: _buildMessageBorderRadius(),
        border: Border.all(
          color: isUser ? const Color(0xFFA5D6A7) : const Color(0xFFC8E6C9),
          width: 1,
        ),
      ),
      child: isStreaming 
          ? const TypingIndicator() 
          : Text(
              message.text,
              style: TextStyle(
                color: isUser ? const Color(0xFF1A4D2B) : const Color(0xFF333333),
              ),
            ),
    );
  }

  BorderRadius _buildMessageBorderRadius() {
    return BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(isUser ? 20 : 0),
      bottomRight: Radius.circular(isUser ? 0 : 20),
    );
  }
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> 
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
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
      children: List.generate(3, (index) => _buildDot()),
    );
  }

  Widget _buildDot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ScaleTransition(
        scale: _animation,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFF1A4D2B),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}