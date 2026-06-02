import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notes_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();
  bool isLoading = false;
  bool isCadastro = false;
  bool senhaVisivel = false;
  String erro = "";

  Future<void> entrarOuCadastrar() async {
    setState(() { isLoading = true; erro = ""; });

    try {
      if (isCadastro) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: senhaController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: senhaController.text.trim(),
        );
      }
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const NotesScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'user-not-found': erro = "Usuário não encontrado."; break;
          case 'wrong-password': erro = "Senha incorreta."; break;
          case 'invalid-credential': erro = "E-mail ou senha incorretos."; break;
          case 'email-already-in-use': erro = "E-mail já cadastrado."; break;
          case 'weak-password': erro = "Senha muito fraca. Use pelo menos 6 caracteres."; break;
          case 'invalid-email': erro = "E-mail inválido."; break;
          default: erro = "Erro: ${e.message}";
        }
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4A148C), Color(0xFF7B1FA2), Color(0xFF9C27B0)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Header com logo
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 48),
                  ),
                  const SizedBox(height: 16),
                  const Text("Study AI",
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Text(
                    isCadastro ? "Crie sua conta gratuita" : "Seu assistente de estudos",
                    style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.8)),
                  ),
                  const SizedBox(height: 40),

                  // Card de login
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCadastro ? "Criar conta" : "Entrar",
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF4A148C)),
                        ),
                        const SizedBox(height: 20),

                        // Campo e-mail
                        KeyboardListener(
                          focusNode: FocusNode(),
                          onKeyEvent: (event) {
                            if (event is KeyDownEvent &&
                                event.logicalKey == LogicalKeyboardKey.enter &&
                                !isLoading) {
                              entrarOuCadastrar();
                            }
                          },
                          child: TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: "E-mail",
                              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF7B1FA2)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF7B1FA2), width: 2),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Campo senha com Enter para enviar
                        TextField(
                          controller: senhaController,
                          obscureText: !senhaVisivel,
                          onSubmitted: (_) { if (!isLoading) entrarOuCadastrar(); },
                          decoration: InputDecoration(
                            labelText: "Senha",
                            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF7B1FA2)),
                            suffixIcon: IconButton(
                              icon: Icon(senhaVisivel ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey),
                              onPressed: () => setState(() => senhaVisivel = !senhaVisivel),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF7B1FA2), width: 2),
                            ),
                          ),
                        ),

                        // Mensagem de erro
                        if (erro.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red.shade700, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(erro,
                                    style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
                              ],
                            ),
                          ),

                        const SizedBox(height: 20),

                        // Botão principal
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : entrarOuCadastrar,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4A148C),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: isLoading
                                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                : Text(isCadastro ? "Criar conta" : "Entrar",
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Alternar login/cadastro
                        Center(
                          child: TextButton(
                            onPressed: () => setState(() { isCadastro = !isCadastro; erro = ""; }),
                            child: Text(
                              isCadastro ? "Já tenho uma conta. Entrar" : "Não tenho conta. Cadastrar",
                              style: const TextStyle(color: Color(0xFF7B1FA2), fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}