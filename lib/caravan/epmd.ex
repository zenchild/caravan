defmodule Caravan.Epmd do
  @moduledoc """
  Shared logic for determining the Erlang distribution port from the node name.
  """

  @default_listen_port 4370

  @doc """
  Returns the Erlang Distribution port based on a node name.

  ### Examples
      iex> Caravan.Epmd.dist_port(:"app-name3434@example.net")
      3434

      iex> Caravan.Epmd.dist_port(:"app-name-4834@example.net")
      4834

  """
  def dist_port(name) when is_atom(name) do
    name |> Atom.to_string() |> dist_port()
  end

  def dist_port(name) when is_list(name) do
    name |> List.to_string() |> dist_port()
  end

  def dist_port(name) when is_binary(name) do
    # The dist_port is the integer just to the left of the @ sign in our node
    # name.  If there is no such number, the port is 4370.
    #
    # Also handle the case when no hostname was specified.
    node_name = Regex.replace(~r/@.*$/, name, "")

    port =
      case Regex.run(~r/[0-9]+$/, node_name) do
        nil ->
          @default_listen_port

        [offset_as_string] ->
          String.to_integer(offset_as_string)
      end

    port
  end
end
