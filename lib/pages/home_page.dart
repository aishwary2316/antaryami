import 'dart:convert';

import 'package:antaryami/pages/scanner.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class Product {
  final String name;
  final String subtitle;
  final String price;
  final String imageAsset;
  final String description;

  Product({
    required this.name,
    required this.subtitle,
    required this.price,
    required this.imageAsset,
    required this.description,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    name: json['name'],
    subtitle: json['subtitle'],
    price: json['price'],
    imageAsset: json['imageAsset'],
    description: json['description'],
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Gemini _gemini = Gemini.instance;

  final ChatUser _currentUser = ChatUser(id: '0', firstName: 'You');
  final ChatUser _geminiUser = ChatUser(
    id: '1',
    firstName: 'Antaryami',
    profileImage: 'assets/logo.png',
  );

  final List<ChatMessage> _messages = [];

  final List<Product> _products = [
    Product(
      name: 'Fur Pink Jacket',
      subtitle: 'Woman, M',
      price: '\$80.50',
      imageAsset: 'assets/product1.png',
      description: 'A cozy fur pink jacket, perfect for chilly evenings.',
    ),
    Product(
      name: 'Silk Pink Dress',
      subtitle: 'Woman, L',
      price: '\$130.00',
      imageAsset: 'assets/product2.png',
      description: 'Elegant silk dress in pink, ideal for summer outings.',
    ),
    Product(
      name: 'Pink Skirt',
      subtitle: 'Woman, M',
      price: '\$60.99',
      imageAsset: 'assets/product3.png',
      description: 'Flared pink skirt with lightweight fabric.',
    ),
  ];

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
            onPressed: _onScanPressed,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: DashChat(
        currentUser: _currentUser,
        messages: _messages,
        onSend: _handleSend,
        messageOptions: MessageOptions(
          currentUserContainerColor: Colors.amberAccent.shade100,
          //containerColor: Color.fromARGB(241, 255, 255, 255),
          textColor: Colors.grey.shade800,
          currentUserTextColor: Colors.white,

          top: (msg, previous, next) {
            if (msg.user.id == _geminiUser.id && msg.text == '__Recommendations...__') {
              final items = msg.customProperties?['products'] as List<dynamic>? ?? [];
              final products = items
                  .map((m) => Product.fromJson(Map<String, dynamic>.from(m)))
                  .toList();
              return _buildProductCarousel(products);
            }
            return const SizedBox.shrink();
          },

          messageTextBuilder: (msg, _, __) {
            if (msg.text == '...') {
              return const Text('...', style: TextStyle(fontSize: 16));
            }
            Color textColor;
            if (msg.user.id == _currentUser.id) {
              textColor = Colors.black;
            } else if (msg.user.id == _geminiUser.id) {
              textColor = Colors.black;
            } else {
              textColor = Colors.grey; // fallback or other bots
            }
            return MarkdownBody(
              data: msg.text,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                  .copyWith(
                p: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontSize: 16, color: textColor),
              ),
            );
          },
        ),
        messageListOptions: MessageListOptions(
          chatFooterBuilder: _messages.isEmpty ? _buildWelcome() : null,
        ),
      ),
    );
  }

  Future<void> _onScanPressed() async {
    final scanned = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const ScanCodePage()),
    );
    if (scanned != null) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text("Scanned Value"),
          content: Text(scanned),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
          ],
        ),
      );
    }
  }

  Widget _buildWelcome() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Image.asset('assets/welcome.png', width: 150, height: 150),
        const SizedBox(height: 24),
        const Text(
          'Hi there!\nAsk me anything about our services.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      ]),
    );
  }

  Future<void> _handleSend(ChatMessage userMessage) async {
    setState(() => _messages.insert(0, userMessage));
    setState(() => _messages.insert(0, ChatMessage(
      user: _geminiUser,
      text: '...',
      createdAt: DateTime.now(),
    )));

    try {
      final resp = await _gemini.prompt(parts: [Part.text(userMessage.text)]);
      final fullText = resp?.output ?? '';

      setState(() {
        _messages.removeWhere((m) => m.user.id == _geminiUser.id && m.text == '...');
      });

      setState(() => _messages.insert(0, ChatMessage(
        user: _geminiUser,
        text: '__Recommendations...__',
        createdAt: DateTime.now(),
        customProperties: {
          'products': _products.map((p) => {
            'name': p.name,
            'subtitle': p.subtitle,
            'price': p.price,
            'imageAsset': p.imageAsset,
            'description': p.description,
          }).toList(),
        },
      )));

      setState(() => _messages.insert(0, ChatMessage(
        user: _geminiUser,
        text: fullText,
        createdAt: DateTime.now(),
      )));
    } catch (err) {
      setState(() {
        _messages.removeWhere((m) => m.user.id == _geminiUser.id && m.text == '...');
        _messages.insert(0, ChatMessage(
          user: _geminiUser,
          text: '⚠️ Error: $err',
          createdAt: DateTime.now(),
        ));
      });
    }
  }

  Widget _buildProductCarousel(List<Product> products) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _buildProductCard(products[i]),
      ),
    );
  }

  Widget _buildProductCard(Product p) {
    return GestureDetector(
      onTap: () => _showProductDialog(p),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 160,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.asset(
                p.imageAsset,
                height: 100,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(p.subtitle, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                Text(p.price, style: const TextStyle(fontSize: 16)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  void _showProductDialog(Product p) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      p.imageAsset,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(p.subtitle, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(p.price, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(p.description),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(c),
              ),
            )
          ],
        ),
      ),
    );
  }
}
