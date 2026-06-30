// 登录/注册页面（邮箱 + 验证码）
import 'package:flutter/material.dart';
import 'theme/colors.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'main.dart';
import 'pages/shell.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
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
      if (code.length != 6) {
        setState(() {
          _error = '请输入6位验证码';
          _loading = false;
        });
        return;
      }
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
        child: LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= 760;
          final form = _loginPanel();
          if (!wide) {
            return Center(child: SingleChildScrollView(padding: const EdgeInsets.all(22), child: form));
          }
          return Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940),
            child: Padding(padding: const EdgeInsets.all(32), child: Row(children: [
              Expanded(child: _brandIntro()),
              const SizedBox(width: 42),
              SizedBox(width: 410, child: form),
            ])),
          ));
        }),
      ),
    );
  }

  Widget _brandIntro() => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    Container(width: 54, height: 54, decoration: BoxDecoration(color: C.selected, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.tablet_mac_rounded, color: C.brand, size: 28)),
    const SizedBox(height: 18),
    Text('机掌柜', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: C.t1)),
    const SizedBox(height: 8),
    Text('二手 iPad 经营工作台', style: TextStyle(fontSize: 15, color: C.t2, fontWeight: FontWeight.w600)),
  ]);

  Widget _loginPanel() => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line), boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 18, offset: Offset(0, 8))]),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_isRegister ? '创建账号' : '欢迎回来', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: C.t1)),
      const SizedBox(height: 6),
      Text(_isRegister ? '填写邮箱、密码与验证码' : '使用邮箱和密码进入工作台', style: TextStyle(fontSize: 12, color: C.t2)),
      const SizedBox(height: 22),
      _input('邮箱地址', _emailCtrl, hint: 'your@email.com', icon: Icons.mail_outline_rounded),
      const SizedBox(height: 14),
      _input('密码', _passCtrl, obscure: true, hint: '至少6位', icon: Icons.lock_outline_rounded),
      const SizedBox(height: 14),
      if (_isRegister) ...[
        Row(children: [
          Expanded(child: _input('验证码', _codeCtrl, hint: '6位数字', icon: Icons.pin_outlined)),
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _loading || _countdown > 0 ? null : _sendCode,
              style: ElevatedButton.styleFrom(backgroundColor: _countdown > 0 ? C.t3 : C.brand, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
              child: Text(_countdown > 0 ? '${_countdown}s' : '获取验证码', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
        const SizedBox(height: 14),
      ],
      if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(_error!, style: TextStyle(color: C.red, fontSize: 12, fontWeight: FontWeight.w600))),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: C.brand, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
          child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_isRegister ? '注册并登录' : '登录', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ),
      ),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_isRegister ? '已有账号？' : '没有账号？', style: TextStyle(fontSize: 12, color: C.t2)),
        GestureDetector(onTap: () => setState(() { _isRegister = !_isRegister; _error = null; }), child: Text(_isRegister ? '去登录' : '去注册', style: TextStyle(fontSize: 12, color: C.brand, fontWeight: FontWeight.w800))),
      ]),
      const SizedBox(height: 16),
      Center(child: TextButton(
        onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainShell())),
        child: Text('离线使用', style: TextStyle(fontSize: 12, color: C.t3, fontWeight: FontWeight.w700)),
      )),
    ]),
  );

  Widget _input(String label, TextEditingController ctrl, {String? hint, bool obscure = false, IconData? icon}) => TextField(
    controller: ctrl,
    obscureText: obscure,
    style: TextStyle(color: C.t1, fontSize: 14),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, color: C.t3, size: 18),
      labelStyle: TextStyle(color: C.t2, fontSize: 13),
      hintStyle: TextStyle(color: C.t3, fontSize: 12),
      filled: true,
      fillColor: C.card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: C.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: C.brand2)),
    ),
  );
}
