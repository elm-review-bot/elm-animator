module Internal.Bezier exposing
    ( Point
    , Spline(..)
    , addX
    , afterLastX
    , atX
    , cssTimingString
    , doesNotMove
    , firstDerivative
    , firstX
    , firstY
    , hash
    , lastX
    , lastY
    , normalize
    , pointOn
    , secondDerivative
    , splitAt
    , splitAtX
    , splitList
    , takeBefore
    , withinX
    )

{-| This module defines types and functions for cubic bezier splines.

This is a mini embedded elm-geometry because I didn't want to impose it as a dependency.

However! It's definitely a package worth checking out!

<https://package.elm-lang.org/packages/ianmackenzie/elm-geometry/3.1.0/>

Thanks Ian!

-}


{-| Number betwen 0 and 1
-}
type alias Proportion =
    Float


type Spline
    = Spline Point Point Point Point


hash : Spline -> String
hash (Spline c0 c1 c2 c3) =
    pointHash c0
        ++ dash
        ++ pointHash c1
        ++ dash
        ++ pointHash c2
        ++ dash
        ++ pointHash c3


floatStr : Float -> String
floatStr f =
    String.fromInt (round (f * 1000))


pointHash : Point -> String
pointHash { x, y } =
    -- In order to reduce the size of the string generated we are going to slightly
    -- the x value is usually a Time.Posix
    -- Which means it's huge like: 1,612,028,089
    -- we can likely wrap this
    let
        xInt =
            round x

        yInt =
            round y
    in
    String.fromInt yInt ++ dash ++ String.fromInt yInt


{-| Normalize the spline from
x : Time.Absolute
y : Absolute Position

to

    x : 0-1 based on time domain
    y : 0-1 based on position domain

-}
cssTimingString : Spline -> String
cssTimingString (Spline c0 c1 c2 c3) =
    let
        xDomain =
            c3.x - c0.x

        yDomain =
            c3.y - c0.y
    in
    if xDomain == 0 || yDomain == 0 then
        "linear"

    else
        "cubic-bezier("
            ++ (String.fromFloat ((c1.x - c0.x) / xDomain) ++ comma)
            ++ (String.fromFloat ((c1.y - c0.y) / yDomain) ++ comma)
            ++ (String.fromFloat ((c2.x - c0.x) / xDomain) ++ comma)
            ++ String.fromFloat ((c2.y - c0.y) / yDomain)
            ++ ")"


comma : String
comma =
    ","


dash : String
dash =
    "-"


doesNotMove : Spline -> Bool
doesNotMove (Spline first one two last) =
    (first.x == last.x)
        && (one.x == first.x)
        && (two.x == two.x)


firstY : Spline -> Float
firstY (Spline first _ _ _) =
    first.y


lastY : Spline -> Float
lastY (Spline _ _ _ last) =
    last.y


firstX : Spline -> Float
firstX (Spline first _ _ _) =
    first.x


lastX : Spline -> Float
lastX (Spline _ _ _ last) =
    last.x


afterLastX : Float -> Spline -> Bool
afterLastX a (Spline _ _ _ last) =
    a > last.x


zeroPoint : Point
zeroPoint =
    { x = 0
    , y = 0
    }


type alias Point =
    { x : Float
    , y : Float
    }


scaleBy : Float -> Point -> Point
scaleBy n { x, y } =
    { x = x * n
    , y = y * n
    }


translateBy : Point -> Point -> Point
translateBy delta { x, y } =
    { x = x + delta.x
    , y = y + delta.y
    }


interpolatePoints : Point -> Point -> Float -> Point
interpolatePoints p1 p2 t =
    if t <= 0.5 then
        { x = p1.x + t * (p2.x - p1.x)
        , y = p1.y + t * (p2.y - p1.y)
        }

    else
        { x = p2.x + (1 - t) * (p1.x - p2.x)
        , y = p2.y + (1 - t) * (p1.y - p2.y)
        }


interpolateValue : Float -> Float -> Float -> Float
interpolateValue start end t =
    if t <= 0.5 then
        start + t * (end - start)

    else
        end + (1 - t) * (start - end)


{-| Borrowed from: <https://github.com/ianmackenzie/elm-geometry/blob/3.1.0/src/CubicSpline2d.elm#L370>
-}
pointOn : Spline -> Proportion -> Point
pointOn ((Spline p1 p2 p3 p4) as s) proportion =
    let
        q1 =
            interpolatePoints p1 p2 proportion

        q2 =
            interpolatePoints p2 p3 proportion

        q3 =
            interpolatePoints p3 p4 proportion

        r1 =
            interpolatePoints q1 q2 proportion

        r2 =
            interpolatePoints q2 q3 proportion
    in
    interpolatePoints r1 r2 proportion


{-| Borrowed from: <https://github.com/ianmackenzie/elm-geometry/blob/3.1.0/src/CubicSpline2d.elm#L778>
-}
firstDerivative : Spline -> Proportion -> Point
firstDerivative (Spline p1 p2 p3 p4) proportion =
    let
        vx1 =
            p2.x - p1.x

        vy1 =
            p2.y - p1.y

        vx2 =
            p3.x - p2.x

        vy2 =
            p3.y - p2.y

        vx3 =
            p4.x - p3.x

        vy3 =
            p4.y - p3.y

        wx1 =
            interpolateValue vx1 vx2 proportion

        wy1 =
            interpolateValue vy1 vy2 proportion

        wx2 =
            interpolateValue vx2 vx3 proportion

        wy2 =
            interpolateValue vy2 vy3 proportion
    in
    { x =
        3 * interpolateValue wx1 wx2 proportion
    , y =
        3 * interpolateValue wy1 wy2 proportion
    }


{-| Borrowed from: <https://github.com/ianmackenzie/elm-geometry/blob/3.1.0/src/CubicSpline2d.elm#L858>
-}
secondDerivative : Spline -> Proportion -> Point
secondDerivative (Spline p1 p2 p3 p4) proportion =
    let
        u1 =
            { x = p2.x - p1.x
            , y = p2.y - p1.y
            }

        u2 =
            { x = p3.x - p2.x
            , y = p3.y - p2.y
            }

        u3 =
            { x = p4.x - p3.x
            , y = p4.y - p3.y
            }

        v1 =
            { x = u2.x - u1.x
            , y = u2.y - u1.y
            }

        v2 =
            { x = u3.x - u2.x
            , y = u3.y - u2.y
            }
    in
    scaleBy 6 (interpolatePoints v1 v2 proportion)


atX : Float -> Spline -> { point : { x : Float, y : Float }, t : Float }
atX x spline =
    atXHelper spline x 0.25 (guessTime x spline) 0


guessTime : Float -> Spline -> Float
guessTime now (Spline one two three four) =
    if (four.x - one.x) == 0 then
        0.5

    else
        (now - one.x) / (four.x - one.x)


atXTolerance : Float
atXTolerance =
    1


{-| Once we have a bezier curve, we need to find the value of y at a given x.

A simple way to do this is just a binary search, which is what this does.

However we could use Newton's Method:
<https://en.wikipedia.org/wiki/Newton%27s_method>
<http://greweb.me/2012/02/bezier-curve-based-easing-functions-from-concept-to-implementation/>

OR (and I'm not 100% on this one), we could use Cardano's method:

as explained here:
<https://stackoverflow.com/questions/51879836/cubic-bezier-curves-get-y-for-given-x-special-case-where-x-of-control-points/51883347#51883347>

-}
atXHelper : Spline -> Float -> Float -> Float -> Int -> { point : { x : Float, y : Float }, t : Float }
atXHelper ((Spline p1 p2 p3 p4) as spline) desiredX jumpSize t depth =
    let
        point =
            if t <= 0.5 then
                let
                    q1 =
                        { x = p1.x + t * (p2.x - p1.x)
                        , y = p1.y + t * (p2.y - p1.y)
                        }

                    q2 =
                        { x = p2.x + t * (p3.x - p2.x)
                        , y = p2.y + t * (p3.y - p2.y)
                        }

                    q3 =
                        { x = p3.x + t * (p4.x - p3.x)
                        , y = p3.y + t * (p4.y - p3.y)
                        }

                    r1 =
                        { x = q1.x + t * (q2.x - q1.x)
                        , y = q1.y + t * (q2.y - q1.y)
                        }

                    r2 =
                        { x = q2.x + t * (q3.x - q2.x)
                        , y = q2.y + t * (q3.y - q2.y)
                        }
                in
                { x = r1.x + t * (r2.x - r1.x)
                , y = r1.y + t * (r2.y - r1.y)
                }

            else
                let
                    q1 =
                        { x = p2.x + (1 - t) * (p1.x - p2.x)
                        , y = p2.y + (1 - t) * (p1.y - p2.y)
                        }

                    q2 =
                        { x = p3.x + (1 - t) * (p2.x - p3.x)
                        , y = p3.y + (1 - t) * (p2.y - p3.y)
                        }

                    q3 =
                        { x = p4.x + (1 - t) * (p3.x - p4.x)
                        , y = p4.y + (1 - t) * (p3.y - p4.y)
                        }

                    r1 =
                        { x = q2.x + (1 - t) * (q1.x - q2.x)
                        , y = q2.y + (1 - t) * (q1.y - q2.y)
                        }

                    r2 =
                        { x = q3.x + (1 - t) * (q2.x - q3.x)
                        , y = q3.y + (1 - t) * (q2.y - q3.y)
                        }
                in
                { x = r2.x + (1 - t) * (r1.x - r2.x)
                , y = r2.y + (1 - t) * (r1.y - r2.y)
                }
    in
    if depth == 10 then
        { point = point
        , t = t
        }

    else if abs (point.x - desiredX) < atXTolerance && abs (point.x - desiredX) >= 0 then
        { point = point
        , t = t
        }

    else if (point.x - desiredX) > 0 then
        atXHelper spline desiredX (jumpSize / 2) (t - jumpSize) (depth + 1)

    else
        atXHelper spline desiredX (jumpSize / 2) (t + jumpSize) (depth + 1)


addX : Float -> Spline -> Spline
addX x (Spline c0 c1 c2 c3) =
    let
        sc0 =
            { x = c0.x + x
            , y = c0.y
            }

        sc1 =
            { x = c1.x + x
            , y = c1.y
            }

        sc2 =
            { x = c2.x + x
            , y = c2.y
            }

        sc3 =
            { x = c3.x + x
            , y = c3.y
            }
    in
    Spline sc0 sc1 sc2 sc3


{-| Takes a bezier and shrinks it so that the domain of c0:c3 is

    0,0:1,1

-}
normalize : Spline -> Spline
normalize (Spline c0 c1 c2 c3) =
    let
        factorX =
            c3.x - c0.x

        factorY =
            c3.y - c0.y
    in
    Spline
        { x = 0
        , y = 0
        }
        { x = (c1.x - c0.x) / factorX
        , y = (c1.y - c0.y) / factorY
        }
        { x = (c2.x - c0.x) / factorX
        , y = (c2.y - c0.y) / factorY
        }
        { x = 1
        , y = 1
        }


withinX : Float -> Spline -> Bool
withinX x (Spline p1 p2 p3 p4) =
    x >= p1.x && x <= p4.x


splitAtX : Float -> Spline -> ( Spline, Spline )
splitAtX x spline =
    let
        { t } =
            atX x spline
    in
    splitAt t spline


{-| Split a spline at a particular parameter value, resulting in two smaller
splines.
-}
splitAt : Float -> Spline -> ( Spline, Spline )
splitAt parameterValue (Spline p1 p2 p3 p4) =
    let
        q1 =
            interpolatePoints p1 p2 parameterValue

        q2 =
            interpolatePoints p2 p3 parameterValue

        q3 =
            interpolatePoints p3 p4 parameterValue

        r1 =
            interpolatePoints q1 q2 parameterValue

        r2 =
            interpolatePoints q2 q3 parameterValue

        s =
            interpolatePoints r1 r2 parameterValue
    in
    ( Spline p1 q1 r1 s
    , Spline s r2 q3 p4
    )


takeBefore : Float -> List Spline -> List Spline
takeBefore cutoff splines =
    takeBeforeHelper cutoff splines []


takeBeforeHelper : Float -> List Spline -> List Spline -> List Spline
takeBeforeHelper cutoff splines captured =
    case splines of
        [] ->
            List.reverse captured

        spline :: upcoming ->
            if withinX cutoff spline then
                let
                    parameter =
                        0.5

                    ( before, _ ) =
                        splitAtX cutoff spline
                in
                List.reverse (before :: captured)

            else
                takeBeforeHelper cutoff upcoming (spline :: captured)


splitList :
    Float
    -> List Spline
    -> List Spline
    ->
        { before : List Spline
        , after : List Spline
        }
splitList at splines passed =
    case splines of
        [] ->
            { before = List.reverse passed
            , after = []
            }

        top :: remain ->
            if withinX at top then
                let
                    ( before, after ) =
                        splitAtX at top
                in
                { before = List.reverse (before :: passed)
                , after = after :: remain
                }

            else
                splitList at remain (top :: passed)
