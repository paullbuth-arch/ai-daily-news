// 登录/注册页面（邮箱 + 验证码）
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  bool _isRegister = false; // true=注册(需验证码), false=登录(仅密码)
  int _countdown = 0;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdown = 60;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        if (_countdown > 0) _countdown--;
      });
      return _countdown > 0;
    });
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) { setState(() => _error = '请输入正确的邮箱'); return; }
    setState(() { _loading = true; _error = null; });
    final err = await ApiService.sendCode(email);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (err == null) {
        _codeSent = true;
        _startCountdown();
      } else {
        _error = err;
      }
    });
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    if (!email.contains('@')) { setState(() => _error = '请输入正确的邮箱'); return; }
    if (password.length < 6) { setState(() => _error = '密码至少6位'); return; }

    setState(() { _loading = true; _error = null; });

    Map<String, dynamic> result;
    if (_isRegister) {
      final code = _codeCtrl.text.trim();
      if (code.length != 6) { setState(() => _error = '请输入6位验证码'); _loading = false; return; }
      result = await ApiService.register(email, password, code);
    } else {
      result = await ApiService.login(email, password);
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (result['error'] != null) {
      setState(() => _error = result['error'] as String);
      // 如果是"邮箱未注册"，自动切换到注册模式
      if (result['error'].toString().contains('未注册')) {
        setState(() => _isRegister = true);
      }
      return;
    }

    final token = result['token'] as String;
    await AuthService.login(gStorage, token, email);
    if (!mounted) return;
    // 跳转到主页面
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainShell()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              // Logo
              Container(width: 72, height: 72, decoration: BoxDecoration(gradient: LinearGradient(colors: [C.brand, C.brand2]), borderRadius: BorderRadius.circular(20)), child: Center(child: Text('📱', style: TextStyle(fontSize: 32)))),
              const SizedBox(height: 16),
              Text('机掌柜', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: C.t1)),
              const SizedBox(height: 4),
              Text('二手iPad经营管理系统', style: TextStyle(fontSize: 13, color: C.t2)),
              const SizedBox(height: 36),

              // 邮箱
              _input('邮箱地址', _emailCtrl, hint: 'your@email.com'),
              const SizedBox(height: 14),

              // 密码
              _input('密码', _passCtrl, obscure: true, hint: '至少6位'),
              const SizedBox(height: 14),

              // 验证码（仅注册时）
              if (_isRegister) ...[
                Row(children: [
                  Expanded(child: _input('验证码', _codeCtrl, hint: '6位数字')),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading || _countdown > 0 ? null : _sendCode,
                      style: ElevatedButton.styleFrom(primary: _countdown > 0 ? C.t3 : C.brand, onPrimary: Colors.white, padding: EdgeInsets.symmetric(horizontal: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                      child: Text(_countdown > 0 ? '${_countdown}s' : '获取验证码', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
              ],

              // 错误提示
              if (_error != null) Padding(padding: EdgeInsets.only(bottom: 14), child: Text(_error!, style: TextStyle(color: C.red, fontSize: 12))),

              // 提交按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(primary: C.brand, onPrimary: Colors.white, padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)), elevation: 0),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_isRegister ? '注册并登录' : '登录', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),

              // 切换模式
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(_isRegister ? '已有账号？' : '没有账号？', style: TextStyle(fontSize: 12, color: C.t2)),
                GestureDetector(onTap: () => setState(() { _isRegister = !_isRegister; _error = null; }), child: Text(_isRegister ? '去登录' : '去注册', style: TextStyle(fontSize: 12, color: C.brand2, fontWeight: FontWeight.w600))),
              ]),

              // 离线模式
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainShell())),
                child: Text('跳过登录，离线使用', style: TextStyle(fontSize: 12, color: C.t3)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _input(String label, TextEditingController ctrl, {String? hint, bool obscure = false}) => TextField(
    controller: ctrl,
    obscureText: obscure,
    style: TextStyle(color: C.t1, fontSize: 14),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: C.t2, fontSize: 13),
      hintStyle: TextStyle(color: C.t3, fontSize: 12),
      filled: true,
      fillColor: C.card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: C.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: C.brand2)),
    ),
  );
}
