## [0.2.0] - 20180915

* config is now stored on FlutterAAD instance so we don't have pass it into every function, but you can always make another instance with a different config if you need to!

## [0.1.4] - 20180915

* Improving descriptions

## [0.1.3] - 20180915

* fixed example to match new code pattern

## [0.1.2] - 20180915

* small bug _really_ fixed

## [0.1.1] - 20180915

* small bug fix

## [0.1.0] - 20180914

* broke a LOT of function signatures... was needed for the auth-refresh
* added apiVersion to AADConfig to keep the interface consistant
* merged all v1 and v2 calls to take advantage of the new apiVersion in the config
* now default to trying to refresh our token if need up to config.refreshTries times
* moved non-token-refreshing versions out and renamed them as auto-refreshing should now be the default

## [0.0.10] - 20180913

* added example
* working on docs
* forgot the v2 variation of GetTokenMapWithAuthCode
* added onError callbacks for all the calls that didn't have them before and needed them

## [0.0.9] - 20180913

* Added Get My Profile methods

## [0.0.8] - 20180912

* Added token refresh call and updates

## [0.0.7] - 20180912

* added get for full token to use when you need more than the access_token

## [0.0.6] - 20180911

* bit of refactoring

## [0.0.5] - 20180911

* little clean up and can now get list items either parsed for you or just the response (so you can send it into built_value directly if you like)

## [0.0.4] - 20180910

* added get list items api call

## [0.0.3] - 20180910

* testing should be good and getting tokens should be good

## [0.0.2] - 20180910

* Now has mocking for http tests
* Started filling out the token system a bit more

## [0.0.1] - 20180910

* Getting the base in for what I'm doing now
