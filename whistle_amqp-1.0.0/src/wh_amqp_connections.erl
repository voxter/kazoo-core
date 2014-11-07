%%%-------------------------------------------------------------------
%%% @copyright (C) 2011-2014, 2600Hz
%%% @doc
%%%
%%% @end
%%% @contributions
%%%
%%%-------------------------------------------------------------------
-module(wh_amqp_connections).

-behaviour(gen_server).

-export([new/1
         ,new/2
        ]).
-export([add/1
         ,add/2
         ,add/3
        ]).
-export([remove/1]).
-export([broker_connections/1]).
-export([broker_available_connections/1]).
-export([primary_broker/0]).
-export([arbitrator_broker/0]).
-export([federated_brokers/0]).
-export([broker_zone/1]).
-export([available/1]).
-export([unavailable/1]).
-export([is_available/0]).
-export([wait_for_available/0]).

-export([brokers_for_zone/1, brokers_for_zone/2, broker_for_zone/1]).
-export([brokers_with_tag/1, brokers_with_tag/2,broker_with_tag/1]).
-export([is_zone_available/1, is_tag_available/1, is_hidden_broker/1]).

-export([start_link/0]).

-export([init/1
         ,handle_call/3
         ,handle_cast/2
         ,handle_info/2
         ,terminate/2
         ,code_change/3
        ]).

-define(TAB, ?MODULE).

-include("amqp_util.hrl").

-record(state, {watchers=sets:new()}).
-type state() :: #state{}.

%%%===================================================================
%%% API
%%%===================================================================
%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link() -> gen_server:start_link({'local', ?MODULE}, ?MODULE, [], []).

-spec new(wh_amqp_connection() | text()) ->
                 wh_amqp_connection() |
                 {'error', _}.
new(Broker) -> new(Broker, 'local').

-spec new(wh_amqp_connection() | text(), text()) ->
                 wh_amqp_connection() |
                 {'error', _}.
new(<<_/binary>> = Broker, Zone) ->
    case broker_connections(Broker) =:= 0 of
        'false' -> {'error', 'exists'};
        'true' -> wh_amqp_connections:add(Broker, Zone)
    end;
new(Broker, Zone) ->
    new(wh_util:to_binary(Broker), Zone).

-spec add(wh_amqp_connection() | text()) ->
                 wh_amqp_connection() |
                 {'error', _}.
-spec add(wh_amqp_connection() | text(), text()) ->
                 wh_amqp_connection() |
                 {'error', _}.
-spec add(wh_amqp_connection() | text(), text(), list()) ->
                 wh_amqp_connection() |
                 {'error', _}.

add(Broker) -> add(Broker, 'local').

add(#wh_amqp_connection{broker=Broker, tags=Tags}=Connection, Zone) ->
    case wh_amqp_connection_sup:add(Connection) of
        {'ok', Pid} ->
            gen_server:cast(?MODULE, {'new_connection', Pid, Broker, Zone, Tags}),
            Connection;
        {'error', Reason} ->
            lager:warning("unable to start amqp connection to '~s': ~p"
                          ,[Broker, Reason]
                         ),
            {'error', Reason}
    end;
add(Broker, Zone) when not is_binary(Broker) ->
    add(wh_util:to_binary(Broker), Zone);
add(Broker, Zone) when not is_atom(Zone) ->
    add(Broker, wh_util:to_atom(Zone, 'true'));
add(Broker, Zone) ->
    add(Broker, Zone, []).

add(Broker, Zone, Tags) ->    
    case catch amqp_uri:parse(wh_util:to_list(Broker)) of
        {'EXIT', _R} ->
            lager:error("failed to parse AMQP URI '~s': ~p", [Broker, _R]),
            {'error', 'invalid_uri'};
        {'error', {Info, _}} ->
            lager:error("failed to parse AMQP URI '~s': ~p", [Broker, Info]),
            {'error', 'invalid_uri'};
        {'ok', #amqp_params_network{}=Params} ->
            add(#wh_amqp_connection{broker=Broker
                                    ,params=Params#amqp_params_network{connection_timeout=500}
                                    ,tags=Tags
                                    ,hidden=is_hidden_broker(Tags)
                                   }
                ,Zone
               );
        {'ok', Params} ->
            add(#wh_amqp_connection{broker=Broker
                                    ,params=Params
                                    ,tags=Tags
                                    ,hidden=is_hidden_broker(Tags)
                                   }
                ,Zone
               )
    end.

-spec remove(pids() | pid() | text()) -> 'ok'.
remove([]) -> 'ok';
remove([Connection|Connections]) when is_pid(Connection) ->
    _ = wh_amqp_connection_sup:remove(Connection),
    remove(Connections);
remove(Connection) when is_pid(Connection) ->
    wh_amqp_connection_sup:remove(Connection);
remove(Broker) when not is_binary(Broker) ->
    remove(wh_util:to_binary(Broker));
remove(Broker) ->
    Pattern = #wh_amqp_connections{broker=Broker
                                   ,connection='$1'
                                   ,_='_'
                                  },
    remove([Connection || [Connection] <- ets:match(?TAB, Pattern)]).

-spec available(pid()) -> 'ok'.
available(Connection) when is_pid(Connection) ->
    gen_server:cast(?MODULE, {'connection_available', Connection}).

-spec unavailable(pid()) -> 'ok'.
unavailable(Connection) when is_pid(Connection) ->
    gen_server:cast(?MODULE, {'connection_unavailable', Connection}).

-spec arbitrator_broker() -> api_binary().
arbitrator_broker() ->
    MatchSpec = [{#wh_amqp_connections{broker='$1'
                                       ,available='true'
                                       ,hidden='false'
                                       ,_='_'
                                      },
                  [],
                  ['$1']}
                ],
    case lists:sort(ets:select(?TAB, MatchSpec)) of
        [] -> 'undefined';
        [Arbitrator|_] -> Arbitrator
    end.

-spec broker_connections(ne_binary()) -> non_neg_integer().
broker_connections(Broker) ->
    MatchSpec = [{#wh_amqp_connections{broker=Broker
                                       ,_='_'
                                      },
                  [],
                  ['true']}
                ],
    ets:select_count(?TAB, MatchSpec).

-spec broker_available_connections(ne_binary()) -> non_neg_integer().
broker_available_connections(Broker) ->
    MatchSpec = [{#wh_amqp_connections{broker=Broker
                                       ,available='true'
                                       ,_='_'
                                      },
                  [],
                  ['true']}
                ],
    ets:select_count(?TAB, MatchSpec).

-spec primary_broker() -> api_binary().
primary_broker() ->
    Pattern = #wh_amqp_connections{available='true'
                                   ,zone='local'
                                   ,hidden='false'
                                   ,broker='$1'
                                   ,_='_'
                                  },
    case lists:sort([Broker
                     || [Broker] <- ets:match(?TAB, Pattern)
                    ])
    of
        [] -> 'undefined';
        [Broker|_] -> Broker
    end.

-spec federated_brokers() -> ne_binaries().
federated_brokers() ->
    MatchSpec = [{#wh_amqp_connections{zone='$1'
                                       ,broker='$2'
                                       ,hidden='$3'
                                       ,_='_'
                                      },
                  [{'andalso',
                     {'=/=', '$1', 'local'},
                     {'=:=', '$3', 'false'}}],
                  ['$2']
                 }
                ],
    sets:to_list(
      sets:from_list(
        ets:select(?TAB, MatchSpec)
       )
     ).

-spec broker_zone(ne_binary()) -> atom().
broker_zone(Broker) ->
    Pattern = #wh_amqp_connections{broker=Broker
                                   ,zone='$1'
                                   ,_='_'
                                  },
    case ets:match(?TAB, Pattern) of
        [[Zone]|_] -> Zone;
        _Else -> 'unknown'
    end.

-spec is_available() -> boolean().
is_available() -> primary_broker() =/= 'undefined'.

-spec wait_for_available() -> 'ok'.
wait_for_available() -> wait_for_available('infinity').

-spec wait_for_available('infinity') -> 'ok';
                        (non_neg_integer()) -> 'ok' | {'error', 'timeout'}.
wait_for_available(Timeout) ->
    case is_available() of
        'true' -> 'ok';
        'false' ->
            gen_server:cast(?MODULE, {'add_watcher', self()}),
            wait_for_notification(Timeout)
    end.

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {'stop', Reason}
%% @end
%%--------------------------------------------------------------------
init([]) ->
    wh_util:put_callid(?LOG_SYSTEM_ID),
    _ = ets:new(?TAB, ['named_table'
                       ,{'keypos', #wh_amqp_connections.connection}
                       ,'protected'
                       ,{'read_concurrency', 'true'}
                      ]),
    {'ok', #state{}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {'reply', Reply, State} |
%%                                   {'reply', Reply, State, Timeout} |
%%                                   {'noreply', State} |
%%                                   {'noreply', State, Timeout} |
%%                                   {'stop', Reason, Reply, State} |
%%                                   {'stop', Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_call(_Msg, _From, State) ->
    {'reply', {'error', 'not_implemented'}, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {'noreply', State} |
%%                                  {'noreply', State, Timeout} |
%%                                  {'stop', Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_cast({'new_connection', Connection, Broker, Zone, Tags}, State) ->
    Ref = erlang:monitor('process', Connection),
    _ = ets:insert(?TAB, #wh_amqp_connections{connection=Connection
                                              ,connection_ref=Ref
                                              ,broker=Broker
                                              ,zone=Zone
                                              ,tags=Tags
                                              ,hidden=is_hidden_broker(Tags)
                                             }),
    {'noreply', State, 'hibernate'};
handle_cast({'connection_available', Connection}, State) ->
    lager:debug("connection ~p is now available", [Connection]),
    Props = [{#wh_amqp_connections.available, 'true'}],
    _ = ets:update_element(?TAB, Connection, Props),
    {'noreply', notify_watchers(State), 'hibernate'};
handle_cast({'connection_unavailable', Connection}, State) ->
    lager:warning("connection ~p is no longer available", [Connection]),
    Props = [{#wh_amqp_connections.available, 'false'}],
    _ = ets:update_element(?TAB, Connection, Props),
    {'noreply', State, 'hibernate'};
handle_cast({'add_watcher', Watcher}, State) ->
    case is_available() of
        'false' -> {'noreply', add_watcher(Watcher, State), 'hibernate'};
        'true' ->
            _ = notify_watcher(Watcher),
            {'noreply', State, 'hibernate'}
    end;
handle_cast(_Msg, State) ->
    {'noreply', State, 'hibernate'}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {'noreply', State} |
%%                                   {'noreply', State, Timeout} |
%%                                   {'stop', Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info({'DOWN', Ref, 'process', Connection, _Reason}, State) ->
    lager:warning("connection ~p went down: ~p"
                  ,[Connection, _Reason]),
    erlang:demonitor(Ref, ['flush']),
    _ = ets:delete(?TAB, Connection),
    {'noreply', State, 'hibernate'};
handle_info(_Info, State) ->
    lager:debug("unhandled message: ~p", [_Info]),
    {'noreply', State, 'hibernate'}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    lager:debug("AMQP connections terminating: ~p", [_Reason]).

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {'ok', State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
%%--------------------------------------------------------------------
%% @private
%% @doc
%%
%% @end
%%--------------------------------------------------------------------
-spec add_watcher(pid(), state()) -> state().
add_watcher(Watcher, #state{watchers=Watchers}=State) ->
    State#state{watchers=sets:add_element(Watcher, Watchers)}.

-spec notify_watchers(state()) -> state().
notify_watchers(#state{watchers=[]}=State) ->
    State#state{watchers=sets:new()};
notify_watchers(#state{watchers=[Watcher|Watchers]}=State) ->
    _ = notify_watcher(Watcher),
    notify_watchers(State#state{watchers=Watchers});
notify_watchers(#state{watchers=Watchers}=State) ->
    notify_watchers(State#state{watchers=sets:to_list(Watchers)}).

-spec notify_watcher(pid()) -> any().
notify_watcher(Watcher) ->
    Watcher ! {'wh_amqp_connections', 'connection_available'}.

-spec wait_for_notification(wh_timeout()) ->
                                   'ok' |
                                   {'error', 'timeout'}.
wait_for_notification(Timeout) ->
    receive
        {'wh_amqp_connections', 'connection_available'} -> 'ok'
    after
        Timeout -> {'error', 'timeout'}
    end.

-spec brokers_with_tag(ne_binary()) -> list().
-spec brokers_with_tag(ne_binary(), api_boolean()) -> list().

brokers_with_tag(Tag) ->
    brokers_with_tag(Tag, 'undefined').

brokers_with_tag(Tag, Available) ->
    MatchSpec = [{#wh_amqp_connections{available='$1'
                                       ,_='_'
                                      },
                  [{'orelse',
                        {'=:=', '$1', {'const', Available}},
                        {'=:=', {'const', Available}, 'undefined'}
                   }
                  ]
                 ,['$_']
                 }
                ],
    lists:foldr(fun(A, Acc) -> broker_filter(Tag, Acc, A) end, [], ets:select(?TAB, MatchSpec)).

-spec broker_filter(ne_binary(), list(), wh_amqp_connections() ) -> list().
broker_filter(Tag, Acc, #wh_amqp_connections{tags=Tags
                                             ,broker=Broker
                                            }) ->
    case lists:member(Tag,Tags) of
        'true' -> [Broker | Acc];
        'false' -> Acc
    end.
        
-spec broker_with_tag(ne_binary()) -> api_binary().
broker_with_tag(Tag) ->
    case brokers_with_tag(Tag, 'true') of
        [] -> 'undefined';
        [Broker|_] -> Broker
    end.

-spec brokers_for_zone(atom()) -> list().
-spec brokers_for_zone(atom(), api_boolean()) -> list().

brokers_for_zone(Zone) ->
    brokers_for_zone(Zone, 'undefined').

brokers_for_zone(Zone, Available) ->
    MatchSpec = [{#wh_amqp_connections{zone='$1'
                                       ,broker='$2'
                                       ,available='$3'
                                       ,_='_'
                                      },
                  [{'andalso',
                     {'=:=', '$1', {'const', Zone}},
                     {'orelse',
                        {'=:=', '$3', {'const', Available}},
                        {'=:=', {'const', Available}, 'undefined'}
                     }
                   }
                  ],
                  ['$2']
                 }
                ],
    [Broker || Broker <- ets:select(?TAB, MatchSpec)].

-spec broker_for_zone(atom()) -> api_binary().
broker_for_zone(Zone) ->
    case brokers_for_zone(Zone, 'true') of
        [] -> 'undefined';
        [Broker|_] -> Broker
    end.

-spec is_zone_available(atom()) -> boolean().
is_zone_available(Zone) -> broker_for_zone(Zone) =/= 'undefined'.

-spec is_tag_available(ne_binary()) -> boolean().
is_tag_available(Tag) -> broker_with_tag(Tag) =/= 'undefined'.

-spec is_hidden_broker(list()) -> boolean().
is_hidden_broker(Tags) -> lists:member(?AMQP_HIDDEN_TAG, Tags).
