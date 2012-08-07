%%======================================================================
%%
%% Leo Commons
%%
%% Copyright (c) 2012 Rakuten, Inc.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% ---------------------------------------------------------------------
%% leo_http  - Utils for HTTP/S3-API
%% @doc
%% @end
%%======================================================================
-module(leo_http).

-author('Yoshiyuki Kanno').
-author('Yosuke Hara').

-export([key/2, key/3,
         get_headers/2, get_headers/3, get_amz_headers/1,
         rfc1123_date/1,web_date/1
        ]).

-include("leo_commons.hrl").
-include_lib("eunit/include/eunit.hrl").

%% @doc Retrieve a filename(KEY) from Host and Path.
%%
-spec(key(string(), string()) ->
             string()).
key(Host, Path) ->
    key([?S3_DEFAULT_ENDPOINT], Host, Path).

-spec(key(list(), string(), string()) ->
             string()).
key(EndPointList, Host, Path) ->
    EndPoint =
        case lists:foldl(fun(E, [] = Acc) ->
                                 case (string:str(Host, E) > 0) of
                                     true  -> [E|Acc];
                                     false -> Acc
                                 end;
                            (_, Acc) ->
                                 Acc
                         end, [], EndPointList) of
            [] -> [];
            [Value|_] -> Value
        end,
    key_1(EndPoint, Host, Path).


%% @doc Retrieve a filename(KEY) from Host and Pat.
%% @private
key_1(EndPoint, Host, Path) ->
    Index = string:str(Host, EndPoint),
    key_2(Index, Host, Path).


%% @doc "S3-Bucket" is a part of the host
%% @private
key_2(0, Host, Path) ->
    case string:tokens(Path, "/") of
        [] ->
            Host ++ "/";
        [Top|_] ->
            case string:equal(Host, Top) of
                true ->
                    "/" ++ Key = Path,
                    Key;
                false ->
                    Key = Host ++ Path,
                    Key
            end
    end;

%% @doc "S3-Bucket" is included in the path
%% @private
key_2(1,_Host, Path) ->
    case string:tokens(Path, "/") of
        [] ->
            "/";
        _ ->
            "/" ++ Key = Path,
            Key
    end;

%% @doc "S3-Bucket" is included in the host
%% @private
key_2(Index, Host, Path) ->
    Bucket = string:substr(Host, 1, Index - 2),
    Bucket ++ Path.


%% @doc Retrieve AMZ-S3-related headers
%%      assume that TreeHeaders is generated by mochiweb_header
%%
-spec(get_headers(list(), function()) ->
             list()).
get_headers(TreeHeaders, FilterFun) when is_function(FilterFun) ->
    Iter = gb_trees:iterator(TreeHeaders),
    get_headers(Iter, FilterFun, []).
get_headers(Iter, FilterFun, Acc) ->
    case gb_trees:next(Iter) of
        none ->
            Acc;
        {Key, Val, Iter2} ->
            case FilterFun(Key) of
                true ->  get_headers(Iter2, FilterFun, [Val|Acc]);
                false -> get_headers(Iter2, FilterFun, Acc)
            end
    end.


%% @doc Retrieve AMZ-S3-related headers
%%
-spec(get_amz_headers(list()) ->
             list()).
get_amz_headers(TreeHeaders) ->
    get_headers(TreeHeaders, fun is_amz_header/1).


%% @doc Retrieve RFC-1123 formated data
%%
-spec(rfc1123_date(string()) ->
             string()).
rfc1123_date(Date) ->
    httpd_util:rfc1123_date(
      calendar:universal_time_to_local_time(
        calendar:gregorian_seconds_to_datetime(Date))).

%% @doc Convert gregorian seconds to date formated data( YYYY-MM-DDTHH:MI:SS000Z )
%%
-spec(web_date(integer()) ->
             string()).
web_date(GregSec) when is_integer(GregSec) ->
    {{Y,M,D},{H,MI,S}} = calendar:gregorian_seconds_to_datetime(GregSec),
    lists:flatten(io_lib:format("~4.10.0B-~2.10.0B-~2.10.0BT~2.10.0B:~2.10.0B:~2.10.0B.000Z",[Y,M,D,H,MI,S])).

%%--------------------------------------------------------------------
%%% INTERNAL FUNCTIONS
%%--------------------------------------------------------------------
%% @doc Is it AMZ-S3's header?
%% @private
-spec(is_amz_header(string()) ->
             boolean()).
is_amz_header(Key) ->
    (string:str(string:to_lower(Key), "x-amz-") == 1).

