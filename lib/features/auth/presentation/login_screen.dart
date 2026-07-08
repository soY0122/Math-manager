import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_provider.dart';
import '../../../core/widgets/math_button.dart';
import '../../../core/widgets/math_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final success = await ref.read(authNotifierProvider.notifier).signIn(email, password);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('성공적으로 로그인되었습니다!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1E293B),
                    const Color(0xFF0F172A),
                  ]
                : [
                    const Color(0xFFEFF6FF),
                    const Color(0xFFDBEAFE),
                  ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Math Manager Branded Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.functions_rounded,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Title
                  Text(
                    'MATH MANAGER',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '수학 학원 관리 솔루션',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Login Input Card
                  Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(24.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.shade100,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Email field
                        MathTextField(
                          controller: _emailController,
                          labelText: '이메일',
                          hintText: 'teacher@academy.com',
                          keyboardType: TextInputType.emailAddress,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return '이메일을 입력해주세요.';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                              return '올바른 이메일 형식을 입력해주세요.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Password field
                        MathTextField(
                          controller: _passwordController,
                          labelText: '비밀번호',
                          hintText: '비밀번호를 입력하세요',
                          obscureText: true,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return '비밀번호를 입력해주세요.';
                            }
                            if (val.trim().length < 6) {
                              return '비밀번호는 최소 6자 이상이어야 합니다.';
                            }
                            return null;
                          },
                        ),
                        
                        // Error message indicator
                        if (authState.errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  authState.errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 32),

                        // Login button
                        MathButton(
                          text: '로그인',
                          isLoading: authState.isLoading,
                          onPressed: authState.isLoading ? null : _submit,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
