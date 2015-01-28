all:
	./rebar get-deps && ./rebar compile

run:
	ERL_LIBS=deps erl +K true -name eve_cache@127.0.0.1 -boot start_sasl -pa ebin -s eve_cache_app -sasl errlog_type error

clean:
	./rebar clean
