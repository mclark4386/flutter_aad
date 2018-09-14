import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as base_http;

import 'aad_config.dart';
import 'constants.dart';

class FlutterAAD {
  final base_http.BaseClient http;

  FlutterAAD({base_http.BaseClient http})
      : this.http = http ?? new base_http.Client();

  /// Generates the OAuth2 v1 URI to be used for a webview to renderer to be able to send
  /// back the authorization code properly.
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

  /// Call out to OAuth2 v1 get a token given an authentication code or empty
  /// string if the call isn't successful. This will also call the passed
  /// onError with the body of the error response.
  Future<String> GetTokenWithAuthCodev1(AADConfig config, String authCode,
      {void onError(String msg)}) async {
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
      Map<String, dynamic> data = json.decode(response.body);
      return data["access_token"];
    } else {
      if (onError != null) {
        onError(response.body);
      }
      return "";
    }
  }

  /// Call out to OAuth2 v1 get the full map token back given an authentication
  /// code or null if the call isn't successful. This will also call the passed
  /// onError with the body of the error response.
  Future<Map<String, dynamic>> GetTokenMapWithAuthCodev1(
      AADConfig config, String authCode,
      {void onError(String msg)}) async {
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
      return json.decode(response.body);
    } else {
      if (onError != null) {
        onError(response.body);
      }
      return null;
    }
  }

  /// Call out to OAuth2 v1 get the full map token back given a refresh token or
  /// null if the call isn't successful. This will also call the passed
  /// onError with the body of the error response.
  Future<Map<String, dynamic>> RefreshTokenMapv1(
      AADConfig config, String refreshToken,
      {void onError(String msg)}) async {
    var body = {
      "grant_type": "refresh_token",
      "client_id": config.ClientID,
      "refresh_token": refreshToken,
      "resource": config.Resource,
    };
    var response = await http.post(Uri.encodeFull(LOGIN_URI),
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: body);
    if (response.statusCode >= 200 && response.statusCode < 400) {
      return json.decode(response.body);
    } else {
      if (onError != null) {
        onError(response.body);
      }
      return null;
    }
  }

  /// Generates the OAuth2 v2 URI to be used for a webview to renderer to be able to send
  /// back the authorization code properly.
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

  /// Call out to OAuth2 v2 get a token given an authentication code or empty
  /// string if the call isn't successful. This will also call the passed
  /// onError with the body of the error response.
  Future<String> GetTokenWithAuthCodev2(AADConfig config, String authCode,
      {void onError(String msg)}) async {
    var body = {
      "grant_type": "authorization_code",
      "client_id": config.ClientID,
      "scope": config.Scope.join(' '),
      "code": authCode,
      "redirect_uri": config.RedirectURI,
    };
    var response = await http.post(Uri.encodeFull(V2_LOGIN_URI),
        headers: {"Accept": "application/json;odata=verbose"}, body: body);
    if (response.statusCode >= 200 && response.statusCode < 400) {
      Map<String, dynamic> data = json.decode(response.body);
      return data["access_token"];
    } else {
      if (onError != null) {
        onError(response.body);
      }
      return "";
    }
  }

  /// Call out to OAuth2 v2 get the full map token back given an authentication
  /// code or null if the call isn't successful. This will also call the passed
  /// onError with the body of the error response.
  Future<Map<String, dynamic>> GetTokenMapWithAuthCodev2(
      AADConfig config, String authCode,
      {void onError(String msg)}) async {
    var body = {
      "grant_type": "authorization_code",
      "client_id": config.ClientID,
      "scope": config.Scope.join(' '),
      "code": authCode,
      "redirect_uri": config.RedirectURI,
    };
    var response = await http.post(Uri.encodeFull(V2_LOGIN_URI),
        headers: {"Accept": "application/json;odata=verbose"}, body: body);
    if (response.statusCode >= 200 && response.statusCode < 400) {
      return json.decode(response.body);
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
  Future<Map<String, dynamic>> GetListItems(
      String site, String title, String token,
      {List<String> select,
      String orderby,
      List<String> filter,
      void onError(String msg)}) async {
    var response = await this.GetListItemsResponse(site, title, token,
        select: select, orderby: orderby, filter: filter);
    if (response.statusCode >= 200 && response.statusCode < 400) {
      return json.decode(response.body);
    } else {
      if (onError != null) {
        onError(response.body);
      }
      return null;
    }
  }

  /// Call out for List items by Title and return the response it gets back.
  Future<base_http.Response> GetListItemsResponse(
      String site, String title, String token,
      {List<String> select, String orderby, List<String> filter}) async {
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
      "Authorization": "Bearer $token"
    });
  }

  /// Call out for the logged in user's profile and return the response it gets
  /// back. This will also call the passed onError with the body of the error
  /// response.
  Future<base_http.Response> GetMyProfileResponse(String token,
      {List<String> select, String orderby, List<String> filter}) async {
    var url = GRAPH_URI + "/me";

    return await http.get(url, headers: {
      "Accept": "application/json;odata=verbose",
      "Authorization": "Bearer $token"
    });
  }

  /// Call out for the logged in user's profile and return null when not
  /// successful and the Map<String, dynamic> that is returned if successful.
  /// This will also call the passed onError with the body of the error response.
  Future<Map<String, dynamic>> GetMyProfile(String token,
      {List<String> select,
      String orderby,
      List<String> filter,
      void onError(String msg)}) async {
    var response = await this.GetMyProfileResponse(token,
        select: select, orderby: orderby, filter: filter);
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
