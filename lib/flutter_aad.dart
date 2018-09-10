library flutter_aad;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as base_http;

class AADConfig {
  final String clientID;
  final String redirectURI;
  final List<String> scope;
  final String resource;

  AADConfig(
      {this.resource, this.clientID, this.redirectURI, List<String> scope})
      : this.scope = scope ?? [];

  String get ClientID => clientID;
  String get RedirectURI => redirectURI;
  List<String> get Scope => List.from(scope);
  String get Resource => resource;
}

const V2_LOGIN_URI =
    'https://login.microsoftonline.com/common/oauth2/v2.0/token';
const LOGIN_URI = 'https://login.microsoftonline.com/common/oauth2/token';
const V2_AUTH_URI =
    'https://login.microsoftonline.com/common/oauth2/v2.0/authorize';
const AUTH_URI = 'https://login.microsoftonline.com/common/oauth2/authorize';

class FlutterAAD {
  base_http.BaseClient http;

  FlutterAAD({base_http.BaseClient http})
      : this.http = http ?? new base_http.Client();

  String GetAuthCodeURIv1(AADConfig config) {
    var uri_base = Uri.parse(AUTH_URI);

    var query = {
      "client_id": config.ClientID,
      "response_type": "code",
      "response_mode": "query",
      "resources": config.Resource,
    };

    var uri = Uri(
        host: uri_base.host,
        scheme: uri_base.scheme,
        path: uri_base.path,
        queryParameters: query);
    var parsed_uri = uri.toString();
    if (config.scope != null && config.scope.length > 0) {
      parsed_uri += "&scope=" + config.Scope.join('%20');
    }
    return parsed_uri;
  }

  Future<String> GetTokenWithAuthCodev1(AADConfig config, String authCode,
      {void onError(String)}) async {
    var body = {
      "grant_type": "authorization_code",
      "client_id": config.ClientID,
      "code": authCode,
      "redirect_uri": config.RedirectURI,
      "resource": config.Resource,
    };
    var response = await http.post(Uri.encodeFull(LOGIN_URI),
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: body);
    if (response.statusCode >= 200 && response.statusCode < 400) {
      print("GET TOKEN\n");
      Map<String, dynamic> data = json.decode(response.body);
      return data["access_token"];
    } else {
      // TODO: HANDLE ERROR!!!
      if (onError != null) {
        onError(response.body);
      }
      return "";
    }
  }

  String GetAuthCodeURIv2(AADConfig config) {
    var uri_base = Uri.parse(AUTH_URI);

    var query = {
      "client_id": config.ClientID,
      "response_type": "code",
      "response_mode": "query",
    };

    var uri = Uri(
        host: uri_base.host,
        scheme: uri_base.scheme,
        path: uri_base.path,
        queryParameters: query);
    var parsed_uri = uri.toString();
    if (config.scope != null && config.scope.length > 0) {
      parsed_uri += "&scope=" + config.Scope.join('%20');
    }
    return parsed_uri;
  }

  Future<String> GetTokenWithAuthCodev2(AADConfig config, String authCode,
      {void onError(String)}) async {
    var body = {
      "grant_type": "authorization_code",
      "client_id": config.ClientID,
      "scope": config.Scope.join(' '),
      "code": authCode,
      "redirect_uri": config.RedirectURI,
    };
    var response = await http.post(Uri.encodeFull(V2_LOGIN_URI),
        headers: {"Accept": "application/json;odata=verbose"}, body: body);
    print("GET TOKEN\n");
    if (response.statusCode >= 200 && response.statusCode < 400) {
      Map<String, dynamic> data = json.decode(response.body);
      return data["access_token"];
    } else {
      // TODO: HANDLE ERROR!!!
      if (onError != null) {
        onError(response.body);
      }
      return "";
    }
  }
}
