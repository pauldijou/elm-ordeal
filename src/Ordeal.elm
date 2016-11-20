module Ordeal exposing
  ( Test
  , describe
  , test
  , testTask
  , andTest
  , expect
  , isExpected
  , not
  , toBe
  , toEqual
  , toMatch
  , toBeDefined
  , toContain
  , toBeLessThan
  , toBeGreaterThan
  )

{-| An `Ordeal` is a trial to see if your code is good enough to reach the production heaven or not.

# Type and Constructors
@docs Test

# Writing suites
@docs describe, test, testTask, andTest

# Writing expectations
@docs expect, isExpected, not, toBe, toEqual, toEqual, toMatch, toBeDefined, toContain, toBeLessThan, toBeGreaterThan
-}

import Task exposing (Task)
import Regex exposing (Regex)
import Native.Ordeal

andThen: (a -> Task x b) -> Task x a -> Task x b
andThen = flip Task.andThen

onError: (x -> Task y a) -> Task x a -> Task y a
onError = flip Task.onError

{-| A `Test` is something
-}
type Test = Test

type BuildingExpectation a = BuildingExpectation a
type Expectation = Expectation

{-|-}
describe: String -> (() -> List Test) -> Test
describe = Native.Ordeal.describe

{-|-}
test: String -> (() -> Expectation) -> Test
test = Native.Ordeal.test


-- Async

nativeTestTask: String -> Task String () -> Test
nativeTestTask = Native.Ordeal.testTask

{-|-}
testTask: String -> Task e a -> Test
testTask name task =
  nativeTestTask name (task |> Task.map (always ()) |> Task.mapError toString)

{-|-}
andTest: (a -> Expectation) -> Task e a -> Task e a
andTest spec task =
  task
  |> andThen (\value ->
    let whatever = spec value in task
  )


-- Matchers

{-|-}
expect: a -> BuildingExpectation a
expect = Native.Ordeal.expect

{-|-}
isExpected: a -> BuildingExpectation a
isExpected = expect

{-|-}
not: BuildingExpectation a -> BuildingExpectation a
not = Native.Ordeal.not

{-|-}
toBe: a -> BuildingExpectation a -> Expectation
toBe = Native.Ordeal.toBe

{-|-}
toEqual: a -> BuildingExpectation a -> Expectation
toEqual = Native.Ordeal.toEqual

{-|-}
toMatch: Regex -> BuildingExpectation String -> Expectation
toMatch = Native.Ordeal.toMatch

{-|-}
toBeDefined: Maybe a -> BuildingExpectation (Maybe a) -> Expectation
toBeDefined = Native.Ordeal.toBeDefined

{-|-}
toContain: List a -> BuildingExpectation (List a) -> Expectation
toContain = Native.Ordeal.toContain

{-|-}
toBeLessThan: number -> BuildingExpectation number -> Expectation
toBeLessThan = Native.Ordeal.toBeLessThan

{-|-}
toBeGreaterThan: number -> BuildingExpectation number -> Expectation
toBeGreaterThan = Native.Ordeal.toBeGreaterThan
