/// 서비스 이름·슬로건. 화면마다 문구를 직접 쓰지 않고 여기서 가져온다.
abstract final class Brand {
  static const name = 'BIND';

  /// 메인 슬로건(로딩 화면 로고 아래)
  static const slogan = '같은 공간에서 같은 관심사로';

  /// 첫 화면 큰 제목으로 쓸 때 두 줄로 나눈 슬로건
  static const sloganTwoLines = '같은 공간에서\n같은 관심사로';

  /// 첫 화면 큰 제목 아래 문구
  static const startCall = '우리들의 스몰톡, 바인드';
}
