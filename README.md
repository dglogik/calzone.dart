# calzone

**Here be dragons.**

A compiler/patcher for a JS bridge to your Dart library, using dart2js and analyzer.

Yes, I'm fully aware that dev_compiler will be able to do this. Better, faster, and with smaller file sizes. But the project I needed this for didn't have the timeframe to wait. I hope if your desperately in need of something like this today, that you'll find good use in calzone. Otherwise, you should probably wait for dev_compiler.

I'm currently refactoring some internal parts of the library, but there is still some rather nasty functions used internally.

Calzone's CLI patching tools are also not exactly up to par right now, in the future there will be a much easier way to use calzone.

calzone is rapidly evolving, changing, and being refactored. If your interested in using it and are having problems using it, please contact mbullington on Freenode, I'm in the #dart channel.

## Transformers

**Exactly what meets the eye, they are pretty simple.**

A large part of calzone works by transformers. A transformer is an addon to the compiler that will bridge together a Dart type (or types) with their JavaScript equivalents. An example of this is the PromiseTransformer, where it will take Promises and convert them to Futures, and vice versa. This API is frozen and is available for projects using calzone to build their own.

The best example of this is in the calzone.transformers library, which is our standard library for transformers.

Wiki documentation for using the dynamic parts of a transformer will be available shortly.

## Using calzone

Right now, the best example I can give for using calzone is [sdk-dslink-javascript](https://www.github.com/IOT-DSA/sdk-dslink-javascript), mostly in the tool/wrapper_gen.dart file. Wiki documentation for this as well will be ready soon.
