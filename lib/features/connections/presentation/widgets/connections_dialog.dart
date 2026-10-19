import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/localization/locale_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/platform_colors.dart';
import '../../../orders/presentation/widgets/orders_dialog_shell.dart';
import '../../data/platform_connections.dart';

String _t(BuildContext context, String en, String ar) =>
    context.isArabic ? ar : en;

/// Where the restaurant types in how to reach its Keeta and HungerStation
/// accounts, and checks it works.
Future<void> showConnectionsDialog(
  BuildContext context, {
  required PlatformConnections connections,
  String platform = 'keeta',
}) {
  return showOrdersDialog<void>(
    context,
    builder: (_) =>
        _ConnectionsDialog(connections: connections, initial: platform),
  );
}

class _ConnectionsDialog extends StatefulWidget {
  const _ConnectionsDialog({required this.connections, required this.initial});

  final PlatformConnections connections;
  final String initial;

  @override
  State<_ConnectionsDialog> createState() => _ConnectionsDialogState();
}

class _ConnectionsDialogState extends State<_ConnectionsDialog> {
  late String _platform = widget.initial;

  @override
  Widget build(BuildContext context) {
    return OrdersDialogShell(
      icon: Icons.link_rounded,
      title: _t(context, 'Platform connections', 'ربط المنصات'),
      subtitle: _t(
        context,
        'The restaurant\'s access to Keeta and HungerStation',
        'وصول المطعم إلى كيتا وهنقرستيشن',
      ),
      maxWidth: 600,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_t(context, 'Close', 'إغلاق')),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              for (final p in PlatformColors.all)
                ButtonSegment(value: p, label: Text(PlatformColors.label(p))),
              ButtonSegment(
                value: 'bayan',
                label: Text(_t(context, 'Bayan orders', 'طلبات بيان')),
              ),
            ],
            selected: {_platform},
            onSelectionChanged: (v) => setState(() => _platform = v.first),
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: switch (_platform) {
              'keeta' => _KeetaForm(
                key: const ValueKey('keeta'),
                connections: widget.connections,
              ),
              'bayan' => _BayanForm(
                key: const ValueKey('bayan'),
                connections: widget.connections,
              ),
              _ => _HungerStationForm(
                key: const ValueKey('hs'),
                connections: widget.connections,
              ),
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Shared bits ───────────────────────────────────────────────────────────────

InputDecoration _decoration(
  String label, {
  String? hint,
  Widget? suffix,
  IconData? icon,
}) => InputDecoration(
  labelText: label,
  hintText: hint,
  suffixIcon: suffix,
  prefixIcon: icon == null ? null : Icon(icon, size: 20),
  filled: true,
  fillColor: AppTheme.surfaceAlt,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppTheme.border),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppTheme.border),
  ),
);

class _SecretField extends StatefulWidget {
  const _SecretField({
    required this.controller,
    required this.label,
    this.hint,
    this.icon = Icons.key_rounded,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;

  @override
  State<_SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<_SecretField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _hidden,
      enableSuggestions: false,
      autocorrect: false,
      textDirection: TextDirection.ltr,
      decoration: _decoration(
        widget.label,
        hint: widget.hint,
        icon: widget.icon,
        suffix: IconButton(
          tooltip: _hidden
              ? _t(context, 'Show', 'إظهار')
              : _t(context, 'Hide', 'إخفاء'),
          icon: Icon(
            _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 20,
          ),
          onPressed: () => setState(() => _hidden = !_hidden),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.child});

  final IconData icon;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: FilledButton.icon(
        onPressed: busy ? null : onPressed,
        icon: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.verified_outlined, size: 18),
        label: Text(_t(context, 'Save and test', 'حفظ واختبار')),
        style: dialogButtonStyle,
      ),
    );
  }
}

const _testValuesNote = _TestValuesNote();

class _TestValuesNote extends StatelessWidget {
  const _TestValuesNote();

  @override
  Widget build(BuildContext context) {
    return _Banner(
      icon: Icons.science_outlined,
      color: AppTheme.warning,
      child: Text(
        _t(
          context,
          'Test values are in use (the mock backend). Enter the real ones to connect to the platform.',
          'القيم الحالية تجريبية (الخادم التجريبي). أدخل القيم الحقيقية للاتصال بالمنصة.',
        ),
        style: const TextStyle(fontSize: 12.5, height: 1.5),
      ),
    );
  }
}

// ── Keeta ─────────────────────────────────────────────────────────────────────

class _KeetaForm extends StatefulWidget {
  const _KeetaForm({super.key, required this.connections});

  final PlatformConnections connections;

  @override
  State<_KeetaForm> createState() => _KeetaFormState();
}

class _KeetaFormState extends State<_KeetaForm> {
  late final KeetaSnapshot _before = widget.connections.keetaSnapshot();
  final _token = TextEditingController();
  final _refresh = TextEditingController();
  late final _shop = TextEditingController(
    text: _before.shopId == null ? '' : '${_before.shopId}',
  );
  late final _appId = TextEditingController(
    text: _before.testValues || _before.appId <= 0 ? '' : '${_before.appId}',
  );
  final _secret = TextEditingController();
  bool _busy = false;
  bool _advanced = false;
  KeetaConnectionResult? _result;
  int? _selectedShop;

  @override
  void dispose() {
    _token.dispose();
    _refresh.dispose();
    _shop.dispose();
    _appId.dispose();
    _secret.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _result = null;
    });
    final result = await widget.connections.connectKeeta(
      appId: int.tryParse(_appId.text.trim()),
      appSecret: _secret.text,
      accessToken: _token.text,
      refreshToken: _refresh.text,
      shopId: int.tryParse(_shop.text.trim()),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = result;
      _selectedShop = result.shopId;
      if (result.shopId != null) _shop.text = '${result.shopId}';
      if (result.ok) {
        _token.clear();
        _refresh.clear();
        _secret.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_before.testValues) ...[_testValuesNote, const SizedBox(height: 12)],
        Text(
          _t(
            context,
            'In Keeta\'s developer portal create an authorization link, let the restaurant owner confirm it, then copy the Access Token from "Authorization Management".',
            'في بوابة مطوّري كيتا أنشئ رابط تفويض، ودع صاحب المطعم يؤكده، ثم انسخ رمز الوصول (Access Token) من «إدارة التفويض».',
          ),
          style: const TextStyle(
            fontSize: 12.5,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        _SecretField(
          controller: _token,
          label: 'Access Token',
          hint: _before.tokenTail == null
              ? null
              : _t(
                  context,
                  'Saved (…${_before.tokenTail}) — leave empty to keep',
                  'محفوظ (…${_before.tokenTail}) — اتركه فارغاً للإبقاء',
                ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _shop,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textDirection: TextDirection.ltr,
          decoration: _decoration(
            'Shop ID',
            icon: Icons.storefront_outlined,
            hint: _t(
              context,
              'Optional if the token has one shop',
              'اختياري إن كان للرمز فرع واحد',
            ),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => setState(() => _advanced = !_advanced),
            icon: Icon(
              _advanced
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              size: 18,
            ),
            label: Text(
              _t(context, 'Application (App ID, secret, refresh token)', 'التطبيق (App ID والسرّ ورمز التجديد)'),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: !_advanced
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 4),
                    TextField(
                      controller: _appId,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textDirection: TextDirection.ltr,
                      decoration: _decoration('App ID', icon: Icons.apps_rounded),
                    ),
                    const SizedBox(height: 10),
                    _SecretField(
                      controller: _secret,
                      label: 'App Secret',
                      hint: _before.hasSecret && !_before.testValues
                          ? _t(context, 'Saved — leave empty to keep', 'محفوظ — اتركه فارغاً للإبقاء')
                          : null,
                      icon: Icons.lock_outline_rounded,
                    ),
                    const SizedBox(height: 10),
                    _SecretField(
                      controller: _refresh,
                      label: 'Refresh Token',
                      hint: _t(context, 'Optional', 'اختياري'),
                      icon: Icons.autorenew_rounded,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
        ),
        const SizedBox(height: 6),
        _SaveButton(busy: _busy, onPressed: _save),
        if (result != null) ...[
          const SizedBox(height: 14),
          if (!result.ok)
            _Banner(
              icon: Icons.error_outline_rounded,
              color: AppTheme.coral,
              child: Text(
                result.error!,
                style: const TextStyle(fontSize: 12.5, height: 1.5),
              ),
            )
          else
            _Banner(
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF16A34A),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.brandName.isEmpty
                        ? _t(context, 'Connected to Keeta', 'تم الاتصال بكيتا')
                        : _t(
                            context,
                            'Connected: ${result.brandName}',
                            'تم الاتصال: ${result.brandName}',
                          ),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  if (result.shops.isEmpty)
                    Text(
                      _t(context, 'No shops are authorized for this token.', 'لا توجد فروع مفوَّضة لهذا الرمز.'),
                      style: const TextStyle(fontSize: 12.5),
                    )
                  else if (result.shops.length > 1 && _selectedShop == null)
                    Text(
                      _t(context, 'Choose the shop to use:', 'اختر الفرع المستعمل:'),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  for (final shop in result.shops)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        await widget.connections.chooseKeetaShop(shop.id);
                        if (!mounted) return;
                        setState(() {
                          _selectedShop = shop.id;
                          _shop.text = '${shop.id}';
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              _selectedShop == shop.id
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              size: 18,
                              color: AppTheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${shop.name} · #${shop.id}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

// ── HungerStation ─────────────────────────────────────────────────────────────

class _HungerStationForm extends StatefulWidget {
  const _HungerStationForm({super.key, required this.connections});

  final PlatformConnections connections;

  @override
  State<_HungerStationForm> createState() => _HungerStationFormState();
}

class _HungerStationFormState extends State<_HungerStationForm> {
  late final HungerStationSnapshot _before = widget.connections
      .hungerStationSnapshot();
  late final _clientId = TextEditingController(
    text: _before.testValues ? '' : _before.clientId,
  );
  final _secret = TextEditingController();
  late final _chain = TextEditingController(
    text: _before.testValues ? '' : _before.chainId,
  );
  late final _vendor = TextEditingController(
    text: _before.testValues ? '' : _before.vendorId,
  );
  late bool _sandbox = _before.sandbox;
  bool _busy = false;
  bool? _ok;
  String? _error;

  @override
  void dispose() {
    _clientId.dispose();
    _secret.dispose();
    _chain.dispose();
    _vendor.dispose();
    super.dispose();
  }

  bool get _valid =>
      _clientId.text.trim().isNotEmpty &&
      _chain.text.trim().isNotEmpty &&
      _vendor.text.trim().isNotEmpty &&
      (_secret.text.trim().isNotEmpty ||
          (_before.hasSecret && !_before.testValues));

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _ok = null;
    });
    final error = await widget.connections.connectHungerStation(
      clientId: _clientId.text,
      clientSecret: _secret.text,
      chainId: _chain.text,
      vendorId: _vendor.text,
      sandbox: _sandbox,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _ok = error == null;
      _error = error;
      if (error == null) _secret.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_before.testValues) ...[_testValuesNote, const SizedBox(height: 12)],
        Text(
          _t(
            context,
            'In the HungerStation Partner Portal (Secret Management) create a client id and secret. The chain and vendor ids come from the same portal or your account manager.',
            'من بوابة شركاء هنقرستيشن (إدارة الأسرار) أنشئ Client ID وسرّاً. معرّفا السلسلة والفرع من البوابة نفسها أو من مدير الحساب.',
          ),
          style: const TextStyle(
            fontSize: 12.5,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        ListenableBuilder(
          listenable: Listenable.merge([_clientId, _secret, _chain, _vendor]),
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _clientId,
                textDirection: TextDirection.ltr,
                decoration: _decoration('Client ID', icon: Icons.badge_outlined),
              ),
              const SizedBox(height: 10),
              _SecretField(
                controller: _secret,
                label: 'Client Secret',
                hint: _before.hasSecret && !_before.testValues
                    ? _t(context, 'Saved — leave empty to keep', 'محفوظ — اتركه فارغاً للإبقاء')
                    : null,
                icon: Icons.lock_outline_rounded,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chain,
                      textDirection: TextDirection.ltr,
                      decoration: _decoration('Chain ID', icon: Icons.account_tree_outlined),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _vendor,
                      textDirection: TextDirection.ltr,
                      decoration: _decoration('Vendor ID', icon: Icons.storefront_outlined),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _sandbox,
                onChanged: (v) => setState(() => _sandbox = v),
                title: Text(_t(context, 'Sandbox (testing)', 'بيئة الاختبار (Sandbox)')),
                subtitle: Text(
                  _t(context, 'Sandbox and production use different credentials.', 'الاختبار والإنتاج لهما بيانات مختلفة.'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              _SaveButton(busy: _busy || !_valid, onPressed: _save),
            ],
          ),
        ),
        if (_ok != null) ...[
          const SizedBox(height: 14),
          _ok!
              ? _Banner(
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF16A34A),
                  child: Text(
                    _t(context, 'Connected to HungerStation', 'تم الاتصال بهنقرستيشن'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                )
              : _Banner(
                  icon: Icons.error_outline_rounded,
                  color: AppTheme.coral,
                  child: Text(
                    _error ?? '',
                    style: const TextStyle(fontSize: 12.5, height: 1.5),
                  ),
                ),
        ],
      ],
    );
  }
}

// ── Bayan orders ──────────────────────────────────────────────────────────────

class _BayanForm extends StatefulWidget {
  const _BayanForm({super.key, required this.connections});

  final PlatformConnections connections;

  @override
  State<_BayanForm> createState() => _BayanFormState();
}

class _BayanFormState extends State<_BayanForm> {
  late final BayanSnapshot _before = widget.connections.bayanSnapshot();
  final _key = TextEditingController();
  late final _keeta = TextEditingController(
    text: _before.keetaAccount?.toString() ?? '',
  );
  late final _hs = TextEditingController(
    text: _before.hungerStationAccount?.toString() ?? '',
  );
  String? _error;
  bool _saved = false;

  @override
  void dispose() {
    _key.dispose();
    _keeta.dispose();
    _hs.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final error = await widget.connections.saveBayan(
      orderKey: _key.text,
      keetaAccount: int.tryParse(_keeta.text.trim()),
      hungerStationAccount: int.tryParse(_hs.text.trim()),
    );
    if (!mounted) return;
    setState(() {
      _error = error;
      _saved = error == null;
      if (error == null) _key.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _t(
            context,
            'Orders are booked in Bayan as invoices. Each platform\'s orders go to its own Bayan account number, and every request carries a time token built from the order key.',
            'تُسجَّل الطلبات في بيان كفواتير. طلبات كل منصة تذهب إلى رقم حسابها في بيان، وكل طلب يحمل رمز وقت مبنياً على مفتاح الطلبات.',
          ),
          style: const TextStyle(
            fontSize: 12.5,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        _SecretField(
          controller: _key,
          label: _t(context, 'Order key (8 characters)', 'مفتاح الطلبات (8 أحرف)'),
          hint: _before.hasKey
              ? _t(context, 'Saved — leave empty to keep', 'محفوظ — اتركه فارغاً للإبقاء')
              : _t(context, 'Or paste the 32-character md5', 'أو الصق md5 المكوّن من 32 حرفاً'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _keeta,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textDirection: TextDirection.ltr,
                decoration: _decoration(
                  _t(context, 'Keeta account', 'حساب كيتا'),
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _hs,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textDirection: TextDirection.ltr,
                decoration: _decoration(
                  _t(context, 'HungerStation account', 'حساب هنقرستيشن'),
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text(_t(context, 'Save', 'حفظ')),
            style: dialogButtonStyle,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _Banner(
            icon: Icons.error_outline_rounded,
            color: AppTheme.coral,
            child: Text(_error!, style: const TextStyle(fontSize: 12.5)),
          ),
        ] else if (_saved) ...[
          const SizedBox(height: 12),
          _Banner(
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF16A34A),
            child: Text(
              _t(context, 'Saved', 'تم الحفظ'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ],
    );
  }
}
