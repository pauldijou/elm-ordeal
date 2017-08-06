module Ordeal.Internals exposing (..)

import Task

import Ordeal.Types exposing (..)


testFailure: String -> Expectation -> Test
testFailure name expectation =
  Test name (expectation |> Task.map (\result ->
    case result of
      Failure _ -> Success
      _ -> Failure <| "We wanted a failure but we got: " ++ (toString result)
  ) |> Task.onError (\error -> Task.succeed Success))

testTimeout: String -> Expectation -> Test
testTimeout name expectation =
  Test name (expectation |> Task.map (\result ->
    case result of
      Timeout -> Success
      _ -> Failure <| "We wanted a timeout but we got: " ++ (toString result)
  ))

testSkipped: String -> Expectation -> Test
testSkipped name expectation =
  Test name (expectation |> Task.map (\result ->
    case result of
      Skipped -> Success
      _ -> Failure <| "We wanted a skipped test but we got: " ++ (toString result)
  ))
