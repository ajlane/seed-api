module Main exposing (..)

import Api exposing (Article, Index, IndexUrl, SearchResponse(..), SearchResults, SearchUrl, get, tracker, withIndexUrl, withSearchUrl)
import Browser exposing (Document)
import Html exposing (div, h1, input, li, p, text)
import Html.Attributes exposing (class)
import Html.Events exposing (onInput)
import Http exposing (Error(..))
import Time


url =
    IndexUrl "http://localhost/blog"


type alias Model =
    { article : Maybe Article
    , search : Maybe SearchUrl
    , query : String
    , results : Maybe SearchResponse
    , error : Maybe Http.Error
    }


type Msg
    = IndexReceived Index
    | IndexUnavailable Http.Error
    | ArticleReceived Article
    | ArticleUnavailable Http.Error
    | QueryUpdated String
    | SearchResultsReceived SearchResponse
    | SearchResultsUnavailable Http.Error


init : flags -> ( Model, Cmd Msg )
init _ =
    ( { article = Nothing, search = Nothing, query = "", results = Nothing, error = Nothing }, withIndexUrl url |> get IndexReceived IndexUnavailable )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        IndexReceived index ->
            ( { model | article = Just index.featured, search = Just index.search }, Cmd.none )

        IndexUnavailable err ->
            ( { model | error = Just err }, Cmd.none )

        ArticleReceived article ->
            ( { model | article = Just article }, Cmd.none )

        ArticleUnavailable err ->
            ( { model | article = Nothing, error = Just err }, Cmd.none )

        QueryUpdated query ->
            case model.search of
                Just search ->
                    ( { model | query = query }, withSearchUrl { q = query, size = Just "10", after = Nothing } search |> tracker "search" |> get SearchResultsReceived SearchResultsUnavailable )

                Nothing ->
                    ( { model | query = query }, Cmd.none )

        SearchResultsReceived results ->
            ( { model | results = Just results }, Cmd.none )

        SearchResultsUnavailable err ->
            ( { model | error = Just err }, Cmd.none )


subscriptions _ =
    Sub.none


searchBox { search, query, results } =
    div [ class "search" ]
        (case search of
            Just _ ->
                [ input [ onInput QueryUpdated ]
                    [ text query ]
                , div
                    [ class "results" ]
                    (if query |> String.isEmpty then
                        []

                     else
                        case results of
                            Just (SearchResponseSome hits) ->
                                hits
                                    |> List.map
                                        (\hit ->
                                            li [] [ text hit.title ]
                                        )

                            Just SearchResponseNone ->
                                [ text "No matches" ]

                            Nothing ->
                                [ text "Loading" ]
                    )
                ]

            Nothing ->
                []
        )


view : Model -> Document Msg
view model =
    { title =
        case ( model.error, model.article ) of
            ( Just _, _ ) ->
                "Error"

            ( Nothing, Just article ) ->
                article.title

            ( Nothing, Nothing ) ->
                "Blog"
    , body =
        case ( model.error, model.article ) of
            ( Just err, _ ) ->
                case err of
                    BadBody msg ->
                        [ text msg, searchBox model ]

                    BadUrl msg ->
                        [ text msg, searchBox model ]

                    Timeout ->
                        [ text "Request timed out", searchBox model ]

                    NetworkError ->
                        [ text "Network failure", searchBox model ]

                    BadStatus status ->
                        [ h1 [] [ text (String.fromInt status) ], searchBox model ]

            ( Nothing, Just article ) ->
                [ h1 [] [ text article.title ]
                , div [ class "year" ]
                    [ article.updated
                        |> Maybe.withDefault article.created
                        |> Time.toYear Time.utc
                        |> String.fromInt
                        |> text
                    ]
                , article.body
                    |> String.split "\n"
                    |> List.filterMap
                        (\line ->
                            if line |> String.isEmpty then
                                Nothing

                            else
                                p [] [ text line ]
                                    |> Just
                        )
                    |> div []
                , searchBox model
                ]

            ( Nothing, Nothing ) ->
                [ text "Please wait" ]
    }


main : Program () Model Msg
main =
    Browser.document
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
