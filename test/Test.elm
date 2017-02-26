port module Test exposing (..)

import Task
import Process
import Ordeal exposing (..)

main: OrdealProgram
main = run emit all

port emit : Event -> Cmd msg

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
      Task.succeed 42 |> andTest (\value -> value |> shouldBeGreaterThan 35)
    )
    , test "My first failure" (
      Task.fail { a = 1, b = "aze" } |> andTest (\value -> value |> shouldEqual "54")
    )
    , test "Another failure" (
      ["a","b","c"] |> shouldContain "d"
    )
    , test "This test will take nearly 50ms" (
      Process.sleep 50
      |> Task.map (always 1)
      |> andTest (\value -> value |> shouldEqual 1)
    )
    , test "This test will timeout" (
      Process.sleep 10000
      |> Task.map (always 1)
      |> andTest (\value -> value |> shouldEqual 1)
    )
    , test "This is a success" (
      success
    )
    , test "This is a failure" (
      failure "You failed"
    )
    ]
