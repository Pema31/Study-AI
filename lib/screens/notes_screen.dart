import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'home.dart';
import 'history_screen.dart';
import 'login_screen.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final nome = user?.email?.split('@')[0] ?? 'aluno';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text("Study AI", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_outlined),
            tooltip: "Chat com IA",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Home())),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: "Histórico",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Sair",
            onPressed: () => _logout(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text("Nova anotação"),
        onPressed: () => _abrirEditor(context, null, null),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            decoration: const BoxDecoration(
              color: Color(0xFF4A148C),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Olá, $nome! 👋",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text("Suas anotações de estudo",
                    style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8))),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("usuarios")
                  .doc(user?.uid)
                  .collection("notas")
                  .orderBy("data", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF4A148C)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A148C).withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.note_add_outlined, size: 48, color: Color(0xFF7B1FA2)),
                        ),
                        const SizedBox(height: 16),
                        const Text("Nenhuma anotação ainda",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black54)),
                        const SizedBox(height: 6),
                        const Text("Toque em + para criar sua primeira anotação",
                            style: TextStyle(fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  );
                }
                final notas = snapshot.data!.docs;
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: notas.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = notas[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final titulo = data["titulo"] ?? "Sem título";
                    final texto = data["texto"] ?? "";
                    final cores = [
                      const Color(0xFFEDE7F6),
                      const Color(0xFFE8EAF6),
                      const Color(0xFFE3F2FD),
                      const Color(0xFFF3E5F5),
                    ];
                    final cor = cores[index % cores.length];
                    return Card(
                      color: cor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _abrirCard(context, doc.id, data),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(titulo,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4A148C))),
                                  ),
                                  PopupMenuButton(
                                    icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(value: "editar", child: Text("Editar")),
                                      const PopupMenuItem(value: "excluir",
                                          child: Text("Excluir", style: TextStyle(color: Colors.red))),
                                    ],
                                    onSelected: (value) async {
                                      if (value == "editar") {
                                        _abrirEditor(context, doc.id, data);
                                      } else if (value == "excluir") {
                                        await _excluirNota(user!.uid, doc.id);
                                      }
                                    },
                                  ),
                                ],
                              ),
                              if (texto.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(texto,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.4)),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  InkWell(
                                    onTap: texto.isNotEmpty
                                        ? () => Navigator.push(context,
                                              MaterialPageRoute(builder: (_) => Home(
                                                textoInicial: texto,
                                                notaId: doc.id,
                                                notaTitulo: titulo,
                                              )))
                                        : null,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4A148C).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.auto_awesome, size: 13, color: Color(0xFF4A148C)),
                                          SizedBox(width: 4),
                                          Text("Analisar com IA",
                                              style: TextStyle(fontSize: 12, color: Color(0xFF4A148C),
                                                  fontWeight: FontWeight.w500)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _abrirEditor(BuildContext context, String? docId, Map<String, dynamic>? data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NoteEditorSheet(docId: docId, data: data),
    );
  }

  void _abrirCard(BuildContext context, String docId, Map<String, dynamic> data) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => NoteDetailScreen(docId: docId, data: data)));
  }

  Future<void> _excluirNota(String uid, String docId) async {
    await FirebaseFirestore.instance
        .collection("usuarios").doc(uid).collection("notas").doc(docId).delete();
  }
}

// ─── Editor de nota ───────────────────────────────────────────────────────────
class NoteEditorSheet extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? data;
  const NoteEditorSheet({super.key, this.docId, this.data});

  @override
  State<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<NoteEditorSheet> {
  late TextEditingController tituloController;
  late TextEditingController textoController;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    tituloController = TextEditingController(text: widget.data?["titulo"] ?? "");
    textoController = TextEditingController(text: widget.data?["texto"] ?? "");
  }

  Future<void> _salvar() async {
    final titulo = tituloController.text.trim();
    final texto = textoController.text.trim();
    if (titulo.isEmpty) return;
    setState(() => isSaving = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ref = FirebaseFirestore.instance.collection("usuarios").doc(user.uid).collection("notas");
    if (widget.docId == null) {
      await ref.add({"titulo": titulo, "texto": texto, "data": FieldValue.serverTimestamp()});
    } else {
      await ref.doc(widget.docId).update({"titulo": titulo, "texto": texto, "data": FieldValue.serverTimestamp()});
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // ✅ SingleChildScrollView evita overflow quando teclado sobe
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(widget.docId == null ? "Nova Anotação" : "Editar Anotação",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4A148C))),
            const SizedBox(height: 20),
            TextField(
              controller: tituloController,
              decoration: InputDecoration(
                labelText: "Título",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF7B1FA2), width: 2)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textoController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: "Anotação",
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF7B1FA2), width: 2)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: isSaving ? null : _salvar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A148C), foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isSaving
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : const Text("Salvar", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Detalhe do card ──────────────────────────────────────────────────────────
class NoteDetailScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  const NoteDetailScreen({super.key, required this.docId, required this.data});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  final TextEditingController _novaAnotacaoController = TextEditingController();
  bool isSaving = false;
  bool isGerandoQuiz = false;
  List<String> _perguntasAnteriores = [];

  static const String _apiKey = "AIzaSyC-VejxORSe6T5b6KX5bDONgrVeyq--7Yg";
  static const String _model = "gemini-2.5-flash";

  @override
  void initState() {
    super.initState();
    _carregarPerguntasAnteriores();
  }

  Future<void> _carregarPerguntasAnteriores() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection("usuarios").doc(user.uid).collection("notas").doc(widget.docId).get();
    final data = doc.data();
    if (data != null && data["perguntasQuiz"] != null) {
      setState(() {
        _perguntasAnteriores = List<String>.from(data["perguntasQuiz"]);
      });
    }
  }

  Future<void> _salvarPerguntasAnteriores() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection("usuarios").doc(user.uid).collection("notas").doc(widget.docId)
        .update({"perguntasQuiz": _perguntasAnteriores});
  }

  Future<void> _adicionarAnotacao() async {
    final novoTexto = _novaAnotacaoController.text.trim();
    if (novoTexto.isEmpty) return;
    setState(() => isSaving = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final docRef = FirebaseFirestore.instance
        .collection("usuarios").doc(user.uid).collection("notas").doc(widget.docId);
    final docSnap = await docRef.get();
    final textoAtual = (docSnap.data() as Map<String, dynamic>?)?["texto"] ?? "";
    final textoAtualizado = textoAtual.isNotEmpty ? "$textoAtual\n$novoTexto" : novoTexto;
    await docRef.update({"texto": textoAtualizado, "data": FieldValue.serverTimestamp()});
    _novaAnotacaoController.clear();
    setState(() => isSaving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text("Anotação adicionada!"),
          ]),
          backgroundColor: const Color(0xFF4A148C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _gerarQuiz(String textoNota) async {
    if (textoNota.isEmpty) return;
    setState(() => isGerandoQuiz = true);

    try {
      final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey",
      );

      final historicoPerguntas = _perguntasAnteriores.isEmpty
          ? "Nenhuma pergunta feita ainda."
          : _perguntasAnteriores.map((p) => "- $p").join("\n");

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {
                  "text": """
Com base no conteúdo abaixo, crie um quiz com 5 perguntas de múltipla escolha (A, B, C, D).

REGRAS OBRIGATÓRIAS:
- NÃO repita nenhuma das perguntas listadas em "PERGUNTAS JÁ FEITAS".
- Explore APENAS aspectos do conteúdo que ainda NÃO foram abordados nas perguntas anteriores.
- Distribua as respostas corretas entre A, B, C e D. Use cada letra pelo menos uma vez.
- Varie a dificuldade entre fácil, médio e difícil.
- Semente: ${DateTime.now().millisecondsSinceEpoch}

PERGUNTAS JÁ FEITAS (não repita nenhuma delas):
$historicoPerguntas

Formato OBRIGATÓRIO para cada pergunta:
PERGUNTA: [texto]
A) [opção]
B) [opção]
C) [opção]
D) [opção]
RESPOSTA: [A, B, C ou D]
EXPLICAÇÃO: [explicação]

---
Conteúdo:
$textoNota
"""
                }
              ]
            }
          ],
          "generationConfig": {"temperature": 0.9, "maxOutputTokens": 8192}
        }),
      );

      // ✅ Print para debug — ver o que a API retorna
      print("=== STATUS: ${response.statusCode} ===");
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final texto = data["candidates"][0]["content"]["parts"][0]["text"] as String;

        print("=== RESPOSTA DA API ===");
        print(texto);
        print("=== FIM ===");

        final novasPerguntas = RegExp(r'PERGUNTA:\s*(.+)')
            .allMatches(texto)
            .map((m) => m.group(1)?.trim() ?? '')
            .where((p) => p.isNotEmpty)
            .toList();

        print("=== PERGUNTAS ENCONTRADAS: ${novasPerguntas.length} ===");

        _perguntasAnteriores.addAll(novasPerguntas);
        await _salvarPerguntasAnteriores();

        if (mounted) {
          setState(() => isGerandoQuiz = false);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => QuizScreen(conteudoQuiz: texto)),
          );
        }
      } else {
        print("=== ERRO DA API ===");
        print(response.body);
        setState(() => isGerandoQuiz = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erro ${response.statusCode}"), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      print("=== EXCEÇÃO: $e ===");
      setState(() => isGerandoQuiz = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao gerar quiz: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("usuarios")
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection("notas")
          .doc(widget.docId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? widget.data;
        final titulo = data["titulo"] ?? "Sem título";
        final texto = data["texto"] ?? "";

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: AppBar(
            backgroundColor: const Color(0xFF4A148C),
            foregroundColor: Colors.white,
            elevation: 0,
            title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: isGerandoQuiz
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.quiz_outlined),
                tooltip: "Gerar Quiz",
                onPressed: isGerandoQuiz ? null : () => _gerarQuiz(texto),
              ),
              IconButton(
                icon: const Icon(Icons.auto_awesome),
                tooltip: "Analisar com IA",
                onPressed: texto.isNotEmpty
                    ? () => Navigator.pushReplacement(context,
                          MaterialPageRoute(builder: (_) => Home(
                            textoInicial: texto,
                            notaId: widget.docId,
                            notaTitulo: titulo,
                          )))
                    : null,
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        texto.isNotEmpty ? texto : "Nenhum conteúdo.",
                        style: const TextStyle(fontSize: 15, height: 1.7),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF4A148C).withOpacity(0.2)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _novaAnotacaoController,
                          maxLines: null,
                          decoration: const InputDecoration(
                            hintText: "Adicionar mais anotações...",
                            hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: IconButton(
                          onPressed: isSaving ? null : _adicionarAnotacao,
                          icon: isSaving
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4A148C)))
                              : const Icon(Icons.add_circle_outline, color: Color(0xFF4A148C)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Tela do Quiz ─────────────────────────────────────────────────────────────
class QuizScreen extends StatefulWidget {
  final String conteudoQuiz;
  const QuizScreen({super.key, required this.conteudoQuiz});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late List<Map<String, dynamic>> perguntas;
  int perguntaAtual = 0;
  String? respostaSelecionada;
  bool mostrarResposta = false;
  int acertos = 0;

  @override
  void initState() {
    super.initState();
    perguntas = _parsearQuiz(widget.conteudoQuiz);
  }

  List<Map<String, dynamic>> _parsearQuiz(String texto) {
    final lista = <Map<String, dynamic>>[];
    final blocos = texto.split(RegExp(r'PERGUNTA:', multiLine: true));
    for (var bloco in blocos) {
      if (bloco.trim().isEmpty) continue;
      final linhas = bloco.trim().split('\n').map((l) => l.trim()).toList();
      if (linhas.isEmpty) continue;
      final pergunta = linhas[0].trim();
      final opcoes = <String, String>{};
      String resposta = '';
      String explicacao = '';
      for (var linha in linhas) {
        if (linha.startsWith('A)')) opcoes['A'] = linha.substring(2).trim();
        else if (linha.startsWith('B)')) opcoes['B'] = linha.substring(2).trim();
        else if (linha.startsWith('C)')) opcoes['C'] = linha.substring(2).trim();
        else if (linha.startsWith('D)')) opcoes['D'] = linha.substring(2).trim();
        else if (linha.startsWith('RESPOSTA:')) resposta = linha.substring(9).trim().toUpperCase();
        else if (linha.startsWith('EXPLICAÇÃO:') || linha.startsWith('EXPLICACAO:'))
          explicacao = linha.contains(':') ? linha.substring(linha.indexOf(':') + 1).trim() : '';
      }
      if (pergunta.isNotEmpty && opcoes.length == 4) {
        lista.add({"pergunta": pergunta, "opcoes": opcoes, "resposta": resposta, "explicacao": explicacao});
      }
    }
    return lista;
  }

  void _responder(String letra) {
    if (mostrarResposta) return;
    setState(() {
      respostaSelecionada = letra;
      mostrarResposta = true;
      if (letra == perguntas[perguntaAtual]["resposta"]) acertos++;
    });
  }

  void _proxima() {
    if (perguntaAtual < perguntas.length - 1) {
      setState(() {
        perguntaAtual++;
        respostaSelecionada = null;
        mostrarResposta = false;
      });
    } else {
      _mostrarResultado();
    }
  }

  void _mostrarResultado() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Resultado", textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A148C))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("$acertos/${perguntas.length}",
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF4A148C))),
            const SizedBox(height: 8),
            Text(
              acertos == perguntas.length ? "Perfeito! 🎉" :
              acertos >= perguntas.length ~/ 2 ? "Bom trabalho! 👍" : "Continue estudando! 📚",
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            child: const Text("Fechar"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A148C), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Novo quiz"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (perguntas.isEmpty) {
      return Scaffold(
        appBar: AppBar(backgroundColor: const Color(0xFF4A148C), foregroundColor: Colors.white,
            title: const Text("Quiz")),
        body: const Center(child: Text("Não foi possível gerar o quiz.")),
      );
    }

    final p = perguntas[perguntaAtual];
    final opcoes = p["opcoes"] as Map<String, String>;
    final respostaCorreta = p["resposta"] as String;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text("Quiz — ${perguntaAtual + 1}/${perguntas.length}",
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: (perguntaAtual + 1) / perguntas.length,
                backgroundColor: Colors.grey[200],
                color: const Color(0xFF4A148C),
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
                ),
                child: Text(p["pergunta"],
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4)),
              ),
              const SizedBox(height: 16),
              ...opcoes.entries.map((entry) {
                final letra = entry.key;
                final opcao = entry.value;
                Color cor = Colors.white;
                Color textoCor = Colors.black87;
                if (mostrarResposta) {
                  if (letra == respostaCorreta) { cor = Colors.green.shade100; textoCor = Colors.green.shade800; }
                  else if (letra == respostaSelecionada) { cor = Colors.red.shade100; textoCor = Colors.red.shade800; }
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => _responder(letra),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: cor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: mostrarResposta && letra == respostaCorreta
                              ? Colors.green : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A148C).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(child: Text(letra,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A148C)))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(opcao, style: TextStyle(fontSize: 14, color: textoCor))),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              if (mostrarResposta && p["explicacao"].isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A148C).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Color(0xFF4A148C)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(p["explicacao"],
                          style: const TextStyle(fontSize: 13, color: Colors.black54))),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              if (mostrarResposta)
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: _proxima,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A148C), foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      perguntaAtual < perguntas.length - 1 ? "Próxima pergunta" : "Ver resultado",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}