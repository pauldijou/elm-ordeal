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
