defmodule Slacker.MatcherTest do
  use ExUnit.Case

  defmodule Test do
    use Slacker.Matcher

    command "wat", :say_wat
    command ~r/what are we doing today (?<name>\w+)?/, :conquer_world
    match "hi", :say_hi
    match "hello", :say_hello
    match ~r/say hi to robot #([0-9]+)/, :say_hello
    match ~r/say bye to robot #([0-9]+)/, :say_goodbye

    def conquer_world(pid, _msg, %{"name" => name}) do
      send pid, "#{name}: the same thing we do every day"
    end

    def say_wat(pid, msg) do
      send pid, "#{msg["text"]} wat"
    end

    def say_hi(pid, msg) do
      send pid, "#{msg["text"]} there"
    end

    def say_hello(pid, msg) do
      send pid, "#{msg["text"]} again"
    end

    def say_hello(pid, _msg, robot_number) do
      send pid, "hello, robot #{robot_number}"
    end

    def say_goodbye(pid, _msg, robot_number) do
      send pid, "bye, robot #{robot_number}"
    end
  end

  test "command!/2 matches strings" do
    Test.command!(self(), %{"text" => "wat"})
    assert_receive "wat wat"
  end

  test "command!/3 matches regexes" do
    Test.command!(self(), %{"text" => "what are we doing today Brain?"})
    assert_receive "Brain: the same thing we do every day"
  end

  test "match!/2 matches strings" do
    Test.match!(self(), %{"text" => "hi"})
    assert_receive "hi there"

    Test.match!(self(), %{"text" => "hello"})
    assert_receive "hello again"
  end

  test "match!/3 matches regexes" do
    Test.match!(self(), %{"text" => "say hi to robot #123"})
    assert_receive "hello, robot 123"

    Test.match!(self(), %{"text" => "say bye to robot #123"})
    assert_receive "bye, robot 123"
  end
end
