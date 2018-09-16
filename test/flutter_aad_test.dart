import 'dart:convert';

import 'package:flutter_aad/flutter_aad.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  var client = new MockClient((request) async {
    if ((request.url.path.contains("/token") &&
            !request.body.contains('client_id=client')) ||
        (request.headers.containsKey("Authorization") &&
            request.headers["Authorization"] != "Bearer token")) {
      return http.Response("bad client id", 404);
    }
    return http.Response(
        json.encode({
          'access_token': 'good-token-yay',
        }),
        200,
        headers: {
          'content-type': 'application/json',
        });
  });

  var config =
      AADConfig(clientID: "client", redirectURI: "theplace", resource: "thing");
  var configWScope = AADConfig(
    clientID: "client",
    redirectURI: "theplace",
    resource: "thing",
    scope: ["first", "second"],
  );
  var badConfig = AADConfig(
      clientID: "bad_client", redirectURI: "theplace", resource: "thing");
//  var badConfigWScope = AADConfig(
//    clientID: "bad_client",
//    redirectURI: "theplace",
//    resource: "thing",
//    scope: ["first", "second"],
//  );

  var configV2 = AADConfig(
    clientID: "client",
    redirectURI: "theplace",
    resource: "thing",
    apiVersion: 2,
  );
  var configWScopeV2 = AADConfig(
    clientID: "client",
    redirectURI: "theplace",
    resource: "thing",
    scope: ["first", "second"],
    apiVersion: 2,
  );
  var badConfigV2 = AADConfig(
    clientID: "bad_client",
    redirectURI: "theplace",
    resource: "thing",
    apiVersion: 2,
  );
  var badConfigWScopeV2 = AADConfig(
    clientID: "bad_client",
    redirectURI: "theplace",
    resource: "thing",
    scope: ["first", "second"],
    apiVersion: 2,
  );

  test('generates v1 auth code uris', () async {
    final aad = new FlutterAAD(config, http: client);
    final aadWScope = new FlutterAAD(configWScope, http: client);
    expect(aad.GetAuthCodeURI(),
        "https://login.microsoftonline.com/common/oauth2/authorize?client_id=client&response_type=code&response_mode=query&resources=thing");
    expect(aadWScope.GetAuthCodeURI(),
        "https://login.microsoftonline.com/common/oauth2/authorize?client_id=client&response_type=code&response_mode=query&resources=thing&scope=first%20second");
  });

  test('generates v2 auth code uris', () async {
    final aad = new FlutterAAD(configV2, http: client);
    final aadWScope = new FlutterAAD(configWScopeV2, http: client);
    expect(aad.GetAuthCodeURI(),
        "https://login.microsoftonline.com/common/oauth2/v2.0/authorize?client_id=client&response_type=code&response_mode=query");
    expect(aadWScope.GetAuthCodeURI(),
        "https://login.microsoftonline.com/common/oauth2/v2.0/authorize?client_id=client&response_type=code&response_mode=query&scope=first%20second");
  });

  test('make v1 token request', () async {
    final aad = new FlutterAAD(config, http: client);
    final aadBad = new FlutterAAD(badConfig, http: client);
    expect((await aad.GetTokenWithAuthCode("")), "good-token-yay");
    expect((await aadBad.GetTokenWithAuthCode("")), "");
    expect(
        (await aadBad.GetTokenWithAuthCode("", onError: (msg) {
          expect(msg, 'bad client id');
        })),
        "");
  });

  test('make v1 token map request', () async {
    final aad = new FlutterAAD(config, http: client);
    final aadBad = new FlutterAAD(badConfig, http: client);
    expect((await aad.GetTokenMapWithAuthCode(""))["access_token"],
        "good-token-yay");
    expect((await aadBad.GetTokenMapWithAuthCode("")), null);
    expect(
        (await aadBad.GetTokenMapWithAuthCode("", onError: (msg) {
          expect(msg, 'bad client id');
        })),
        null);
  });

  test('make v2 token request', () async {
    final aad = new FlutterAAD(configWScopeV2, http: client);
    final aadBad = new FlutterAAD(badConfigWScopeV2, http: client);
    expect((await aad.GetTokenWithAuthCode("")), "good-token-yay");
    expect((await aadBad.GetTokenWithAuthCode("")), "");
    expect(
        (await aadBad.GetTokenWithAuthCode("", onError: (msg) {
          expect(msg, 'bad client id');
        })),
        "");
  });

  test('make v2 token map request', () async {
    final aad = new FlutterAAD(configWScopeV2, http: client);
    final aadBad = new FlutterAAD(badConfigWScopeV2, http: client);
    expect((await aad.GetTokenMapWithAuthCode(""))["access_token"],
        "good-token-yay");
    expect((await aadBad.GetTokenMapWithAuthCode("")), null);
    expect(
        (await aadBad.GetTokenMapWithAuthCode("", onError: (msg) {
          expect(msg, 'bad client id');
        })),
        null);
  });

  test('refresh v1 token map request', () async {
    final aad = new FlutterAAD(config, http: client);
    final aadBad = new FlutterAAD(badConfig, http: client);
    expect((await aad.RefreshTokenMap(""))["access_token"], "good-token-yay");
    expect((await aadBad.RefreshTokenMap("")), null);
    expect(
        (await aadBad.RefreshTokenMap("", onError: (msg) {
          expect(msg, 'bad client id');
        })),
        null);
  });

  test('refresh v2 token map request', () async {
    final aad = new FlutterAAD(configV2, http: client);
    final aadBad = new FlutterAAD(badConfigV2, http: client);
    expect((await aad.RefreshTokenMap(""))["access_token"], "good-token-yay");
    expect((await aadBad.RefreshTokenMap("")), null);
    expect(
        (await aadBad.RefreshTokenMap("", onError: (msg) {
          expect(msg, 'bad client id');
        })),
        null);
  });

  test('get list items', () async {
    final aad = new FlutterAAD(config, http: client);

    expect(
        (await aad.GetListItems(
                "https://test.site", "Title", "token", "refresh_token"))
            .map['access_token'],
        'good-token-yay');
    expect(
        (await aad.GetListItems(
                "https://test.site", "Title", "token", "refresh_token",
                select: ["ID", "Title", "Body", "Image", "Created", "Expires"]))
            .map['access_token'],
        'good-token-yay');
    expect(
        (await aad.GetListItems(
                "https://test.site", "Title", "token", "refresh_token",
                orderby: "Created%20desc"))
            .map['access_token'],
        'good-token-yay');
    expect(
        (await aad.GetListItems(
                "https://test.site", "Title", "token", "refresh_token",
                select: ["ID", "Title", "Body", "Image", "Created", "Expires"],
                orderby: "Created%20desc",
                filter: [
                  "(StartTime le '01/01/1971')",
                  "(EndTime ge '01/01/1971')"
                ]))
            .map['access_token'],
        'good-token-yay');

    expect(
        (await aad.GetListItems(
            "https://test.site", "Bad Title", "bad_token", "refresh_token")),
        null);

    expect(
        (await aad.GetListItemsResponse(
                "https://test.site", "Title", "token", "refresh_token",
                select: ["ID", "Title", "Body", "Image", "Created", "Expires"],
                orderby: "Created%20desc",
                filter: [
                  "(StartTime le '01/01/1971')",
                  "(EndTime ge '01/01/1971')"
                ]))
            .response
            .statusCode,
        200);

    expect(
        (await aad.GetListItemsResponse(
                "https://test.site", "Bad Title", "bad_token", "refresh_token"))
            .response
            .statusCode,
        404);
  });

  test('get my profile', () async {
    final aad = new FlutterAAD(config, http: client);

    expect((await aad.GetMyProfile("token"))['access_token'], 'good-token-yay');
    expect(
        (await aad.GetMyProfile("token", select: [
          "ID",
          "Title",
          "Body",
          "Image",
          "Created",
          "Expires"
        ]))['access_token'],
        'good-token-yay');
    expect(
        (await aad.GetMyProfile("token",
            orderby: "Created%20desc"))['access_token'],
        'good-token-yay');
    expect(
        (await aad.GetMyProfile("token",
            select: ["ID", "Title", "Body", "Image", "Created", "Expires"],
            orderby: "Created%20desc",
            filter: [
              "(StartTime le '01/01/1971')",
              "(EndTime ge '01/01/1971')"
            ]))['access_token'],
        'good-token-yay');

    expect((await aad.GetMyProfile("bad_token")), null);

    expect(
        (await aad.GetMyProfileResponse("token",
                select: ["ID", "Title", "Body", "Image", "Created", "Expires"],
                orderby: "Created%20desc",
                filter: [
                  "(StartTime le '01/01/1971')",
                  "(EndTime ge '01/01/1971')"
                ]))
            .statusCode,
        200);

    expect((await aad.GetMyProfileResponse("bad_token")).statusCode, 404);
  });
}
