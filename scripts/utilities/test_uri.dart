void main() {
  final uri = Uri.tryParse('/?mode=resetPassword&oobCode=123');
  print('Path: ${uri?.path}');
  print('Mode: ${uri?.queryParameters['mode']}');
}
