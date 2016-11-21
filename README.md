# elm-ordeal

> Write unit tests in Elm, support async Task out of the box

## Install

```bash
elm-package install pauldijou/elm-ordeal
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
      Task.succeed 42 |> andTest (\value -> value |> shouldEqual 42)
    )
    , test "My first failure" (
      Task.fail { a = 1, b = "aze" } |> andTest (\value -> value |> shouldEqual "54")
    )
    , test "Another failure" (
      "a" |> shouldEqual "b"
    )
    ]

```

## Running tests

Consider using [elm-ordeal-cli](https://github.com/pauldijou/elm-ordeal-cli)


```bash
npm install elm-ordeal-cli
elm-ordeal-cli your/TestFile.elm --node
```

## License

This software is licensed under the Apache 2 license, quoted below.

Copyright 2017 Paul Dijou ([http://pauldijou.fr](http://pauldijou.fr)).

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this project except in compliance with the License. You may obtain a copy of the License at [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
