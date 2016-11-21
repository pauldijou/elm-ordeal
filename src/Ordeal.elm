port module Ordeal exposing
  ( Test
  , run
  , describe
  , xdescribe
  , test
  , xtest
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
@docs run, describe, xdescribe, test, xtest, andTest

# Writing expectations
@docs shouldEqual, shouldNotEqual
-}

import String
import Time exposing (Time)
import Task exposing (Task)
-- import Regex exposing (Regex)
import Html exposing (Html)
import Html.App

andThen: (a -> Task x b) -> Task x a -> Task x b
andThen = flip Task.andThen

{-| A `Test` is something
-}
type Test
  = Suite String (List Test)
  | Test String Expectation

type TestResult
  = Success
  | Skipped
  | Timeout
  | Failure String

type alias Expectation = Task String TestResult

type Operator = Equal | NotEqual

{-|-}
describe: String -> List Test -> Test
describe = Suite

{-|-}
xdescribe: String -> List Test -> Test
xdescribe name = skip << Suite name

{-|-}
test: String -> Expectation -> Test
test = Test

{-|-}
xtest: String -> Expectation -> Test
xtest name = skip << Test name

skip: Test -> Test
skip test =
  case test of
    Suite name tests -> Suite name (List.map skip tests)
    Test name expectation -> Test name (Task.succeed Skipped)

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

type QueueValue
  = SuiteStart String
  | SuiteDone String
  | TestRun QueueTest

type alias QueueTest =
   { id: TestId
   , name: String
   , expectation: Expectation
    }

type alias Queue = List QueueValue

type Report
  = ReportSuite String (List Report)
  | ReportTest { id: TestId, result: Maybe Tested }

type alias Model =
  { timeout: Float
  , queue: Queue
  , report: Report
  }

type alias Tested =
  { name: String
  , suites: List String
  , success: Bool
  , timeout: Bool
  , skipped: Bool
  , failure: String
  , start: Time
  , end: Time
  , duration: Float
  }

type Msg
  = Run Queue
  | RunnedTest QueueTest (TestResult, Time, Time)
  | Done

type alias Settings =
  { timeout: Float }

type alias StartReport =
  { suites: Int
  , tests: Int
  }

type alias EndReport =
  { failures: List Tested
  , skipped: List Tested
  , timeouts: List Tested
  }

{-|-}
run: Test -> Program Settings
run test =
  Html.App.programWithFlags
    { init = init test
    , update = update
    , subscriptions = subscriptions
    , view = view
    }

init: Test -> Settings -> (Model, Cmd Msg)
init spec settings =
  let
    (id, report, queue) = initReport 0 spec
    (md, fx) = update (Run queue) { timeout = settings.timeout, queue = queue, report = report }
  in
    md ! [ started <| makeStartReport md.report, fx ]

message: Msg -> Cmd Msg
message msg =
  Task.perform (always msg) (always msg) (Task.succeed ())

update: Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Run queue -> case queue of
      [] -> update Done model
      next :: rest ->
        let
          updatedModel = { model | queue = rest }
        in
          case next of
            SuiteStart name ->
              updatedModel ! [ suiteStarted name, message <| Run updatedModel.queue ]
            SuiteDone name ->
              updatedModel ! [ suiteDone name, message <| Run updatedModel.queue ]
            TestRun nextTest ->
              updatedModel ! [
                testStarted nextTest.name,
                Task.perform
                  (\(err, start, end) -> RunnedTest nextTest (Failure err, start, end))
                  (RunnedTest nextTest)
                  (wrap nextTest.expectation)
              ]

    RunnedTest value (result, start, end) ->
      let
        testedTemplate =
          { name = value.name
          , suites = []
          , success = False
          , timeout = False
          , skipped = False
          , failure = ""
          , start = start
          , end = end
          , duration = end - start
          }

        tested = case result of
          Success -> { testedTemplate | success = True }
          Failure err -> { testedTemplate | success = False, failure = err }
          Timeout -> { testedTemplate | timeout = True }
          Skipped -> { testedTemplate | skipped = True }
      in
        { model | report = updateReport value.id tested model.report } ! [ testDone tested, message <| Run model.queue]

    Done ->
      (model, done <| makeEndReport model.report)

subscriptions: Model -> Sub Msg
subscriptions model =
  Sub.none

view: Model -> Html Msg
view model =
  Html.text ""

onError = flip Task.onError

wrap: Expectation -> Task (String, Time, Time) (TestResult, Time, Time)
wrap expectation =
  Time.now
  |> andThen (\start ->
    expectation
    |> Task.map (\res -> (res, start))
    |> Task.mapError (\err -> (err, start))
  )
  |> andThen (\(result, start) ->
    Time.now
    |> Task.map (\end -> (result, start, end))
  )
  |> onError (\(result, start) ->
    Time.now
    |> andThen (\end -> Task.fail (result, start, end))
  )

initReport: TestId -> Test -> (TestId, Report, Queue)
initReport lastId spec =
  case spec of
    Test name expectation ->
      let
        id = lastId + 1
      in
        (id, ReportTest { id = id, result = Nothing }, [ TestRun { id = id, name = name, expectation = expectation } ])
    Suite name tests ->
      let
        (nextId, structure, queue) =
          List.foldl
            (\value (id, struc, que) ->
              let
                (i, s, q) = initReport id value
              in
                (i, s :: struc, que ++ q)
            )
            (lastId, [], [ SuiteStart name ])
            tests
      in
        (nextId, ReportSuite name (List.reverse structure), queue ++ [ SuiteDone name ])

updateReport: TestId -> Tested -> Report -> Report
updateReport id tested report =
  case report of
    ReportSuite name tests -> ReportSuite name (List.map (updateReport id tested) tests)
    ReportTest params ->
      if params.id == id
      then ReportTest { params | result = Just tested }
      else ReportTest params


makeStartReport: Report -> StartReport
makeStartReport report =
  case report of
    ReportTest _ -> { suites = 0, tests = 1 }
    ReportSuite name tests ->
      List.foldl
        (\value acc ->
          let { suites, tests } = makeStartReport value
          in { suites = acc.suites + suites, tests = acc.tests + tests }
        )
        { suites = 1, tests = 0 }
        tests

makeEndReport: Report -> EndReport
makeEndReport report =
  extratSubsets report

emptySubset: { failures: List Tested, skipped: List Tested, timeouts: List Tested }
emptySubset =
  { failures = [], skipped = [], timeouts = [] }

extratSubsets: Report -> { failures: List Tested, skipped: List Tested, timeouts: List Tested }
extratSubsets report =
  case report of
    ReportTest { id, result } -> case result of
      Nothing -> emptySubset
      Just r ->
        if r.skipped
        then { emptySubset | skipped = [ r ] }
        else if r.timeout
        then { emptySubset | timeouts = [ r ] }
        else if (not r.success)
        then { emptySubset | failures = [ r ] }
        else emptySubset

    ReportSuite name reports ->
      List.foldl
        (\r acc ->
          let { failures, skipped, timeouts } = extratSubsets r
          in { failures = acc.failures ++ failures, skipped = acc.skipped ++ skipped, timeouts = acc.timeouts ++ timeouts }
        )
        emptySubset
        reports

port started: StartReport -> Cmd msg

port suiteStarted: String -> Cmd msg

port testStarted: String -> Cmd msg

port testDone: Tested -> Cmd msg

port suiteDone: String -> Cmd msg

port done: EndReport -> Cmd msg
