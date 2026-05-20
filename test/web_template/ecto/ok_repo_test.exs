defmodule WebTemplate.Ecto.OKRepoTest do
  use WebTemplate.DataCase, async: true

  import WebTemplate.Factory

  alias WebTemplate.Accounts.User
  alias WebTemplate.Repo

  # WebTemplate.Repo `use`s OKRepo, so the wrappers under test are the
  # ones every context actually calls.

  describe "all_ok/2" do
    test "wraps the result list in an :ok tuple" do
      user = :user |> build() |> insert()
      assert {:ok, users} = Repo.all_ok(User)
      assert Enum.map(users, & &1.id) == [user.id]
    end

    test "returns {:ok, []} when nothing matches" do
      assert {:ok, []} = Repo.all_ok(User)
    end
  end

  describe "get_ok/3" do
    test "returns {:ok, struct} when the row exists" do
      user = :user |> build() |> insert()
      assert {:ok, %User{} = found} = Repo.get_ok(User, user.id)
      assert found.id == user.id
    end

    test "returns {:error, :not_found} for an unknown id" do
      assert {:error, :not_found} = Repo.get_ok(User, Ecto.UUID.generate())
    end

    test "returns {:error, :not_found} for a nil id without hitting the DB" do
      assert {:error, :not_found} = Repo.get_ok(User, nil)
    end

    test "returns {:error, :invalid_id} for a malformed id" do
      assert {:error, :invalid_id} = Repo.get_ok(User, "not-a-uuid")
    end
  end

  describe "get_by_ok/3" do
    test "returns {:ok, struct} when a row matches" do
      user = :user |> build() |> insert()
      assert {:ok, %User{} = found} = Repo.get_by_ok(User, email: user.email)
      assert found.id == user.id
    end

    test "returns {:error, :not_found} when no row matches" do
      assert {:error, :not_found} = Repo.get_by_ok(User, email: "missing@example.com")
    end

    test "drops nil clauses and returns {:error, :not_found} when none remain" do
      # All-nil clauses would otherwise match an arbitrary row.
      assert {:error, :not_found} = Repo.get_by_ok(User, email: nil)
    end
  end

  describe "one_ok/2" do
    test "returns {:ok, struct} when the query returns a single row" do
      user = :user |> build() |> insert()
      assert {:ok, %User{} = found} = Repo.one_ok(User)
      assert found.id == user.id
    end

    test "returns {:error, :not_found} when the query returns nothing" do
      assert {:error, :not_found} = Repo.one_ok(User)
    end
  end

  describe "aggregate_ok/4" do
    test "wraps the aggregate value in an :ok tuple" do
      :user |> build() |> insert()
      :user |> build() |> insert()
      assert {:ok, 2} = Repo.aggregate_ok(User, :count)
    end
  end
end
