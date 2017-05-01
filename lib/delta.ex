defmodule TextDelta.Delta do
  @moduledoc """
  Delta is a format used to describe documents and changes.

  Delta can describe any rich text changes or a rich document itself, preserving
  all the formatting.

  At the baseline level, delta is an array of operations (constructed via
  `TextDelta.Operation`). Operations can be either
  `t:TextDelta.Operation.insert/0`, `t:TextDelta.Operation.retain/0` or
  `t:TextDelta.Operation.delete/0`. None of the operations contain index,
  meaning that delta aways describes document or a change staring from the very
  beginning.

  Delta can describe both changes to and documents themselves. We can think of a
  document as an artefact of all the changes applied to it. This way, newly
  imported document can be thinked of as simply a sequence of `insert`s applied
  to an empty document.

  Deltas are composable. This means that a document delta can be composed with
  another delta for that document, resulting in a shorter, optimized delta.

  Deltas are also transformable. This attribute of deltas is what enables
  [Operational Transformation][ot] - a way to transform one operation against
  the context of another one. Operational Transformation allows us to build
  optimistic, non-locking collaborative editors.

  The format for deltas was deliberately copied from [Quill][quill] - a rich
  text editor for web. This library aims to be an Elixir counter-part for Quill,
  enabling us to build matching backends for the editor.

  ## Example

      iex> alias TextDelta.Delta
      iex> delta = Delta.new() |> Delta.insert("Gandalf", %{bold: true})
      [%{insert: "Gandalf", attributes: %{bold: true}}]
      iex> delta = delta |> Delta.insert(" the ")
      [%{insert: "Gandalf", attributes: %{bold: true}}, %{insert: " the "}]
      iex> delta |> Delta.insert("Grey", %{color: "#ccc"})
      [%{insert: "Gandalf", attributes: %{bold: true}}, %{insert: " the "},
       %{insert: "Grey", attributes: %{color: "#ccc"}}]

  [ot]: https://en.wikipedia.org/wiki/Operational_transformation
  [quill]: https://quilljs.com
  """

  alias TextDelta.{Operation, Attributes}
  alias TextDelta.Delta.{Composition, Transformation}

  @typedoc """
  Delta is a list of `t:TextDelta.Operation.retain/0`,
  `t:TextDelta.Operation.insert/0`, or `t:TextDelta.Operation.delete/0`
  operations.
  """
  @type t :: [Operation.t]

  @typedoc """
  A document represented as delta. Any rich document can be represented as a set
  of `t:TextDelta.Operation.insert/0` operations.
  """
  @type document :: [Operation.insert]

  @doc """
  Creates new delta.

  You can optionally pass list of operations. All of the operations will be
  properly appended and compacted.
  """
  @spec new([Operation.t]) :: t
  def new(ops \\ [])
  def new([]), do: []
  def new(ops), do: Enum.reduce(ops, new(), &append(&2, &1))

  @doc """
  Creates and appends new insert operation to the delta.

  Same as with underlying `TextDelta.Operation.insert/2` function, attributes
  are optional.

  `TextDelta.Delta.append/2` is used undert the hood to add operation to the
  delta after construction. So all `append` rules apply.

  ## Example

      iex> alias TextDelta.Delta
      iex> Delta.new() |> Delta.insert("hello", %{bold: true})
      [%{insert: "hello", attributes: %{bold: true}}]
  """
  @spec insert(t, Operation.element, Attributes.t) :: t
  def insert(delta, el, attrs \\ %{}) do
    append(delta, Operation.insert(el, attrs))
  end

  @doc """
  Creates and appends new retain operation to the delta.

  Same as with underlying `TextDelta.Operation.retain/2` function, attributes
  are optional.

  `TextDelta.Delta.append/2` is used undert the hood to add operation to the
  delta after construction. So all `append` rules apply.

  ## Example

      iex> alias TextDelta.Delta
      iex> Delta.new() |> Delta.retain(5, %{italic: true})
      [%{retain: 5, attributes: %{italic: true}}]
  """
  @spec retain(t, non_neg_integer, Attributes.t) :: t
  def retain(delta, len, attrs \\ %{}) do
    append(delta, Operation.retain(len, attrs))
  end

  @doc """
  Creates and appends new delete operation to the delta.

  `TextDelta.Delta.append/2` is used undert the hood to add operation to the
  delta after construction. So all `append` rules apply.

  ## Example

      iex> alias TextDelta.Delta
      iex> Delta.new() |> Delta.delete(3)
      [%{delete: 3}]
  """
  @spec delete(t, non_neg_integer) :: t
  def delete(delta, len) do
    append(delta, Operation.delete(len))
  end

  @doc """
  Appends given operation to the delta.

  Before adding operation to the delta, this function attempts to compact it by
  applying 2 simple rules:

  1. Delete followed by insert is swapped to ensure that insert goes first.
  2. Same operations with the same attributes are merged.

  These two rules ensure that our deltas are always as short as possible and
  canonical, making it easier to compare, compose and transform them.

  ## Example

      iex> operation = TextDelta.Operation.insert("hello")
      iex> TextDelta.Delta.new() |> TextDelta.Delta.append(operation)
      [%{insert: "hello"}]
  """
  @spec append(t, Operation.t) :: t
  def append(delta, op)
  def append(nil, op), do: append([], op)
  def append([], op), do: compact([], op)
  def append(delta, []), do: delta
  def append(delta, op) do
    delta
    |> Enum.reverse()
    |> compact(op)
    |> Enum.reverse()
  end

  defdelegate compose(delta_a, delta_b), to: Composition
  defdelegate transform(delta_a, delta_b, priority), to: Transformation

  @doc """
  Trims trailing retains from the end of a given delta.

  ## Example

      iex> [%{insert: "hello"}, %{retain: 5}] |> TextDelta.Delta.trim()
      [%{insert: "hello"}]
  """
  @spec trim(t) :: t
  def trim(delta)
  def trim([]), do: []
  def trim(delta) do
    last_operation = List.last(delta)
    case Operation.trimmable?(last_operation) do
      true ->
        delta
        |> Enum.slice(0..-2)
        |> trim()
      false ->
        delta
    end
  end

  @doc """
  Calculates the length of a given delta.

  Length of delta is a sum of its operations length.

  ## Example

      iex> [%{insert: "hello"}, %{retain: 5}] |> TextDelta.Delta.length()
      10

  The function also allows to select which types of operations we include in the
  summary with optional second argument:

      iex> [%{insert: "hi"}, %{retain: 5}] |> TextDelta.Delta.length([:retain])
      5
  """
  @spec length(t, [Operation.type]) :: non_neg_integer
  def length(delta, included_ops \\ [:insert, :retain, :delete]) do
    delta
    |> Enum.filter(&(Enum.member?(included_ops, Operation.type(&1))))
    |> Enum.map(&Operation.length/1)
    |> Enum.sum()
  end

  defp compact(delta, %{insert: ""}) do
    delta
  end

  defp compact(delta, %{retain: 0}) do
    delta
  end

  defp compact(delta, %{delete: 0}) do
    delta
  end

  defp compact(delta, []) do
    delta
  end

  defp compact(delta, nil) do
    delta
  end

  defp compact([], new_op) do
    [new_op]
  end

  defp compact([%{delete: _} = del | delta_remainder], %{insert: _} = ins) do
    compact(compact(delta_remainder, ins), del)
  end

  defp compact([last_op | delta_remainder], new_op) do
    last_op
    |> Operation.compact(new_op)
    |> Enum.reverse()
    |> Kernel.++(delta_remainder)
  end
end
