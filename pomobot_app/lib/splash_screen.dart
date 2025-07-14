import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;
  
  const SplashScreen({Key? key, required this.nextScreen}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _subtitleController;
  late AnimationController _backgroundController;
  late AnimationController _particleController;
  
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotationAnimation;
  late Animation<double> _logoPulseAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _subtitleFadeAnimation;
  late Animation<Offset> _subtitleSlideAnimation;
  late Animation<double> _backgroundFadeAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startAnimationSequence();
  }

  void _initAnimations() {
    // 背景动画控制器
    _backgroundController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    
    // Logo动画控制器
    _logoController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );
    
    // 主标题动画控制器
    _textController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );
    
    // 副标题动画控制器
    _subtitleController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    // 粒子动画控制器
    _particleController = AnimationController(
      duration: Duration(seconds: 10),
      vsync: this,
    )..repeat();

    // 背景渐变动画
    _backgroundFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeInOut,
    ));

    // Logo缩放动画
    _logoScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));

    // Logo旋转动画
    _logoRotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeInOut,
    ));

    // Logo脉冲动画
    _logoPulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeInOut,
    ));

    // 主标题淡入动画
    _textFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeInOut,
    ));

    // 主标题滑入动画
    _textSlideAnimation = Tween<Offset>(
      begin: Offset(0, 0.8),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.elasticOut,
    ));

    // 副标题淡入动画
    _subtitleFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _subtitleController,
      curve: Curves.easeInOut,
    ));

    // 副标题滑入动画
    _subtitleSlideAnimation = Tween<Offset>(
      begin: Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _subtitleController,
      curve: Curves.easeOutBack,
    ));
  }

  void _startAnimationSequence() async {
    // 启动背景动画
    _backgroundController.forward();
    
    // 延迟300ms后启动Logo动画
    await Future.delayed(Duration(milliseconds: 300));
    _logoController.forward();
    
    // 延迟800ms后启动主标题动画
    await Future.delayed(Duration(milliseconds: 800));
    _textController.forward();
    
    // 延迟400ms后启动副标题动画
    await Future.delayed(Duration(milliseconds: 400));
    _subtitleController.forward();
    
    // 动画完成后等待1.5秒，然后跳转到主页面
    await Future.delayed(Duration(milliseconds: 2000));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => widget.nextScreen,
          transitionDuration: Duration(milliseconds: 1000),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(0, 0.1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: child,
              ),
            );
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _logoController.dispose();
    _textController.dispose();
    _subtitleController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _backgroundController,
          _logoController,
          _textController,
          _subtitleController,
          _particleController,
        ]),
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
            ),
            child: Stack(
              children: [
                // 红色粒子背景
                ...List.generate(12, (index) => _buildParticle(index)),
                
                // 主内容
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo部分
                      Transform.scale(
                        scale: _logoScaleAnimation.value * _logoPulseAnimation.value,
                        child: Transform.rotate(
                          angle: _logoRotationAnimation.value * math.pi,
                          child: Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(40),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red[100]!.withOpacity(0.8),
                                  blurRadius: 30,
                                  offset: Offset(0, 10),
                                  spreadRadius: 8,
                                ),
                                BoxShadow(
                                  color: Colors.red[300]!.withOpacity(0.6),
                                  blurRadius: 50,
                                  offset: Offset(0, 0),
                                  spreadRadius: 15,
                                ),
                                BoxShadow(
                                  color: Colors.grey[200]!,
                                  blurRadius: 20,
                                  offset: Offset(0, 15),
                                  spreadRadius: 5,
                                ),
                              ],
                              border: Border.all(
                                color: Colors.red[50]!,
                                width: 3,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.smart_toy_rounded,
                                size: 80,
                                color: Colors.red[600],
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 60),
                      
                      // 主标题
                      SlideTransition(
                        position: _textSlideAnimation,
                        child: FadeTransition(
                          opacity: _textFadeAnimation,
                          child: Text(
                            'PomoBot',
                            style: TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
                              letterSpacing: 4.0,
                              shadows: [
                                Shadow(
                                  color: Colors.red[200]!.withOpacity(0.6),
                                  offset: Offset(2, 4),
                                  blurRadius: 8,
                                ),
                                Shadow(
                                  color: Colors.grey[300]!.withOpacity(0.4),
                                  offset: Offset(4, 8),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 24),
                      
                      // 副标题
                      SlideTransition(
                        position: _subtitleSlideAnimation,
                        child: FadeTransition(
                          opacity: _subtitleFadeAnimation,
                          child: Text(
                            'Your Desk Companion',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w300,
                              color: Colors.grey[700],
                              letterSpacing: 2.0,
                              shadows: [
                                Shadow(
                                  color: Colors.grey[200]!.withOpacity(0.8),
                                  offset: Offset(1, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 100),
                      
                      // 加载指示器
                      FadeTransition(
                        opacity: _subtitleFadeAnimation,
                        child: Column(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red[100]!.withOpacity(0.6),
                                    blurRadius: 20,
                                    offset: Offset(0, 5),
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: SizedBox(
                                  width: 30,
                                  height: 30,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.red[600]!,
                                    ),
                                    strokeWidth: 3,
                                  ),
                                ),
                              ),
                            ),
                            
                            SizedBox(height: 30),
                            
                            Text(
                              'Initializing Your Productivity Partner...',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildParticle(int index) {
    final random = math.Random(index);
    final startX = random.nextDouble();
    final startY = random.nextDouble();
    final size = 3 + random.nextDouble() * 6;
    
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        final progress = (_particleController.value + index * 0.15) % 1.0;
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        
        return Positioned(
          left: startX * screenWidth + math.sin(progress * 2 * math.pi) * 40,
          top: startY * screenHeight - progress * screenHeight * 0.6,
          child: Opacity(
            opacity: (1 - progress) * 0.4 * _backgroundFadeAnimation.value,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.red[300],
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red[200]!.withOpacity(0.6),
                    blurRadius: size * 3,
                    spreadRadius: size * 0.8,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}