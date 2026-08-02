import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supa_app/core/theme/app_theme.dart';
import 'package:supa_app/core/widgets/supa_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;
  String _selectedType = 'IDEA';

  void _submitFeedback() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      
      if (userId == null) {
        throw Exception('User is not logged in. Please sign in to submit feedback.');
      }

      await client.from('feedbacks').insert({
        'user_id': userId,
        'category': _selectedType.toLowerCase(),
        'message': content,
      });

      if (mounted) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feedback submitted successfully! Thank you for helping us improve.'),
            backgroundColor: AppTheme.accent,
          ),
        );
      }
    } catch (e) {
      debugPrint('[Feedback] Submission error: $e');
      if (mounted) {
        setState(() => _isSubmitting = false);
        
        String errorMsg = 'Failed to submit feedback. Please check your connection.';
        if (e is PostgrestException) {
          errorMsg = 'Failed to submit feedback: ${e.message}';
        } else if (e is Exception) {
          final cleanMsg = e.toString().replaceFirst('Exception: ', '');
          errorMsg = 'Failed to submit feedback: $cleanMsg';
        } else {
          errorMsg = 'Failed to submit feedback: $e';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accent.withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.blueAccent.withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white38),
                  onPressed: () => Navigator.pop(context),
                ),
                floating: true,
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      'Share Feedback',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ).animate().fadeIn().slideY(begin: 0.1, end: 0),
                    const SizedBox(height: 12),
                    Text(
                      'Help us improve Vectrax. Let us know what features you would like to see, or if you encountered any issues.',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.6,
                        fontWeight: FontWeight.w400,
                      ),
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 48),
                    Text(
                      'SELECT FEEDBACK TYPE',
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _buildTypeCard(
                            'BUG', Icons.bug_report_rounded, Colors.redAccent),
                        const SizedBox(width: 12),
                        _buildTypeCard('FEATURE', Icons.auto_awesome_rounded,
                            Colors.blueAccent),
                        const SizedBox(width: 12),
                        _buildTypeCard(
                            'IDEA', Icons.lightbulb_rounded, AppTheme.accent),
                      ],
                    ),
                    const SizedBox(height: 48),
                    Text(
                      'YOUR FEEDBACK',
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: AnimatedContainer(
                          duration: 400.ms,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: _getTypeColor().withOpacity(0.15),
                              width: 1,
                            ),
                          ),
                          child: TextField(
                            controller: _controller,
                            maxLines: 6,
                            cursorColor: _getTypeColor(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  'Describe your request or issue in detail...',
                              hintStyle: GoogleFonts.inter(
                                color: Colors.white38,
                                fontSize: 15,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(24),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    SupaButton(
                      isLoading: _isSubmitting,
                      onPressed: _submitFeedback,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      child: Center(
                        child: Text(
                          'SUBMIT FEEDBACK',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 100),
                    Center(
                      child: Text(
                        'SECURE CONNECTION',
                        style: GoogleFonts.inter(
                          color: Colors.white10,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getTypeColor() {
    switch (_selectedType) {
      case 'BUG':
        return Colors.redAccent;
      case 'FEATURE':
        return Colors.blueAccent;
      case 'IDEA':
        return AppTheme.accent;
      default:
        return AppTheme.accent;
    }
  }

  Widget _buildTypeCard(String type, IconData icon, Color color) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedType = type);
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: AnimatedContainer(
              duration: 300.ms,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withOpacity(0.08)
                    : Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? color.withOpacity(0.3)
                      : Colors.white.withOpacity(0.05),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(icon, color: isSelected ? color : Colors.white24, size: 22),
                  const SizedBox(height: 8),
                  Text(
                    type,
                    style: GoogleFonts.inter(
                      color: isSelected ? color : Colors.white24,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
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
