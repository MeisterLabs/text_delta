defmodule TextDelta.ApplicationTest do
  use ExUnit.Case

  doctest TextDelta.Application

  @state TextDelta.insert(TextDelta.new(), "test")

  describe "apply" do
    test "insert delta" do
      delta =
        TextDelta.new()
        |> TextDelta.insert("hi")

      assert TextDelta.apply(@state, delta) ==
               {:ok, TextDelta.compose(@state, delta)}
    end

    test "insert delta outside original text length" do
      delta =
        TextDelta.new()
        |> TextDelta.insert("this is a ")

      assert TextDelta.apply(@state, delta) ==
               {:ok, TextDelta.compose(@state, delta)}
    end

    test "remove delta within original text length" do
      delta =
        TextDelta.new()
        |> TextDelta.delete(3)

      assert TextDelta.apply(@state, delta) ==
               {:ok, TextDelta.compose(@state, delta)}
    end

    test "remove delta outside original text length" do
      delta =
        TextDelta.new()
        |> TextDelta.delete(5)

      assert TextDelta.apply(@state, delta) == {:error, :length_mismatch}
    end

    test "retain delta within original text length" do
      delta =
        TextDelta.new()
        |> TextDelta.retain(3)

      assert TextDelta.apply(@state, delta) ==
               {:ok, TextDelta.compose(@state, delta)}
    end

    test "retain delta outside original text length" do
      delta =
        TextDelta.new()
        |> TextDelta.retain(5)

      assert TextDelta.apply(@state, delta) == {:error, :length_mismatch}
    end
  end

  describe "apply!" do
    test "insert delta" do
      delta =
        TextDelta.new()
        |> TextDelta.insert("hi")

      assert TextDelta.apply!(@state, delta) == TextDelta.compose(@state, delta)
    end

    test "retain delta outside original text length" do
      delta =
        TextDelta.new()
        |> TextDelta.retain(5)

      assert_raise RuntimeError, fn ->
        TextDelta.apply!(@state, delta)
      end
    end
  end
end
