port module Test exposing (..)

import Task
import Process
import Ordeal exposing (..)

main: Ordeal
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
      , test "My first failure" (
        Task.fail { a = 1, b = "aze" } |> andTest (\value -> value |> shouldEqual "54")
      )
      ]
    , xtest "A skipped test" (
      "a" |> shouldEqual "b"
    )
    , test "My first async test" (
      Task.succeed 42 |> andTest (\value -> value |> shouldBeGreaterThan 35)
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
    , test "This test will be skipped" (
      skipped
    )
    , test "This test will also timeout" (
      timeout
    )
    , test "This test is lazy" (
      lazy (\_ -> success)
    )
    , test "andTest" (
      Task.succeed 1
      |> andTest (\value ->
        if (value == 1) then success else failure "Should be 1"
      )
    )
    , test "andThen" (
      success
      |> andThen ("abc" |> shouldEqual "abc")
      |> andThen (42    |> shouldEqual 42)
      |> andThen (True  |> shouldEqual True)
    )
    , describe "Task"
      [ test "should succeed" (
        Task.succeed 1
        |> shouldSucceed
      )
      , test "should succeed but will not" (
        Task.fail True
        |> shouldSucceed
      )
      , test "should succeed with 1" (
        Task.succeed 1
        |> shouldSucceedWith 1
      )
      , test "should succeed with True but will not" (
        Task.succeed False
        |> shouldSucceedWith True
      )
      , test "should fail" (
        Task.fail "boom"
        |> shouldFail
      )
      , test "should fail but will not" (
        Task.succeed 4.2
        |> shouldFail
      )
      , test "should fail with { a = 1, b = True}" (
        Task.fail { a = 1, b = True}
        |> shouldFailWith { b = True, a = 1 }
      )
      , test "should fail with 'a' but will not" (
        Task.fail "b"
        |> shouldFailWith "a"
      )
      ]
    ]
