defmodule Slacker.Matcher do
  @moduledoc """
  Provides a DSL for matching incoming messages.
  """

  defmacro __using__(_opts) do
    quote do
      @command_patterns []
      @match_patterns []
      Module.register_attribute(__MODULE__, :command_patterns, accumulate: true)
      Module.register_attribute(__MODULE__, :match_patterns, accumulate: true)

      import unquote(__MODULE__), only: [command: 2, match: 2]

      @before_compile unquote(__MODULE__)

      @doc """
      Tries to find a command in any incoming message direct message.
      """
      def handle_cast({:handle_incoming, "message", %{"channel" => "D" <> _, "text" => _} = data}, state) do
        command!(self(), data)
        match!(self(), data)
        {:noreply, state}
      end

      @doc """
      Tries to match any incoming message with a text value.

      When a command is found, it dispatches the command. Otherwise, generic matches
      are looked for.
      """
      def handle_cast({:handle_incoming, "message", %{"text" => message} = data}, %{username: username} = state) do
        regex = ~r/^(?<bot>[[:alnum:][:punct:]@<>]*)\s+(?<command>\w+)(\s+(?<expression>.*)|)$/i
        match = Regex.named_captures(regex, message)

        if match do
          case match do
            %{"bot" => username} ->
              command!(self(), Map.put(data, "text", match["command"] <> match["expression"]))
          end
        end

        match!(self(), data)
        {:noreply, state}
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @doc """
      Tries to match against the command regular expressions/
      """
      def command!(slacker, %{"text" => text} = data) do
        Enum.each(@command_patterns, fn {pattern, [module, function]} ->
          match = Regex.named_captures(pattern, text)

          if match do
            apply(module, function, [slacker, data, match])
          end
        end)
      end

      @doc """
      Matches against the regular expressesion defined with the `match` macro.
      """
      def match!(slacker, %{"text" => text} = msg) do
        Enum.each(@match_patterns, fn {pattern, [module, function]} ->
          match = Regex.run(pattern, text)
          if match do
            [_text | captures] = match
            apply(module, function, [slacker, msg] ++ captures)
          end
        end)
      end
    end
  end

  @doc """
  Defines a patterns to match messages and the function to perform on match.
  """
  defmacro command(pattern, function) do
    [module, function] =
      case function do
        function when is_atom(function) -> [__CALLER__.module, function]
        [module, function] -> [module, function]
      end

    quote do
      if is_binary(unquote(pattern)) do
        def command!(slacker, %{"text" => unquote(pattern)} = data) do
          apply(unquote(module), unquote(function), [slacker, data])
        end
      else
        @command_patterns {unquote(pattern), [unquote(module), unquote(function)]}
      end
    end
  end

  @doc """
  Defines a patterns to match messages and the function to perform on match.
  """
  defmacro match(pattern, function) do
    [module, function] =
      case function do
        function when is_atom(function) -> [__CALLER__.module, function]
        [module, function] -> [module, function]
      end

    quote do
      if is_binary(unquote(pattern)) do
        def match!(slacker, %{"text" => unquote(pattern)} = msg) do
          apply(unquote(module), unquote(function), [slacker, msg])
        end
      else
        @match_patterns {unquote(pattern), [unquote(module), unquote(function)]}
      end
    end
  end
end
