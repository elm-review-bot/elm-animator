module Basic exposing (main, subscriptions, update, view)

import Animator
import Browser
import Color
import Help.Plot
import Html
import Html.Attributes as Attr
import Html.Events as Events
import Internal.Timeline
import Time


main =
    Browser.document
        { init =
            \() ->
                update QueueThree
                    { timeline =
                        Animator.init (Time.millisToPosix 0) Hufflepuff
                    , time = Time.millisToPosix 0
                    , house = Hufflepuff
                    , chart = Help.Plot.init
                    }

        -- , Cmd.none
        -- )
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type alias Model =
    { timeline : Animator.Timeline House
    , time : Time.Posix
    , house : House
    , chart : Help.Plot.Model
    }


type Msg
    = Tick (Animator.Timeline House)
    | NextHouse
    | QueueThree
    | NewTime Time.Posix
    | ChartMsg Help.Plot.Msg


type House
    = Hufflepuff
    | Griffyndor
    | Slytherin
    | Ravenclaw


view : Model -> Browser.Document Msg
view model =
    { title = "Elm - Select Harry Potter House"
    , body =
        let
            toPos =
                toHousePositionWithOrbit
        in
        [ Html.div
            [ Attr.style "display" "flex"
            , Attr.style "padding" "50px"
            , Attr.style "width" "100%"
            , Attr.style "flex-direction" "column"
            , Attr.style "align-items" "center"
            ]
            [ Html.span [] [ Html.text "Scrub timeline" ]
            , Html.input
                [ Attr.type_ "range"
                , Attr.value (String.fromInt (Time.posixToMillis model.time))
                , Attr.min "0"
                , Attr.max "4000"
                , Attr.style "width" "1000px"
                , Events.onInput
                    (\newTime ->
                        case String.toInt newTime of
                            Nothing ->
                                NewTime (Time.millisToPosix 0)

                            Just t ->
                                NewTime (Time.millisToPosix t)
                    )
                ]
                []
            , Html.div
                [ Attr.style "display" "flex"
                ]
                [ Html.button [ Events.onClick QueueThree ] [ Html.text "Queue Three" ]
                , Html.button [ Events.onClick NextHouse ] [ Html.text "Next" ]
                ]
            ]
        , Html.div
            [ Attr.style "display" "flex"
            , Attr.style "width" "100%"
            , Attr.style "height" "400px"
            ]
            [ Html.div
                [ Attr.style "width" "200px"
                , Attr.style "height" "200px"
                , Attr.style "align-self" "center"
                , Attr.style "justify-self" "center"
                , Events.onClick NextHouse
                , Attr.style "transform"
                    (toPx
                        (.position (Animator.move model.timeline toPos))
                    )
                , Attr.style "background-color" "red"

                -- (Color.toCssString
                --     (Animator.color model.timeline <|
                --         \event ->
                --             case event of
                --                 Hufflepuff ->
                --                     yellow
                --                 Griffyndor ->
                --                     red
                --                 Slytherin ->
                --                     green
                --                 Ravenclaw ->
                --                     blue
                --     )
                -- )
                ]
                [ case Animator.move model.timeline toPos of
                    { position, velocity } ->
                        Html.div []
                            [ Html.div [] [ Html.text "pos: ", Html.text (String.fromFloat position) ]
                            , Html.div [] [ Html.text "vel: ", Html.text (String.fromFloat velocity) ]

                            -- , Html.div [] [ Html.text "between: ", Html.text (Debug.toString between) ]
                            ]
                ]
            ]
        , Html.map ChartMsg
            (Help.Plot.view
                model.chart
                (renderPoints Animator.move model.timeline toPos)
                (renderEvents (Internal.Timeline.getEvents model.timeline))
                { position = .position (Animator.move model.timeline toPos)
                , time = toFloat (Time.posixToMillis model.time)
                }
            )
        ]
    }


renderEvents events =
    List.map
        (\( time, ev ) ->
            { time = toFloat (Time.posixToMillis time)
            , position = 300
            }
        )
        events


renderPoints move timeline toPos =
    List.foldl
        (\i rendered ->
            let
                currentTime =
                    Time.millisToPosix (i * 50)
            in
            case move (Animator.update currentTime timeline) toPos of
                current ->
                    { time = toFloat i * 50
                    , position = current.position
                    }
                        :: rendered
        )
        []
        (List.range 0 100)


next house =
    case house of
        Hufflepuff ->
            Griffyndor

        Griffyndor ->
            Slytherin

        Slytherin ->
            Ravenclaw

        Ravenclaw ->
            Hufflepuff


update msg model =
    case msg of
        Tick newTimeline ->
            ( { model | timeline = newTimeline }
            , Cmd.none
            )

        ChartMsg chartMsg ->
            ( { model | chart = Help.Plot.update chartMsg model.chart }
            , Cmd.none
            )

        QueueThree ->
            let
                addToQueue _ ( q, house ) =
                    ( Animator.wait (Animator.seconds 1)
                        :: Animator.event (Animator.seconds 1) (next house)
                        :: q
                    , next house
                    )

                ( forQueue, newHouse ) =
                    List.foldl addToQueue ( [], model.house ) (List.range 1 3)
            in
            ( { model
                | timeline =
                    Animator.queue (Animator.wait (Animator.seconds 0.5) :: List.reverse forQueue) model.timeline
              }
            , Cmd.none
            )

        NextHouse ->
            let
                newHouse =
                    next model.house
            in
            ( { model
                | timeline =
                    Animator.queue [ Animator.event (Animator.seconds 1) newHouse ] model.timeline
                , house = newHouse
              }
            , Cmd.none
            )

        NewTime newPosix ->
            ( { model
                | time = newPosix
                , timeline =
                    Animator.update newPosix model.timeline
              }
            , Cmd.none
            )


subscriptions model =
    Sub.batch
        [--Animator.subscription Tick model.timeline
        ]


red =
    Color.rgb 1 0 0


green =
    Color.rgb 0 1 0


blue =
    Color.rgb 0 0 1


yellow =
    Color.rgb 1 1 0


toPx x =
    "translate(" ++ String.fromFloat x ++ "px, 0)"


toHousePosition event =
    case event of
        Hufflepuff ->
            Animator.to 100

        Griffyndor ->
            Animator.to 400

        Slytherin ->
            Animator.to 700

        Ravenclaw ->
            Animator.to 1000


toHousePositionWithOrbit event =
    case event of
        Hufflepuff ->
            Animator.to 100

        Griffyndor ->
            Animator.orbit
                { point = 400
                , duration = Animator.millis 200
                , toPosition =
                    \u ->
                        100 * sin (u * (2 * pi))
                }

        Slytherin ->
            Animator.to 700

        Ravenclaw ->
            Animator.to 1000
