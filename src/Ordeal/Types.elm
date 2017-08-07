module Ordeal.Types exposing (..)

import Task exposing (Task)

type Test
  = Suite String (List Test)
  | Test String Expectation

type TestResult
  = Success
  | Skipped
  | Timeout
  | Failure String

type alias Expectation = Task Never TestResult
