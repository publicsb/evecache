-module(eve_cache_app).

-behaviour(application).

%% Application callbacks
-export([start/0, start/2, stop/1]).
-include("configure.hrl").

%% ===================================================================
%% Application callbacks
%% ===================================================================


start()->
	application:start(eve_cache).

start(_StartType, _StartArgs) ->
	inets:start(),
	ssl:start(),
	erlmc:start(),
	application:start(crypto),
	application:start(cowlib),
	application:start(ranch),
	Routes = [
		{"/favicon.ico", cowboy_static, {file, "favicon.ico"}},
    	{'_', req_handler, []}
	],
	
	Dispatch = cowboy_router:compile([
		{'_', Routes}
	]),
	HTTPPort = ?PORT,
	ProtoOpts = [{dispatch, Dispatch},{max_keepalive,4096}],
	ok = application:start(cowboy),

	{ok, _} = cowboy:start_http(http, 100, [{port, HTTPPort}], [
		{env, ProtoOpts}
	]),
	eve_cache_sup:start_link().

stop(_State) ->
	erlmc:stop(),
    ok.
