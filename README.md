# calzone

Use your Dart library from JavaScript!

A compiler/patcher for a JS bridge to your Dart library, using dart2js and analyzer.

Even though calzone.dart is reaching maturity, if you're interested in using it
and are having problems using it, please contact mbullington on the Dart Slack.

## Transformers

A large part of calzone works by transformers. A transformer is an addon to the
compiler that will bridge together a Dart type (or types) with their JavaScript
equivalents. An example of this is the PromiseTransformer, where it will take
Promises and convert them to Futures, and vice versa. This API is frozen and is
available for projects using calzone to build their own.

The best example of this is in the calzone.transformers library, which is our
standard library for transformers. Most of these transformers are suggested
for use, such as Promises <-> Future, Closure, and Collections.

## Using calzone

Please refer to the Wiki on how to use calzone, starting with
[Creating a Stub](https://github.com/dglogik/calzone.dart/wiki/Creating-a-Stub),
then [Internal Workings](https://github.com/dglogik/calzone.dart/wiki/Internal-Workings).
For most usecases, you'll want to use the high-level Builder abstraction.

For an example of using Builder, please refer to test/, or to
[sdk-dslink-javascript](https://www.github.com/IOT-DSA/sdk-dslink-javascript).
