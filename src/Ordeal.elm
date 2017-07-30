module Ordeal exposing
  ( Test
  , Event
  , OrdealProgram
  , run
  , describe
  , xdescribe
  , test
  , xtest
  , andTest
  , success
  , failure
  , shouldEqual
  , shouldNotEqual
  , shouldMatch
  , shouldNotMatch
  , shouldBeDefined
  , shouldNotBeDefined
  , shouldContain
  , shouldNotContain
  , shouldBeLessThan
  , shouldBeGreaterThan
  , shouldSucceed
  , shouldSucceedWith
  , shouldFail
  , shouldFailWith
  )

{-| An `Ordeal` is a trial to see if your code is good enough to reach the production heaven or not.

# Type and Constructors
@docs Test, Event, OrdealProgram

# Writing tests
@docs run, describe, xdescribe, test, xtest, andTest, success, failure

# Writing expectations
@docs shouldEqual, shouldNotEqual, shouldMatch, shouldNotMatch, shouldBeDefined, shouldNotBeDefined, shouldContain, shouldNotContain, shouldBeLessThan, shouldBeGreaterThan, shouldSucceed, shouldSucceedWith, shouldFail, shouldFailWith
-}

import Time exposing (Time)
import Process
import Task exposing (Task)
import Regex exposing (Regex)
import Json.Encode
-- FIXME remove when issue is fixed https://github.com/elm-lang/elm-make/issues/134
import Json.Decode

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

type Operator = Equal | Match | Contain | Less | Greater

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
  |> Task.andThen spec

{-|-}
success: Expectation
success =
  Task.succeed Success

{-|-}
failure: String -> Expectation
failure reason =
  Task.succeed (Failure reason)

-- Matchers

operatorToString: Operator -> Bool -> a -> b -> String
operatorToString op no actual expected =
  case op of
    Equal -> "Expected " ++ (toString actual) ++ (if no then " not" else "") ++ " to equal " ++ (toString expected)
    Match -> "Expected " ++ (toString actual) ++ (if no then " not" else "") ++ " to match " ++ (toString expected)
    Contain -> "Expected " ++ (toString actual) ++ (if no then " not" else "") ++ " to contain " ++ (toString expected)
    Less -> "Expected " ++ (toString actual) ++ (if no then " not" else "") ++ " to be less than " ++ (toString expected)
    Greater -> "Expected " ++ (toString actual) ++ (if no then " not" else "") ++ " to be greater than " ++ (toString expected)

internalCompare: (Bool -> Bool) -> Operator -> (a -> b -> Bool) -> b -> a -> Expectation
internalCompare inverse op predicate expected actual =
  Task.succeed (
    if inverse <| predicate actual expected
    then Success
    else Failure (operatorToString op (inverse False) actual expected)
  )

compare: Operator -> (a -> b -> Bool) -> b -> a -> Expectation
compare = internalCompare identity

compareNot: Operator -> (a -> b -> Bool) -> b -> a -> Expectation
compareNot = internalCompare not

{-|-}
shouldEqual: a -> a -> Expectation
shouldEqual = compare Equal (==)

{-|-}
shouldNotEqual: a -> a -> Expectation
shouldNotEqual = compareNot Equal (==)

{-|-}
shouldMatch: Regex -> String -> Expectation
shouldMatch = compare Match (flip Regex.contains)

{-|-}
shouldNotMatch: Regex -> String -> Expectation
shouldNotMatch = compareNot Match (flip Regex.contains)

{-|-}
shouldBeDefined: Maybe a -> Expectation
shouldBeDefined = shouldNotEqual Nothing

{-|-}
shouldNotBeDefined: Maybe a -> Expectation
shouldNotBeDefined = shouldEqual Nothing

{-|-}
shouldContain: a -> List a -> Expectation
shouldContain = compare Contain (flip List.member)

{-|-}
shouldNotContain: a -> List a -> Expectation
shouldNotContain = compareNot Contain (flip List.member)

{-|-}
shouldBeLessThan: comparable -> comparable -> Expectation
shouldBeLessThan = compare Less (<)

{-|-}
shouldBeGreaterThan: comparable -> comparable -> Expectation
shouldBeGreaterThan = compare Greater (>)

{-|-}
shouldSucceed: Task a b -> Expectation
shouldSucceed task =
  task
  |> Task.map (\success -> Success)
  |> Task.onError(\err -> Task.succeed <| Failure <| "Task was supposed to succeed but failed with: " ++ (toString err))

{-|-}
shouldSucceedWith: b -> Task a b -> Expectation
shouldSucceedWith result task =
  task
  |> Task.mapError toString
  |> Task.andThen (shouldEqual result)
  |> Task.onError(\err -> Task.succeed <| Failure <| "Task was supposed to succeed but failed with: " ++ err)

{-|-}
shouldFail: Task a b -> Expectation
shouldFail task =
  task
  |> Task.map (\success -> Failure <| "Task was supposed to failed but succeed with: " ++ (toString success))
  |> Task.onError(\_ -> Task.succeed Success)

{-|-}
shouldFailWith: a -> Task a b -> Expectation
shouldFailWith error task =
  task
  |> Task.map (\success -> Failure <| "Task was supposed to failed but succeed with: " ++ (toString success))
  |> Task.onError(shouldEqual error)

-- Runner

{-|-}
type alias OrdealProgram = Program Settings Model Msg

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
  { successes: List Tested
  , failures: List Tested
  , skipped: List Tested
  , timeouts: List Tested
  }

{-|-}
run: EventEmitter Msg -> Test -> OrdealProgram
run emitter test =
  Platform.programWithFlags
    { init = init emitter test
    , update = update emitter
    , subscriptions = subscriptions
    }

init: EventEmitter Msg -> Test -> Settings -> (Model, Cmd Msg)
init emitter spec settings =
  let
    (id, report, queue) = initReport 0 spec
    model =
      { timeout = settings.timeout
      , queue = queue
      , report = report
      }
  in
    model ! [ started emitter <| makeStartReport model.report, message <| Run queue ]

message: Msg -> Cmd Msg
message msg =
  Task.perform (always msg) (Task.succeed ())

update: EventEmitter Msg -> Msg -> Model -> (Model, Cmd Msg)
update emitter msg model =
  case msg of
    Run queue -> case queue of
      [] -> (model, message Done)
      next :: rest ->
        let
          updatedModel = { model | queue = rest }
        in
          case next of
            SuiteStart name ->
              updatedModel ! [ suiteStarted emitter name, message <| Run updatedModel.queue ]
            SuiteDone name ->
              updatedModel ! [ suiteDone emitter name, message <| Run updatedModel.queue ]
            TestRun nextTest ->
              updatedModel ! [
                testStarted emitter nextTest.name,
                Task.attempt
                  (\taskResult -> case taskResult of
                    Ok res -> RunnedTest nextTest res
                    Err (err, start, end) -> RunnedTest nextTest (Failure err, start, end)
                  )
                  (wrap nextTest.expectation),
                Task.attempt
                  (\taskResult -> case taskResult of
                    Ok res -> RunnedTest nextTest res
                    Err (err, start, end) -> RunnedTest nextTest (Failure err, start, end)
                  )
                  (wrap <| timeout model.timeout)
              ]

    RunnedTest value (result, start, end) ->
      if testAlreadyDone value.id model.report
      then (model, Cmd.none)
      else (
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
            Timeout -> { testedTemplate | timeout = True }
            Skipped -> { testedTemplate | skipped = True }
            Failure err -> { testedTemplate | failure = err }
        in
          { model | report = updateReport value.id tested model.report } ! [ testDone emitter tested, message <| Run model.queue]
      )

    Done ->
      (model, done emitter <| makeEndReport model.report)

subscriptions: Model -> Sub Msg
subscriptions model =
  Sub.none

timeout: Time -> Expectation
timeout duration =
  Process.spawn (Task.succeed ())
  |> Task.andThen (\_ -> Process.sleep duration)
  |> Task.map (always Timeout)
  |> Task.mapError (always "")

wrap: Expectation -> Task (String, Time, Time) (TestResult, Time, Time)
wrap expectation =
  Time.now
  |> Task.andThen (\start ->
    expectation
    |> Task.map (\res -> (res, start))
    |> Task.mapError (\err -> (err, start))
  )
  |> Task.andThen (\(result, start) ->
    Time.now
    |> Task.map (\end -> (result, start, end))
  )
  |> Task.onError (\(result, start) ->
    Time.now
    |> Task.andThen (\end -> Task.fail (result, start, end))
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

testAlreadyDone: TestId -> Report -> Bool
testAlreadyDone id report =
  case report of
    ReportSuite name tests -> List.foldl (\test acc -> acc || testAlreadyDone id test) False tests
    ReportTest params -> params.id == id && params.result /= Nothing

updateReport: TestId -> Tested -> Report -> Report
updateReport id tested report =
  case report of
    ReportSuite name tests -> ReportSuite name (List.map (updateReport id tested) tests)
    ReportTest params ->
      if params.id == id && params.result == Nothing
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

emptySubset: { successes: List Tested, failures: List Tested, skipped: List Tested, timeouts: List Tested }
emptySubset =
  { successes = [], failures = [], skipped = [], timeouts = [] }

extratSubsets: Report -> { successes: List Tested, failures: List Tested, skipped: List Tested, timeouts: List Tested }
extratSubsets report =
  case report of
    ReportTest { id, result } -> case result of
      Nothing -> emptySubset
      Just r ->
        if r.skipped
        then { emptySubset | skipped = [ r ] }
        else if r.timeout
        then { emptySubset | timeouts = [ r ] }
        else if r.success
        then { emptySubset | successes = [ r ] }
        else { emptySubset | failures = [ r ] }

    ReportSuite name reports ->
      List.foldl
        (\r acc ->
          let { successes, failures, skipped, timeouts } = extratSubsets r
          in
            { successes = acc.successes ++ successes
            , failures  = acc.failures  ++ failures
            , skipped   = acc.skipped   ++ skipped
            , timeouts  = acc.timeouts  ++ timeouts
          }
        )
        emptySubset
        reports



-- Events

type alias EventEmitter msg = Event -> Cmd msg

{-|-}
type alias Event =
  { target: String
  , atStart: Bool
  , value: Json.Encode.Value
  }

started: EventEmitter Msg -> StartReport -> Cmd Msg
started emit value =
  emit { target = "", atStart = True, value = encodeStartReport value  }

suiteStarted: EventEmitter Msg -> String -> Cmd Msg
suiteStarted emit value =
  emit { target = "suite", atStart = True, value = Json.Encode.string value}

testStarted: EventEmitter Msg -> String -> Cmd Msg
testStarted emit value =
  emit { target = "test", atStart = True, value = Json.Encode.string value }

testDone: EventEmitter Msg -> Tested -> Cmd Msg
testDone emit value =
  emit { target = "test", atStart = False, value = encodeTested value }

suiteDone: EventEmitter Msg -> String -> Cmd Msg
suiteDone emit value =
  emit { target = "suite", atStart = False, value = Json.Encode.string value }

done: EventEmitter Msg -> EndReport -> Cmd Msg
done emit value =
  emit { target = "", atStart = False, value = encodeEndReport value }


encodeTested: Tested -> Json.Encode.Value
encodeTested tested =
  Json.Encode.object
    [ ("name", Json.Encode.string tested.name)
    , ("suites", Json.Encode.list <| List.map Json.Encode.string tested.suites)
    , ("success", Json.Encode.bool tested.success)
    , ("timeout", Json.Encode.bool tested.timeout)
    , ("skipped", Json.Encode.bool tested.skipped)
    , ("failure", Json.Encode.string tested.failure)
    , ("start", Json.Encode.float tested.start)
    , ("end", Json.Encode.float tested.end)
    , ("duration", Json.Encode.float tested.duration)
    ]

encodeStartReport: StartReport -> Json.Encode.Value
encodeStartReport report =
  Json.Encode.object
    [ ("suites", Json.Encode.int report.suites)
    , ("tests", Json.Encode.int report.tests)
    ]

encodeEndReport: EndReport -> Json.Encode.Value
encodeEndReport report =
  Json.Encode.object
    [ ("successes", Json.Encode.list <| List.map encodeTested report.successes)
    , ("failures", Json.Encode.list <| List.map encodeTested report.failures)
    , ("skipped", Json.Encode.list <| List.map encodeTested report.skipped)
    , ("timeouts", Json.Encode.list <| List.map encodeTested report.timeouts)
    ]
