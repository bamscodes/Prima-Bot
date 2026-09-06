import 'package:test/test.dart';
import 'package:android_libcpp_shared/src/locate_ndk.dart';

void main() {
  test('locate returns non-empty set of paths', () async {
    final ndkPaths = await NDKLocator.locate();
    expect(ndkPaths, isNotEmpty);
  });
}
