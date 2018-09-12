import 'dart:convert';

import 'package:test/test.dart';

import 'package:flutter_aad/flutter_aad.dart';

import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

void main() {
  var client = new MockClient((request) async {
    if ((request.url.path.contains("/token") && !request.body.contains('client_id=client')) || (request.headers.containsKey("Authorization") && request.headers["Authorization"] != "Bearer token")) {
      return http.Response("bad client id", 404);
    }
    return http.Response(json.encode({
      'access_token':'good-token-yay',
    }), 200, headers: {
      'content-type': 'application/json',
    });
  });

  var config = AADConfig(clientID: "client", redirectURI: "theplace", resource: "thing");
  var configWScope = AADConfig(clientID: "client", redirectURI: "theplace", resource: "thing", scope: ["first","second"]);
  var badConfig = AADConfig(clientID: "bad_client", redirectURI: "theplace", resource: "thing");
  var badConfigWScope = AADConfig(clientID: "bad_client", redirectURI: "theplace", resource: "thing", scope: ["first","second"]);

  test('generates v1 auth code uris', () async {
    final aad = new FlutterAAD(http: client);
    expect(aad.GetAuthCodeURIv1(config), "https://login.microsoftonline.com/common/oauth2/authorize?client_id=client&response_type=code&response_mode=query&resources=thing");
    expect(aad.GetAuthCodeURIv1(configWScope), "https://login.microsoftonline.com/common/oauth2/authorize?client_id=client&response_type=code&response_mode=query&resources=thing&scope=first%20second");
  });
  test('generates v2 auth code uris', () async {
    final aad = new FlutterAAD(http: client);
    expect(aad.GetAuthCodeURIv2(config), "https://login.microsoftonline.com/common/oauth2/authorize?client_id=client&response_type=code&response_mode=query");
    expect(aad.GetAuthCodeURIv2(configWScope), "https://login.microsoftonline.com/common/oauth2/authorize?client_id=client&response_type=code&response_mode=query&scope=first%20second");
  });
  test('make v1 token request', () async {
    final aad = new FlutterAAD(http: client);
    expect((await aad.GetTokenWithAuthCodev1(config, "")), "good-token-yay");
    expect((await aad.GetTokenWithAuthCodev1(badConfig, "")), "");
    expect((await aad.GetTokenWithAuthCodev1(badConfig, "",onError: (msg){
      expect(msg, 'bad client id');
    })), "");
  });
  test('make v1 token map request', () async {
    final aad = new FlutterAAD(http: client);
    expect((await aad.GetTokenMapWithAuthCodev1(config, ""))["access_token"], "good-token-yay");
    expect((await aad.GetTokenMapWithAuthCodev1(badConfig, "")), null);
    expect((await aad.GetTokenMapWithAuthCodev1(badConfig, "",onError: (msg){
      expect(msg, 'bad client id');
    })), null);
  });
  test('make v2 token request', () async {
    final aad = new FlutterAAD(http: client);
    expect((await aad.GetTokenWithAuthCodev2(configWScope, "")), "good-token-yay");
    expect((await aad.GetTokenWithAuthCodev2(badConfigWScope, "")), "");
    expect((await aad.GetTokenWithAuthCodev2(badConfigWScope, "",onError: (msg){
      expect(msg, 'bad client id');
    })), "");
  });

  test('get list items', () async {
    final aad = new FlutterAAD(http: client);

    expect((await aad.GetListItems("https://test.site", "Title", "token"))['access_token'],'good-token-yay');
    expect((await aad.GetListItems("https://test.site", "Title", "token", select: ["ID","Title","Body","Image","Created","Expires"]))['access_token'],'good-token-yay');
    expect((await aad.GetListItems("https://test.site", "Title", "token", orderby: "Created%20desc"))['access_token'],'good-token-yay');
    expect((await aad.GetListItems("https://test.site", "Title", "token", select: ["ID","Title","Body","Image","Created","Expires"], orderby: "Created%20desc", filter: ["(StartTime le '01/01/1971')","(EndTime ge '01/01/1971')"]))['access_token'],'good-token-yay');

    expect((await aad.GetListItems("https://test.site", "Bad Title", "bad_token")), null);

    expect((await aad.GetListItemsResponse("https://test.site", "Title", "token", select: ["ID","Title","Body","Image","Created","Expires"], orderby: "Created%20desc", filter: ["(StartTime le '01/01/1971')","(EndTime ge '01/01/1971')"])).statusCode,200);

    expect((await aad.GetListItemsResponse("https://test.site", "Bad Title", "bad_token")).statusCode, 404);
  });
//  "?\$select=ID,Title,Body,Image,Created,Expires&\$orderby=Created%20desc"
}
