port module Test exposing (..)

import Task
import Process
import Regex
import Ordeal exposing (..)
import Ordeal.Internals exposing (..)

main: Ordeal
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
    , test "My first async test" (
      Task.succeed 42 |> andTest (\value -> value |> shouldBeGreaterThan 35)
    )
    , test "This test will take nearly 10ms" (
      Process.sleep 10
      |> Task.map (always 1)
      |> andTest (\value -> value |> shouldEqual 1)
    )
    , describe "Helpers"
      [ test "This test is lazy" (
        lazy (\_ -> success)
      )
      , test "andTest" (
        Task.succeed 1
        |> andTest (\value ->
          if (value == 1) then success else failure "Should be 1"
        )
      )
      , test "and" (
        all
          [ success |> and success |> isSuccess
          , success |> and skipped |> isSuccess
          , success |> and timeout |> isTimeout
          , success |> and (failure "") |> (isFailure "")
          , skipped |> and success |> isSuccess
          , skipped |> and skipped |> isSkipped
          , skipped |> and timeout |> isTimeout
          , skipped |> and (failure "") |> (isFailure "")
          , timeout |> and success |> isTimeout
          , timeout |> and skipped |> isTimeout
          , timeout |> and timeout |> isTimeout
          , timeout |> and (failure "") |> isTimeout
          , (failure "") |> and success |> (isFailure "")
          , (failure "") |> and skipped |> (isFailure "")
          , (failure "") |> and timeout |> (isFailure "")
          , (failure "a") |> and (failure "b") |> (isFailure "a")
          ]
      )
      , test "or" (
        all
          [ success |> or success |> isSuccess
          , success |> or skipped |> isSuccess
          , success |> or timeout |> isSuccess
          , success |> or (failure "") |> isSuccess
          , skipped |> or success |> isSuccess
          , skipped |> or skipped |> isSkipped
          , skipped |> or timeout |> isTimeout
          , skipped |> or (failure "") |> (isFailure "")
          , timeout |> or success |> isSuccess
          , timeout |> or skipped |> isTimeout
          , timeout |> or timeout |> isTimeout
          , timeout |> or (failure "") |> (isFailure "")
          , (failure "") |> or success |> isSuccess
          , (failure "") |> or skipped |> (isFailure "")
          , (failure "") |> or timeout |> isTimeout
          , (failure "a") |> or (failure "b") |> (isFailure "b")
          ]
      )
      , test "all (empty)" (
        all []
      )
      , test "all (success)" (
        all [ success, success, success ]
      )
      , testFailure "all (failure)" (
        all [ success, failure "", success ]
      )
      , test "any (empty)" (
        any []
      )
      , test "any (success)" (
        any [ skipped, success, timeout, failure "" ]
      )
      , testFailure "any (failure)" (
        any [ timeout, failure "", skipped ]
      )
      ]
    , describe "Test results"
      [ testFailure "My first failure" (
        Task.fail { a = 1, b = "aze" } |> andTest (\value -> value |> shouldEqual "54")
      )
      , xtest "A skipped test" (
        "a" |> shouldEqual "b"
      )
      , testTimeout "This test will timeout" (
        Process.sleep 100
        |> Task.map (\_ -> 1)
        |> andTest (\value -> value |> shouldEqual 1)
      )
      , test "This is a success" (
        success
      )
      , testFailure "This is a failure" (
        failure "You failed"
      )
      , testSkipped "This test will be skipped" (
        skipped
      )
      , testTimeout "This test will also timeout" (
        timeout
      )
      ]
    , describe "Operators"
      [ test "shouldEqual" (
        "1" |> shouldEqual "1"
      )
      , test "shouldNotEqual" (
        "1" |> shouldNotEqual "2"
      )
      , test "shouldMatch" (
        "abc" |> shouldMatch (Regex.regex "[a-z]+")
      )
      , test "shouldNotMatch" (
        "abc" |> shouldNotMatch (Regex.regex "[A-Z]+")
      )
      , test "shouldBeJust" (
        (Just 1) |> shouldBeJust
      )
      , test "shouldBeNothing" (
        Nothing |> shouldBeNothing
      )
      , test "shouldBeOk" (
        (Ok 1) |> shouldBeOk
      )
      , test "shouldBeErr" (
        (Err 1) |> shouldBeErr
      )
      , test "shouldContain" (
        [1, 2, 3] |> shouldContain 2
      )
      , test "shouldNotContain" (
        [1, 2, 3] |> shouldNotContain 4
      )
      , test "shouldBeOneOf" (
        2 |> shouldBeOneOf [1, 2, 3]
      )
      , test "shouldNotBeOneOf" (
        4 |> shouldNotBeOneOf [1, 2, 3]
      )
      , test "shouldBeLessThan" (
        1 |> shouldBeLessThan 2
      )
      , test "shouldBeGreaterThan" (
        2 |> shouldBeGreaterThan 1
      )
      , test "shouldPass" (
        2 |> shouldPass (\v -> v > 1 && v < 3)
      )
      , test "shouldNotPass" (
        2 |> shouldNotPass (\v -> v /= 2)
      )
      ]
    , describe "Task"
      [ test "should succeed" (
        Task.succeed 1
        |> shouldSucceed
      )
      , testFailure "should succeed but will not" (
        Task.fail True
        |> shouldSucceed
      )
      , test "should succeed with 1" (
        Task.succeed 1
        |> shouldSucceedWith 1
      )
      , testFailure "should succeed with True but will not" (
        Task.succeed False
        |> shouldSucceedWith True
      )
      , test "should fail" (
        Task.fail "boom"
        |> shouldFail
      )
      , testFailure "should fail but will not" (
        Task.succeed 4.2
        |> shouldFail
      )
      , test "should fail with { a = 1, b = True}" (
        Task.fail { a = 1, b = True}
        |> shouldFailWith { b = True, a = 1 }
      )
      , testFailure "should fail with 'a' but will not" (
        Task.fail "b"
        |> shouldFailWith "a"
      )
      ]
    ]
