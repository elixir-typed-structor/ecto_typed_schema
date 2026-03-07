defmodule EctoTypedSchema.ChangesetExtractorTest do
  use ExUnit.Case, async: true
  alias EctoTypedSchema.ChangesetExtractor

  describe "extract/1" do
    test "extracts primitive field types" do
      body = [do: {:%{}, [], [name: :string, age: :integer]}]
      assert ChangesetExtractor.extract(body) == [name: :string, age: :integer]
    end

    test "extracts parameterized types" do
      body = [do: {:%{}, [], [status: {:parameterized, {Ecto.Enum, %{values: [:a]}}}]}]

      assert [{:status, {:parameterized, {Ecto.Enum, %{values: [:a]}}}}] =
               ChangesetExtractor.extract(body)
    end

    test "extracts association types" do
      assoc_args = [
        field: :user,
        owner: MyApp.Post,
        related: MyApp.User,
        cardinality: :one
      ]

      body = [do: {:%{}, [], [user: {:assoc, {:%{}, [], assoc_args}}]}]
      [{:user, {:assoc, result}}] = ChangesetExtractor.extract(body)
      assert is_map(result)
      assert result.related == MyApp.User
    end

    test "extracts embed types" do
      embed_args = [related: MyApp.Address, cardinality: :one]
      body = [do: {:%{}, [], [address: {:embed, {:%{}, [], embed_args}}]}]
      [{:address, {:embed, result}}] = ChangesetExtractor.extract(body)
      assert is_map(result)
      assert result.related == MyApp.Address
    end

    test "raises on unexpected body shape" do
      assert_raise ArgumentError, ~r/unexpected __changeset__\/0 body shape/, fn ->
        ChangesetExtractor.extract(do: :unexpected)
      end
    end
  end
end
