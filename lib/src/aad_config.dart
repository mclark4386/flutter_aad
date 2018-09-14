import 'package:meta/meta.dart';

class AADConfig {
  final String clientID;
  final String redirectURI;
  final List<String> scope;
  final String resource;

  AADConfig(
      {this.resource,
      @required this.clientID,
      @required this.redirectURI,
      List<String> scope})
      : this.scope = scope ?? [];

  String get ClientID => clientID;
  String get RedirectURI => redirectURI;
  List<String> get Scope => List.from(scope);
  String get Resource => resource;
}
