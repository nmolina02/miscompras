import 'package:flutter/material.dart';

class Chatbot {
  Chatbot();

  Positioned productEditButton(BuildContext context) {
    return
    // Botón flotante en esquina inferior derecha
    Positioned(
      bottom: 16,
      right: 16,
      child: FloatingActionButton(
        onPressed: () {
          _runChatbot(context);
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(
          Icons.chat_rounded,
          color: Colors.white,
        ),
      ),
    );
  }

  void _runChatbot(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const _ChatbotScreen(),
      ),
    );
  }
}

class _ChatbotScreen extends StatefulWidget {
  const _ChatbotScreen();

  @override
  State<_ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<_ChatbotScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chatbot'),
      ),
      body: const Center(
        child: Text(
          'Funcionalidad de chatbot en desarrollo.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}