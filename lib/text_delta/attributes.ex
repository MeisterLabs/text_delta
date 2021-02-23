defmodule TextDelta.Attributes do
  @moduledoc """
  Attributes represent format associated with `t:TextDelta.Operation.insert/0`
  or `t:TextDelta.Operation.retain/0` operations. This library uses maps to
  represent attributes.

  Same as `TextDelta`, attributes are composable and transformable. This library
  does not make any assumptions about attribute types, values or composition.
  """

  @typedoc """
  A set of attributes applicable to an operation.
  """
  @type t :: map

  @typedoc """
  Atom representing transformation priority. Should we prioritise left or right
  side?
  """
  @type priority :: :left | :right

  @doc """
  Composes two sets of attributes into one.

  Simplest way to think about composing arguments is two maps being merged (in
  fact, that's exactly how it is implemented at the moment).

  The only thing that makes it different from standard map merge is an optional
  `keep_nils` flag. This flag controls if we want to cleanup all the `null`
  attributes before returning.

  This function is used by `TextDelta.compose/2`.

  ## Examples

      iex> TextDelta.Attributes.compose(%{color: "blue"}, %{italic: true})
      %{color: "blue", italic: true}

      iex> TextDelta.Attributes.compose(%{bold: true}, %{bold: nil}, true)
      %{bold: nil}

      iex> TextDelta.Attributes.compose(%{bold: true}, %{bold: nil}, false)
      %{}
  """
  @spec compose(t, t, boolean) :: t
  def compose(first, second, keep_nils \\ false)

  def compose(nil, second, keep_nils) do
    compose(%{}, second, keep_nils)
  end

  def compose(first, nil, keep_nils) do
    compose(first, %{}, keep_nils)
  end

  def compose(first, second, true) do
    Map.merge(first, second)
    |> Enum.map(fn {key, _} ->
      value_before = Map.get(first, key)
      value_after = Map.get(second, key)
      compose_attr(key, value_before, value_after, true)
    end)
  end

  def compose(first, second, false) do
    first
    |> Map.merge(second)
    |> Enum.map(fn {key, _} ->
      value_before = Map.get(first, key)
      value_after = Map.get(second, key)
      compose_attr(key, value_before, value_after, false)
    end)
    |> remove_nils()
  end

  defp compose_attr(
         key,
         %{ops: ops_before} = _value_before,
         %{ops: ops_after} = _value_after
       ) do
    delta_before = TextDelta.new(ops_before)
    delta_after = TextDelta.new(ops_after)

    delta_patch = TextDelta.compose(delta_before, delta_after)
    {key, delta_patch}
  end

  defp compose_attr(key, nil, value_after, _keep_nils), do: {key, value_after}
  defp compose_attr(key, value_before, nil, false), do: {key, value_before}
  defp compose_attr(key, _value_before, nil, true), do: {key, nil}
  defp compose_attr(key, _value_before, value_after, _keep_nils), do: {key, value_after}

  @doc """
  Calculates and returns difference between two sets of attributes.

  Given an initial set of attributes and the final one, this function will
  generate an attribute set that is when composed with original one would yield
  the final result.

  ## Examples

    iex> TextDelta.Attributes.diff(%{font: "arial", color: "blue"},
    iex>                           %{color: "red"})
    %{font: nil, color: "red"}
  """
  @spec diff(t, t) :: t
  def diff(attrs_a, attrs_b)

  def diff(attrs_a, attrs_b) do
    attributes_a_keys = Map.keys(attrs_a)
    attributes_b_keys = Map.keys(attrs_b)

    attributes_a_keys
    |> Enum.concat(attributes_b_keys)
    |> Enum.reduce(%{}, fn key, acc ->
      value_a = Map.get(attrs_a, key)
      value_b = Map.get(attrs_b, key)

      diff_attribute(value_a, value_b, key, acc)
    end)
  end

  defp diff_attribute(_attr_value_a, nil, key, result),
    do: Map.put(result, key, nil)

  defp diff_attribute(nil, attr_value_b, key, result),
    do: Map.put(result, key, attr_value_b)

  defp diff_attribute(%{ops: left_ops}, %{ops: right_ops}, key, result) do
    delta_left = TextDelta.new(left_ops)
    delta_right = TextDelta.new(right_ops)
    {:ok, ops} = TextDelta.diff(delta_left, delta_right)
    Map.put(result, key, ops)
  end

  defp diff_attribute(attr_value_a, attr_value_b, _key, result)
       when attr_value_a == attr_value_b,
       do: result

  defp diff_attribute(attr_value_a, attr_value_b, key, result)
       when attr_value_a != attr_value_b,
       do: Map.put(result, key, attr_value_b)

  @doc """
  Transforms `right` attribute set against the `left` one.

  The function also takes a third `t:TextDelta.Attributes.priority/0`
  argument that indicates which set came first.

  This function is used by `TextDelta.transform/3`.

  ## Example

      iex> TextDelta.Attributes.transform(%{italic: true},
      iex>                                %{bold: true}, :left)
      %{bold: true}
  """
  @spec transform(t, t, priority) :: t
  def transform(left, right, priority)

  def transform(nil, right, priority) do
    transform(%{}, right, priority)
  end

  def transform(left, nil, priority) do
    transform(left, %{}, priority)
  end

  def transform(left, right, priority) do
    transformed = transform_inner(left, right, priority)
    nested = transform_nested(left, right, priority)

    Map.merge(transformed, nested)
  end

  def transform_inner(_, right, :right) do
    right
  end

  def transform_inner(left, right, :left) do
    remove_duplicates(right, left)
  end

  def transform_nested(left, right, priority) do
    left_keys = Map.keys(left)
    right_keys = Map.keys(right)
    keys = Enum.uniq(left_keys ++ right_keys)

    keys = keys
    |> Enum.reduce(%{}, fn key, acc ->
      transform_nested_delta(acc, key, Map.get(left, key), Map.get(right, key), priority)
    end)
  end

  def transform_nested_delta(acc, key, %{ops: ops_left}, %{ops: ops_right}, priority) do
    delta_left = TextDelta.new(ops_left)
    delta_right = TextDelta.new(ops_right)
    delta = TextDelta.transform(delta_left, delta_right, priority)
    Map.put(acc, key, delta)
  end

  def transform_nested_delta(acc, _, _, _, _) do
    acc
  end

  defp add_changes(result, from, to) do
    to
    |> Enum.filter(fn {key, val} -> Map.get(from, key) != val end)
    |> Enum.into(%{})
    |> Map.merge(result)
  end

  defp add_deletions(result, from, to) do
    from
    |> Enum.filter(fn {key, _} -> not Map.has_key?(to, key) end)
    |> Enum.map(fn {key, _} -> {key, nil} end)
    |> Enum.into(%{})
    |> Map.merge(result)
  end

  defp remove_nils(result) do
    result
    |> Enum.filter(fn {_, v} -> not is_nil(v) end)
    |> Enum.into(%{})
  end

  defp remove_duplicates(attrs_a, attrs_b) do
    attrs_a
    |> Enum.filter(fn {key, _} -> not Map.has_key?(attrs_b, key) end)
    |> Enum.into(%{})
  end
end
