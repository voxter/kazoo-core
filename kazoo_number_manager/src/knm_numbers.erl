%%%-------------------------------------------------------------------
%%% @copyright (C) 2015, 2600Hz INC
%%% @doc
%%%
%%% @end
%%% @contributors
%%%   Peter Defebvre
%%%-------------------------------------------------------------------
-module(knm_numbers).

-export([get/1, get/2
         ,create/1
         ,move/1 ,move/2
         ,update/1 ,update/2
         ,reconcile/2
         ,release/1 ,release/2
         ,change_state/1 ,change_state/2
         ,assigned_to_app/1 ,assigned_to_app/2
         ,buy/2
         ,free/1
         ,emergency_enabled/1
        ]).

-include("knm.hrl").

-type numbers_return() :: [ {ne_binary(), knm_number_return()} |
                            {'error', any()}
                          ].

%%--------------------------------------------------------------------
%% @public
%% @doc
%% @end
%%--------------------------------------------------------------------
-spec get(ne_binaries()) ->
                 numbers_return().
-spec get(ne_binaries(), knm_number_options:options()) ->
                 numbers_return().
get(Nums) ->
    get(Nums, knm_number_options:default()).

get(Nums, Options) ->
    do_get(Nums, Options, []).

-spec do_get(ne_binaries(), knm_number_options:options(), numbers_return()) ->
                    numbers_return().
do_get([], _Options, Acc) -> Acc;
do_get([Num|Nums], Options, Acc) ->
    Return = knm_number:get(Num, Options),
    do_get(Nums, Options, [{Num, Return}|Acc]).

%%--------------------------------------------------------------------
%% @public
%% @doc
%% @end
%%--------------------------------------------------------------------
-spec create(wh_proplist()) -> numbers_return().
create(Props) ->
    do_create(Props, []).

-spec do_create(wh_proplist(), numbers_return()) -> numbers_return().
do_create([], Acc) -> Acc;
do_create([{Num, Data}|Props], Acc) ->
    Return = knm_number:create(Num, Data),
    do_create(Props, [{Num, Return}|Acc]).

%%--------------------------------------------------------------------
%% @public
%% @doc
%% @end
%%--------------------------------------------------------------------
-spec move(wh_proplist()) ->
                  numbers_return().
-spec move(wh_proplist(), knm_number_options:options()) ->
                  numbers_return().
move(Props) ->
    move(Props, knm_number_options:default()).

move(Props, Options) ->
    do_move(Props, Options, []).

-spec do_move(wh_proplist(), knm_number_options:options(), numbers_return()) ->
                     numbers_return().
do_move([], _Options, Acc) -> Acc;
do_move([{Num, MoveTo}|Props], Options, Acc) ->
    Return = knm_number:move(Num, MoveTo, Options),
    do_move(Props, Options, [{Num, Return}|Acc]).

%%--------------------------------------------------------------------
%% @public
%% @doc
%% @end
%%--------------------------------------------------------------------
-spec update(wh_proplist()) ->
                    numbers_return().
-spec update(wh_proplist(), knm_number_options:options()) ->
                    numbers_return().
update(Props) ->
    update(Props, knm_number_options:default()).

update(Props, Options) ->
    do_update(Props, Options, []).

-spec do_update(wh_proplist(), knm_number_options:options(), numbers_return()) ->
                       numbers_return().
do_update([], _Options, Acc) -> Acc;
do_update([{Num, Data}|Props], Options, Acc) ->
    Return = knm_number:update(Num, Data, Options),
    do_update(Props, Options, [{Num, Return}|Acc]).

%%--------------------------------------------------------------------
%% @public
%% @doc
%% @end
%%--------------------------------------------------------------------
-spec reconcile(ne_binaries(), knm_number_options:options()) ->
                       numbers_return().
reconcile(Numbers, Options) ->
    do_reconcile(Numbers, Options, []).

-spec do_reconcile(ne_binaries(), knm_number_options:options(), numbers_return()) ->
                          numbers_return().
do_reconcile([], _Options, Acc) -> Acc;
do_reconcile([Number|Numbers], Options, Acc) ->
    Return = knm_number:reconcile(Number, Options),
    do_reconcile(Numbers, Options, [{Number, Return}|Acc]).

%%--------------------------------------------------------------------
%% @public
%% @doc
%% @end
%%--------------------------------------------------------------------
-spec release(ne_binaries()) ->
                     numbers_return().
-spec release(ne_binaries(), knm_number_options:options()) ->
                     numbers_return().
release(Props) ->
    release(Props, knm_number_options:default()).

release(Props, Options) ->
    do_release(Props, Options, []).

-spec do_release(ne_binaries(), knm_number_options:options(), numbers_return()) ->
                        numbers_return().
do_release([], _Options, Acc) -> Acc;
do_release([Num|Nums], Options, Acc) ->
    Return = knm_number:release(Num, Options),
    do_release(Nums, Options, [{Num, Return}|Acc]).

%%--------------------------------------------------------------------
%% @public
%% @doc
%% @end
%%--------------------------------------------------------------------
-spec change_state(wh_proplist()) ->
                          numbers_return().
-spec change_state(wh_proplist(), knm_number_options:options()) ->
                          numbers_return().
change_state(Props) ->
    change_state(Props, knm_number_options:default()).

change_state(Props, Options) ->
    do_change_state(Props, Options, []).

-spec do_change_state(wh_proplist(), knm_number_options:options(), numbers_return()) ->
                             numbers_return().
do_change_state([], _Options, Acc) -> Acc;
do_change_state([{Num, State}|Props], Options, Acc) ->
    try knm_number_states:to_state(Num, State, Options) of
        Number -> do_change_state(Props, Options, [{Num, {'ok', Number}}|Acc])
    catch
        'throw':R ->
            do_change_state(Props, Options, [{Num, R} | Acc])
    end.

%%--------------------------------------------------------------------
%% @public
%% @doc
%% @end
%%--------------------------------------------------------------------
-spec assigned_to_app(wh_proplist()) ->
                             numbers_return().
-spec assigned_to_app(wh_proplist(), knm_number_options:options()) ->
                             numbers_return().
assigned_to_app(Props) ->
    assigned_to_app(Props, knm_number_options:default()).

assigned_to_app(Props, Options) ->
    do_assigned_to_app(Props, Options, []).

-spec do_assigned_to_app(wh_proplist(), knm_number_options:options(), numbers_return()) ->
                                numbers_return().
do_assigned_to_app([], _Options, Acc) -> Acc;
do_assigned_to_app([{Num, App}|Props], Options, Acc) ->
    Return = knm_number:assign_to_app(Num, App, Options),
    do_assigned_to_app(Props, Options, [{Num, Return}|Acc]).

%%--------------------------------------------------------------------
%% @public
%% @doc
%% @end
%%--------------------------------------------------------------------
-spec buy(ne_binaries(), ne_binary()) -> numbers_return().
buy(Nums, Account) ->
    [knm_number:buy(Num, Account) || Num <- Nums].

%%--------------------------------------------------------------------
%% @public
%% @doc
%% @end
%%--------------------------------------------------------------------
-spec free(ne_binary()) -> 'ok'.
free(AccountId)
  when is_binary(AccountId) ->
    AccountDb = wh_util:format_account_id(AccountId, 'encoded'),
    case kz_datamgr:open_cache_doc(AccountDb, ?KNM_PHONE_NUMBERS_DOC) of
        {'ok', JObj} ->
            free_numbers(AccountId, JObj);
        {'error', _E} ->
            lager:debug("failed to open ~s in ~s: ~p"
                        ,[?KNM_PHONE_NUMBERS_DOC, AccountId, _E]
                       )
    end.

-spec free_numbers(ne_binary(), wh_json:object()) -> 'ok'.
free_numbers(AccountId, JObj) ->
    _ = [maybe_free_number(AccountId, DID)
         || DID <- wh_json:get_public_keys(JObj)],
    'ok'.

-spec maybe_free_number(ne_binary(), ne_binary()) -> 'ok'.
maybe_free_number(AccountId, DID) ->
    case knm_number:get(DID) of
        {'error', _E} ->
            lager:debug("failed to release ~s for account ~s: ~p", [DID, AccountId, _E]);
        {'ok', Number} ->
            check_to_free_number(AccountId, Number)
    end.

-spec check_to_free_number(ne_binary(), knm_number:knm_number()) -> 'ok'.
check_to_free_number(AccountId, Number) ->
    To = knm_phone_number:assigned_to(knm_number:phone_number(Number)),
    check_to_free_number(AccountId, Number, To).

-spec check_to_free_number(ne_binary(), knm_number:knm_number(), api_binary()) -> 'ok'.
check_to_free_number(AccountId, Number, AccountId) ->
    try knm_number_states:to_state(Number, ?NUMBER_STATE_RELEASED) of
        _Number ->
            lager:debug("released ~s for account ~s"
                        ,[knm_phone_number:number(knm_number:phone_number(Number))
                          ,AccountId
                         ]
                       )
    catch
        'throw':_R ->
            lager:debug("failed to release ~s for account ~s: ~p"
                        ,[knm_phone_number:number(knm_number:phone_number(Number))
                          ,AccountId
                          ,_R
                         ]
                       )
    end;
check_to_free_number(_AccountId, Number, _OtherAccountId) ->
    lager:debug("not releasing ~s for account ~s; it is assigned to account ~s"
                ,[knm_phone_number:number(knm_number:phone_number(Number))
                  ,_AccountId
                  ,_OtherAccountId
                 ]
               ).

%%--------------------------------------------------------------------
%% @public
%% @doc Find an account's numbers that have emergency services enabled
%%--------------------------------------------------------------------
-spec emergency_enabled(ne_binary()) -> {'ok', knm_number:knm_numbers()} |
                                        {'error', any()}.
emergency_enabled(Account = ?NE_BINARY) ->
    AccountDb = wh_util:format_account_id(Account, 'encoded'),
    case kz_datamgr:open_cache_doc(AccountDb, ?KNM_PHONE_NUMBERS_DOC) of
        {'ok', JObj} ->
            Numbers = wh_json:get_keys(wh_json:public_fields(JObj)),
            Options = [{'assigned_to', wh_util:format_account_id(Account)}
                      ],
            PhoneNumbers = fetch(Numbers, Options),
            EnabledNumbers =
                [PhoneNumber || PhoneNumber <- PhoneNumbers,
                                knm_providers:has_emergency_services(PhoneNumber)],
            {'ok', EnabledNumbers};
        {'error', _R}=Error ->
            Error
    end.

%%%===================================================================
%%% Internal functions
%%%===================================================================

-spec fetch(ne_binaries(), knm_number_options:opions()) ->
                   knm_number:knm_numbers().
fetch(Numbers, Options) ->
    lists:foldl(
      fun (Number, Acc) ->
              case knm_phone_number:fetch(Number, Options) of
                  {'ok', PN} ->
                      [knm_number:set_phone_number(knm_number:new(), PN) | Acc];
                  _Else -> Acc
              end
      end
      ,[]
      ,Numbers
     ).
