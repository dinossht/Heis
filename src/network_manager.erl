-module(network_manager).
-export([start/0]).

-define(UDP_RECV_PORT, 8888).
-define(UDP_BCAST_PORT, 8889).
-define(SEEK_PERIOD, 2000).

%register(shell, self()) // ckeck Tharaldyo
%{PID_functon, elevator@190.10.2.2} ! [Message}.
%receive {[Message]} -> %Do something with the message.
%register(nameman, spawn(fun() -> name_manager(Node_name) end)),

start() ->
  node_init("master"),

  spawn(fun() -> udp_receive() end),
  spawn(fun() -> udp_broadcast() end),

  timer:sleep(1000000).

udp_receive() ->
  {ok, Socket} = gen_udp:open(?UDP_RECV_PORT,[list,{active, false}]),
  udp_receive(Socket).
udp_receive(Socket) ->
  {ok,{_Address, _Port, Node_name}} = gen_udp:recv(Socket, 0),
  Node = list_to_atom(Node_name),
  io:fwrite(Node_name),
  case is_in_cluster(Node) of
    true ->
      udp_receive(Socket),
      io:fwrite("Node already in cluster\n");
    false ->
      io:fwrite("A new node is detected, try add to cluster\n"),
      add_to_node(Node),
      udp_receive(Socket)
  end.

udp_broadcast() ->
  {ok, Socket} = gen_udp:open(?UDP_BCAST_PORT),
  udp_broadcast(Socket).
udp_broadcast(Socket) ->
  Node_name = atom_to_list(node()),
  io:fwrite("This node is: "++Node_name++"\n"),
  gen_udp:send(Socket, {255,255,255,255}, ?UDP_RECV_PORT, Node_name),
  timer:sleep(?SEEK_PERIOD),
  udp_broadcast(Socket).


add_to_node(Node) ->
  net_adm:ping(Node).

is_in_cluster(Node) ->
  Node_list = [node()|nodes()],
  lists:member(Node, Node_list).

node_init(Node_type_list) ->
  os:cmd("epmd -daemon"), % start epmd as daemon in case it's not running
  timer:sleep(100), % give epmd some time to start
  %% Generate node name %%
  {ok, [{IP_tuple,_,_}|_]} = inet:getif(),

  %% Initialize node with "password protection" %%
  Node_name = Node_type_list++"@"++integer_to_list(element(1,IP_tuple))++"."++integer_to_list(element(2, IP_tuple))++"."++integer_to_list(element(3, IP_tuple))++"."++integer_to_list(element(4, IP_tuple)),

  %register(nameman, spawn(fun() -> name_manager(Node_name) end)),
  net_kernel:start([list_to_atom(Node_name), longnames]),
  erlang:set_cookie(node(), 'robert-og-dino').

name_manager(Node_name) ->
  receive {get_name, PID} ->
    PID ! {node_name, Node_name}
  end,
  name_manager(Node_name).

