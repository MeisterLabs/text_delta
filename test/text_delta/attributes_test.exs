defmodule TextDelta.AttributesTest do
  use ExUnit.Case
  alias TextDelta.Attributes

  doctest TextDelta.Attributes

  describe "compose" do
    @attributes %{bold: true, color: "red"}

    test "from nothing" do
      assert Attributes.compose(%{}, @attributes) == @attributes
    end

    test "to nothing" do
      assert Attributes.compose(@attributes, %{}) == @attributes
    end

    test "nothing with nothing" do
      assert Attributes.compose(%{}, %{}) == %{}
    end

    test "with new attribute" do
      assert Attributes.compose(@attributes, %{italic: true}) == %{
               bold: true,
               italic: true,
               color: "red"
             }
    end

    test "with overwriten attribute" do
      assert Attributes.compose(@attributes, %{bold: false, color: "blue"}) ==
               %{
                 bold: false,
                 color: "blue"
               }
    end

    test "with attribute removed" do
      assert Attributes.compose(@attributes, %{bold: nil}) == %{color: "red"}
    end

    test "with all attributes removed" do
      assert Attributes.compose(@attributes, %{bold: nil, color: nil}) == %{}
    end

    test "with removal of inexistent element" do
      assert Attributes.compose(@attributes, %{italic: nil}) == @attributes
    end

    test "string-keyed attributes" do
      attrs_a = %{"bold" => true, "color" => "red"}
      attrs_b = %{"italic" => true, "color" => "blue"}
      composed = %{"bold" => true, "color" => "blue", "italic" => true}
      assert Attributes.compose(attrs_a, attrs_b) == composed
    end

    test "nested delta attributes" do
      delta_a =
        TextDelta.new()
        |> TextDelta.insert(%{block: "one"}, %{
          two:
            TextDelta.new()
            |> TextDelta.insert("three")
        })

      delta_b =
        TextDelta.new()
        |> TextDelta.retain(1, %{
          two:
            TextDelta.new()
            |> TextDelta.retain(5)
            |> TextDelta.insert(" six")
        })

      delta_c =
        TextDelta.new()
        |> TextDelta.insert(%{block: "one"}, %{
          two:
            TextDelta.new()
            |> TextDelta.insert("three six")
            |> Map.from_struct()
        })

      composition = TextDelta.compose(delta_a, delta_b)

      assert composition == delta_c
    end

    test "empty delta" do
      delta_a =
        TextDelta.new()
        |> TextDelta.insert(%{block: "one"}, %{
          two:
            TextDelta.new()
            |> TextDelta.insert("three")
        })

      delta_b =
        TextDelta.new()
        |> TextDelta.retain(1, %{
          two: TextDelta.new()
        })

      expected_composition =
        TextDelta.new()
        |> TextDelta.insert(%{block: "one"}, %{
          two:
            TextDelta.new()
            |> TextDelta.insert("three")
            |> Map.from_struct()
        })

      composition = TextDelta.compose(delta_a, delta_b)

      assert composition == expected_composition
    end
  end

  describe "transform" do
    @lft %{bold: true, color: "red", font: nil}
    @rgt %{color: "blue", font: "serif", italic: true}

    test "from nothing" do
      assert Attributes.transform(%{}, @rgt, :right) == @rgt
    end

    test "to nothing" do
      assert Attributes.transform(@lft, %{}, :right) == %{}
    end

    test "nothing to nothing" do
      assert Attributes.transform(%{}, %{}, :right) == %{}
    end

    test "left to right with priority" do
      assert Attributes.transform(@lft, @rgt, :left) == %{italic: true}
    end

    test "left to right without priority" do
      assert Attributes.transform(@lft, @rgt, :right) == @rgt
    end

    test "string-keyed attributes" do
      attrs_a = %{"bold" => true, "color" => "red", "font" => nil}
      attrs_b = %{"color" => "blue", "font" => "serif", "italic" => true}

      assert Attributes.transform(attrs_a, attrs_b, :left) == %{
               "italic" => true
             }

      assert Attributes.transform(attrs_a, attrs_b, :right) == attrs_b
    end

    test "nested delta attributes" do
      delta_a =
        TextDelta.new()
        |> TextDelta.retain(1, %{
          two:
            TextDelta.new()
            |> TextDelta.insert("one")
        })

      delta_b =
        TextDelta.new()
        |> TextDelta.retain(1, %{
          two:
            TextDelta.new()
            |> TextDelta.insert("two")
        })

      expected_left =
        TextDelta.new()
        |> TextDelta.retain(1, %{
          two:
            TextDelta.new()
            |> TextDelta.retain(3)
            |> TextDelta.insert("one")
            |> Map.from_struct()
        })

      expected_right =
        TextDelta.new()
        |> TextDelta.retain(1, %{
          two:
            TextDelta.new()
            |> TextDelta.insert("one")
            |> Map.from_struct()
        })

      transform_left = TextDelta.transform(delta_b, delta_a, :left)
      transform_right = TextDelta.transform(delta_b, delta_a, :right)

      assert transform_left == expected_left
      assert transform_right == expected_right
    end

    test "empty delta - insert/retain" do
      delta_a =
        TextDelta.new()
        |> TextDelta.insert(%{block: "one"}, %{
          two: TextDelta.new() |> TextDelta.insert("three")
        })

      delta_b =
        TextDelta.new()
        |> TextDelta.retain(1, %{
          two: TextDelta.new()
        })

      expected_transformation =
        TextDelta.new()
        |> TextDelta.insert(%{block: "one"}, %{
          two:
            TextDelta.new()
            |> TextDelta.insert("three")
        })

      transfomation = TextDelta.transform(delta_b, delta_a, :left)

      assert expected_transformation == transfomation
    end

    test "empty delta - retain/retain" do
      delta_a =
        TextDelta.new()
        |> TextDelta.retain(1, %{
          two: TextDelta.new() |> TextDelta.insert("three")
        })

      delta_b =
        TextDelta.new()
        |> TextDelta.retain(1, %{
          two: TextDelta.new()
        })

      expected_transformation =
        TextDelta.new()
        |> TextDelta.retain(1, %{
          two:
            TextDelta.new()
            |> TextDelta.insert("three")
            |> Map.from_struct()
        })

      transfomation = TextDelta.transform(delta_b, delta_a, :left)

      assert expected_transformation == transfomation
    end
  end

  describe "diff" do
    @attributes %{bold: true, color: "red"}

    test "nothing with attributes" do
      assert Attributes.diff(%{}, @attributes) == @attributes
    end

    test "attributes with nothing" do
      assert Attributes.diff(@attributes, %{}) == %{bold: nil, color: nil}
    end

    test "same attributes" do
      assert Attributes.diff(@attributes, @attributes) == %{}
    end

    test "with added attribute" do
      assert Attributes.diff(@attributes, %{
               bold: true,
               color: "red",
               italic: true
             }) == %{
               italic: true
             }
    end

    test "with removed attribute" do
      assert Attributes.diff(@attributes, %{bold: true}) == %{color: nil}
    end

    test "with overwriten attribute" do
      assert Attributes.diff(@attributes, %{bold: true, color: "blue"}) == %{
               color: "blue"
             }
    end

    test "nested delta attributes" do
      delta_a =
        TextDelta.new()
        |> TextDelta.insert(%{block: "one"}, %{
          foo: true,
          two:
            TextDelta.new()
            |> TextDelta.insert("three")
        })

      delta_b =
        TextDelta.new()
        |> TextDelta.insert(%{block: "one"}, %{
          foo: false,
          two:
            TextDelta.new()
            |> TextDelta.insert("three")
        })

      expected_diff =
        TextDelta.new()
        |> TextDelta.retain(1, %{
          foo: false
        })

      diff = TextDelta.diff!(delta_a, delta_b)

      assert diff == expected_diff
    end

    test "empty delta" do
      delta_a =
        TextDelta.new()
        |> TextDelta.insert(%{block: "one"}, %{
          foo: true,
          two:
            TextDelta.new()
            |> TextDelta.insert("three")
        })

      delta_b =
        TextDelta.new()
        |> TextDelta.insert(
          %{block: "one"},
          %{
            foo: false,
            two: TextDelta.new() |> TextDelta.insert("three")
          }
        )

      delta_c =
        TextDelta.new()
        |> TextDelta.retain(1, %{
          foo: false
        })

      diff = TextDelta.diff!(delta_a, delta_b)

      assert diff == delta_c
    end
  end
end
