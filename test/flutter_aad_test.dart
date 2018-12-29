import 'dart:convert';

import 'package:flutter_aad/flutter_aad.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  var client = new MockClient((request) async {
    if ((request.url.path.contains("/token") &&
        !request.body.contains('client_id=client'))) {
      return http.Response("bad client id", 404);
    } else if ((request.url.path.contains("/items") ||
            request.url.path.contains("/me") ||
            request.url.path.contains("/query")) &&
        request.headers.containsKey("Authorization") &&
        request.headers["Authorization"] != "Bearer token") {
      return http.Response("Bad JWT. The token is expired.", 401);
    } else if (request.url.path.contains("/token") &&
        !request.body.contains('refresh_token=refresh_token') &&
        request.body.contains('grant_type=refresh_token')) {
      return http.Response("bad refresh token", 404);
    } else if (request.url.path.contains("/token") &&
        request.body.contains('refresh_token=refresh_token') &&
        request.body.contains('grant_type=refresh_token') &&
        request.body.contains('client_id=client')) {
      return http.Response(
          json.encode({
            'access_token': 'token',
            'refresh_token': 'refresh_token',
          }),
          200,
          headers: {
            'content-type': 'application/json',
          });
    }
    return http.Response(
        json.encode({
          'access_token': 'good-token-yay',
          'refresh_token': 'good-token-yay',
        }),
        200,
        headers: {
          'content-type': 'application/json',
        });
  });

  var config =
      AADConfig(clientID: "client", redirectURI: "theplace", resource: "thing");
  var configWScope = AADConfig.clone(config)..scope.addAll(["first", "second"]);
  var badConfig = AADConfig.clone(config)..clientID = "bad_client";
//  var badConfigWScope = AADConfig(
//    clientID: "bad_client",
//    redirectURI: "theplace",
//    resource: "thing",
//    scope: ["first", "second"],
//  );

  var configV2 = AADConfig.clone(config)..apiVersion = 2;
  var configWScopeV2 = AADConfig.clone(configWScope)..apiVersion = 2;
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

  test('getters should work as expected', () async {
    final aad = new FlutterAAD(config, http: client);
    expect(aad.fullToken, null);
    expect(aad.loggedIn, false);
    expect(aad.currentToken, "");
    expect(aad.currentRefreshToken, "");

    await aad.GetTokenWithAuthCode("");
    expect(aad.fullToken["access_token"], "good-token-yay");
    expect(aad.loggedIn, true);
    expect(aad.currentToken, "good-token-yay");
    expect(aad.currentRefreshToken, "good-token-yay");

    expect(aad.headersWithToken("test"), {
      "Authorization": "Bearer test",
    });
    expect(aad.headersWithToken("test", FBA: true), {
      "Cookie": "FedAuth=test",
    });
  });

  test('generates v1 auth code uris', () async {
    final aad = new FlutterAAD(config);
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

    expect(aad.login, emitsInAnyOrder([true, false]));

    expect((await aad.GetTokenWithAuthCode("")), "good-token-yay");
    expect(aad.loggedIn, true);
    aad.Logout();
    expect(aad.loggedIn, false);
    expect(aad.fullToken, null);

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

  test('make v1 token response request', () async {
    final aad = new FlutterAAD(config, http: client);
    final aadBad = new FlutterAAD(badConfig, http: client);
    expect(
        (await aad.GetTokenResponseWithAuthCode("")).full_token["access_token"],
        "good-token-yay");
    expect((await aadBad.GetTokenResponseWithAuthCode("")).full_token, null);
    expect(
        (await aadBad.GetTokenResponseWithAuthCode("", onError: (msg) {
          expect(msg, 'bad client id');
        }))
            .full_token,
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

  test('make v2 token response request', () async {
    final aad = new FlutterAAD(configWScopeV2, http: client);
    final aadBad = new FlutterAAD(badConfigWScopeV2, http: client);
    expect(
        (await aad.GetTokenResponseWithAuthCode("")).full_token["access_token"],
        "good-token-yay");
    expect((await aadBad.GetTokenResponseWithAuthCode("")).full_token, null);
    expect(
        (await aadBad.GetTokenResponseWithAuthCode("", onError: (msg) {
          expect(msg, 'bad client id');
        }))
            .full_token,
        null);
  });

  test('refresh v1 token map request', () async {
    final aad = new FlutterAAD(config, http: client);
    final aadBad = new FlutterAAD(badConfig, http: client);
    expect(
        (await aad.RefreshTokenMap()), null); //can't refresh if not logged in
    expect(
        (await aad.RefreshTokenMap(
            refreshToken: "refresh_token"))["access_token"],
        "token");
    expect((await aadBad.RefreshTokenMap()), null);
    expect(
        (await aadBad.RefreshTokenMap(
            refreshToken: "bad_refresh_token",
            onError: (msg) {
              expect(msg, 'bad client id');
            })),
        null);
    expect(
        (await aadBad.RefreshTokenMap(onError: (msg) {
          expect(msg, "No refresh token passed and saved full token is empty.");
        })),
        null);
  });

  test('refresh v2 token map request', () async {
    final aad = new FlutterAAD(configV2, http: client);
    final aadBad = new FlutterAAD(badConfigV2, http: client);
    expect(
        (await aad.RefreshTokenMap()), null); //can't refresh if not logged in
    expect(
        (await aad.RefreshTokenMap(
            refreshToken: "refresh_token"))["access_token"],
        "token");
    expect((await aadBad.RefreshTokenMap()), null);
    expect(
        (await aadBad.RefreshTokenMap(
            refreshToken: "bad_refresh_token",
            onError: (msg) {
              expect(msg, 'bad client id');
            })),
        null);
  });

  test('get list items', () async {
    final aad_logged_out = new FlutterAAD(config, http: client);
    final aad_one_off = new FlutterAAD(config, http: client, fullToken: {
      'access_token': 'bad_token',
      'refresh_token': 'refresh_token',
    });
    final aad = new FlutterAAD(config, http: client, fullToken: {
      'access_token': 'token',
      'refresh_token': 'refresh_token',
    });

    expect(aad_logged_out.fullToken, null);
    expect((await aad_logged_out.GetListItems("https://test.site", "Title")),
        null); //can't refresh if not logged in
    expect(aad_logged_out.fullToken, null);
    expect(
        (await aad_logged_out.GetListItems("https://test.site", "Title",
            onError: (msg) {
          expect(msg, "No access token passed and saved full token is empty.");
        })),
        null);
    expect(aad_logged_out.fullToken, null);
    expect(
        (await (FlutterAAD(config, http: client, fullToken: {
          'access_token': 'bad_token',
        }))
            .GetListItems("https://test.site", "Title", onError: (msg) {
          expect(msg, "No refresh token passed and saved full token is empty.");
        })),
        null);
    expect(aad_logged_out.fullToken, null);
    expect(
        (await (FlutterAAD(config, http: client, fullToken: {
          'access_token': 'bad_token',
        }))
            .GetListItems("https://test.site", "Title",
                refresh_token: "bad_token", onError: (msg) {
          expect(msg, "Bad JWT. The token is expired.");
        })),
        null);
    expect(aad_logged_out.fullToken, null);
    expect(
        (await aad_logged_out.GetListItemsResponse("https://test.site", "Title",
            onError: (msg) {
          expect(msg, "No access token passed and saved full token is empty.");
        })),
        null);
    expect(aad_logged_out.fullToken, null);
    expect(
        (await aad_logged_out.GetListItemsResponse("https://test.site", "Title",
            onError: (msg) {
          expect(msg, "No refresh token passed and saved full token is empty.");
        })),
        null);
    expect(aad_logged_out.fullToken, null);
    expect(
        (await (FlutterAAD(config, http: client, fullToken: {
          'access_token': 'bad_token',
        }))
                .GetListItemsResponse("https://test.site", "Title",
                    refresh_token: "bad_token", onError: (msg) {
          expect(msg, "Bad JWT. The token is expired.");
        }))
            .response
            .statusCode,
        401);
    expect(aad_logged_out.fullToken, null);
    //should refresh token
    expect(
        (await aad_one_off.GetListItemsResponse("https://test.site", "Title"))
            .response
            .statusCode,
        200);
    expect(
        (await aad.GetListItems(
          "https://test.site",
          "Title",
        ))
            .map['access_token'],
        'good-token-yay');
    expect(
        (await aad.GetListItems(
          "https://test.site",
          "Title",
          expand: ["test"],
        ))
            .map['access_token'],
        'good-token-yay');
    expect(
        (await aad.GetListItems("https://test.site", "Title",
                select: ["ID", "Title", "Body", "Image", "Created", "Expires"]))
            .map['access_token'],
        'good-token-yay');
    expect(
        (await aad.GetListItems("https://test.site", "Title",
                refresh_token: "refresh_token", orderby: "Created%20desc"))
            .map['access_token'],
        'good-token-yay');
    expect(
        (await aad.GetListItems("https://test.site", "Title",
                select: ["ID", "Title", "Body", "Image", "Created", "Expires"],
                orderby: "Created%20desc",
                expand: ["test"],
                filter: [
                  "(StartTime le '01/01/1971')",
                  "(EndTime ge '01/01/1971')"
                ]))
            .map['access_token'],
        'good-token-yay');

    expect(
        (await (FlutterAAD(config, http: client, fullToken: {
          'access_token': 'bad_token',
          'refresh_token': 'refresh_token',
        }))
            .GetListItems("https://test.site", "Bad Title",
                refresh_token: "bad_token")),
        null);

    expect(
        (await aad.GetListItemsResponse("https://test.site", "Title",
                select: ["ID", "Title", "Body", "Image", "Created", "Expires"],
                orderby: "Created%20desc",
                expand: ["test"],
                filter: [
                  "(StartTime le '01/01/1971')",
                  "(EndTime ge '01/01/1971')"
                ]))
            .response
            .statusCode,
        200);

    expect(
        (await aad.GetListItemsResponse("https://test.site", "Title", filter: [
          "(StartTime le '01/01/1971')",
          "(EndTime ge '01/01/1971')"
        ]))
            .response
            .statusCode,
        200);

    expect(
        (await aad.GetListItemsResponse("https://test.site", "Title",
                expand: ["test"]))
            .response
            .statusCode,
        200);

    expect(
        (await (FlutterAAD(config, http: client, fullToken: {
          'access_token': 'bad_token',
        }))
                .GetListItemsResponse("https://test.site", "Bad Title",
                    refresh_token: "bad_token"))
            .response
            .statusCode,
        401);
  });

  test('get list items w/o refresh', () async {
    final aad_logged_out = new FlutterAAD(config, http: client);
    final aad = new FlutterAAD(config, http: client, fullToken: {
      'access_token': 'token',
      'refresh_token': 'refresh_token',
    });

    expect(
        (await aad_logged_out.GetListItemsWORefresh(
            "https://test.site", "Title")),
        null); //can't refresh if not logged in
    expect(
        (await aad_logged_out.GetListItemsWORefresh(
            "https://test.site", "Title", onError: (msg) {
          expect(msg, "No access token passed and saved full token is empty.");
        })),
        null);
    expect(
        (await aad_logged_out.GetListItemsWORefresh(
            "https://test.site", "Title", onError: (msg) {
          expect(msg, "bad client id");
        })),
        null);
    expect(
        (await aad.GetListItemsWORefresh(
          "https://test.site",
          "Title",
          expand: ["test"],
        ))['access_token'],
        'good-token-yay');
    expect(
        (await aad.GetListItemsWORefresh(
          "https://test.site",
          "Title",
          select: ["ID", "Title", "Body", "Image", "Created", "Expires"],
          expand: ["test"],
        ))['access_token'],
        'good-token-yay');
    expect(
        (await aad.GetListItemsWORefresh("https://test.site", "Title",
            orderby: "Created%20desc"))['access_token'],
        'good-token-yay');
    expect(
        (await aad.GetListItemsWORefresh("https://test.site", "Title",
            select: ["ID", "Title", "Body", "Image", "Created", "Expires"],
            orderby: "Created%20desc",
            filter: [
              "(StartTime le '01/01/1971')",
              "(EndTime ge '01/01/1971')"
            ]))['access_token'],
        'good-token-yay');

    expect(
        (await (FlutterAAD(config, http: client, fullToken: {
          'access_token': 'bad_token',
          'refresh_token': 'refresh_token',
        }))
            .GetListItemsWORefresh("https://test.site", "Bad Title")),
        null);

    expect(
        (await aad.GetListItemsResponseWORefresh("https://test.site", "Title",
                select: ["ID", "Title", "Body", "Image", "Created", "Expires"],
                orderby: "Created%20desc",
                expand: ["test"],
                filter: [
                  "(StartTime le '01/01/1971')",
                  "(EndTime ge '01/01/1971')"
                ]))
            .statusCode,
        200);

    expect(
        (await aad.GetListItemsResponseWORefresh("https://test.site", "Title",
                filter: [
              "(StartTime le '01/01/1971')",
              "(EndTime ge '01/01/1971')"
            ]))
            .statusCode,
        200);

    expect(
        (await aad.GetListItemsResponseWORefresh("https://test.site", "Title",
                expand: ["test"]))
            .statusCode,
        200);

    expect(
        (await (FlutterAAD(config, http: client, fullToken: {
          'access_token': 'bad_token',
          'refresh_token': 'refresh_token',
        }))
                .GetListItemsResponseWORefresh(
                    "https://test.site", "Bad Title"))
            .statusCode,
        401);

    expect(
        (await (FlutterAAD(config, http: client, fullToken: {
          'access_token': '2_bad_token',
          'refresh_token': 'refresh_token',
        }))
                .GetListItemsResponseWORefresh(
                    "https://test.site", "Bad Title"))
            .statusCode,
        401);
  });

  test('get my profile', () async {
    final aad_logged_out = new FlutterAAD(config, http: client);
    final aad = new FlutterAAD(config, http: client, fullToken: {
      'access_token': 'token',
      'refresh_token': 'refresh_token',
    });

    expect((await aad_logged_out.GetMyProfile()), null);
    expect(
        (await aad_logged_out.GetMyProfile(onError: (msg) {
          expect(msg, "No access token passed and saved full token is empty.");
        })),
        null);
    expect((await aad.GetMyProfile())['access_token'], 'good-token-yay');
    expect(
        (await aad.GetMyProfile(select: [
          "ID",
          "Title",
          "Body",
          "Image",
          "Created",
          "Expires"
        ]))['access_token'],
        'good-token-yay');
    expect((await aad.GetMyProfile(orderby: "Created%20desc"))['access_token'],
        'good-token-yay');
    expect(
        (await aad.GetMyProfile(
            select: ["ID", "Title", "Body", "Image", "Created", "Expires"],
            orderby: "Created%20desc",
            filter: [
              "(StartTime le '01/01/1971')",
              "(EndTime ge '01/01/1971')"
            ]))['access_token'],
        'good-token-yay');

    expect(
        (await (FlutterAAD(config, http: client, fullToken: {
          'access_token': 'bad_token',
          'refresh_token': 'refresh_token',
        }))
            .GetMyProfile(onError: (msg) {
          expect(msg, "Bad JWT. The token is expired.");
        })),
        null);

    expect(
        (await aad.GetMyProfileResponse(
                select: ["ID", "Title", "Body", "Image", "Created", "Expires"],
                orderby: "Created%20desc",
                filter: [
                  "(StartTime le '01/01/1971')",
                  "(EndTime ge '01/01/1971')"
                ]))
            .statusCode,
        200);

    expect(
        (await (FlutterAAD(config, http: client, fullToken: {
          'access_token': 'bad_token',
          'refresh_token': 'refresh_token',
        }))
                .GetMyProfileResponse())
            .statusCode,
        401);
  });

  test('get sharepoint search', () async {
    // setup
    final aad_logged_out = new FlutterAAD(config, http: client);
    final aad_one_off = new FlutterAAD(config, http: client, fullToken: {
      'access_token': 'bad_token',
      'refresh_token': 'refresh_token',
    });
    final aad = new FlutterAAD(config, http: client, fullToken: {
      'access_token': 'token',
      'refresh_token': 'refresh_token',
    });

    // null token if logged out
    expect(aad_logged_out.fullToken, null);

    // null response if logged out
    expect(
        (await aad_logged_out.GetSharepointSearchResponse("https://test.site")),
        null);
    expect(aad_logged_out.fullToken, null);

    // null response with message
    expect(
        (await aad_logged_out.GetSharepointSearchResponse("https://test.site",
            onError: (msg) {
          expect(msg, "No access token passed and saved full token is empty.");
        })),
        null);
    expect(aad_logged_out.fullToken, null);

    // null response with token but no refresh token
    expect(
        (await aad_logged_out.GetSharepointSearchResponse("https://test.site",
            onError: (msg) {
          expect(msg, "No access token passed and saved full token is empty.");
        })),
        null);
    expect(aad_logged_out.fullToken, null);

    // 401 response with bad tokens
    expect(
        (await (FlutterAAD(
          config,
          http: client,
          fullToken: {
            'access_token': 'bad_token',
            'refresh_token': 'refresh_token',
          },
        ))
                .GetSharepointSearchResponse("https://test.site",
                    refresh_token: "bad_token", onError: (msg) {
          expect(msg, "Bad JWT. The token is expired.");
        }))
            .response
            .statusCode,
        401);
    expect(aad_logged_out.fullToken, null);

    // successful response with valid refresh token
    expect(
        (await aad_one_off.GetSharepointSearchResponse("https://test.site"))
            .response
            .statusCode,
        200);

    // successful response with valid credentials and query params
    expect(
        (await aad.GetSharepointSearchResponse("https://test.site",
                select: ["FirstName", "LastName", "AccountName"],
                sourceid: "id",
                orderby: "LastName:ascending",
                rowlimit: 100,
                startrow: 1))
            .response
            .statusCode,
        200);
    expect(
        (await aad.GetSharepointSearchResponse("https://test.site",
                sourceid: "id", rowlimit: 100, startrow: 1))
            .response
            .statusCode,
        200);
    expect(
        (await aad.GetSharepointSearchResponse("https://test.site",
                orderby: "LastName:ascending", rowlimit: 100, startrow: 1))
            .response
            .statusCode,
        200);
    expect(
        (await aad.GetSharepointSearchResponse("https://test.site",
                rowlimit: 100, startrow: 1))
            .response
            .statusCode,
        200);
    expect(
        (await aad.GetSharepointSearchResponse("https://test.site",
                startrow: 1))
            .response
            .statusCode,
        200);

    // 401 with bad tokens overriding saved tokens
    expect(
        (await (FlutterAAD(config, http: client, fullToken: {
          'access_token': 'bad_token',
          'refresh_token': 'refresh_token',
        }))
                .GetSharepointSearchResponse("https://test.site",
                    refresh_token: "bad_token"))
            .response
            .statusCode,
        401);
  });

  test('get sharepoint search w/o refresh', () async {
    final aad = new FlutterAAD(config, http: client, fullToken: {
      'access_token': 'token',
      'refresh_token': 'refresh_token',
    });

    expect(
        (await aad.GetSharepointSearchResponseWORefresh("https://test.site",
                select: ["FirstName", "LastName", "AccountName"],
                orderby: "LastName:ascending",
                sourceid: "id"))
            .statusCode,
        200);

    expect(
        (await aad.GetSharepointSearchResponseWORefresh("https://test.site",
                orderby: "LastName:ascending",
                sourceid: "id",
                rowlimit: 100,
                startrow: 10))
            .statusCode,
        200);

    expect(
        (await aad.GetSharepointSearchResponseWORefresh("https://test.site",
                sourceid: "id", rowlimit: 100, startrow: 10))
            .statusCode,
        200);

    expect(
        (await aad.GetSharepointSearchResponseWORefresh("https://test.site",
                rowlimit: 100, startrow: 10))
            .statusCode,
        200);

    expect(
        (await aad.GetSharepointSearchResponseWORefresh("https://test.site",
                startrow: 10))
            .statusCode,
        200);

    expect(
        (await (FlutterAAD(config, http: client, fullToken: {
          'access_token': 'bad_token',
          'refresh_token': 'refresh_token',
        }))
                .GetSharepointSearchResponseWORefresh("https://test.site"))
            .statusCode,
        401);

    expect(
        (await (FlutterAAD(config, http: client, fullToken: {
          'access_token': '2_bad_token',
          'refresh_token': 'refresh_token',
        }))
                .GetSharepointSearchResponseWORefresh("https://test.site"))
            .statusCode,
        401);
  });
}
