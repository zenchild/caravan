defmodule Caravan.Epmd.Client do
  @moduledoc """
  Implementation of the `epmd` client logic. Meant for use with the `-epmd_module`
  flag

  It will return a port from `Caravan.Epmd.dist_port/1` as opposed to calling
  out to the `epmd` daemon and having it assign us one.

  If you are setting the `ERL_DIST_PORT` environment variable, you have the
  ability to run a different internal port from your external port.
  """
  alias Caravan.Epmd

  # erl_distribution wants us to start a worker process.  We don't
  # need one, though.
  def start_link do
    :ignore
  end

  # As of Erlang/OTP 19.1, register_node/3 is used instead of
  # register_node/2, passing along the address family, 'inet_tcp' or
  # 'inet6_tcp'.  This makes no difference for our purposes.
  def register_node(name, port, _family) do
    register_node(name, port)
  end

  def register_node(_name, _port) do
    # This is where we would connect to epmd and tell it which port
    # we're listening on, but since we're epmd-less, we don't do that.

    # Need to return a "creation" number between 1 and 3.
    creation = :rand.uniform(3)
    {:ok, creation}
  end

  def port_please(name, ip) do
    port =
      if ip == {127, 0, 0, 1} do
        local_dist_port(name)
      else
        Epmd.dist_port(name)
      end

    # The distribution protocol version number has been 5 ever since
    # Erlang/OTP R6.
    version = 5
    {:port, port, version}
  end

  # added for OTP-21
  def address_please(_name, host, _address_family) do
    my_node = node() |> to_string() |> String.split("@") |> List.last()
    service_host = to_string(host)

    if my_node == service_host do
      {:ok, {127, 0, 0, 1}}
    else
      :inet.getaddr(host, :inet)
    end
  end

  def listen_port_please(name, _host) do
    {:ok, port} =
      if String.match?(to_string(name), ~r/^(rpc|rem)-/) do
        {:ok, 0}
      else
        {:ok, local_dist_port(name)}
      end

    {:ok, port}
  end

  # ERL_DIST_PORT is available after OTP-23 and can be used to set the Dist
  # port. If this is being used, you don't need to set
  # `-proto_dist Caravan.Epmd.Dist`
  defp local_dist_port(name) do
    case System.get_env("ERL_DIST_PORT") do
      nil ->
        Epmd.dist_port(name)

      port ->
        String.to_integer(port)
    end
  end

  def names(_hostname) do
    # Since we don't have epmd, we don't really know what other nodes
    # there are.
    {:error, :address}
  end
end
