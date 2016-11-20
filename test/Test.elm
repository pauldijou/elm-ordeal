module Test exposing (..)

import Task
import Ordeal exposing (..)

andThen = flip Task.andThen

all: Test
all =
  describe "My first suite" <| \() ->
    [ test "My very first test" <| \() ->
      expect "a"
      |> toBe "a"
    , describe "A sub-suite" <| \() ->
      [ test "And a sub-test" <| \() ->
        { a = 1, b = False }
        |> isExpected
        |> toEqual { a = 1, b = False }
      ]
    , testTask "My first async test" (
      Task.succeed 42
      |> andTest (\value -> expect value |> toBe 42)
      |> Task.map toString
      |> andTest (\value -> expect value |> toBe "42")
    )
    , testTask "My first failure" (
      Task.fail { a = 1, b = "aze" }
      |> andTest (\value -> expect value |> toBe "54")
    )
    ]
