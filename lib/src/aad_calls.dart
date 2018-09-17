import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as base_http;

import 'aad_classes.dart';
import 'constants.dart';

class FlutterAAD {
  final base_http.BaseClient http;
  Map<String, dynamic> _fullToken;
  Map<String, dynamic> get fullToken =>
      _fullToken == null ? null : Map.from(_fullToken);
  bool get loggedIn => (_fullToken != null &&
      _fullToken["access_token"] != null &&
      _fullToken["access_token"] != "");

  String get currentToken {
    if (_fullToken != null && _fullToken["access_token"] != null) {
      return _fullToken["access_token"];
    }
    return "";
  }

  String get currentRefreshToken {
    if (_fullToken != null && _fullToken["refresh_token"] != null) {
      return _fullToken["refresh_token"];
    }
    return "";
  }

  final AADConfig _config;
  AADConfig get config => _config;

  FlutterAAD(this._config,
      {base_http.BaseClient http, Map<String, dynamic> fullToken})
      : this.http = http ?? new base_http.Client(),
        this._fullToken = fullToken;

  /// Generates the OAuth2 URI to be used for a webview to renderer to be able to send
  /// back the authorization code properly.
  String GetAuthCodeURI() {
    var uri_base = Uri.parse(AUTH_URI);
    if (config.apiVersion != 1) {
      uri_base = Uri.parse(V2_AUTH_URI);
    }

    var query = {
      "client_id": config.clientID,
      "response_type": "code",
      "response_mode": "query",
    };
    if (config.apiVersion == 1) {
      query["resources"] = config.resource;
    }

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

  /// Call out to OAuth2 and get a token given an authentication code or empty
  /// string if the call isn't successful. This will also call the passed
  /// onError with the body of the error response.
  Future<String> GetTokenWithAuthCode(String authCode,
      {void onError(String msg)}) async {
    Map<String, dynamic> data =
        await this.GetTokenMapWithAuthCode(authCode, onError: onError);
    if (data != null) {
      return data["access_token"];
    } else {
      return "";
    }
  }

  /// Call out to OAuth2 and get the full map token back given an authentication
  /// code or null if the call isn't successful. This will also call the passed
  /// onError with the body of the error response.
  Future<Map<String, dynamic>> GetTokenMapWithAuthCode(String authCode,
      {void onError(String msg)}) async {
    var body = {
      "grant_type": "authorization_code",
      "client_id": config.clientID,
      "code": authCode,
      "redirect_uri": config.redirectURI,
    };
    switch (config.apiVersion) {
      case 1:
        body["resource"] = config.resource;
        break;
      case 2:
        body["scope"] = config.Scope.join(' ');
        break;
    }
    base_http.Response response;
    if (config.apiVersion == 1) {
      response = await http.post(Uri.encodeFull(LOGIN_URI),
          headers: {"Content-Type": "application/x-www-form-urlencoded"},
          body: body);
    } else {
      response = await http.post(Uri.encodeFull(V2_LOGIN_URI),
          headers: {"Accept": "application/json;odata=verbose"}, body: body);
    }

    if (response != null &&
        response.statusCode >= 200 &&
        response.statusCode < 400) {
      _fullToken = json.decode(response.body);
      return _fullToken;
    } else {
      if (onError != null) {
        onError(response?.body);
      }
      return null;
    }
  }

  /// Call out to OAuth2 and get the full map token back given a refresh token or
  /// null if the call isn't successful. This will also call the passed
  /// onError with the body of the error response.
  Future<Map<String, dynamic>> RefreshTokenMap(
      {String refreshToken, void onError(String msg)}) async {
    var rtoken = refreshToken;
    if (rtoken == null || rtoken == "") {
      rtoken = this.currentRefreshToken;
      if (rtoken == "") {
        if (onError != null) {
          onError("No refresh token passed and saved full token is empty.");
        }
        return null;
      }
    }
    var body = {
      "grant_type": "refresh_token",
      "client_id": config.clientID,
      "refresh_token": rtoken,
    };

    var login_url = LOGIN_URI;
    if (config.apiVersion == 1) {
      body["resource"] = config.resource;
    } else {
      body["scope"] = config.Scope.join(' ');
      body["redirect_uri"] = config.redirectURI;
      login_url = V2_LOGIN_URI;
    }

    var response = await http.post(Uri.encodeFull(login_url),
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: body);
    if (response.statusCode >= 200 && response.statusCode < 400) {
      _fullToken = json.decode(response.body);
      return _fullToken;
    } else {
      if (onError != null) {
        onError(response.body);
      }
      return null;
    }
  }

  /// Call out for List items by Title and return null when not successful and
  /// the Map<String, dynamic> that is returned if successful. This will also
  /// call the passed onError with the body of the error response.
  Future<AADMap> GetListItems(String site, String title,
      {String token,
      String refresh_token,
      List<String> select,
      String orderby,
      List<String> filter,
      void onError(String msg)}) async {
    var tok = token;
    if (tok == null || tok == "") {
      tok = this.currentToken;
      if (tok == "") {
        if (onError != null) {
          onError("No access token passed and saved full token is empty.");
        }
        return null;
      }
    }

    var rtoken = refresh_token;
    if (rtoken == null || rtoken == "") {
      rtoken = this.currentRefreshToken;
      if (rtoken == "") {
        if (onError != null) {
          onError("No refresh token passed and saved full token is empty.");
        }
        return null;
      }
    }

    var response = await this.GetListItemsResponse(site, title,
        token: tok,
        refresh_token: rtoken,
        select: select,
        orderby: orderby,
        filter: filter);
    if (response.response.statusCode >= 200 &&
        response.response.statusCode < 400) {
      return AADMap(json.decode(response.response.body),
          response.didRefreshToken, response.full_token);
    } else {
      if (onError != null) {
        onError(response.response.body);
      }
      return null;
    }
  }

  /// Call out for List items by Title and return null when not successful and
  /// the Map<String, dynamic> that is returned if successful. This will also
  /// call the passed onError with the body of the error response.
  /// DOES NOT TRY TO REFRESH TOKEN FOR YOU!
  Future<Map<String, dynamic>> GetListItemsWORefresh(String site, String title,
      {String token,
      List<String> select,
      String orderby,
      List<String> filter,
      void onError(String msg)}) async {
    var tok = token;
    if (tok == null || tok == "") {
      tok = this.currentToken;
      if (tok == "") {
        if (onError != null) {
          onError("No access token passed and saved full token is empty.");
        }
        return null;
      }
    }

    var response = await this.GetListItemsResponseWORefresh(site, title,
        token: tok, select: select, orderby: orderby, filter: filter);
    if (response != null &&
        response.statusCode >= 200 &&
        response.statusCode < 400) {
      return json.decode(response.body);
    } else {
      return null;
    }
  }

  /// Call out for List items by Title and return the response it gets back.
  Future<AADResponse> GetListItemsResponse(String site, String title,
      {String token,
      String refresh_token,
      List<String> select,
      String orderby,
      List<String> filter,
      void onError(String msg)}) async {
    var tok = token;
    if (tok == null || tok == "") {
      tok = this.currentToken;
      if (tok == "") {
        if (onError != null) {
          onError("No access token passed and saved full token is empty.");
        }
        return null;
      }
    }

    var rtoken = refresh_token;
    if (rtoken == null || rtoken == "") {
      rtoken = this.currentRefreshToken;
      if (rtoken == "") {
        if (onError != null) {
          onError("No refresh token passed and saved full token is empty.");
        }
        return null;
      }
    }

    var url = site;
    if (!site.endsWith("/")) {
      url += "/";
    }
    url += "_api/web/lists/getbytitle('$title')/items";

    var first = true;
    if (select != null && select.length > 0) {
      url += "?\$select=" + select.join(",");
      first = false;
    }

    if (filter != null && filter.length > 0) {
      if (first) {
        url += "?\$filter=" + filter.join(" and ");
        first = false;
      } else {
        url += "&\$filter=" + filter.join(" and ");
      }
    }

    if (orderby != null && orderby.length > 0) {
      if (first) {
        url += "?\$orderby=$orderby";
      } else {
        url += "&\$orderby=$orderby";
      }
    }

    var response = await http.get(url, headers: {
      "Accept": "application/json;odata=verbose",
      "Authorization": "Bearer $tok"
    });

    // handle refresh
    Map<String, dynamic> full_token;
    if (response.statusCode == 401 && rtoken != "") {
      //statusCode:401
      //body: {"error_description":"Invalid JWT token. The token is expired."}
      for (int i = 0; i < config.refreshTries; i++) {
        full_token = await this.RefreshTokenMap(refreshToken: rtoken);
        if (full_token != null) {
          var sub_resp = await GetListItemsResponseWORefresh(site, title,
              select: select, orderby: orderby, filter: filter);
          if (sub_resp.statusCode >= 200 && sub_resp.statusCode < 400) {
            return AADResponse(sub_resp, true, full_token);
          }
        }
      }
      print(
          "Failed to properly refresh token! Calling onError with original response body.");
    }
    if (response.statusCode < 200 ||
        response.statusCode == 400 ||
        response.statusCode > 401 ||
        (response.statusCode == 401 && full_token == null)) {
      if (onError != null) {
        onError(response.body);
      }
    }

    return AADResponse(response);
  }

  /// Call out for List items by Title and return the response it gets back.
  /// DOES NOT TRY TO REFRESH TOKEN FOR YOU!
  Future<base_http.Response> GetListItemsResponseWORefresh(
      String site, String title,
      {String token,
      List<String> select,
      String orderby,
      List<String> filter}) async {
    var tok = token;
    if (tok == null || tok == "") {
      tok = this.currentToken;
      if (tok == "") {
        return null;
      }
    }

    var url = site;
    if (!site.endsWith("/")) {
      url += "/";
    }
    url += "_api/web/lists/getbytitle('$title')/items";

    var first = true;
    if (select != null && select.length > 0) {
      url += "?\$select=" + select.join(",");
      first = false;
    }

    if (filter != null && filter.length > 0) {
      if (first) {
        url += "?\$filter=" + filter.join(" and ");
        first = false;
      } else {
        url += "&\$filter=" + filter.join(" and ");
      }
    }

    if (orderby != null && orderby.length > 0) {
      if (first) {
        url += "?\$orderby=$orderby";
      } else {
        url += "&\$orderby=$orderby";
      }
    }

    return await http.get(url, headers: {
      "Accept": "application/json;odata=verbose",
      "Authorization": "Bearer $tok"
    });
  }

  /// Call out for the logged in user's profile and return the response it gets
  /// back. This will also call the passed onError with the body of the error
  /// response.
  Future<base_http.Response> GetMyProfileResponse(
      {String token,
      List<String> select,
      String orderby,
      List<String> filter}) async {
    var url = GRAPH_URI + "/me";
    var tok = token;
    if (tok == null || tok == "") {
      tok = this.currentToken;
      if (tok == "") {
        return null;
      }
    }

    return await http.get(url, headers: {
      "Accept": "application/json;odata=verbose",
      "Authorization": "Bearer $tok"
    });
  }

  /// Call out for the logged in user's profile and return null when not
  /// successful and the Map<String, dynamic> that is returned if successful.
  /// This will also call the passed onError with the body of the error response.
  Future<Map<String, dynamic>> GetMyProfile(
      {String token,
      List<String> select,
      String orderby,
      List<String> filter,
      void onError(String msg)}) async {
    var tok = token;
    if (tok == null || tok == "") {
      tok = this.currentToken;
      if (tok == "") {
        if (onError != null) {
          onError("No access token passed and saved full token is empty.");
        }
        return null;
      }
    }

    var response = await this.GetMyProfileResponse(
        token: tok, select: select, orderby: orderby, filter: filter);
    if (response.statusCode >= 200 && response.statusCode < 400) {
      return json.decode(response.body);
    } else {
      if (onError != null) {
        onError(response.body);
      }
      return null;
    }
  }
}
