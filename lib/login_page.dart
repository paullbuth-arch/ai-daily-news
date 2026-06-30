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

/// 扫描线动画效果
class _ScanLineEffect extends StatefulWidget {
  const _ScanLineEffect();

  @override
  State<_ScanLineEffect> createState() => _ScanLineEffectState();
}

class _ScanLineEffectState extends State<_ScanLineEffect> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _animation = Tween<double>(begin: -0.1, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _ScanLinePainter(_animation.value),
            );
          },
        );
      },
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  final double progress;

  _ScanLinePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00F0FF).withOpacity(0.06)
      ..style = PaintingStyle.fill;
    const lineHeight = 2.0;
    final y = progress * size.height;
    if (y > -lineHeight && y < size.height + lineHeight) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, lineHeight), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter oldDelegate) => oldDelegate.progress != progress;
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _isRegister = false; // true=注册(需验证码), false=登录(仅密码)
  int _countdown = 0;
  String? _error;

  late final AnimationController _scanController;
  late final Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _scanAnimation = Tween<double>(begin: -0.1, end: 1.1).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passCtrl.dispose();
    _scanController.dispose();
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
      backgroundColor: C.bgDeep,
      body: Stack(
        children: [
          const _ScanLineEffect(),
          SafeArea(
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
        ],
      ),
    );
  }

  Widget _brandIntro() => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: C.heroGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: C.cyan.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4)),
          BoxShadow(color: C.purple.withOpacity(0.3), blurRadius: 24, offset: const Offset(0, 0)),
        ],
      ),
      child: const Icon(Icons.tablet_mac_rounded, color: Colors.white, size: 32),
    ),
    const SizedBox(height: 20),
    Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => C.heroGradient.createShader(bounds),
          child: const Text(
            '机掌柜',
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: C.cyan, width: 1),
            boxShadow: [BoxShadow(color: C.cyan.withOpacity(0.3), blurRadius: 8)],
          ),
          child: const Text(
            'PRO',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: C.cyan),
          ),
        ),
      ],
    ),
    const SizedBox(height: 10),
    Text('二手 iPad 经营工作台', style: TextStyle(fontSize: 15, color: C.t2, fontWeight: FontWeight.w600)),
  ]);

  Widget _loginPanel() => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: C.bgCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: C.border),
      boxShadow: [
        const BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 8)),
        BoxShadow(color: C.cyan.withOpacity(0.05), blurRadius: 30, spreadRadius: 2),
      ],
    ),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: _countdown > 0 ? C.t3 : C.cyan,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
                shadowColor: C.cyan.withOpacity(0.5),
              ),
              child: Text(_countdown > 0 ? '${_countdown}s' : '获取验证码', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
        const SizedBox(height: 14),
      ],
      if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(_error!, style: TextStyle(color: C.red, fontSize: 12, fontWeight: FontWeight.w600))),
      SizedBox(
        width: double.infinity,
        height: 48,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: C.heroGradient,
            boxShadow: [
              BoxShadow(color: C.cyan.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4)),
              BoxShadow(color: C.purple.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 0)),
            ],
          ),
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_isRegister ? '注册并登录' : '登录', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_isRegister ? '已有账号？' : '没有账号？', style: TextStyle(fontSize: 12, color: C.t2)),
        GestureDetector(onTap: () => setState(() { _isRegister = !_isRegister; _error = null; }), child: Text(_isRegister ? '去登录' : '去注册', style: TextStyle(fontSize: 12, color: C.cyan, fontWeight: FontWeight.w800))),
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
    style: const TextStyle(color: C.t1, fontSize: 14),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, color: C.t3, size: 18),
      labelStyle: const TextStyle(color: C.t2, fontSize: 13),
      hintStyle: const TextStyle(color: C.t3, fontSize: 12),
      filled: true,
      fillColor: C.bgSurface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.cyan, width: 1.5)),
    ),
  );
}
