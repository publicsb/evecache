-module(req_handler).

-compile(export_all).
-include_lib("xmerl/include/xmerl.hrl").
-include("configure.hrl").

init(_Type, Req, []) ->
	{ok, Req, undefined}.

handle(Req, Opts) ->
	{Path,_} = cowboy_req:path(Req),
	LPath = binary_to_list(Path),
	Length = length(LPath),
	Key = key(LPath, Length),
	case find_key(Key) of
		<<>> ->
			case send_req(LPath) of
				{ok, Body}->
					cache(LPath, Body, Length),
				    {ok, Req2} = cowboy_req:reply(200, [{<<"content-type">>, <<"text/xml">>}], Body, Req),
				    {ok, Req2, Opts};
				{error, Code, Body}->
				    {ok, Req2} = cowboy_req:reply(Code, [{<<"content-type">>, <<"text/html">>}], Body, Req),
				    {ok, Req2, Opts}
			end;
		Body when is_binary(Body) ->
			{ok, Req2} = cowboy_req:reply(200, [{<<"content-type">>, <<"text/xml">>}], Body, Req),
			{ok, Req2, Opts}
	end.

terminate(_Reason, _Req, _State) ->
	ok.

send_req(Path) when is_list(Path)->
	{ok, {{_, Code, _}, _, Body}} = httpc:request(get,{?API_SERVER++Path, []},[],[{body_format, binary}]),
	case Code of
		200->
			{ok, Body};
		_->
			{error, Code, Body}
	end;
send_req(Path)->
	io:format("~p~n", [Path]).


find_key(Key)->
	erlmc:get(Key).

cache(Req,Response) when is_binary(Req)->
	cache(Req,Response,length(binary_to_list(Req)));
cache(Req,Response) when is_list(Req)->
	cache(list_to_binary(Req),Response,length(Req)).
cache(Req,Response,Length) when is_binary(Response)->
	Key = key(Req, Length),
	{Xml, _} = xmerl_scan:string(binary:bin_to_list(Response)),
	CacheUntil = val(xmerl_xpath:string("//cachedUntil", Xml)),
	{ok, [Y,M,D,H,Mm,S],_} = io_lib:fread("~d-~d-~d ~d:~d:~d", CacheUntil),
	TimeStamp = calendar:datetime_to_gregorian_seconds({{Y,M,D},{H,Mm,S}})-62167219200,
	erlmc:set(Key, Response, TimeStamp).

val(X) ->
    [#xmlElement{content = [#xmlText{value = V}|_]}] = X,
    V.

key(Req) when is_binary(Req)->
	key(Req, length(binary_to_list(Req)));
key(Req) when is_list(Req)->
	key(list_to_binary(Req), length(Req)).
key(Req, Length)->
	if
		Length < ?HASH_LENGTH ->  %% use req as key
			Req;
		true->  %% use hash of req as key
			crypto:hash(?HASH, Req)
	end.