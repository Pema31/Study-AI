import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<void> _deletarConversa(BuildContext context, String uid, String docId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Excluir conversa"),
        content: const Text("Tem certeza que deseja excluir esta conversa? Esta ação não pode ser desfeita."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Excluir"),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await FirebaseFirestore.instance
          .collection("usuarios")
          .doc(uid)
          .collection("conversas")
          .doc(docId)
          .delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text("Histórico", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("usuarios")
            .doc(user?.uid)
            .collection("conversas")
            .orderBy("data", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF4A148C)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 60, color: Colors.grey),
                  SizedBox(height: 12),
                  Text("Nenhuma conversa salva ainda.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final conversas = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: conversas.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = conversas[index];
              final data = doc.data() as Map<String, dynamic>;
              final titulo = data["titulo"] ?? "Sem título";
              final timestamp = data["data"] as Timestamp?;
              final dataFormatada = timestamp != null ? _formatarData(timestamp.toDate()) : "";
              final mensagens = data["mensagens"] as List<dynamic>?;
              final totalMensagens = mensagens != null ? "${mensagens.length} mensagens" : "conversa antiga";

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A148C).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.chat_outlined, color: Color(0xFF4A148C), size: 20),
                  ),
                  title: Text(
                    titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "$dataFormatada · $totalMensagens",
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                  trailing: PopupMenuButton(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: "abrir",
                        child: Row(
                          children: [
                            Icon(Icons.open_in_new, size: 18, color: Colors.black54),
                            SizedBox(width: 10),
                            Text("Abrir"),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: "excluir",
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            SizedBox(width: 10),
                            Text("Excluir", style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) async {
                      if (value == "abrir") {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ConversaScreen(data: data, conversaId: doc.id),
                          ),
                        );
                      } else if (value == "excluir") {
                        await _deletarConversa(context, user!.uid, doc.id);
                      }
                    },
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ConversaScreen(data: data, conversaId: doc.id),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatarData(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }
}

class Mensagem {
  final String texto;
  final bool isUsuario;
  Mensagem({required this.texto, required this.isUsuario});
}

class ConversaScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String conversaId;
  const ConversaScreen({super.key, required this.data, required this.conversaId});

  @override
  State<ConversaScreen> createState() => _ConversaScreenState();
}

class _ConversaScreenState extends State<ConversaScreen> {
  final TextEditingController controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late List<Mensagem> mensagens;
  bool isLoading = false;

  static const String _apiKey = "SUA_CHAVE_AQUI";
  static const String _model = "gemini-2.5-flash";

  @override
  void initState() {
    super.initState();
    mensagens = _carregarMensagens();
  }

  List<Mensagem> _carregarMensagens() {
    final msgs = widget.data["mensagens"] as List<dynamic>?;
    if (msgs != null) {
      return msgs.map((m) {
        final msg = m as Map<String, dynamic>;
        return Mensagem(texto: msg["texto"], isUsuario: msg["isUsuario"]);
      }).toList();
    } else {
      final anotacoes = widget.data["anotacoes"] as String? ?? "";
      final resposta = widget.data["resposta"] as String? ?? "";
      return [
        Mensagem(texto: anotacoes, isUsuario: true),
        Mensagem(texto: resposta, isUsuario: false),
      ];
    }
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

    final historico = mensagens
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
    final mensagensJson = mensagens.map((m) => {"texto": m.texto, "isUsuario": m.isUsuario}).toList();
    await FirebaseFirestore.instance
        .collection("usuarios").doc(user.uid).collection("conversas").doc(widget.conversaId)
        .update({"mensagens": mensagensJson, "data": FieldValue.serverTimestamp()});
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text("Conversa", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: mensagens.length + (isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == mensagens.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
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
                  return _buildBolha(mensagens[index]);
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
                          maxLines: null,
                          decoration: const InputDecoration(
                            hintText: "Continue a conversa...",
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