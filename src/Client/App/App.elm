module Client.App.App exposing (init, view, update, subscriptions)

import Client.App.Menu
import Client.App.Models exposing (Content(DashBoardContent, GraphContent, FileTreeContent, PackageDependenciesContent), Model, Msg(..), packageDependenciesPage, PackageDependenciesPageMsg, ModuleGraphPageMsg, moduleGraphPage)
import Client.DashBoard.DashBoard as DashBoard
import Client.Graph.Graph as Graph
import Client.FileTree as FileTree
import Client.Socket exposing (controlAddress)
import Html exposing (Html, div)
import Html.Attributes exposing (id)
import Navigation exposing (Location)
import Tuple2
import WebSocket as WS
import Client.StaticStatePage as StaticStatePage


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ case model.content of
            DashBoardContent sub ->
                DashBoard.subscriptions model.location sub |> Sub.map DashBoardMsg

            GraphContent _ ->
                Sub.none

            FileTreeContent sub ->
                FileTree.subscriptions model.location sub |> Sub.map FileTreeMsg

            PackageDependenciesContent _ ->
                Sub.none
        , WS.keepAlive (controlAddress model.location)
        ]


init : Location -> ( Model, Cmd Msg )
init =
    onLocation


onLocation : Location -> ( Model, Cmd Msg )
onLocation l =
    case l.hash of
        "#tree" ->
            FileTree.init l
                |> Tuple2.mapFirst (\x -> { content = FileTreeContent x, location = l })
                |> Tuple2.mapSecond (Cmd.map FileTreeMsg)

        "#module-graph" ->
            moduleGraphPage
                |> Tuple2.mapFirst (\x -> { content = GraphContent x, location = l })
                |> Tuple2.mapSecond (Cmd.map GraphMsg)

        "#package-dependencies" ->
            packageDependenciesPage
                |> Tuple2.mapFirst (\x -> { content = PackageDependenciesContent x, location = l })
                |> Tuple2.mapSecond (Cmd.map PackageDependenciesMsg)

        _ ->
            DashBoard.init l
                |> Tuple2.mapFirst (\x -> { content = DashBoardContent x, location = l })
                |> Tuple2.mapSecond (Cmd.map DashBoardMsg)


view : Model -> Html.Html Msg
view m =
    div []
        [ Client.App.Menu.view m.location
        , div [ id "page-wrapper" ]
            [ case m.content of
                DashBoardContent subModel ->
                    DashBoard.view subModel |> Html.map DashBoardMsg

                GraphContent subModel ->
                    StaticStatePage.view subModel |> Html.map GraphMsg

                FileTreeContent subModel ->
                    FileTree.view subModel |> Html.map FileTreeMsg

                PackageDependenciesContent subModel ->
                    StaticStatePage.view subModel |> Html.map PackageDependenciesMsg
            ]
        ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        OnLocation l ->
            let
                ( newModel, cmd ) =
                    onLocation l

                removeGraphCmd =
                    if newModel.location.hash /= "#module-graph" then
                        -- attempt to remove graph if we are not in graph view
                        Graph.removeCmd
                    else
                        Cmd.none
            in
                newModel ! [ cmd, removeGraphCmd ]

        Refresh ->
            ( model
            , WS.send (controlAddress model.location) "reload"
            )

        DashBoardMsg subMsg ->
            onDashBoardMsg subMsg model

        GraphMsg subMsg ->
            onGraphMsg subMsg model

        FileTreeMsg subMsg ->
            onFileTreeMsg subMsg model

        PackageDependenciesMsg subMsg ->
            onPackageDependenciesMsg subMsg model


onPackageDependenciesMsg : PackageDependenciesPageMsg -> Model -> ( Model, Cmd Msg )
onPackageDependenciesMsg subMsg model =
    case model.content of
        PackageDependenciesContent subModel ->
            StaticStatePage.update subMsg subModel
                |> Tuple2.mapFirst (\x -> { model | content = PackageDependenciesContent x })
                |> Tuple2.mapSecond (Cmd.map PackageDependenciesMsg)

        _ ->
            model ! []


onFileTreeMsg : FileTree.Msg -> Model -> ( Model, Cmd Msg )
onFileTreeMsg subMsg model =
    case model.content of
        FileTreeContent subModel ->
            FileTree.update model.location subMsg subModel
                |> Tuple2.mapFirst (\x -> { model | content = FileTreeContent x })
                |> Tuple2.mapSecond (Cmd.map FileTreeMsg)

        _ ->
            model ! []


onDashBoardMsg : DashBoard.Msg -> Model -> ( Model, Cmd Msg )
onDashBoardMsg subMsg model =
    case model.content of
        DashBoardContent subModel ->
            DashBoard.update model.location subMsg subModel
                |> Tuple2.mapFirst (\x -> { model | content = DashBoardContent x })
                |> Tuple2.mapSecond (Cmd.map DashBoardMsg)

        _ ->
            model ! []


onGraphMsg : ModuleGraphPageMsg -> Model -> ( Model, Cmd Msg )
onGraphMsg subMsg model =
    case model.content of
        GraphContent subModel ->
            StaticStatePage.update subMsg subModel
                |> Tuple2.mapFirst (\x -> { model | content = GraphContent x })
                |> Tuple2.mapSecond (Cmd.map GraphMsg)

        _ ->
            model ! []
