defmodule TextDelta.TransformationTest do
  use ExUnit.Case

  describe "transform" do
    test "insert against insert" do
      first =
        TextDelta.new()
        |> TextDelta.insert("A")

      second =
        TextDelta.new()
        |> TextDelta.insert("B")

      transformed_left =
        TextDelta.new()
        |> TextDelta.retain(1)
        |> TextDelta.insert("B")

      transformed_right =
        TextDelta.new()
        |> TextDelta.insert("B")

      assert TextDelta.transform(first, second, :left) == transformed_left
      assert TextDelta.transform(first, second, :right) == transformed_right
    end

    test "retain against insert" do
      first =
        TextDelta.new()
        |> TextDelta.insert("A")

      second =
        TextDelta.new()
        |> TextDelta.retain(1, %{bold: true, color: "red"})

      transformed =
        TextDelta.new()
        |> TextDelta.retain(1)
        |> TextDelta.retain(1, %{bold: true, color: "red"})

      assert TextDelta.transform(first, second, :left) == transformed
    end

    test "delete against insert" do
      first =
        TextDelta.new()
        |> TextDelta.insert("A")

      second =
        TextDelta.new()
        |> TextDelta.delete(1)

      transformed =
        TextDelta.new()
        |> TextDelta.retain(1)
        |> TextDelta.delete(1)

      assert TextDelta.transform(first, second, :left) == transformed
    end

    test "insert against delete" do
      first =
        TextDelta.new()
        |> TextDelta.delete(1)

      second =
        TextDelta.new()
        |> TextDelta.insert("B")

      transformed =
        TextDelta.new()
        |> TextDelta.insert("B")

      assert TextDelta.transform(first, second, :left) == transformed
    end

    test "retain against delete" do
      first =
        TextDelta.new()
        |> TextDelta.delete(1)

      second =
        TextDelta.new()
        |> TextDelta.retain(1, %{bold: true, color: "red"})

      transformed = TextDelta.new()
      assert TextDelta.transform(first, second, :left) == transformed
    end

    test "delete against delete" do
      first =
        TextDelta.new()
        |> TextDelta.delete(1)

      second =
        TextDelta.new()
        |> TextDelta.delete(1)

      transformed = TextDelta.new()
      assert TextDelta.transform(first, second, :left) == transformed
    end

    test "insert against retain" do
      first =
        TextDelta.new()
        |> TextDelta.retain(1, %{color: "blue"})

      second =
        TextDelta.new()
        |> TextDelta.insert("B")

      transformed =
        TextDelta.new()
        |> TextDelta.insert("B")

      assert TextDelta.transform(first, second, :left) == transformed
    end

    test "retain against retain" do
      first =
        TextDelta.new()
        |> TextDelta.retain(1, %{color: "blue"})

      second =
        TextDelta.new()
        |> TextDelta.retain(1, %{bold: true, color: "red"})

      transformed_second =
        TextDelta.new()
        |> TextDelta.retain(1, %{bold: true})

      transformed_first = TextDelta.new()
      assert TextDelta.transform(first, second, :left) == transformed_second
      assert TextDelta.transform(second, first, :left) == transformed_first
    end

    test "retain against retain with right as priority" do
      first =
        TextDelta.new()
        |> TextDelta.retain(1, %{color: "blue"})

      second =
        TextDelta.new()
        |> TextDelta.retain(1, %{bold: true, color: "red"})

      transformed_second =
        TextDelta.new()
        |> TextDelta.retain(1, %{bold: true, color: "red"})

      transformed_first =
        TextDelta.new()
        |> TextDelta.retain(1, %{color: "blue"})

      assert TextDelta.transform(first, second, :right) == transformed_second
      assert TextDelta.transform(second, first, :right) == transformed_first
    end

    test "delete against retain" do
      first =
        TextDelta.new()
        |> TextDelta.retain(1, %{color: "blue"})

      second =
        TextDelta.new()
        |> TextDelta.delete(1)

      transformed =
        TextDelta.new()
        |> TextDelta.delete(1)

      assert TextDelta.transform(first, second, :left) == transformed
    end

    test "alternating edits" do
      first =
        TextDelta.new()
        |> TextDelta.retain(2)
        |> TextDelta.insert("si")
        |> TextDelta.delete(5)

      second =
        TextDelta.new()
        |> TextDelta.retain(1)
        |> TextDelta.insert("e")
        |> TextDelta.delete(5)
        |> TextDelta.retain(1)
        |> TextDelta.insert("ow")

      transformed_second =
        TextDelta.new()
        |> TextDelta.retain(1)
        |> TextDelta.insert("e")
        |> TextDelta.delete(1)
        |> TextDelta.retain(2)
        |> TextDelta.insert("ow")

      transformed_first =
        TextDelta.new()
        |> TextDelta.retain(2)
        |> TextDelta.insert("si")
        |> TextDelta.delete(1)

      assert TextDelta.transform(first, second, :right) == transformed_second
      assert TextDelta.transform(second, first, :right) == transformed_first
    end

    test "conflicting appends" do
      first =
        TextDelta.new()
        |> TextDelta.retain(3)
        |> TextDelta.insert("aa")

      second =
        TextDelta.new()
        |> TextDelta.retain(3)
        |> TextDelta.insert("bb")

      transformed_second_with_left_priority =
        TextDelta.new()
        |> TextDelta.retain(5)
        |> TextDelta.insert("bb")

      transformed_first_with_right_priority =
        TextDelta.new()
        |> TextDelta.retain(3)
        |> TextDelta.insert("aa")

      assert TextDelta.transform(first, second, :left) ==
               transformed_second_with_left_priority

      assert TextDelta.transform(second, first, :right) ==
               transformed_first_with_right_priority
    end

    test "prepend and append" do
      first =
        TextDelta.new()
        |> TextDelta.insert("aa")

      second =
        TextDelta.new()
        |> TextDelta.retain(3)
        |> TextDelta.insert("bb")

      transformed_second =
        TextDelta.new()
        |> TextDelta.retain(5)
        |> TextDelta.insert("bb")

      transformed_first =
        TextDelta.new()
        |> TextDelta.insert("aa")

      assert TextDelta.transform(first, second, :right) == transformed_second
      assert TextDelta.transform(second, first, :right) == transformed_first
    end

    test "trailing deletes with differing lengths" do
      first =
        TextDelta.new()
        |> TextDelta.retain(2)
        |> TextDelta.delete(1)

      second =
        TextDelta.new()
        |> TextDelta.delete(3)

      transformed_second =
        TextDelta.new()
        |> TextDelta.delete(2)

      transformed_first = TextDelta.new()
      assert TextDelta.transform(first, second, :right) == transformed_second
      assert TextDelta.transform(second, first, :right) == transformed_first
    end
  end
end
