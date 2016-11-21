module Ordeal exposing
  ( Test
  , run
  , describe
  , test
  , andTest
  , shouldEqual
  , shouldNotEqual
  -- , toMatch
  -- , toBeDefined
  -- , toContain
  -- , toBeLessThan
  -- , toBeGreaterThan
  )

{-| An `Ordeal` is a trial to see if your code is good enough to reach the production heaven or not.

# Type and Constructors
@docs Test

# Writing suites
@docs run, describe, test, andTest

# Writing expectations
@docs shouldEqual, shouldNotEqual
-}

import String
import Dict exposing (Dict)
import Task exposing (Task)
-- import Regex exposing (Regex)
import Html exposing (Html)
import Html.App

andThen: (a -> Task x b) -> Task x a -> Task x b
andThen = flip Task.andThen

onError: (x -> Task y a) -> Task x a -> Task y a
onError = flip Task.onError

{-| A `Test` is something
-}
type Test
  = Suite String (List Test)
  | Test String Expectation

type TestResult
  = Success
  | Failure String

type alias Expectation = Task String TestResult

type Operator = Equal | NotEqual

{-|-}
describe: String -> List Test -> Test
describe = Suite

{-|-}
test: String -> Expectation -> Test
test = Test

{-|-}
andTest: (a -> Expectation) -> Task e a -> Expectation
andTest spec task =
  task
  |> Task.mapError toString
  |> andThen spec


-- Matchers

operatorToString: Operator -> a -> b -> String
operatorToString op source target =
  case op of
    Equal -> "Expected " ++ (toString source) ++ " to equal " ++ (toString target)
    NotEqual -> "Expected " ++ (toString source) ++ " not to equal " ++ (toString target)

compare: Operator -> (a -> b -> Bool) -> b -> a -> Expectation
compare op spec target source =
  Task.succeed (
    if spec source target
    then Success
    else Failure (operatorToString op source target)
  )

{-|-}
shouldEqual: a -> a -> Expectation
shouldEqual = compare Equal (==)

{-|-}
shouldNotEqual: a -> a -> Expectation
shouldNotEqual = compare Equal (/=)

-- {-|-}
-- toMatch: Regex -> BuildingExpectation String -> Expectation
-- toMatch = Native.Ordeal.toMatch
--
-- {-|-}
-- toBeDefined: Maybe a -> BuildingExpectation (Maybe a) -> Expectation
-- toBeDefined = Native.Ordeal.toBeDefined
--
-- {-|-}
-- toContain: List a -> BuildingExpectation (List a) -> Expectation
-- toContain = Native.Ordeal.toContain
--
-- {-|-}
-- toBeLessThan: number -> BuildingExpectation number -> Expectation
-- toBeLessThan = Native.Ordeal.toBeLessThan
--
-- {-|-}
-- toBeGreaterThan: number -> BuildingExpectation number -> Expectation
-- toBeGreaterThan = Native.Ordeal.toBeGreaterThan


-- Runner

type alias TestId = Int

type alias Queue = List { id: TestId, expectation: Expectation }

type ReportStructure
  = ReportStructureSuite String (List ReportStructure)
  | ReportStructureTest String TestId

type Report
  = ReportSuite String (List Report)
  | ReportTest String TestResult

type alias Model = {
  results: Dict TestId TestResult,
  queue: Queue,
  report: ReportStructure
}

type Msg
  = Run Queue
  | Runned TestId TestResult
  | Done

{-|-}
run: Test -> Program Never
run test =
  Html.App.program
    { init = init test
    , update = update
    , subscriptions = subscriptions
    , view = view
    }

init: Test -> (Model, Cmd Msg)
init spec =
  let
    (id, report, queue) = parseTest 0 spec
  in
    update (Run queue) { results = Dict.empty, queue = queue, report = report }

update: Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Run queue -> case queue of
      [] -> update Done model
      next :: rest ->
        { model | queue = rest } ! [
          Task.perform
            (\err -> Runned next.id <| Failure err)
            (Runned next.id)
            next.expectation
        ]

    Runned id result ->
      update (Run model.queue) { model | results = Dict.insert id result model.results }

    Done ->
      let aze = Debug.log "Report" (reportToString "" <| generateReport model.results model.report) in (model, Cmd.none)

subscriptions: Model -> Sub Msg
subscriptions model =
  Sub.none

view: Model -> Html Msg
view model =
  Html.text ""

parseTest: TestId -> Test -> (TestId, ReportStructure, Queue)
parseTest lastId spec =
  case spec of
    Test name expectation ->
      let
        id = lastId + 1
      in
        (id, ReportStructureTest name id, [ { id = id, expectation = expectation } ])
    Suite name tests ->
      let
        (nextId, structure, queue) =
          List.foldl
            (\value (id, struc, que) ->
              let
                (i, s, q) = parseTest id value
              in
                (i, s :: struc, q ++ que)
            )
            (lastId, [], [])
            tests
      in
        (nextId, ReportStructureSuite name structure, queue)


generateReport: Dict TestId TestResult -> ReportStructure -> Report
generateReport results structure =
  case structure of
    ReportStructureTest name id -> case Dict.get id results of
      Nothing -> ReportTest name (Failure "We lost the test...")
      Just result -> ReportTest name result

    ReportStructureSuite name reports ->
      ReportSuite name (
        List.map
          (generateReport results)
          reports
      )

reportToString: String -> Report -> List String
reportToString padding report =
  case report of
    ReportTest name result -> case result of
      Success -> [ padding ++ " Ok: " ++ name ]
      Failure err -> [ padding ++ " Ko: " ++ name ++ " | " ++ err ]

    ReportSuite name results ->
      (padding ++ name) :: ( List.concatMap (reportToString (padding ++ "  ")) results )
