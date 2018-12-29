import 'package:http/http.dart' as base_http;
import 'package:meta/meta.dart';

class AADConfig {
  String clientID;
  String redirectURI;
  final List<String> scope;
  String resource;
  int refreshTries;
  int apiVersion;

  AADConfig({
    this.resource,
    @required this.clientID,
    @required this.redirectURI,
    List<String> scope,
    this.refreshTries = 3,
    this.apiVersion = 1,
  }) : this.scope = scope ?? [];

  AADConfig.clone(AADConfig config)
      : resource = config.resource,
        clientID = config.clientID,
        redirectURI = config.redirectURI,
        scope = List.from(config.scope),
        refreshTries = config.refreshTries,
        apiVersion = config.apiVersion;

  List<String> get Scope => List.from(scope);
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
