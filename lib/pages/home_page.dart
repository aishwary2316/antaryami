import 'dart:convert';

import 'package:antaryami/pages/scanner.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class Product {
  final String name;
  final String description;
  final String imageAsset;

  Product({required this.name, required this.description, required this.imageAsset});
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Gemini _gemini = Gemini.instance;

  final ChatUser _currentUser = ChatUser(
    id: '0',
    firstName: 'You',
  );

  final ChatUser _geminiUser = ChatUser(
    id: '1',
    firstName: 'Antaryami',
    profileImage: 'assets/logo.png',
  );

  final List<ChatMessage> _messages = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('Antaryami AI'),
        centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner, color: Colors.blue),
              onPressed: () async {
                //Navigator.push(context, MaterialPageRoute(builder: (context) => ScanCodePage(),));
                final scannedValue = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ScanCodePage()),
                );

                if (scannedValue != null) {
                  // Now we have the scanned result here in `scannedValue`
                  // Note: Only text value stored in QR COde or Bar Code is directly passed and stored in 'scannedValue'
                  // Example: send it to Gemini automatically
                  // _handleSend(ChatMessage(
                  //   user: _currentUser,
                  //   createdAt: DateTime.now(),
                  //   text: scannedValue.toString(),
                  // ));

                  showDialog(context: context, builder: (context) {
                    return AlertDialog(
                      title: Text("Scanned Value"),
                      content: Text(scannedValue),
                      actions: [
                        TextButton(
                          onPressed: () {
                          },
                          child: const Text('OK'),
                        ),
                      ],
                    );
                  });

                }

              },
            ),
            IconButton(
      icon: const Icon(Icons.more_vert, color: Colors.black87),
      onPressed: () {
        // Show menu options
      },
    ),

          ],

    ),
      body: DashChat(
        currentUser: _currentUser,
        messages: _messages,
        onSend: _handleSend,

        // messageBuilder: (chatMessage, previousMessage, nextMessage) {
        //   if (chatMessage.user.id == _geminiUser.id && chatMessage.text == '__products__') {
        //     // Build the product carousel as part of chat
        //     final List products = chatMessage.customProperties?['products'] ?? [];
        //     return _buildProductCarousel(products);
        //   }
        //
        //   return null; // fallback to normal rendering
        // },

        messageOptions: MessageOptions(
          // intercept any message and render its text as Markdown
          messageTextBuilder: (msg, _, __) {
            // keep typing indicator as before
            if (msg.text == '...') {
              return const Text('...', style: TextStyle(fontSize: 16));
            }
            // for all other messages, render Markdown
            return MarkdownBody(
              data: msg.text,
              // match your chat bubble text style
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                  .copyWith(
                p: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontSize: 16),
              ),
            );
          },



        ),
        messageListOptions: MessageListOptions(
          // show this widget as the footer *only* when there are no messages:
          chatFooterBuilder: _messages.isEmpty
              ? _buildWelcome()
              : null,
        ),
      ),
    );
  }

  /// A simple Column with an image and some text, centered in the screen
  Widget _buildWelcome() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // replace with your own asset
          Image.asset(
            'assets/welcome.png',
            width: 150,
            height: 150,
          ),
          const SizedBox(height: 24),
          const Text(
            'Hi there!\nAsk me anything about our services.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSend(ChatMessage userMessage) async {
    // 1) show the user's bubble
    setState(() => _messages.insert(0, userMessage));

    // 2) show typing indicator
    final typingMsg = ChatMessage(
      user: _geminiUser,
      text: '...',
      createdAt: DateTime.now(),
    );
    setState(() => _messages.insert(0, typingMsg));

    try {
      // 3) one-shot prompt call
      final resp = await _gemini.prompt(parts: [
        Part.text(userMessage.text),
      ]);

      final fullText = resp?.output ?? '';

      // 4) build JSON payload if needed
      final jsonMap = {
        'output': fullText,
        'parts': resp?.content?.parts
            ?.map((p) => Part.toJson(p))
            .toList() ??
            [],
      };
      debugPrint(jsonEncode(jsonMap));

      // 5) remove typing bubble
      setState(() {
        _messages.removeWhere(
                (m) => m.user.id ==   _geminiUser.id && m.text == '...');
      });

  //     final productSuggestion = ChatMessage(
  //       user: _geminiUser,
  //       text: '__products__', // Special marker to differentiate
  //       createdAt: DateTime.now(),
  //       customProperties: {
  //         'products': _products.map((p) => {
  //           'name': p.name,
  //           'description': p.description,
  //           'image': p.imageAsset,
  //         }).toList(),
  //       },
  //     );
  //     setState(() => _messages.insert(0, productSuggestion));
  //
  //     final botMsg = ChatMessage(
  //       user: _geminiUser,
  //       text: fullText,
  //       createdAt: DateTime.now(),
  //     );
  //     setState(() => _messages.insert(0, botMsg));
  //
  //   } catch (err) {
  //     setState(() {
  //       _messages.removeWhere((m) => m.user.id == _geminiUser.id && m.text == '...');
  //       _messages.insert(0, ChatMessage(
  //         user: _geminiUser,
  //         createdAt: DateTime.now(),
  //         text: '⚠️ Error: $err',
  //       ));
  //     });
  //   }
  // }

      // 6) insert the final bot reply with markdown
      final botMsg = ChatMessage(
        user: _geminiUser,
        text: fullText,
        createdAt: DateTime.now(),
      );
      setState(() => _messages.insert(0, botMsg));
    } catch (err) {
      // on error: remove typing and show error
      setState(() {
        _messages.removeWhere(
                (m) => m.user.id == _geminiUser.id && m.text == '...');
        _messages.insert(
          0,
          ChatMessage(
            user: _geminiUser,
            createdAt: DateTime.now(),
            text: '⚠️ Error: $err',
          ),
        );
      });
    }
  }
}
