import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

class AnimatedIncidentCard extends StatefulWidget {
  final int index;
  final Map<String, dynamic>? incident;
  const AnimatedIncidentCard({super.key, required this.index, this.incident});

  @override
  State<AnimatedIncidentCard> createState() => _AnimatedIncidentCardState();
}

class _AnimatedIncidentCardState extends State<AnimatedIncidentCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _rotationX = 0;
  double _rotationY = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
    final box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    
    setState(() {
      _rotationX = (localPosition.dy - box.size.height / 2) / (box.size.height / 2) * 0.12;
      _rotationY = (box.size.width / 2 - localPosition.dx) / (box.size.width / 2) * 0.12;
    });
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    setState(() {
      _rotationX = 0;
      _rotationY = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final severity = widget.incident?['severity'] as String? ?? "Medium";
    final isHigh = severity == 'High';
    final accentColor = isHigh ? const Color(0xFFFF3B30) : const Color(0xFFFB923C);

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: () {
        _controller.reverse();
        setState(() {
          _rotationX = 0;
          _rotationY = 0;
        });
      },
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(_rotationX)
              ..rotateY(_rotationY)
              ..scale(_animation.value),
            alignment: FractionalOffset.center,
            child: child,
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.6),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Hero(
                          tag: 'incident_icon_${widget.index}',
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: accentColor.withOpacity(0.2)),
                              boxShadow: [
                                BoxShadow(color: accentColor.withOpacity(0.2), blurRadius: 15, spreadRadius: -2),
                              ],
                            ),
                            child: Icon(
                              isHigh ? Icons.gpp_maybe_rounded : Icons.security_rounded, 
                              color: accentColor, 
                              size: 24
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    widget.incident != null 
                                        ? widget.incident!['type'].toString().toUpperCase()
                                        : 'SYSTEM ALERT',
                                    style: TextStyle(
                                      color: accentColor, 
                                      fontWeight: FontWeight.w900, 
                                      fontSize: 10, 
                                      letterSpacing: 1.5
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'LIVE',
                                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 8, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.incident != null 
                                    ? widget.incident!['description'] as String? ?? "No Description"
                                    : 'UNIDENTIFIED MOVEMENT DETECTED',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700, 
                                  fontSize: 16, 
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, size: 10, color: Colors.white24),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.incident != null
                                        ? widget.incident!['location'] as String? ?? "GHANA"
                                        : 'ACCRA SECTOR B',
                                    style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
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
          ),
        ),
      ),
    );
  }
}
