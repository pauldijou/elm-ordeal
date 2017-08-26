module Ordeal exposing
  ( Test
  , TestResult
  , Expectation
  , Event
  , Ordeal
  , run
  , describe
  , xdescribe
  , test
  , xtest
  , andTest
  , and
  , or
  , all
  , any
  , success
  , failure
  , skipped
  , timeout
  , lazy
  , shouldEqual
  , shouldNotEqual
  , shouldMatch
  , shouldNotMatch
  , shouldBeNothing
  , shouldBeJust
  , shouldBeOk
  , shouldBeErr
  , shouldContain
  , shouldNotContain
  , shouldBeOneOf
  , shouldNotBeOneOf
  , shouldBeLessThan
  , shouldBeGreaterThan
  , shouldPass
  , shouldNotPass
  , shouldSucceed
  , shouldSucceedWith
  , shouldFail
  , shouldFailWith
  )

{-| An `Ordeal` is a trial to see if your code is good enough to reach the production heaven or not.

# Type and Constructors
@docs Test, TestResult, Expectation, Event, Ordeal

# Writing tests
@docs run, describe, xdescribe, test, xtest, andTest, and, or, all, any, success, failure, skipped, timeout, lazy

# Writing expectations
@docs shouldEqual, shouldNotEqual, shouldMatch, shouldNotMatch, shouldBeNothing, shouldBeJust, shouldBeOk, shouldBeErr, shouldContain, shouldNotContain, shouldBeOneOf, shouldNotBeOneOf, shouldBeLessThan, shouldBeGreaterThan, shouldPass, shouldNotPass, shouldSucceed, shouldSucceedWith, shouldFail, shouldFailWith
-}

import Time exposing (Time)
import Process
import Task exposing (Task)
import Regex exposing (Regex)
import Json.Encode
-- FIXME remove when issue is fixed https://github.com/elm-lang/elm-make/issues/134
import Json.Decode

import Ordeal.Types exposing (..)
import Ordeal.Internals exposing (andThenBoth)

{-| A `Test` is just a name and an expectation -}
type alias Test = Ordeal.Types.Test

{-| A `TestResult` can be a Success, a Skipped test, a Timeout or a Failure -}
type alias TestResult = Ordeal.Types.TestResult

{-| An `Expectation` is just an alias for `Task Never TestResult` which means, at some point in the future, it will give us a result for the test (for sure) -}
type alias Expectation = Ordeal.Types.Expectation


type Operator = Equal | Match | Contain | OneOf | Less | Greater | Pass

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
  |> andThenBoth
    (Task.succeed << Failure << toString)
    (spec)

{-|-}
and: Expectation -> Expectation -> Expectation
and second first =
  first
  |> Task.andThen (\result -> case result of
    Success ->
      second
      |> Task.map (\result2 ->
        if result2 == Skipped
        then Success
        else result2
      )
    Skipped -> second
    Timeout -> timeout
    Failure reason -> failure reason
  )

{-|-}
or: Expectation -> Expectation -> Expectation
or second first =
  first
  |> Task.andThen (\result -> case result of
    Success -> success
    Skipped -> second
    _ ->
      second
      |> Task.map (\result2 ->
        if result2 == Skipped
        then result
        else result2
      )
  )

{-| First to fail is the final failure, ignoring all others -}
all: List Expectation -> Expectation
all =
  List.foldl and success

{-| We just want at least one Success, otherwise return last timeout or failure -}
any: List Expectation -> Expectation
any expectations =
  if List.isEmpty expectations
  then success
  else List.foldl or (failure "We need at least one success") expectations

{-|-}
success: Expectation
success =
  Task.succeed Success

{-|-}
failure: String -> Expectation
failure reason =
  Task.succeed (Failure reason)

{-|-}
skipped: Expectation
skipped =
  Task.succeed Skipped

{-|-}
timeout: Expectation
timeout =
  Task.succeed Timeout

{-|-}
lazy: (() -> Expectation) -> Expectation
lazy fn =
  Task.succeed ()
  |> Task.andThen fn


-- Matchers

operatorToString: Operator -> Bool -> a -> b -> String
operatorToString op no actual expected =
  case op of
    Equal -> "Expected " ++ (toString actual) ++ (if no then " not" else "") ++ " to equal " ++ (toString expected)
    Match -> "Expected " ++ (toString actual) ++ (if no then " not" else "") ++ " to match " ++ (toString expected)
    Contain -> "Expected " ++ (toString actual) ++ (if no then " not" else "") ++ " to contain " ++ (toString expected)
    OneOf -> "Expected " ++ (toString actual) ++ (if no then " not" else "") ++ " to be one of " ++ (toString expected)
    Less -> "Expected " ++ (toString actual) ++ (if no then " not" else "") ++ " to be less than " ++ (toString expected)
    Greater -> "Expected " ++ (toString actual) ++ (if no then " not" else "") ++ " to be greater than " ++ (toString expected)
    Pass -> "Expected " ++ (toString actual) ++ (if no then " not" else "") ++ " to pass the predicate"

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
shouldBeNothing: Maybe a -> Expectation
shouldBeNothing = shouldEqual Nothing

{-|-}
shouldBeJust: Maybe a -> Expectation
shouldBeJust = shouldNotEqual Nothing

{-|-}
shouldBeOk: Result e a -> Expectation
shouldBeOk result =
  case result of
    Ok _ -> success
    Err error -> failure <| "Expected an Ok but got: " ++ (toString error)

{-|-}
shouldBeErr: Result e a -> Expectation
shouldBeErr result =
  case result of
    Err _ -> success
    Ok value -> failure <| "Expected an Err but got:" ++ (toString value)

{-|-}
shouldContain: a -> List a -> Expectation
shouldContain = compare Contain (flip List.member)

{-|-}
shouldNotContain: a -> List a -> Expectation
shouldNotContain = compareNot Contain (flip List.member)

{-|-}
shouldBeOneOf: List a -> a -> Expectation
shouldBeOneOf = compare OneOf (List.member)

{-|-}
shouldNotBeOneOf: List a -> a -> Expectation
shouldNotBeOneOf = compareNot OneOf (List.member)

{-|-}
shouldBeLessThan: comparable -> comparable -> Expectation
shouldBeLessThan = compare Less (<)

{-|-}
shouldBeGreaterThan: comparable -> comparable -> Expectation
shouldBeGreaterThan = compare Greater (>)

{-|-}
shouldPass: (a -> Bool) -> a -> Expectation
shouldPass = compare Pass (\value predicate -> predicate value)

{-|-}
shouldNotPass: (a -> Bool) -> a -> Expectation
shouldNotPass = compareNot Pass (\value predicate -> predicate value)

{-|-}
shouldSucceed: Task err res -> Expectation
shouldSucceed task =
  task
  |> Task.map (\success -> Success)
  |> Task.onError(\err ->
    "Task was supposed to succeed but failed with: " ++ (toString err)
    |> Failure
    |> Task.succeed
  )

{-|-}
shouldSucceedWith: res -> Task err res -> Expectation
shouldSucceedWith result task =
  task
  |> andThenBoth
    (Task.succeed << Failure << toString)
    (shouldEqual result)

{-|-}
shouldFail: Task err res -> Expectation
shouldFail task =
  task
  |> Task.map (\success ->
    "Task was supposed to failed but succeed with: " ++ (toString success)
    |> Failure
  )
  |> Task.onError(\_ -> Task.succeed Success)

{-|-}
shouldFailWith: err -> Task err res -> Expectation
shouldFailWith error task =
  task
  |> Task.map (\success ->
    "Task was supposed to failed but succeed with: " ++ (toString success)
    |> Failure
  )
  |> Task.onError(shouldEqual error)

-- Runner

{-|-}
type alias Ordeal = Program Settings Model Msg

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
run: EventEmitter Msg -> Test -> Ordeal
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
  Task.perform (\_ -> msg) (Task.succeed ())

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
                Task.perform (RunnedTest nextTest) (wrap nextTest.expectation),
                Task.perform (RunnedTest nextTest) (wrap <| timeoutIn model.timeout)
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

timeoutIn: Time -> Expectation
timeoutIn duration =
  Process.spawn (Task.succeed ())
  |> Task.andThen (\_ -> Process.sleep duration)
  |> Task.map (\_ -> Timeout)

wrap: Expectation -> Task Never (TestResult, Time, Time)
wrap expectation =
  Time.now
  |> Task.andThen (\start ->
    expectation
    |> Task.map (\res -> (res, start))
  )
  |> Task.andThen (\(result, start) ->
    Time.now
    |> Task.map (\end -> (result, start, end))
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
