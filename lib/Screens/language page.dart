import 'package:flutter/material.dart';
class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  // ✅ List of languages
  final List<String> languages = [
    "English",
    "हिन्दी (Hindi)",
    "Español (Spanish)",
    "Français (French)",
    "Deutsch (German)",
    "中文 (Chinese)",
    "日本語 (Japanese)",
    "한국어 (Korean)",
    "Русский (Russian)",
    "العربية (Arabic)",
  ];

  String? selectedLanguage; // To keep track of selected language

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xffB8F8FF),
        title: const Text("Language"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            const Text(
              "Select Language",
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: languages.length,
                itemBuilder: (context, index) {
                  final lang = languages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5.0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedLanguage = lang;
                        });
                      },
                      child: Container(
                        height: 50,
                        width: double.infinity,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            width: 1,
                            color: selectedLanguage == lang
                                ? Colors.blue
                                : Colors.grey.shade400,
                          ),
                          color: selectedLanguage == lang
                              ? Colors.blue.shade50
                              : Colors.transparent,
                        ),
                        child: Text(
                          lang,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: selectedLanguage == lang
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
