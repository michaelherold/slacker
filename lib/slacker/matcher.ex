defmodule Slacker.Matcher do
  @moduledoc """
  Provides a DSL for matching incoming messages.
  """

  defmacro __using__(_opts) do
    quote do
      @regex_patterns []
      Module.register_attribute(__MODULE__, :regex_patterns, accumulate: true)

      import unquote(__MODULE__), only: [match: 2]

      @before_compile unquote(__MODULE__)

      @doc """
      Tries to match any incoming message with a text value.
      """
      def handle_cast({:handle_incoming, "message", %{"text" => _} = msg}, state) do
        match!(self(), msg)
        {:noreply, state}
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @doc """
      Matches against the regular expressesion defined with the `match` macro.
      """
      def match!(slacker, %{"text" => text} = msg) do
        Enum.each(@regex_patterns, fn {pattern, [module, function]} ->
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
        @regex_patterns {unquote(pattern), [unquote(module), unquote(function)]}
      end
    end
  end
end
