%%%-----------------------------------------------------------------------------
%%% @Copyright (C) 2010-2016, 2600Hz
%%% @doc Test utilities for manipulating Kazoo/Kazoo documents
%%% @author Pierre Fenoll
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_doc_tests).

-include_lib("eunit/include/eunit.hrl").
-define(APP, 'kazoo_documents').

latest_attachment_id_test_() ->
    {'ok', JObj1} = kz_json:fixture(?APP, <<"fixtures/doc_no_attachment.json">>),
    {'ok', JObj2} = kz_json:fixture(?APP, <<"fixtures/doc_one_attachment.json">>),
    {'ok', JObj3} = kz_json:fixture(?APP, <<"fixtures/doc_multiple_attachments.json">>),
    [?_assertEqual('undefined', kz_doc:latest_attachment_id(JObj1))
    ,?_assertEqual(<<"csv.csv">>, kz_doc:latest_attachment_id(JObj2))
    ,?_assertEqual(<<"newest">>, kz_doc:latest_attachment_id(JObj3))
    ].

read_only_test_() ->
    {'ok', JObj} = kz_json:fixture(?APP, <<"fixtures/doc_no_attachment.json">>),
    Leaked = kz_doc:leak_private_fields(JObj),

    {Tests, _} = kz_json:foldl(fun read_only_fold/3, {[], Leaked}, JObj),
    Tests.

read_only_fold(Key, Value, {Tests, Leaked}) ->
    {[{"has leaked key " ++ kz_term:to_list(kz_doc:remove_pvt(Key)), ?_assertEqual(Value, kz_json:get_value([<<"_read_only">>, kz_doc:remove_pvt(Key)], Leaked))}
     ,{"doesn't have private key " ++ kz_term:to_list(Key), ?_assert(not kz_json:is_defined(Key, Leaked))}
      | Tests
     ]
    ,Leaked
    }.
