import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:chat_bubbles/chat_bubbles.dart';
import 'main.dart'; // Import to access the API key

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  late final GenerativeModel _model;

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: geminiApiKey);

    // Add a welcome message
    _addBotMessage(
      'Hello! I\'m your FinAI assistant. How can I help you with your financial questions today?',
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
    });
    _scrollToBottom();
  }

  void _addBotMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: false));
    });
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    if (_textController.text.trim().isEmpty) return;

    final userMessage = _textController.text;
    _addUserMessage(userMessage);
    _textController.clear();

    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare the prompt with financial context
      final prompt =
          '''
      You are FinAI, a specialized financial advisor chatbot. Your expertise is in personal finance, 
      budgeting, investments, retirement planning, and financial education. 
      
      Provide helpful, accurate, and educational responses to financial questions. 
      If you're unsure about specific financial details, acknowledge the limitations 
      and suggest consulting with a professional financial advisor for personalized advice.
      
      User query: $userMessage
      ''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final responseText =
          response.text ?? 'Sorry, I couldn\'t generate a response.';

      _addBotMessage(responseText);
    } catch (e) {
      _addBotMessage('Sorry, I encountered an error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        title: const Text(
          'FinAI Chatbot',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0E27),
              Color(0xFF1A1B3A),
              Color(0xFF2E1065),
              Color(0xFF4C1D95),
              Color(0xFF5B21B6),
            ],
            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                // Remove light background to let gradient show
                decoration: const BoxDecoration(color: Colors.transparent),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return _buildMessageBubble(message);
                  },
                ),
              ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
      child: message.isUser
          ? BubbleSpecialThree(
              text: message.text,
              color: const Color(0xFF5B21B6),
              tail: true,
              isSender: true,
              textStyle: const TextStyle(color: Colors.white, fontSize: 16),
            )
          : BubbleSpecialThree(
              text: message.text,
              color: const Color(0xFF1A1B3A),
              tail: true,
              isSender: false,
              textStyle: const TextStyle(color: Colors.white, fontSize: 16),
            ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ask a financial question...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 12.0,
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8.0),
          _isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF4C1D95),
                        Color(0xFF6D28D9),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _sendMessage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}
