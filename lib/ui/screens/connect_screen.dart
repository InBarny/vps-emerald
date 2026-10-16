// lib/ui/screens/connect_screen.dart
import 'package:flutter/material.dart';
import '../../vpn/vpn_status.dart';
import '../app_controller.dart';
import '../widgets/glass_card.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _measurePing();
  }

  Future<void> _measurePing() async {
    await widget.controller.probeLatencies();
  }

  @override
  void didUpdateWidget(covariant ConnectScreen oldWidget) {
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
    super.dispose();
  }

  String get _timerText {
    final seconds = widget.controller.sessionSeconds;
    final h = (seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String get _statusLabel {
    switch (widget.controller.vpnStatus.state) {
      case VpnState.disconnected:
        return 'Отключен';
      case VpnState.connecting:
        return 'Подключение...';
      case VpnState.connected:
        return 'Подключено';
      case VpnState.disconnecting:
        return 'Отключение...';
      case VpnState.error:
        return 'Ошибка';
    }
  }

  Color _getStatusColor(VpnState state) {
    switch (state) {
      case VpnState.disconnected:
        return const Color(0xFFff4444);
      case VpnState.connecting:
      case VpnState.disconnecting:
        return const Color(0xFFffaa00);
      case VpnState.connected:
        return const Color(0xFF00ff88);
      case VpnState.error:
        return const Color(0xFFff4444);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.controller.vpnStatus;
    final isBusy =
        status.state == VpnState.connecting ||
        status.state == VpnState.disconnecting;
    final isConnected = status.state == VpnState.connected;
    final statusColor = _getStatusColor(status.state);

    return Padding(
      padding: const EdgeInsets.all(40),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitle('Панель управления'),
            const SizedBox(height: 32),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 12,
                        child: GlassCard(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildStatus(isConnected, statusColor),
                              const SizedBox(height: 32),
                              _buildPlayButton(isConnected, isBusy),
                              const SizedBox(height: 32),
                              _buildTimer(),
                              const SizedBox(height: 32),
                              _buildServerSelect(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 8,
                        child: Column(
                          children: [
                            _buildQuickConnect(isConnected, isBusy),
                            const SizedBox(height: 20),
                            _buildPlanCard(),
                            const SizedBox(height: 20),
                            _buildStatsCard(status),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStatus(isConnected, statusColor),
                          const SizedBox(height: 24),
                          _buildPlayButton(isConnected, isBusy),
                          const SizedBox(height: 24),
                          _buildTimer(),
                          const SizedBox(height: 24),
                          _buildServerSelect(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildQuickConnect(isConnected, isBusy),
                    const SizedBox(height: 20),
                    _buildPlanCard(),
                    const SizedBox(height: 20),
                    _buildStatsCard(status),
                  ],
                );
              },
            ),
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

  Widget _buildStatus(bool isConnected, Color statusColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: statusColor,
            boxShadow: [
              BoxShadow(color: statusColor.withOpacity(0.6), blurRadius: 10),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _statusLabel,
          style: const TextStyle(fontSize: 16, color: Color(0xFF88b89a)),
        ),
      ],
    );
  }

  Widget _buildPlayButton(bool isConnected, bool isBusy) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isBusy
          ? () {}
          : () {
              if (isConnected) {
                widget.controller.disconnect();
              } else {
                widget.controller.connect();
              }
            },
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF00ff88), Color(0xFF00cc6a)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00ff88).withOpacity(0.3),
              blurRadius: 40,
              spreadRadius: 5,
            ),
            BoxShadow(
              color: const Color(0xFF00ff88).withOpacity(0.1),
              blurRadius: 80,
              spreadRadius: 20,
            ),
          ],
        ),
        child: Center(
          child: isConnected
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 10,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF05140c),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 10,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF05140c),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                )
              : CustomPaint(
                  size: const Size(40, 48),
                  painter: _PlayIconPainter(),
                ),
        ),
      ),
    );
  }

  Widget _buildTimer() {
    return Text(
      _timerText,
      style: TextStyle(
        fontFamily: 'JetBrainsMono',
        fontSize: 42,
        fontWeight: FontWeight.w300,
        color: Colors.white,
        letterSpacing: 4,
        shadows: [
          Shadow(
            color: const Color(0xFF00ff88).withOpacity(0.3),
            blurRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildServerSelect() {
    final server = widget.controller.selectedServer;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      onTap: () {},
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.language,
                size: 18,
                color: const Color(0xFF88b89a).withOpacity(0.6),
              ),
              const SizedBox(width: 10),
              Text(
                server?.name ?? 'Не выбран',
                style: const TextStyle(fontSize: 14, color: Color(0xFF88b89a)),
              ),
            ],
          ),
          Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: const Color(0xFF88b89a).withOpacity(0.4),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickConnect(bool isConnected, bool isBusy) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Быстрое подключение',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isBusy || isConnected
                  ? null
                  : () => widget.controller.connect(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00ff88),
                foregroundColor: const Color(0xFF05140c),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Подключиться',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard() {
    final info = widget.controller.subscriptionInfo;
    final hasPlan = info.isActive;
    final days = info.daysRemaining;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Текущий план',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
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
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00ff88),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                hasPlan ? '$days дней осталось' : 'Без подписки',
                style: const TextStyle(fontSize: 13, color: Color(0xFF88b89a)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(VpnStatus status) {
    final isConnected = status.state == VpnState.connected;
    final sessionTime = isConnected ? _timerText : '—';
    final selectedServer = widget.controller.selectedServer;
    final pingText = selectedServer?.latencyMs != null
        ? '${selectedServer!.latencyMs} ms'
        : '—';

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Статистика',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStat(sessionTime, 'Время сессии'),
              const SizedBox(width: 32),
              _buildStat(pingText, 'Пинг'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 24,
            color: const Color(0xFF00ff88),
            shadows: [
              Shadow(
                color: const Color(0xFF00ff88).withOpacity(0.3),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF88b89a)),
        ),
      ],
    );
  }
}

class _PlayIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF05140c)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
