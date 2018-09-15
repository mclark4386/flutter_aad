import 'dart:convert';
import 'dart:io';

import 'package:flutter_aad/flutter_aad.dart';

void main() async {
  Map<String, String> envVars = Platform.environment;
  final aadConfig = AADConfig(
      resource: envVars['AAD_RESOURCE'],
      clientID: envVars['AAD_CLIENT_ID'],
      redirectURI: envVars['AAD_REDIRECT_URI'],
      scope: [
        "openid",
        "offline_access",
        "Sites.Read.All",
        "User.Read",
        "profile"
      ]);

  var aad = FlutterAAD();

  final auth_code_uri = await aad.GetAuthCodeURI(aadConfig);
  print(
      "Please use a browsers to access the following url and then copy and paste the uri it redirected you to here:" +
          auth_code_uri);
  final redirected_uri = Uri.parse(stdin.readLineSync());

  if (!redirected_uri.hasQuery ||
      redirected_uri.queryParameters["code"] == null) {
    print("ERROR GETTING AUTH CODE!!!");
    print(redirected_uri);
    return;
  }

  final authCode = redirected_uri.queryParameters["code"];

  var full_token = await aad.GetTokenMapWithAuthCode(aadConfig, authCode);

  if (full_token == null) {
    print("ERROR GETTING TOKEN!!!");
    return;
  }

  print("Full token:");
  print(full_token);

  JsonEncoder encoder = new JsonEncoder.withIndent('  ');

  var profile = await aad.GetMyProfile(full_token["access_token"]);
  print("here is the profile:");
  print(encoder.convert(profile));

  var lists = await aad.GetListItems(aadConfig,
      aadConfig.resource, "Documents", full_token["access_token"], full_token["refresh_token"]);
  print("Here is our lists:");
  print(encoder.convert(lists.map));
}
