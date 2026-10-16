// lib/ui/screens/subscription_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../models/subscription_models.dart';
import '../app_controller.dart';
import '../widgets/glass_card.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = false;
  final TextEditingController _promoController = TextEditingController();
  String? _promoMessage;
  bool _promoSuccess = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _checkPending();
    _checkPromoOnServer();
  }

  Future<void> _checkPromoOnServer() async {
    if (!widget.controller.isPromoUsed) {
      final used = await widget.controller.checkPromoAlreadyUsedOnServer();
      if (used) {
        await widget.controller.markPromoUsed();
        if (mounted) setState(() {});
      }
    }
  }

  @override
  void didUpdateWidget(covariant SubscriptionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _checkPending() async {
    if (widget.controller.pendingPayment != null) {
      setState(() => _isLoading = true);
      await widget.controller.checkPendingPayment();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pay(SubscriptionPlan plan) async {
    setState(() => _isLoading = true);

    if (widget.controller.pendingPayment == null) {
      widget.controller.initYooKassa();
    }

    final result = await widget.controller.createSubscriptionPayment(
      plan,
      returnUrl: AppConfig.yookassaReturnUrl,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result != null && result.confirmationUrl.isNotEmpty) {
        final uri = Uri.parse(result.confirmationUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else if (widget.controller.pendingPayment != null) {
        final uri = Uri.parse(
          widget.controller.pendingPayment!.confirmationUrl,
        );
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    }
  }

  Future<void> _activatePromo() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) return;

    if (widget.controller.isPromoUsed) {
      setState(() {
        _promoSuccess = false;
        _promoMessage = 'Промокод уже использован';
      });
      return;
    }

    setState(() => _isLoading = true);

    // Server-side anti-abuse check
    final alreadyUsedOnServer = await widget.controller.checkPromoAlreadyUsedOnServer();
    if (alreadyUsedOnServer) {
      await widget.controller.markPromoUsed();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _promoSuccess = false;
          _promoMessage = 'Промокод уже использован';
        });
      }
      return;
    }

    if (code.toUpperCase() == widget.controller.promoCode?.toUpperCase()) {
      await widget.controller.extendSubscription(4, isPromo: true);
      await widget.controller.markPromoUsed();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _promoSuccess = true;
          _promoMessage = 'Промокод активирован! +4 дня добавлено.';
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _promoSuccess = false;
          _promoMessage = 'Неверный промокод';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.controller.subscriptionInfo;
    final pending = widget.controller.pendingPayment;

    return Padding(
      padding: const EdgeInsets.all(40),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitle('Подписка'),
            const SizedBox(height: 32),
            _buildCurrentPlan(info, pending),
            const SizedBox(height: 32),
            _buildPlans(pending),
            const SizedBox(height: 32),
            _buildPromocode(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle(String text) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Colors.white, Color(0xFF88ffaa)],
      ).createShader(bounds),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildCurrentPlan(SubscriptionInfo info, PendingPayment? pending) {
    final hasPlan = info.isActive;
    final days = info.daysRemaining;

    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Текущий план',
                  style: TextStyle(fontSize: 14, color: Color(0xFF88b89a)),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00ff88).withOpacity(0.15),
                    border: Border.all(
                      color: const Color(0xFF00ff88).withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    hasPlan ? info.plan.toUpperCase() : 'FREE',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF00ff88),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (hasPlan) ...[
                  Text(
                    'Действителен до ${_formatDate(info.expireDate!)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF88b89a),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Осталось $days дней',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF00ff88),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildClearButton(),
                  if (info.vpnLink != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00ff88).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF00ff88).withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'VPN ключ:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF88b89a),
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: info.vpnLink!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      backgroundColor: Color(0xFF0a1f14),
                                      content: Text(
                                        'Скопировано',
                                        style: TextStyle(color: Color(0xFF00ff88)),
                                      ),
                                    ),
                                  );
                                },
                                child: const Icon(
                                  Icons.copy,
                                  size: 16,
                                  color: Color(0xFF88b89a),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            info.vpnLink!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ] else ...[
                  const Text(
                    'Нет активной подписки',
                    style: TextStyle(fontSize: 14, color: Color(0xFF88b89a)),
                  ),
                ],
                if (pending != null) ...[
                  const SizedBox(height: 16),
                  const Divider(color: Color(0x2E00ff88)),
                  Row(
                    children: [
                      const Icon(
                        Icons.hourglass_top,
                        color: Color(0xFFffaa00),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ожидается оплата: ${pending.amount.toStringAsFixed(0)} ₽',
                          style: const TextStyle(
                            color: Color(0xFFffaa00),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _checkPending,
                        child: const Text(
                          'Проверить',
                          style: TextStyle(color: Color(0xFF00ff88)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildPlans(PendingPayment? pending) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 500;
        final children = AppController.plans.map((plan) {
          return Expanded(
            child: GlassCard(
              child: Column(
                children: [
                  Text(
                    plan.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₽',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF00ff88),
                        ),
                      ),
                      Text(
                        plan.priceRub.toStringAsFixed(0),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${plan.days} дней',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF88b89a),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading || pending != null
                          ? null
                          : () => _pay(plan),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00ff88),
                        foregroundColor: const Color(0xFF05140c),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF05140c),
                              ),
                            )
                          : Text(
                              pending != null ? 'Ожидание оплаты' : 'Оплатить',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList();

        if (isWide) {
          return Row(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                children[i],
              ],
            ],
          );
        }
        return Column(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 16),
              children[i],
            ],
          ],
        );
      },
    );
  }

  Widget _buildPromocode() {
    final promoCode = widget.controller.promoCode;
    final isUsed = widget.controller.isPromoUsed;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Промокод',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          if (promoCode != null && !isUsed) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF00ff88).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF00ff88).withOpacity(0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.card_giftcard,
                    size: 18,
                    color: Color(0xFF00ff88),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ваш персональный промокод',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF88b89a),
                          ),
                        ),
                        const SizedBox(height: 2),
                        SelectableText(
                          promoCode,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF00ff88),
                            fontFamily: 'JetBrainsMono',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else if (isUsed) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFff4444).withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFff4444).withOpacity(0.25),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 18,
                    color: Color(0xFFff4444),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Промокод уже использован',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFFff6b6b),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: _buildGlassInput(
                  controller: _promoController,
                  hint: 'Введите промокод',
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: isUsed ? null : _activatePromo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00ff88),
                  foregroundColor: const Color(0xFF05140c),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Активировать'),
              ),
            ],
          ),
          if (_promoMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _promoMessage!,
              style: TextStyle(
                fontSize: 12,
                color: _promoSuccess
                    ? const Color(0xFF00ff88)
                    : const Color(0xFFff4444),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGlassInput({
    required TextEditingController controller,
    required String hint,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.03),
                const Color(0xFF00ff88).withOpacity(0.01),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF00ff88).withOpacity(0.15),
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFF4a7a5c)),
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClearButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF0a1f14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0x2E00ff88)),
              ),
              title: const Text(
                'Сбросить подписку?',
                style: TextStyle(color: Colors.white),
              ),
              content: const Text(
                'Все данные подписки и VPN-ключи будут удалены. Продолжить?',
                style: TextStyle(color: Color(0xFF88b89a)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(
                    'Отмена',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text(
                    'Сбросить',
                    style: TextStyle(color: Color(0xFFff4444)),
                  ),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            setState(() => _isLoading = true);
            await widget.controller.clearSubscription();
            if (mounted) setState(() => _isLoading = false);
          }
        },
        icon: const Icon(
          Icons.delete_forever,
          color: Color(0xFFff6b6b),
          size: 18,
        ),
        label: const Text(
          'Сбросить подписку',
          style: TextStyle(color: Color(0xFFff6b6b)),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: const Color(0xFFff4444).withOpacity(0.4)),
          backgroundColor: const Color(0xFFff4444).withOpacity(0.06),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
