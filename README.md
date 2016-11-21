# elm-ordeal

> Test your Elm code inside Node or any major browser. Support async Task out of the box

## Proof of concept

This project is currently no more than a **proof-of-concept**, it's not published in the NPM nor Elm registry. But, if you have Chrome, you can see it in action by doing:

```bash
git clone https://github.com/pauldijou/elm-ordeal
git clone https://github.com/pauldijou/elm-ordeal-cli
cd elm-ordeal-cli

# NPM users
npm install
npm test
# Yarn users
yarn install
yarn test
```

## Writing your first tests

```elm
module Test exposing (..)

import Task
import Ordeal exposing (..)

main = run all

all: Test
all =
  describe "My first suite"
    [ test "My very first test" (
      "a"
      |> shouldEqual "a"
    )
    , describe "A sub-suite"
      [ test "And a sub-test" (
        { a = 1, b = False }
        |> shouldEqual { a = 1, b = False }
      )
      ]
    , test "My first async test" (
      Task.succeed 42
      |> andTest (\value -> value |> shouldEqual 42)
    )
    , test "My first failure" (
      Task.fail { a = 1, b = "aze" }
      |> andTest (\value -> value |> shouldEqual "54")
    )
    ]
```

## Envs

You can run your tests on the following environments, just specify the correct CLI argument when running `elm-ordeal`. Don't forget it's up to you to locally install any browser you want to use.

- Node (`--node`)
- Chrome (`--chrome`)
- Firefox (`--firefox`)
- Safari (`--safari`)
- Edge / Internet Explorer (`--ie`)
- Opera (`--opera`)

## Thanks

A big thank to [@rtfeldman](https://github.com/gaearon) for creating [node-test-runner](https://github.com/rtfeldman/node-test-runner) which I took a lot of inspiration from.

## License

This software is licensed under the Apache 2 license, quoted below.

Copyright 2017 Paul Dijou ([http://pauldijou.fr](http://pauldijou.fr)).

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this project except in compliance with the License. You may obtain a copy of the License at [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
