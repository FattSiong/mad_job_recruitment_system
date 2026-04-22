import 'package:flutter/material.dart';
import '../../modules/admin/screens/admin_dashboard.dart'; // 导入你的Admin页面

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // 控制是 Login 还是 Sign Up
  bool isLogin = true;

  // 用于获取输入的 Email 和 Password
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _handleAuth() {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    // 关键逻辑：如果是特定的 Admin 账号
    if (email == "admin@jobs.com" && password == "admin123") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminDashboard()),
      );
    } else {
      // 其他账号（求职者或雇主）跳转逻辑
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Logged in as User")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // 标题根据状态切换
            Text(
              isLogin ? "Login" : "Sign Up",
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1A2A4D)),
            ),
            const SizedBox(height: 40),

            // Email 输入框
            _buildTextField(_emailController, "Email", Icons.email_outlined),
            const SizedBox(height: 20),

            // Password 输入框
            _buildTextField(_passwordController, "Password", Icons.lock_outline, isObscure: true),
            const SizedBox(height: 40),

            // 提交按钮：不再显示 "Continue as Admin"
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _handleAuth,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A2A4D),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: Text(
                  isLogin ? "Log In" : "Create Account",
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 25),

            // 切换 Login 和 Sign Up 的入口
            Center(
              child: GestureDetector(
                onTap: () => setState(() => isLogin = !isLogin),
                child: RichText(
                  text: TextSpan(
                    text: isLogin ? "Don't have an account? " : "Already have an account? ",
                    style: const TextStyle(color: Colors.grey),
                    children: [
                      TextSpan(
                        text: isLogin ? "Sign Up" : "Log In",
                        style: const TextStyle(color: Color(0xFF1A2A4D), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool isObscure = false}) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey, size: 20),
        filled: true,
        fillColor: const Color(0xFFF9F9F7),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }
}