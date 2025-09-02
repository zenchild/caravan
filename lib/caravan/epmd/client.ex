defmodule Caravan.Epmd.Client do
  @moduledoc """
  Implementation of the `epmd` client logic. Meant for use with the `-epmd_module`
  flag

  Since OTP 20, you can now set the `ERL_DIST_PORT` environment variable to
  specify the port to use for distribution. Coupled with a service mesh like
  Consul, this allows you to run a different ports for OTP clustering instead of
  having to choose a static port. This code does all of the work to connect to
  epmd and register the node with the correct port.
  """

  # The distribution protocol version number has been 5 ever since Erlang/OTP R6.
  @distro_version 5

  @doc """
  erl_distribution wants us to start a worker process. We don't need one,
  though.

  Returns :ignore
  """
  def start_link do
    :ignore
  end

  @doc """
  See: https://www.erlang.org/doc/apps/kernel/erl_epmd.html#register_node/3

  As of Erlang/OTP 19.1, register_node/3 is used instead of register_node/2,
  passing along the address family, 'inet_tcp' or 'inet6_tcp'. This makes no
  difference for our purposes.
  """
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

  @doc """
  See: https://www.erlang.org/doc/apps/kernel/erl_epmd.html#address_please/3

  This is using optimized version of this function that also returns the port
  and version. This will ensure that we don't need to also call port_please/3.
  """
  def address_please(name, host, _address_family) do
    my_node = node() |> to_string() |> String.replace("@", ".")
    target_node = "#{name}.#{host}"

    if String.match?(my_node, ~r/^((rpc|rem)-.*-)?#{target_node}$/) do
      {:ok, {127, 0, 0, 1}, local_dist_port(), @distro_version}
    else
      {address, service_port} = get_remote_ip_and_port(target_node)
      {:ok, address, service_port, @distro_version}
    end
  end

  def listen_port_please(name, _host) do
    if String.match?(to_string(name), ~r/^(rpc|rem)-/) do
      {:ok, 0}
    else
      {:ok, local_dist_port()}
    end
  end

  @doc """
  See: https://www.erlang.org/doc/apps/kernel/erl_epmd.html#names/1

  We are not implementing this because we are not running epmd.
  """
  def names(_hostname) do
    {:error, :address}
  end

  defp local_dist_port() do
    case System.get_env("ERL_DIST_PORT") do
      nil ->
        raise "ERL_DIST_PORT is not set"

      port ->
        String.to_integer(port)
    end
  end

  # Given a target node name, return the IP address and service port.
  # For Consul the target_node might look like "<node_name>.<service_name>.service.consul".
  # In this case, the EPMD node name is "<node_name>@<service_name>.service.consul"
  defp get_remote_ip_and_port(target_node) do
    target_node = String.to_charlist(target_node)

    # Get the IP Address
    {:ok, address} = :inet.getaddr(target_node, :inet)

    # Get the Service Port
    [{_, _, service_port, _host} | _rest] = :inet_res.lookup(target_node, :in, :srv)

    {address, service_port}
  end
end
