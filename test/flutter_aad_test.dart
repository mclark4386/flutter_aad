import 'package:test/test.dart';

import 'package:flutter_aad/flutter_aad.dart';

void main() {
  test('adds one to input values', () async {
    final aad = new FlutterAAD();
    expect(aad.GetAuthCodeURIv1(AADConfig(clientID: "client", redirectURI: "theplace", resource: "thing")), "https://login.microsoftonline.com/common/oauth2/authorize?client_id=client&response_type=code&response_mode=query&resources=thing");
    expect(aad.GetAuthCodeURIv1(AADConfig(clientID: "client", redirectURI: "theplace", resource: "thing", scope: ["first","second"])), "https://login.microsoftonline.com/common/oauth2/authorize?client_id=client&response_type=code&response_mode=query&resources=thing&scope=first%20second");
    expect((await aad.GetTokenWithAuthCodev1(AADConfig(), "")), "");
    expect(aad.GetAuthCodeURIv2(AADConfig(clientID: "client", redirectURI: "theplace")), "https://login.microsoftonline.com/common/oauth2/authorize?client_id=client&response_type=code&response_mode=query");
    expect(aad.GetAuthCodeURIv2(AADConfig(clientID: "client", redirectURI: "theplace", scope: ["first","second"])), "https://login.microsoftonline.com/common/oauth2/authorize?client_id=client&response_type=code&response_mode=query&scope=first%20second");

  });
}
