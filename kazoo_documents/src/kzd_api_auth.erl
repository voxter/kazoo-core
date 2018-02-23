%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2018, 2600Hz
%%% @doc
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_api_auth).

-export([new/0]).
-export([api_key/1, api_key/2, set_api_key/2]).


-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"api_auth">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec api_key(doc()) -> kz_term:api_ne_binary().
api_key(Doc) ->
    api_key(Doc, 'undefined').

-spec api_key(doc(), Default) -> kz_term:ne_binary() | Default.
api_key(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"api_key">>], Doc, Default).

-spec set_api_key(doc(), kz_term:ne_binary()) -> doc().
set_api_key(Doc, ApiKey) ->
    kz_json:set_value([<<"api_key">>], ApiKey, Doc).
