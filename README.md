# elm-ordeal

> Write unit tests in Elm, support async Task out of the box

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
      Task.succeed 42 |> and (\value -> value |> shouldBeGreaterThan 35)
    )
    , test "My first failure" (
      Task.fail { a = 1, b = "aze" } |> and (\value -> value |> shouldEqual "54")
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
elm-ordeal your/TestFile.elm --node

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

You can run your tests on the following environments, just specify the correct CLI argument when running `elm-ordeal`. Don't forget it's up to you to locally install any browser you want to use.

- Node (`--node`)
- Chrome (`--chrome`)
- Edge Explorer (`--edge`)
- Firefox (`--firefox`)
- Internet Explorer (`--ie`)
- Opera (`--opera`)
- Safari (`--safari`)

## Why? Why not just use elm-test?

It's up to you, I think `elm-test` is good but when I started writing tests in Elm, I needed to test `Task` and there was no way to do it easily using `elm-test` (not sure if there is now). In `elm-ordeal`, all tests are tasks, so they can be can synchronous or asynchronous, the package does not care.

## Thanks

A big thank to [@rtfeldman](https://github.com/gaearon) for creating [node-test-runner](https://github.com/rtfeldman/node-test-runner) which I took a lot of inspiration from.

## License

This software is licensed under the Apache 2 license, quoted below.

Copyright Paul Dijou ([http://pauldijou.fr](http://pauldijou.fr)).

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this project except in compliance with the License. You may obtain a copy of the License at [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
