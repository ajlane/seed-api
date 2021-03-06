module Api.Http exposing (..)

import Api.Decode
import Api.Encode
import Api.Model
import Dict
import Http
import Json.Decode
import Json.Encode
import Task
import Time
import Url
import Url.Interpolate


searchUrlToString { after, q, size } (Api.Model.SearchUrl template) =
    Url.Interpolate.interpolate
        template
        (Dict.fromList
            ([ after |> Maybe.map (\p -> ( "after", p ))
             , Just ( "q", q )
             , size |> Maybe.map (\p -> ( "size", p ))
             ]
                |> List.filterMap identity
            )
        )


searchUrlGet params url =
    { method = "GET"
    , url = searchUrlToString params url
    , body = Nothing
    , expect = Api.Decode.searchResponse
    , headers = [ Http.header "Accept" "application/json" ]
    , timeout = Nothing
    , tracker = Nothing
    }


indexUrlToString (Api.Model.IndexUrl url) =
    Url.Interpolate.interpolate url Dict.empty


indexUrlGet url =
    { method = "GET"
    , url = indexUrlToString url
    , body = Nothing
    , expect = Api.Decode.index
    , headers = [ Http.header "Accept" "application/json" ]
    , timeout = Nothing
    , tracker = Nothing
    }


indexUrlPost body url =
    { method = "POST"
    , url = indexUrlToString url
    , body = Api.Encode.newDraft body |> Just
    , expect = Api.Decode.newArticleResponse
    , headers = [ Http.header "Accept" "application/json" ]
    , timeout = Nothing
    , tracker = Nothing
    }


articleUrlToString (Api.Model.ArticleUrl url) =
    Url.Interpolate.interpolate url Dict.empty


articleUrlGet url =
    { method = "GET"
    , url = articleUrlToString url
    , body = Nothing
    , expect = Api.Decode.article
    , headers = [ Http.header "Accept" "application/json" ]
    , timeout = Nothing
    , tracker = Nothing
    }


articleUrlPut body url =
    { method = "PUT"
    , url = articleUrlToString url
    , body = Api.Encode.updateDraft body |> Just
    , expect = Api.Decode.updateArticleResponse
    , headers = [ Http.header "Accept" "application/json" ]
    , timeout = Nothing
    , tracker = Nothing
    }


articleUrlDelete url =
    { method = "DELETE"
    , url = articleUrlToString url
    , body = Nothing
    , expect = Json.Decode.string
    , headers = [ Http.header "Accept" "application/json" ]
    , timeout = Nothing
    , tracker = Nothing
    }


expectArticle msg =
    Http.expectJson msg Api.Decode.article


expectIndex msg =
    Http.expectJson msg Api.Decode.index


expectNewArticleResponse msg =
    Http.expectJson msg Api.Decode.newArticleResponse


expectSearchResponse msg =
    Http.expectJson msg Api.Decode.searchResponse


expectUpdateArticleResponse msg =
    Http.expectJson msg Api.Decode.updateArticleResponse


newDraftBody body =
    body |> Api.Encode.newDraft |> Http.jsonBody


updateDraftBody body =
    body |> Api.Encode.updateDraft |> Http.jsonBody


resultToMsg ok err result =
    case result of
        Result.Ok value ->
            ok value

        Result.Err value ->
            err value


maybeToMsg just nothing maybe =
    case maybe of
        Maybe.Just value ->
            just value

        Maybe.Nothing ->
            nothing


headers list req =
    { req | headers = list |> List.map (\( k, v ) -> Http.header k v) }


header key value req =
    { req | headers = req.headers ++ [ Http.header key value ] }


timeout t req =
    { req | timeout = Just t }


noTimeout req =
    { req | timeout = Nothing }


tracker name req =
    { req | tracker = Just name }


noTracker name req =
    { req | tracker = Nothing }


request ok err req =
    { method = req.method
    , url = req.url
    , body = req.body |> maybeToMsg Http.jsonBody Http.emptyBody
    , expect = req.expect |> Http.expectJson (resultToMsg ok err)
    , headers = req.headers
    , timeout = req.timeout
    , tracker = req.tracker
    }
        |> Http.request


mock res ok err req =
    req.url
        |> Url.fromString
        |> maybeToMsg
            (\url ->
                res { method = req.method, url = url, body = req.body }
                    |> resultToMsg
                        (Json.Decode.decodeValue req.expect
                            >> resultToMsg
                                ok
                                (Json.Decode.errorToString
                                    >> Http.BadBody
                                    >> err
                                )
                        )
                        err
            )
            (req.url |> Http.BadUrl |> err)
        |> Task.succeed
        |> Task.perform identity
