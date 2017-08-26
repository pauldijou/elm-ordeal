module Ordeal.Internals exposing (..)

import Task exposing (Task)

import Ordeal.Types exposing (..)

fromResult: Result err res -> Task err res
fromResult result =
  case result of
    Ok value -> Task.succeed value
    Err error -> Task.fail error

toResult: Task err res -> Task Never (Result err res)
toResult task =
  task
  |> Task.map Ok
  |> Task.onError (Task.succeed << Err)

mapBoth: (err -> nextErr) -> (res -> nextRes) -> Task err res -> Task nextErr nextRes
mapBoth onFailure onSuccess task =
  task
  |> Task.map onSuccess
  |> Task.mapError onFailure

andThenBoth: (err -> Task nextErr nextRes) -> (res -> Task nextErr nextRes) -> Task err res -> Task nextErr nextRes
andThenBoth onFailure onSuccess task =
  task
  |> Task.map Ok
  |> Task.onError (Task.succeed << Err)
  |> Task.andThen (\result -> case result of
    Ok success -> onSuccess success
    Err failure -> onFailure failure
  )

testFailure: String -> Expectation -> Test
testFailure name expectation =
  Test name (expectation |> Task.map (\result ->
    case result of
      Failure _ -> Success
      _ -> Failure <| "Expected a failure but we got: " ++ (toString result)
  ) |> Task.onError (\error -> Task.succeed Success))

testTimeout: String -> Expectation -> Test
testTimeout name expectation =
  Test name (expectation |> Task.map (\result ->
    case result of
      Timeout -> Success
      _ -> Failure <| "Expected a timeout but we got: " ++ (toString result)
  ))

testSkipped: String -> Expectation -> Test
testSkipped name expectation =
  Test name (expectation |> Task.map (\result ->
    case result of
      Skipped -> Success
      _ -> Failure <| "Expected a skipped test but we got: " ++ (toString result)
  ))

isSuccess: Expectation -> Expectation
isSuccess expectation =
  expectation
  |> Task.map (\result ->
    case result of
      Success -> Success
      _ -> Failure "Expected a success"
  )

isSkipped: Expectation -> Expectation
isSkipped expectation =
  expectation
  |> Task.map (\result ->
    case result of
      Skipped -> Success
      _ -> Failure "Expected a skipped test"
  )

isTimeout: Expectation -> Expectation
isTimeout expectation =
  expectation
  |> Task.map (\result ->
    case result of
      Timeout -> Success
      _ -> Failure "Expected a timeout"
  )

isFailure: String -> Expectation -> Expectation
isFailure error expectation =
  expectation
  |> Task.map (\result ->
    case result of
      Failure err ->
        if error == err
        then Success
        else Failure ("Expected the failure to be '" ++ error ++ "' but got '" ++ err ++ "'")
      _ ->
        Failure "Expected a failure"
  )
