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
      appBar: AppBar(
        title: const Text(
          'FinAI Chatbot',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: Colors.grey[100]),
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
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: message.isUser
          ? BubbleSpecialThree(
              text: message.text,
              color: Colors.blue,
              tail: true,
              isSender: true,
              textStyle: const TextStyle(color: Colors.white, fontSize: 16),
            )
          : BubbleSpecialThree(
              text: message.text,
              color: Colors.white,
              tail: true,
              isSender: false,
              textStyle: const TextStyle(color: Colors.black, fontSize: 16),
            ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'Ask a financial question...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 10.0,
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8.0),
          _isLoading
              ? const CircularProgressIndicator()
              : FloatingActionButton(
                  onPressed: _sendMessage,
                  backgroundColor: Colors.blue,
                  elevation: 2,
                  child: const Icon(Icons.send, color: Colors.white),
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
