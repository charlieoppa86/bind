import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/bind_logo.dart';
import '../../session/account_controller.dart';

/// 인증 > 스플래시: 로그인 상태 확인 후 라우터 redirect가 자동 분기한다.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(accountProvider).restore());
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BindLogo(size: 44),
            SizedBox(height: AppSpacing.md),
            Text('지금 여기, 같은 주제의 사람과 바로 대화', style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}
