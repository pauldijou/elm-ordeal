module Ordeal.Types exposing (..)

import Task exposing (Task)

type Test
  = Suite String (List Test) -- NEXT: Suite { name: String, only: Bool, tests: List Test }
  | Test String Expectation -- NEXT: Test { name: String, only: Bool, hint: Maybe String, expectation: Expectation }

type TestResult
  = Success
  | Skipped
  | Timeout
  | Failure String

type alias Expectation = Task String TestResult
