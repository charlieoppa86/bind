import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../notice/in_app_notice.dart';

/// 앱 밖 주소. 약관·방침은 charlieoppa86/bind-policy 저장소(GitHub Pages)에 있다.
abstract final class AppLinks {
  static final terms = Uri.parse(
    'https://charlieoppa86.github.io/bind-policy/terms/',
  );
  static final privacy = Uri.parse(
    'https://charlieoppa86.github.io/bind-policy/privacy/',
  );

  /// 문의·이의 제기 이메일(약관 제16조, 개인정보처리방침 10항과 같게)
  static const supportEmail = 'futureworkers.global@gmail.com';

  static Uri supportMail({String? subject}) => Uri(
    scheme: 'mailto',
    path: supportEmail,
    query: subject == null
        ? null
        : 'subject=${Uri.encodeComponent(subject)}',
  );
}

/// 주소를 연다. 열었으면 true. 테스트에서는 바꿔 끼워 연 주소를 확인한다.
typedef LinkOpener = Future<bool> Function(Uri uri);

final linkOpenerProvider = Provider<LinkOpener>((ref) => _launch);

Future<bool> _launch(Uri uri) async {
  try {
    // 웹 페이지는 앱 안 브라우저(iOS Safari 보기, Android Custom Tabs),
    // mailto는 메일 앱으로 연다.
    return await launchUrl(
      uri,
      mode: uri.scheme == 'mailto'
          ? LaunchMode.externalApplication
          : LaunchMode.inAppBrowserView,
    );
  } catch (_) {
    return false;
  }
}

/// [uri]를 열고, 못 열면 화면 위 배너로 알린다.
Future<void> openLink(WidgetRef ref, Uri uri) async {
  final ok = await ref.read(linkOpenerProvider)(uri);
  if (ok) return;
  ref
      .read(inAppNoticeProvider.notifier)
      .show(
        InAppNotice(
          uri.scheme == 'mailto'
              ? '메일 앱을 열지 못했어요. ${AppLinks.supportEmail}로 보내 주세요.'
              : '페이지를 열지 못했어요. 잠시 후 다시 시도해 주세요.',
        ),
      );
}
