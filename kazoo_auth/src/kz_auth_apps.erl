%%%-------------------------------------------------------------------
%%% @copyright (C) 2012-2017, 2600Hz, INC
%%% @doc
%%%
%%% @end
%%% @contributors
%%%-------------------------------------------------------------------
-module(kz_auth_apps).

-include("kazoo_auth.hrl").

%% ====================================================================
%% API functions
%% ====================================================================
-export([get_auth_app/1, get_auth_app/2
        ]).


-spec get_auth_app(ne_binary()) -> map() | {'error', ne_binary()}.
get_auth_app(AppId) ->
    get_auth_app(AppId, 'false').

-spec get_auth_app(ne_binary(), boolean()) -> map() | {'error', ne_binary()}.
get_auth_app(AppId, MergeProvider) ->
    case do_get_auth_app(AppId) of
        {'error', _} = Error -> Error;
        #{}=App when MergeProvider -> merge_provider(App);
        #{}=App -> App
    end.

-spec do_get_auth_app(ne_binary()) -> map() | {'error', ne_binary()}.
do_get_auth_app(<<"kazoo">>) ->
    #{name => <<"kazoo">>
     ,pvt_server_key => ?SYSTEM_KEY_ID
     ,pvt_auth_provider => <<"kazoo">>
     };
do_get_auth_app(AppId) ->
    case kz_datamgr:open_cache_doc(?KZ_AUTH_DB, AppId) of
        {'ok', JObj} ->
            #{'_id' := Id} = Map = kz_auth_util:map_keys_to_atoms(kz_json:to_map(JObj)),
            Map#{name => Id};
        {'error', _} -> {'error', <<"AUTH - App ", AppId/binary, " not found">>}
    end.

merge_provider(#{pvt_auth_provider := ProviderId}=App) ->
    Provider = kz_auth_providers:get_auth_provider(ProviderId),
    maps:merge( Provider, App);
merge_provider(App) -> App.
