import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<Home> {
  final TextEditingController controller = TextEditingController();
  String resultado = "";
  bool isLoading = false;

  static const String _apiKey = "AIzaSyBaOmo1kqYPAaEcy4PBXex0mdESSBicqGc";
  static const String _model = "gemini-2.5-flash";

  Future<void> gerarResumo() async {
    final textoUsuario = controller.text.trim();
    if (textoUsuario.isEmpty) return;

    setState(() {
      isLoading = true;
      resultado = "";
    });

    controller.clear();

    try {
      final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey",
      );

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {
"text": """
Você é uma tutora de estudos especializada em transformar anotações de alunos em material didático de alta qualidade.

O aluno enviou suas anotações pessoais sobre um conteúdo. Sua missão é:

📌 PONTOS-CHAVE
Identifique os conceitos centrais das anotações e explique cada um de forma simples e direta, como se estivesse explicando para alguém que nunca viu o assunto.

📝 RESUMO DIDÁTICO
Reorganize e complemente as anotações do aluno em um texto coeso, claro e fácil de entender. Conecte os conceitos entre si, preencha lacunas de explicação e use linguagem acessível. NÃO copie as anotações, reescreva com suas próprias palavras.

💡 COMPLEMENTO
Adicione informações relevantes que o aluno pode não ter anotado mas que são importantes para entender o tema completamente. Traga exemplos práticos e analogias quando possível.

🗒️ TERMOS IMPORTANTES
Liste os termos técnicos presentes nas anotações com uma explicação simples de cada um.

❓ POSSÍVEIS DÚVIDAS
Antecipe 2 a 3 perguntas que o aluno pode ter sobre o conteúdo e responda cada uma de forma objetiva.

---
Anotações do aluno:
$textoUsuario
"""
                }
              ]
            }
          ],
          "generationConfig": {
            "temperature": 0.7,
            "maxOutputTokens": 8192, 
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final texto = data["candidates"][0]["content"]["parts"][0]["text"] as String;
        setState(() => resultado = texto);
      } else {
        final erro = jsonDecode(response.body);
        setState(() => resultado = "Erro ${response.statusCode}: ${erro["error"]["message"]}");
      }
    } catch (e) {
      setState(() => resultado = "Erro de conexão: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Study AI"),
      ),
      // Evita overflow quando o teclado aparece
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Área de resultado (rolável)
            Expanded(
              child: resultado.isEmpty && !isLoading
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.auto_awesome, color: Colors.deepPurple, size: 60),
                        SizedBox(height: 10),
                        Text(
                          "Cole ou digite um texto abaixo\npara gerar resumo, anotações e pontos-chave.",
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : isLoading
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Colors.deepPurple),
                              SizedBox(height: 16),
                              Text("Analisando seu texto..."),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: MarkdownBody(
                            data: resultado,
                            softLineBreak: true,
                          ),
                        ),
            ),

            // Barra de input — altura limitada com scroll interno
            Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 150),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                        child: TextField(
                          controller: controller,
                          maxLines: null, // cresce mas respeita o maxHeight do Container
                          decoration: const InputDecoration(
                            hintText: "Cole ou digite seu texto aqui...",
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: IconButton(
                        onPressed: isLoading ? null : gerarResumo,
                        icon: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.deepPurple,
                                ),
                              )
                            : const Icon(Icons.send),
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}