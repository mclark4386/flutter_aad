## [0.3.9] - 20190110

* testing a fba refresh call back

## [0.3.8] - 20181229

* can now clone configs

## [0.3.7] - 20181228

* fixed bug onlyOutput path

## [0.3.6] - 20181228

* added ability to only output and not update internal token
* added ability to make a token_header with given token

## [0.3.5] - 20181228

* adding refresh overrides for adding access to tokens

## [0.3.4] - 20181106

* moved to http 0.12.0

## [0.3.3] - 20181101

* helps if logggedIn works with fedAuth as well

## [0.3.2] - 20181101

* now keeping track of the host for you!

## [0.3.1] - 20181101

* host for FBAlogin should include protocol now
* (still testing if this is stable)

## [0.3.0] - 20181031

* lots of spooky changes! (Suggest not touching this version until I have it evened out... sorry)
* major changes to how auth is handled so that we can also (hopefully) handle "on site" Form Based Authentications

## [0.2.9] - 20181022

* fixed some params for search

## [0.2.8] - 20181009

* move back to 0.11.0 for http since that's what beta channel is on
* added token getter that also returns the response so that you can get at the headers as well if needed

## [0.2.7] - 20181004

* use latest http

## [0.2.6] - 20180921

* made refresh more selective

## [0.2.5] - 20180921

* added expand to list item calls

## [0.2.4] - 20180920

* improved sharepoint search call

## [0.2.3] - 20180920

* added sharepoint search call

## [0.2.2] - 20180917

* added stream for watching login state

## [0.2.1] - 20180917

* now have 100% coverage
* fixed a couple of bugs found by improving the testing

## [0.2.0] - 20180915

* config is now stored on FlutterAAD instance so we don't have pass it into every function, but you can always make another instance with a different config if you need to!
* with the move of the config into state it made sense to also store the token in state and update calls accordingly

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
