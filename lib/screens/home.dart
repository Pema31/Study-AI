import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'history_screen.dart';

class Mensagem {
  final String texto;
  final bool isUsuario;
  Mensagem({required this.texto, required this.isUsuario});
}

class Home extends StatefulWidget {
  final String? textoInicial;
  final String? notaId;      // ID da nota no Firestore para poder atualizar
  final String? notaTitulo;  // Título da nota para mostrar no banner
  const Home({super.key, this.textoInicial, this.notaId, this.notaTitulo});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final TextEditingController controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<Mensagem> mensagens = [];
  bool isLoading = false;
  bool bannerExpandido = false;
  bool isSavingNota = false;
  String? _conversaId;

  static const String _apiKey = "AIzaSyC-VejxORSe6T5b6KX5bDONgrVeyq--7Yg";
  static const String _model = "gemini-2.5-flash";

  @override
  void initState() {
    super.initState();
    // Se veio de uma nota, envia automaticamente sem preencher o campo
    if (widget.textoInicial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _enviarAnotacaoAutomatica(widget.textoInicial!);
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // Envia a anotação automaticamente como primeira mensagem (sem mostrar no campo)
  Future<void> _enviarAnotacaoAutomatica(String texto) async {
    setState(() {
      mensagens.add(Mensagem(texto: texto, isUsuario: true));
      isLoading = true;
    });

    await _chamarAPI(texto);
  }

  Future<void> enviarMensagem() async {
    final textoUsuario = controller.text.trim();
    if (textoUsuario.isEmpty) return;

    setState(() {
      mensagens.add(Mensagem(texto: textoUsuario, isUsuario: true));
      isLoading = true;
    });

    controller.clear();
    _scrollToBottom();
    await _chamarAPI(textoUsuario);
  }

  Future<void> _chamarAPI(String textoUsuario) async {
    _scrollToBottom();

    final historico = mensagens
        .where((m) => !isLoading || m != mensagens.last)
        .map((m) => m.isUsuario ? "Aluno: ${m.texto}" : "Tutora: ${m.texto}")
        .join("\n\n");

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
Você é uma tutora de estudos especializada em transformar anotações de alunos em material didático de alta qualidade. Você está em uma conversa contínua com o aluno.

Se for a primeira mensagem, analise as anotações e gere:

📌 PONTOS-CHAVE
Identifique os conceitos centrais e explique cada um de forma simples e direta.

📝 RESUMO DIDÁTICO
Reorganize e complemente as anotações em um texto coeso e fácil de entender. NÃO copie as anotações, reescreva com suas próprias palavras.

💡 COMPLEMENTO
Adicione informações relevantes que o aluno pode não ter anotado. Traga exemplos práticos e analogias quando possível.

🗒️ TERMOS IMPORTANTES
Liste os termos técnicos com uma explicação simples de cada um.

❓ POSSÍVEIS DÚVIDAS
Antecipe 2 a 3 perguntas e responda cada uma de forma objetiva.

Se for uma mensagem de acompanhamento, responda de forma direta e didática, mantendo o contexto da conversa anterior.

---
Histórico da conversa:
$historico

Nova mensagem do aluno:
$textoUsuario
"""
                }
              ]
            }
          ],
          "generationConfig": {"temperature": 0.7, "maxOutputTokens": 8192}
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final texto = data["candidates"][0]["content"]["parts"][0]["text"] as String;
        setState(() => mensagens.add(Mensagem(texto: texto, isUsuario: false)));
        _scrollToBottom();
        await _salvarConversa();
      } else {
        final erro = jsonDecode(response.body);
        setState(() => mensagens.add(Mensagem(
          texto: "Erro ${response.statusCode}: ${erro["error"]["message"]}",
          isUsuario: false,
        )));
      }
    } catch (e) {
      setState(() => mensagens.add(Mensagem(texto: "Erro de conexão: $e", isUsuario: false)));
    } finally {
      setState(() => isLoading = false);
      _scrollToBottom();
    }
  }

  Future<void> _salvarConversa() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final titulo = mensagens.first.texto.length > 50
        ? "${mensagens.first.texto.substring(0, 50)}..."
        : mensagens.first.texto;
    final mensagensJson = mensagens.map((m) => {"texto": m.texto, "isUsuario": m.isUsuario}).toList();
    if (_conversaId == null) {
      final doc = await FirebaseFirestore.instance
          .collection("usuarios").doc(user.uid).collection("conversas")
          .add({"titulo": titulo, "mensagens": mensagensJson, "data": FieldValue.serverTimestamp()});
      _conversaId = doc.id;
    } else {
      await FirebaseFirestore.instance
          .collection("usuarios").doc(user.uid).collection("conversas").doc(_conversaId)
          .update({"mensagens": mensagensJson, "data": FieldValue.serverTimestamp()});
    }
  }

  // Salva os pontos relevantes da conversa de volta na anotação
  Future<void> _salvarNaAnotacao() async {
    if (widget.notaId == null) return;

    setState(() => isSavingNota = true);

    try {
      // Pede para a IA extrair os pontos mais relevantes da conversa
      final historico = mensagens
          .map((m) => m.isUsuario ? "Aluno: ${m.texto}" : "Tutora: ${m.texto}")
          .join("\n\n");

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
Com base na conversa abaixo entre um aluno e uma tutora, extraia TODOS os pontos importantes para o aluno guardar como material de estudo.

INCLUA OBRIGATORIAMENTE:
- Todos os conceitos explicados pela tutora
- Definições de termos técnicos mencionados
- Datas, nomes e eventos importantes
- Exemplos e analogias usados para explicar
- Respostas às dúvidas do aluno
- Complementos e informações adicionais

Formate em tópicos claros e organizados por seção. Use títulos para separar os temas. Seja COMPLETO — é melhor ter mais informação do que perder algo importante, tudo isso matendo uma organização, não deixe conteudo incompleto, não coloque asteriscos no conteudo.

Conversa:
$historico
"""
                }
              ]
            }
          ],
        "generationConfig": {"temperature": 0.3, "maxOutputTokens": 4096}
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final resumo = data["candidates"][0]["content"]["parts"][0]["text"] as String;

        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        // Lê o texto atual da nota
        final docRef = FirebaseFirestore.instance
            .collection("usuarios").doc(user.uid).collection("notas").doc(widget.notaId);
        final docSnap = await docRef.get();
        final textoAtual = (docSnap.data() as Map<String, dynamic>?)?["texto"] ?? "";

        // Atualiza a nota adicionando os novos pontos
        final novoTexto = textoAtual.isNotEmpty
            ? "$textoAtual\n\n--- Atualizado pela IA ---\n$resumo"
            : resumo;

        await docRef.update({"texto": novoTexto, "data": FieldValue.serverTimestamp()});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text("Anotação atualizada com sucesso!"),
                ],
              ),
              backgroundColor: const Color(0xFF4A148C),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao salvar: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => isSavingNota = false);
    }
  }

  void _novaConversa() => setState(() { mensagens.clear(); _conversaId = null; });

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text("Chat com IA", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (mensagens.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add_comment_outlined),
              tooltip: "Nova conversa",
              onPressed: _novaConversa,
            ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: "Histórico",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
          ),
        ],
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [

            // Banner da anotação anexada
            if (widget.textoInicial != null)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A148C).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF4A148C).withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => bannerExpandido = !bannerExpandido),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.attach_file, size: 16, color: Color(0xFF4A148C)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.notaTitulo ?? "Anotação anexada",
                                style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4A148C)),
                              ),
                            ),
                            Icon(
                              bannerExpandido ? Icons.expand_less : Icons.expand_more,
                              size: 18, color: const Color(0xFF4A148C),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (bannerExpandido)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Text(
                          widget.textoInicial!,
                          style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.5),
                          maxLines: 8,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),

            // Área do chat
            Expanded(
              child: mensagens.isEmpty && !isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A148C).withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.auto_awesome, color: Color(0xFF4A148C), size: 48),
                          ),
                          const SizedBox(height: 16),
                          const Text("Tutora de Estudos",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A148C))),
                          const SizedBox(height: 8),
                          const Text(
                            "Cole suas anotações ou faça uma pergunta.\nPressione Enter para enviar.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: mensagens.length + (isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == mensagens.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Row(
                                    children: [
                                      SizedBox(width: 16, height: 16,
                                          child: CircularProgressIndicator(color: Color(0xFF4A148C), strokeWidth: 2)),
                                      SizedBox(width: 10),
                                      Text("Analisando...", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final mensagem = mensagens[index];
                        final isUltima = index == mensagens.length - 1;
                        final isRespostaIA = !mensagem.isUsuario;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildBolha(mensagem),
                            // Botão "Salvar na anotação" aparece após última resposta da IA
                            if (isUltima && isRespostaIA && widget.notaId != null && !isLoading)
                              Padding(
                                padding: const EdgeInsets.only(top: 8, bottom: 4),
                                child: Center(
                                  child: TextButton.icon(
                                    onPressed: isSavingNota ? null : _salvarNaAnotacao,
                                    icon: isSavingNota
                                        ? const SizedBox(width: 14, height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4A148C)))
                                        : const Icon(Icons.save_outlined, size: 16, color: Color(0xFF4A148C)),
                                    label: Text(
                                      isSavingNota ? "Salvando..." : "Salvar pontos na anotação",
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF4A148C)),
                                    ),
                                    style: TextButton.styleFrom(
                                      backgroundColor: const Color(0xFF4A148C).withOpacity(0.08),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
            ),

            // Barra de input
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF4A148C).withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: KeyboardListener(
                        focusNode: FocusNode(),
                        onKeyEvent: (event) {
                          if (event is KeyDownEvent &&
                              event.logicalKey == LogicalKeyboardKey.enter &&
                              !HardwareKeyboard.instance.isShiftPressed &&
                              !isLoading) {
                            enviarMensagem();
                          }
                        },
                        child: TextField(
                          controller: controller,
                          focusNode: _focusNode,
                          maxLines: null,
                          decoration: const InputDecoration(
                            hintText: "Faça uma pergunta sobre o conteúdo...",
                            hintStyle: TextStyle(fontSize: 13),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: IconButton(
                        onPressed: isLoading ? null : enviarMensagem,
                        icon: isLoading
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4A148C)))
                            : const Icon(Icons.send_rounded),
                        color: const Color(0xFF4A148C),
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

  Widget _buildBolha(Mensagem mensagem) {
    final isUsuario = mensagem.isUsuario;
    return Align(
      alignment: isUsuario ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: isUsuario ? const Color(0xFF4A148C) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUsuario ? 18 : 4),
            bottomRight: Radius.circular(isUsuario ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: isUsuario
            ? Text(mensagem.texto, style: const TextStyle(color: Colors.white, fontSize: 14))
            : MarkdownBody(
                data: mensagem.texto,
                softLineBreak: true,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
                  h3: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF4A148C)),
                ),
              ),
      ),
    );
  }
}