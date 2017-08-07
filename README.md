# elm-ordeal

> Write unit tests in Elm, support async Task out of the box, can run directly on Node or any major browsers.

**Warning** This is still a work in progress, API will probably change a bit before 1.0 release.

## Install

```bash
elm-package install pauldijou/elm-ordeal
```

## Writing your first tests

```elm
port module Test exposing (..)

import Task
import Ordeal exposing (..)

main: OrdealProgram
main = run emit tests

port emit : Event -> Cmd msg

tests: Test
tests =
  describe "My first suite"
    [ test "My very first test" (
      "a" |> shouldEqual "a"
    )
    , describe "A sub-suite"
      [ test "And a sub-test" (
        { a = 1, b = False } |> shouldEqual { a = 1, b = False }
      )
      , test "Another sub-test" (
        True |> shouldNotEqual False
      )
      ]
    , xtest "A skipped test" (
      "a" |> shouldEqual "b"
    )
    , test "My first async test" (
      Task.succeed 42 |> andTest (\value -> value |> shouldBeGreaterThan 35)
    )
    , test "My first failure" (
      Task.fail { a = 1, b = "aze" } |> andTest (\value -> value |> shouldEqual "54")
    )
    , test "Another failure" (
      ["a","b","c"] |> shouldContain "d"
    )
    ]
```

## Running tests

The easiest way is to use the [elm-ordeal](https://www.npmjs.com/package/elm-ordeal) CLI with Yarn or NPM.


### Getting started

```bash
# NPM users
npm install --save-dev elm-ordeal
# Yarn users
yarn add --dev elm-ordeal

# Run
elm-ordeal your/TestFile.elm

# Learn
elm-ordeal --help
```

You could also update your `package.json` file:

```json
{
  "scripts": {
    "test": "elm-ordeal your/TestFile.elm"
  }
}
```

```bash
# Then run the added script
npm test
yarn test
```

### Envs

You can run your tests on the following environments, just specify the correct CLI argument when running `elm-ordeal`. Don't forget it's up to you to locally install any browser you want to use. If you don't provide any env, it will run as Node. You can specify several envs at once of course.

- Node (`--node`)
- Chrome (`--chrome`)
- Edge Explorer (`--edge`)
- Firefox (`--firefox`)
- Internet Explorer (`--ie`)
- Opera (`--opera`)
- Safari (`--safari`)

## Combinators

You can combine tests using `Ordeal.and` or `Ordeal.or`. Here is the result of combining two tests:

⮳ and       | Success | Skipped | Timeout | Failure
------------|---------|---------|---------|--------
**Success** | Success | Success | Timeout | Failure
**Skipped** | Success | Skipped | Timeout | Failure
**Timeout** | Timeout | Timeout | Timeout | Timeout
**Failure** | Failure | Failure | Failure | Failure

⮳ or       | Success | Skipped | Timeout | Failure
------------|---------|---------|---------|--------
**Success** | Success | Success | Success | Success
**Skipped** | Success | Skipped | Timeout | Failure
**Timeout** | Success | Timeout | Timeout | Failure
**Failure** | Success | Failure | Timeout | Failure

In case of two `Failure`, `Ordeal.and` will return the first one while `Ordeal.or` will return the second one.

You can also use `Ordeal.all` and `Ordeal.any` which works on list of tests just folding them using `Ordeal.and` and `Ordeal.or` respectively.

## Why? Why not just use elm-test?

It's up to you, I think `elm-test` is good but when I started writing tests in Elm, I needed to test `Task` and there was no way to do it easily using `elm-test` (not sure if there is now). In `elm-ordeal`, all tests are tasks, so they can be can synchronous or asynchronous, the package does not care.

## Test

You can run the tests using `yarn install && yarn test`. Currently, the final result should be one timeout, one skipped and all other success.

## Thanks

A big thank to [@rtfeldman](https://github.com/gaearon) for creating [node-test-runner](https://github.com/rtfeldman/node-test-runner) which I took a lot of inspiration from.

## License

This software is licensed under the Apache 2 license, quoted below.

Copyright Paul Dijou ([http://pauldijou.fr](http://pauldijou.fr)).

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this project except in compliance with the License. You may obtain a copy of the License at [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
