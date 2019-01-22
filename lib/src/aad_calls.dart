import 'dart:async';
import 'dart:convert';

import 'package:corsac_jwt/corsac_jwt.dart';
import 'package:http/http.dart' as base_http;

import 'aad_classes.dart';
import 'constants.dart';

class FlutterAAD {
  final base_http.BaseClient http;
  StreamController<bool> _tokenStreamController =
      StreamController<bool>.broadcast();
  StreamSink<bool> get _tokenIn => _tokenStreamController.sink;
  Stream<bool> get login => _tokenStreamController.stream;

  Map<String, dynamic> _fullToken;
  Map<String, dynamic> get fullToken =>
      _fullToken == null ? null : Map.from(_fullToken);
  bool get loggedIn => ((_fullToken != null &&
          _fullToken["access_token"] != null &&
          _fullToken["access_token"] != "") ||
      (_fedAuthToken != null && _fedAuthToken != ""));

  String _fedAuthToken;
  String get fedAuthToken => _fedAuthToken;

  Function _fbaRefreshCallback;

  String _host;
  String get host {
    if (payload != null && payload.containsKey("aud")) {
      return payload["aud"];
    } else {
      return _host;
    }
  }

  JWT get jwt {
    if (currentToken != null && currentToken != "") {
      return new JWT.parse(currentToken);
    } else {
      return null;
    }
  }

  Map<String, dynamic> get payload {
    if (currentToken != null && currentToken != "") {
      return new JWT.parse(currentToken).claims;
    } else {
      return null;
    }
  }

  Map<String, String> headersWithToken(String token, {bool FBA = false}) {
    if (!FBA && token != null && token != "") {
      return {
        "Authorization": "Bearer $token",
      };
    } else if (token != null && token != "") {
      return {
        "Cookie": "FedAuth=$token",
      };
    }
    return {};
  }

  Map<String, String> get currentHeaders {
    if (fullToken != null) {
      return {
        "Authorization": "Bearer ${this.currentToken}",
      };
    } else if (fedAuthToken != null && fedAuthToken != "") {
      return {
        "Cookie": "FedAuth=${fedAuthToken}",
      };
    }
    return {};
  }

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
      {base_http.BaseClient http,
      Map<String, dynamic> fullToken,
      String fedAuthToken, String host})
      : this.http = http ?? new base_http.Client(),
        this._fullToken = fullToken,
        this._fedAuthToken = fedAuthToken, 
        this._host = host ?? "";

  void Logout() {
    this._fullToken = null;
    this._fedAuthToken = '';
    this._tokenIn.add(false);
  }

  /// Tries to Login to "on-site" Form Based Authentication
  Future<base_http.Response> FBALogin(host, user, password,
      {Function refreshCallback}) async {
    final soapEnv = "<?xml version=\"1.0\" encoding=\"utf-8\"?>" +
        "<soap:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\">" +
        "<soap:Body>" +
        "<Login xmlns=\"http://schemas.microsoft.com/sharepoint/soap/\">" +
        "<username>$user</username>" +
        "<password>$password</password>" +
        "</Login>" +
        "</soap:Body>" +
        "</soap:Envelope>";
    print(soapEnv);

    final url = "$host/_vti_bin/authentication.asmx";
    var response = await http.post(url,
        headers: {
          "Content-Type": "text/xml; charset=utf-8",
          "SOAPAction": "http://schemas.microsoft.com/sharepoint/soap/Login",
        },
        body: soapEnv);

    print(
        "[${response.statusCode}](${response.contentLength})${response.body}\n");
    print("header:${response.headers}\n");

    if (response.statusCode == 200) {
      var cookie = response.headers["set-cookie"];
      print(cookie);
      String raw_auth = cookie
          .split(";")
          .firstWhere((item) => item.startsWith("FedAuth"))
          .replaceAll("FedAuth=", "");

      this._host = host;

      if (refreshCallback != null) {
        this._fbaRefreshCallback = refreshCallback;
      }

      this._fedAuthToken = raw_auth;
      this._tokenIn.add(true);
    }
    return response;
  }

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
  Future<Map<String, dynamic>> GetTokenMapWithAuthCode(
    String authCode, {
    void onError(String msg),
  }) async {
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
      response = await http.post(
        Uri.encodeFull(LOGIN_URI),
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: body,
      );
    } else {
      response = await http.post(
        Uri.encodeFull(V2_LOGIN_URI),
        headers: {"Accept": "application/json;odata=verbose"},
        body: body,
      );
    }

    if (response != null &&
        response.statusCode >= 200 &&
        response.statusCode < 400) {
      _fullToken = json.decode(response.body);
      _tokenIn.add(this.loggedIn);
      return _fullToken;
    } else {
      if (onError != null) {
        onError(response?.body);
      }
      return null;
    }
  }

  /// Call out to OAuth2 and get the full map token and response back given an
  /// authentication code or null if the call isn't successful. This will also
  /// call the passed onError with the body of the error response.
  Future<AADResponse> GetTokenResponseWithAuthCode(
    String authCode, {
    void onError(String msg),
  }) async {
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
      response = await http.post(
        Uri.encodeFull(LOGIN_URI),
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: body,
      );
    } else {
      response = await http.post(
        Uri.encodeFull(V2_LOGIN_URI),
        headers: {"Accept": "application/json;odata=verbose"},
        body: body,
      );
    }

    if (response != null &&
        response.statusCode >= 200 &&
        response.statusCode < 400) {
      _fullToken = json.decode(response.body);
      _tokenIn.add(this.loggedIn);
      return AADResponse(response, false, _fullToken);
    } else {
      if (onError != null) {
        onError(response?.body);
      }
      return AADResponse(response, false, null);
    }
  }

  /// Call out to OAuth2 and get the full map token back given a refresh token or
  /// null if the call isn't successful. This will also call the passed
  /// onError with the body of the error response.
  Future<Map<String, dynamic>> RefreshTokenMap({
    String refreshToken,
    void onError(String msg),
    String clientID,
    String resource,
    String redirectURI,
    bool onlyOutput = false,
  }) async {
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
      "client_id": clientID ?? config.clientID,
      "refresh_token": rtoken,
    };

    var login_url = LOGIN_URI;
    if (config.apiVersion == 1) {
      body["resource"] = resource ?? config.resource;
    } else {
      body["scope"] = config.Scope.join(' ');
      body["redirect_uri"] = redirectURI ?? config.redirectURI;
      login_url = V2_LOGIN_URI;
    }

    var response = await http.post(Uri.encodeFull(login_url),
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: body);
    if (response.statusCode >= 200 && response.statusCode < 400) {
      var token = json.decode(response.body);
      if (!onlyOutput) {
        _tokenIn.add(this.loggedIn);
        _fullToken = token;
      }
      return token;
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
      {String refresh_token,
      List<String> select,
      String orderby,
      List<String> expand,
      List<String> filter,
      void onError(String msg)}) async {
    if (currentHeaders.keys.length == 0) {
      if (onError != null) {
        onError("No access token passed and saved full token is empty.");
      }
      return null;
    }

    var rtoken = refresh_token;
    if ((rtoken == null || rtoken == "") &&
        currentHeaders.containsKey("Authorization")) {
      rtoken = this.currentRefreshToken;
      if (rtoken == "") {
        if (onError != null) {
          onError("No refresh token passed and saved full token is empty.");
        }
        return null;
      }
    }

    var response = await this.GetListItemsResponse(site, title,
        refresh_token: rtoken,
        select: select,
        orderby: orderby,
        filter: filter,
        expand: expand);
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
      {List<String> select,
      String orderby,
      List<String> filter,
      List<String> expand,
      void onError(String msg)}) async {
    if (this.currentHeaders.keys.length == 0) {
      return null;
    }

    var response = await this.GetListItemsResponseWORefresh(site, title,
        select: select, orderby: orderby, filter: filter, expand: expand);
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
      {String refresh_token,
      List<String> select,
      String orderby,
      List<String> filter,
      List<String> expand,
      void onError(String msg)}) async {
    if (this.currentHeaders.keys.length == 0) {
      return null;
    }

    var rtoken = refresh_token;
    if ((rtoken == null || rtoken == "") &&
        (this.currentHeaders.containsKey("Authorization"))) {
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
        first = false;
      } else {
        url += "&\$orderby=$orderby";
      }
    }

    if (expand != null && expand.length > 0) {
      if (first) {
        url += "?\expand=" + expand.join(",");
        first = false;
      } else {
        url += "&\expand=" + expand.join(",");
      }
    }

    var headers = currentHeaders;
    headers["Accept"] = "application/json;odata=verbose";

    var response = await http.get(url, headers: headers);

    print("response[${response.statusCode}]:${response.body}");

    // handle refresh
    Map<String, dynamic> full_token;
    if (response.statusCode == 401 &&
        response.body.contains("The token is expired") &&
        this.currentHeaders.containsKey("Authorization")) {
      //statusCode:401
      //body: {"error_description":"Invalid JWT token. The token is expired."}
      for (int i = 0; i < config.refreshTries; i++) {
        full_token = await this.RefreshTokenMap(refreshToken: rtoken);
        if (full_token != null) {
          var sub_resp = await GetListItemsResponseWORefresh(site, title,
              select: select, orderby: orderby, filter: filter, expand: expand);
          if (sub_resp.statusCode >= 200 && sub_resp.statusCode < 400) {
            return AADResponse(sub_resp, true, full_token);
          }
        }
      }
      print(
          "Failed to properly refresh token! Calling onError with original response body.");
    } else if ((response.statusCode == 401 || response.statusCode == 403) &&
        fedAuthToken != null &&
        this._fbaRefreshCallback != null) {
      //body: {"error_description":"Invalid JWT token. The token is expired."}
      for (int i = 0; i < config.refreshTries; i++) {
        print("calling fbaRefreshCallback");
        full_token = await this._fbaRefreshCallback();
        if (full_token != null) {
          var sub_resp = await GetListItemsResponseWORefresh(site, title,
              select: select, orderby: orderby, filter: filter, expand: expand);
          if (sub_resp.statusCode >= 200 && sub_resp.statusCode < 400) {
            return AADResponse(sub_resp, true, full_token);
          }
        }
      }
      print(
          "Failed to properly refresh token! Calling onError with original response body.");
    }
        print("not calling fbaRefreshCallback:${this._fbaRefreshCallback}");
    if (response.statusCode < 200 ||
        response.statusCode == 400 ||
        response.statusCode > 403 ||
        response.statusCode == 402 ||
        (response.statusCode == 401 && full_token == null)||
        (response.statusCode == 403 && fedAuthToken == null)) {
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
      {List<String> select,
      String orderby,
      List<String> filter,
      List<String> expand}) async {
    if (this.currentHeaders.keys.length == 0) {
      return null;
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
        first = false;
      } else {
        url += "&\$orderby=$orderby";
      }
    }

    if (expand != null && expand.length > 0) {
      if (first) {
        url += "?\expand=" + expand.join(",");
        first = false;
      } else {
        url += "&\expand=" + expand.join(",");
      }
    }

    var headers = currentHeaders;
    headers["Accept"] = "application/json;odata=verbose";

    return await http.get(url, headers: headers);
  }

  /// Call out for the logged in user's profile and return the response it gets
  /// back. This will also call the passed onError with the body of the error
  /// response.
  Future<base_http.Response> GetMyProfileResponse(
      {List<String> select, String orderby, List<String> filter}) async {
    var url = GRAPH_URI + "/me";
    if (currentHeaders.keys.length == 0) {
      return null;
    }

    var headers = currentHeaders;
    headers["Accept"] = "application/json;odata=verbose";

    return await http.get(url, headers: headers);
  }

  /// Call out for the logged in user's profile and return null when not
  /// successful and the Map<String, dynamic> that is returned if successful.
  /// This will also call the passed onError with the body of the error response.
  Future<Map<String, dynamic>> GetMyProfile(
      {List<String> select,
      String orderby,
      List<String> filter,
      void onError(String msg)}) async {
    if (currentHeaders.keys.length == 0) {
      if (onError != null) {
        onError("No access token passed and saved full token is empty.");
      }
      return null;
    }

    var response = await this
        .GetMyProfileResponse(select: select, orderby: orderby, filter: filter);
    if (response.statusCode >= 200 && response.statusCode < 400) {
      return json.decode(response.body);
    } else {
      if (onError != null) {
        onError(response.body);
      }
      return null;
    }
  }

  /// Call out for a general query to the site
  Future<AADResponse> GetSharepointSearchResponse(String site,
      {String query,
      String refresh_token,
      List<String> select,
      String orderby,
      String sourceid,
      int rowlimit,
      int startrow,
      void onError(String msg)}) async {
    if (currentHeaders.keys.length == 0) {
      if (onError != null) {
        onError("No access token passed and saved full token is empty.");
      }
      return null;
    }

    var rtoken = refresh_token;
    if ((rtoken == null || rtoken == "") &&
        this.currentHeaders.containsKey("Authorization")) {
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
    url += "_api/search/query";

    url += "?querytext='" + (query ?? "*") + "'";
    if (select != null && select.length > 0) {
      url += "&selectproperties='" + select.join(",") + "'";
    }

    if (orderby != null && orderby.length > 0) {
      url += "&sortlist='$orderby'";
    }

    if (sourceid != null && sourceid.length > 0) {
      url += "&sourceid='$sourceid'";
    }

    if (rowlimit != null && rowlimit > 0) {
      url += "&rowlimit=$rowlimit";
    }

    if (startrow != null && startrow > 0) {
      url += "&startrow=$startrow";
    }

    var headers = currentHeaders;
    headers["Accept"] = "application/json;odata=verbose";

    var response = await http.get(url, headers: headers);

    print("response[${response.statusCode}]:${response.body}");

    Map<String, dynamic> full_token;
    if (response.statusCode == 401 &&
        this.currentHeaders.containsKey("Authorization")) {
      //statusCode:401
      //body: {"error_description":"Invalid JWT token. The token is expired."}
      for (int i = 0; i < config.refreshTries; i++) {
        full_token = await this.RefreshTokenMap(refreshToken: rtoken);
        if (full_token != null) {
          var sub_resp = await GetSharepointSearchResponseWORefresh(site,
              select: select,
              orderby: orderby,
              sourceid: sourceid,
              rowlimit: rowlimit,
              startrow: startrow);
          if (sub_resp.statusCode >= 200 && sub_resp.statusCode < 400) {
            return AADResponse(sub_resp, true, full_token);
          }
        }
      }
      print(
          "Failed to properly refresh token! Calling onError with original response body.");
    }else if ((response.statusCode == 401 || response.statusCode == 403) &&
        fedAuthToken != null &&
        this._fbaRefreshCallback != null) {
      //statusCode:401
      //body: {"error_description":"Invalid JWT token. The token is expired."}
      for (int i = 0; i < config.refreshTries; i++) {
        print("calling fbaRefreshCallback:${this._fbaRefreshCallback}");
        full_token = await this._fbaRefreshCallback();
        if (full_token != null) {
          var sub_resp = await GetSharepointSearchResponseWORefresh(site,
              select: select,
              orderby: orderby,
              sourceid: sourceid,
              rowlimit: rowlimit,
              startrow: startrow);
          if (sub_resp.statusCode >= 200 && sub_resp.statusCode < 400) {
            return AADResponse(sub_resp, true, full_token);
          }
        }
      }
      print(
          "Failed to properly refresh token! Calling onError with original response body.");
    }
    print("not calling fbaRefreshCallback:${this._fbaRefreshCallback}");
    if (response.statusCode < 200 ||
        response.statusCode == 400 ||
        response.statusCode > 403 ||
        response.statusCode == 402 ||
        (response.statusCode == 401 && full_token == null)||
        (response.statusCode == 403 && fedAuthToken == null)) {
      if (onError != null) {
        onError(response.body);
      }
    }

    return AADResponse(response);
  }

  /// Call out for a general query to the site
  /// DOES NOT TRY TO REFRESH TOKEN FOR YOU
  Future<base_http.Response> GetSharepointSearchResponseWORefresh(
    String site, {
    String query,
    List<String> select,
    String orderby,
    String sourceid,
    int rowlimit,
    int startrow,
  }) async {
    if (currentHeaders.keys.length == 0) {
      return null;
    }

    var url = site;
    if (!site.endsWith("/")) {
      url += "/";
    }
    url += "_api/search/query";

    url += "?querytext='" + (query ?? "*") + "'";
    if (select != null && select.length > 0) {
      url += "&selectproperties='" + select.join(",") + "'";
    }

    if (orderby != null && orderby.length > 0) {
      url += "&sortlist='$orderby'";
    }

    if (sourceid != null && sourceid.length > 0) {
      url += "&sourceid='$sourceid'";
    }

    if (rowlimit != null && rowlimit > 0) {
      url += "&rowlimit=$rowlimit";
    }

    if (startrow != null && startrow > 0) {
      url += "&startrow=$startrow";
    }

    var headers = currentHeaders;
    headers["Accept"] = "application/json;odata=verbose";

    return await http.get(url, headers: headers);
  }
}
