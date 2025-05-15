import 'package:flutter/material.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({Key? key}) : super(key: key);

  final List<Map<String, String>> faqs = const [
    {
      'question': 'What is this app about?',
      'answer': 'This app is designed to support mental health by providing tools, resources, and a safe space for users.'
    },
    {
      'question': 'How do I edit my profile?',
      'answer': 'Go to the Account screen and tap on Edit Profile to update your information.'
    },
    {
      'question': 'How is my data secured?',
      'answer': 'Your data is securely stored using Supabase and is only accessible to you.'
    },
    {
      'question': 'How do I delete my account?',
      'answer': 'On the Account screen, tap Delete Account and confirm your choice.'
    },
    {
      'question': 'Who can I contact for support?',
      'answer': 'You can reach out to our support team via the contact option in the app.'
    },
    {
      'question': 'Can I use this app offline?',
      'answer': 'Some features may be available offline, but for full functionality and data sync, an internet connection is required.'
    },
    {
      'question': 'How do I reset my password?',
      'answer': 'On the sign-in screen, tap on "Forgot Password" and follow the instructions to reset your password via email.'
    },
    {
      'question': 'Is my personal information shared with others?',
      'answer': 'No, your personal information is private and is not shared with other users or third parties.'
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1B2B1A) : null;
    final cardColor = isDark ? const Color(0xFF223D1B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQs'),
        backgroundColor: isDark ? const Color(0xFF223D1B) : Colors.lightGreen[100],
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Container(
            decoration: isDark
                ? const BoxDecoration(color: Color(0xFF1B2B1A))
                : const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF9CB36B), Color(0xFFF5F5F5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
          ),
          if (!isDark) ...[
            Positioned(
              top: -40,
              left: -40,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.lightGreen[100]?.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              right: -30,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.brown[100]?.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
          ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: faqs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 18),
            itemBuilder: (context, index) {
              final faq = faqs[index];
              return Card(
                elevation: 4,
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ExpansionTile(
                  title: Text(
                    faq['question']!,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        faq['answer']!,
                        style: TextStyle(fontSize: 15, color: textColor.withOpacity(0.85)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
} 