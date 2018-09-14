import 'package:http/http.dart' as base_http;
import 'package:meta/meta.dart';

class AADConfig {
  final String clientID;
  final String redirectURI;
  final List<String> scope;
  final String resource;
  final int refreshTries;
  final int apiVersion;

  AADConfig({
    this.resource,
    @required this.clientID,
    @required this.redirectURI,
    List<String> scope,
    this.refreshTries = 3,
    this.apiVersion = 1,
  }) : this.scope = scope ?? [];

  String get ClientID => clientID;
  String get RedirectURI => redirectURI;
  List<String> get Scope => List.from(scope);
  String get Resource => resource;
}

class AADMap {
  Map<String, dynamic> map;
  bool didRefreshToken;
  Map<String, dynamic> full_token;
  AADMap(this.map, [this.didRefreshToken = false, this.full_token = null]);
}

class AADResponse {
  base_http.Response response;
  bool didRefreshToken;
  Map<String, dynamic> full_token;
  AADResponse(this.response,
      [this.didRefreshToken = false, this.full_token = null]);
}
