import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supa_app/core/theme/app_theme.dart';
import 'package:supa_app/core/widgets/glass_card.dart';

class CpuDetailsScreen extends StatefulWidget {
  const CpuDetailsScreen({super.key});

  @override
  State<CpuDetailsScreen> createState() => _CpuDetailsScreenState();
}

class _CpuDetailsScreenState extends State<CpuDetailsScreen> {
  final Random _random = Random();
  Timer? _timer;
  final int _maxDataPoints = 15;
  List<double> _cpuData = [];
  double _currentCpu = 15.4;

  @override
  void initState() {
    super.initState();
    _cpuData = List.generate(
        _maxDataPoints, (index) => 15.0 + (_random.nextDouble() * 5 - 2.5));
    _cpuData.add(_currentCpu);
    if (_cpuData.length > _maxDataPoints) _cpuData.removeAt(0);
    _startLiveStream();
  }

  void _startLiveStream() {
    _timer = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
      if (!mounted) return;
      setState(() {
        final change = (_random.nextDouble() - 0.5) * 6; // Fluctuate by +/- 3%
        _currentCpu = (_currentCpu + change).clamp(2.0, 98.0);
        _cpuData.removeAt(0);
        _cpuData.add(_currentCpu);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Hero(
          tag: 'cpu_metric_hero',
          child: Material(
            type: MaterialType.transparency,
            child: GlassCard(
              padding: const EdgeInsets.all(24),
              borderRadius: BorderRadius.circular(24),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.speed_rounded,
                            color: AppTheme.accent, size: 28),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 10),
                          )
                              .animate(
                                  onPlay: (controller) =>
                                      controller.repeat(reverse: true))
                              .fadeOut(duration: 800.ms),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'CPU USAGE',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_currentCpu.toStringAsFixed(1)}%',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 200,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) => FlLine(
                                color: Colors.white.withOpacity(0.05),
                                strokeWidth: 1),
                          ),
                          titlesData: FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: _cpuData
                                  .asMap()
                                  .entries
                                  .map((e) => FlSpot(e.key.toDouble(), e.value))
                                  .toList(),
                              isCurved: true,
                              curveSmoothness: 0.35,
                              color: AppTheme.accent,
                              barWidth: 4,
                              isStrokeCapRound: true,
                              dotData: FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.accent.withOpacity(0.3),
                                    AppTheme.accent.withOpacity(0.0)
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ],
                          minY: 0,
                          maxY: 100,
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 600.ms, delay: 300.ms)
                        .slideY(begin: 0.1),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
