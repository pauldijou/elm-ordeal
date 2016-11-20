port module Runner exposing (..)

import Task exposing (Task)
import Html exposing (Html)
import Html.App
import Json.Encode

import Native.Runner

type alias Model = {}

type alias RunningTask =
  { task: Json.Encode.Value
  , done: Json.Encode.Value
  , failure: Maybe String
  }

type Msg
  = Run RunningTask
  | Runned RunningTask

main: Program Never
main =
  Html.App.program
    { init = init
    , update = update
    , subscriptions = subscriptions
    , view = view
    }

init: (Model, Cmd Msg)
init =
  ({}, Cmd.none)

update: Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Run task -> (model, Task.perform (\err -> Runned { task | failure = Just err }) (always <| Runned task) <| parseTask task)
    Runned task -> (model, runnedTask task)

subscriptions: Model -> Sub Msg
subscriptions model =
  runTask Run

view: Model -> Html Msg
view model =
  Html.text ""

parseTask: RunningTask -> Task String ()
parseTask running = Native.Runner.parseTask running.task

port runTask: (RunningTask -> msg) -> Sub msg

port runnedTask: RunningTask -> Cmd msg
