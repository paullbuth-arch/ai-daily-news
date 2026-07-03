import 'package:flutter/material.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'components/index.dart';
import 'main.dart';
import 'pages/shell.dart';
import 'theme/colors.dart';

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
  bool _isRegister = false;
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
    if (!email.contains('@')) {
      setState(() => _error = '请输入正确的邮箱');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
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
    if (!email.contains('@')) {
      setState(() => _error = '请输入正确的邮箱');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = '密码至少 6 位');
      return;
    }
    if (_isRegister && _codeCtrl.text.trim().length != 6) {
      setState(() => _error = '请输入 6 位验证码');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result =
        _isRegister
            ? await ApiService.register(email, password, _codeCtrl.text.trim())
            : await ApiService.login(email, password);
    if (!mounted) return;
    setState(() => _loading = false);

    if (result['error'] != null) {
      setState(() {
        _error = result['error'] as String;
        if (_error!.contains('未注册')) _isRegister = true;
      });
      return;
    }

    await AuthService.login(gStorage, result['token'] as String, email);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bgDeep,
    body: Stack(
      children: [
        const AppBackdrop(),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth >= 820;
              if (!wide) {
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _loginPanel(),
                  ),
                );
              }
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Padding(
                    padding: const EdgeInsets.all(34),
                    child: Row(
                      children: [
                        const Expanded(child: _BrandStage()),
                        const SizedBox(width: 44),
                        SizedBox(width: 410, child: _loginPanel()),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _loginPanel() => GlassPanel(
    padding: const EdgeInsets.all(22),
    radius: 28,
    color: const Color(0xEA0A0D14),
    realtimeBlur: true,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: C.cyan,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.tablet_mac_rounded, color: Colors.black),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _isRegister ? '创建账号' : '欢迎回来',
                style: const TextStyle(
                  color: C.t1,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _isRegister ? '填写邮箱、密码与验证码' : '登录后继续管理库存、订单和利润',
          style: const TextStyle(
            color: C.t2,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 22),
        _input(
          '邮箱地址',
          _emailCtrl,
          hint: 'your@email.com',
          icon: Icons.mail_outline_rounded,
        ),
        const SizedBox(height: 13),
        _input(
          '密码',
          _passCtrl,
          hint: '至少 6 位',
          icon: Icons.lock_outline_rounded,
          obscure: true,
        ),
        if (_isRegister) ...[
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: _input(
                  '验证码',
                  _codeCtrl,
                  hint: '6 位数字',
                  icon: Icons.pin_outlined,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _loading || _countdown > 0 ? null : _sendCode,
                  child: Text(_countdown > 0 ? '${_countdown}s' : '获取验证码'),
                ),
              ),
            ],
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 14),
          StatusChip(_error!, C.red),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _loading ? null : _submit,
            child:
                _loading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                    : Text(_isRegister ? '注册并登录' : '登录'),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isRegister ? '已有账号？' : '没有账号？',
              style: const TextStyle(color: C.t2, fontSize: 12),
            ),
            TextButton(
              onPressed:
                  () => setState(() {
                    _isRegister = !_isRegister;
                    _error = null;
                  }),
              child: Text(_isRegister ? '去登录' : '去注册'),
            ),
          ],
        ),
        Center(
          child: TextButton(
            onPressed:
                () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const MainShell()),
                ),
            child: const Text(
              '离线使用',
              style: TextStyle(color: C.t3, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _input(
    String label,
    TextEditingController controller, {
    String? hint,
    IconData? icon,
    bool obscure = false,
  }) => TextField(
    controller: controller,
    obscureText: obscure,
    style: const TextStyle(
      color: C.t1,
      fontSize: 14,
      fontWeight: FontWeight.w700,
    ),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, color: C.t3, size: 18),
    ),
  );
}

class _BrandStage extends StatelessWidget {
  const _BrandStage();

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Transform.rotate(
        angle: -0.10,
        child: GlassPanel(
          padding: const EdgeInsets.all(20),
          radius: 36,
          color: const Color(0xF006080D),
          realtimeBlur: true,
          child: SizedBox(
            height: 520,
            child: Column(
              children: [
                Row(
                  children: [
                    _StageCircle(icon: Icons.search_rounded),
                    const Spacer(),
                    Container(
                      width: 94,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    const Spacer(),
                    _StageCircle(icon: Icons.settings_outlined),
                  ],
                ),
                const Spacer(),
                const Text(
                  '二手 iPad\n经营舱',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: C.t1,
                    fontSize: 38,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '库存、订单、利润，一屏判断下一步',
                  style: TextStyle(
                    color: C.t2,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Row(
                  children: const [
                    Expanded(
                      child: _StagePill(
                        label: '收货',
                        color: C.cyan,
                        icon: Icons.qr_code_scanner_rounded,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _StagePill(
                        label: '利润',
                        color: C.purple,
                        icon: Icons.show_chart_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      Positioned(
        left: -36,
        top: 78,
        child: _FloatingBadge(color: C.mint, title: '库存', value: '实时'),
      ),
      Positioned(
        right: -26,
        top: 142,
        child: _FloatingBadge(color: C.purple, title: '毛利', value: '清晰'),
      ),
      Positioned(
        right: 34,
        bottom: 92,
        child: _FloatingBadge(color: C.cyan, title: '订单', value: '快速'),
      ),
    ],
  );
}

class _StageCircle extends StatelessWidget {
  final IconData icon;
  const _StageCircle({required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    width: 46,
    height: 46,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.10),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, color: C.t1, size: 22),
  );
}

class _StagePill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StagePill({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ],
    ),
  );
}

class _FloatingBadge extends StatelessWidget {
  final Color color;
  final String title;
  final String value;

  const _FloatingBadge({
    required this.color,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: 150,
    padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.22),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.52),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
        ),
      ],
    ),
  );
}
