defmodule ElixirReactStarter.Ecto.OKRepo do
  @moduledoc """
  A generic wrapper for Ecto Repos that normalizes return values.
  Instead of returning `nil` or raising errors, functions return:
  - `{:ok, result}`
  - `{:error, :not_found}`
  - `{:error, reason}`
  """

  alias ElixirReactStarter.Ecto.OKRepo

  @type queryable :: Ecto.Queryable.t()
  @type schema :: Ecto.Schema.t()
  @type id :: term()
  @type opts :: Keyword.t()

  @type success(t) :: {:ok, t}
  @type error_reason :: :not_found | :invalid_id | atom()
  @type error :: {:error, error_reason}
  @type result(t) :: success(t) | error

  @doc false
  defmacro __using__(_opts) do
    quote do
      import ElixirReactStarter.Ecto.OKRepo

      # Explicitly delegate generic function to the module logic
      # passing the current module (The Repo) as the first argument.

      def all_ok(queryable, opts \\ []) do
        OKRepo.all_ok(__MODULE__, queryable, opts)
      end

      def get_ok(queryable, id, opts \\ []) do
        OKRepo.get_ok(__MODULE__, queryable, id, opts)
      end

      def get_by_ok(queryable, clauses, opts \\ []) do
        OKRepo.get_by_ok(__MODULE__, queryable, clauses, opts)
      end

      def one_ok(queryable, opts \\ []) do
        OKRepo.one_ok(__MODULE__, queryable, opts)
      end

      def aggregate_ok(queryable, type, opts \\ []) do
        OKRepo.aggregate_ok(__MODULE__, queryable, type, opts)
      end
    end
  end

  @doc """
  Wraps `Repo.all/2`. Always returns `{:ok, list}`.
  """
  @spec all_ok(module(), queryable, opts) :: success([schema])
  def all_ok(repo, queryable, opts) do
    {:ok, repo.all(queryable, opts)}
  end

  @doc """
  Wraps `Repo.get/3`. Returns `{:ok, schema}` or `{:error, :not_found}`.
  Handles invalid integer parsing automatically.
  """
  @spec get_ok(module(), queryable, id, opts) :: result(schema)
  def get_ok(_repo, _queryable, nil, _opts), do: {:error, :not_found}

  def get_ok(repo, queryable, id, opts) do
    case repo.get(queryable, id, opts) do
      nil -> {:error, :not_found}
      result -> {:ok, result}
    end
  rescue
    Ecto.Query.CastError -> {:error, :invalid_id}
    # Catch DB-specific ID errors (like UUID format errors)
    Ecto.QueryError -> {:error, :invalid_id}
    ArgumentError -> {:error, :invalid_id}
  end

  @doc """
  Wraps `Repo.get_by/3`. Returns `{:ok, schema}` or `{:error, :not_found}`.
  Filters out nil values from clauses before querying.
  """
  @spec get_by_ok(module(), queryable, Keyword.t() | map(), opts) :: result(schema)
  def get_by_ok(repo, queryable, clauses, opts) do
    # Filter out nil values from clauses
    filtered_clauses = Enum.reject(clauses, fn {_key, value} -> is_nil(value) end)

    # If no valid clauses remain, return not_found immediately
    if filtered_clauses == [] do
      {:error, :not_found}
    else
      case repo.get_by(queryable, filtered_clauses, opts) do
        nil -> {:error, :not_found}
        result -> {:ok, result}
      end
    end
  end

  @doc """
  Wraps `Repo.one/2`. Returns `{:ok, schema}` or `{:error, :not_found}`.
  """
  @spec one_ok(module(), queryable, opts) :: result(schema)
  def one_ok(repo, queryable, opts) do
    case repo.one(queryable, opts) do
      nil -> {:error, :not_found}
      result -> {:ok, result}
    end
  end

  @doc """
  Wraps `Repo.aggregate/3`. Returns `{:ok, value}`.
  Commonly used for counts: `Repo.aggregate_ok(User, :count)`
  """
  @spec aggregate_ok(module(), queryable, atom(), opts) :: success(term())
  def aggregate_ok(repo, queryable, type, opts) do
    {:ok, repo.aggregate(queryable, type, opts)}
  end
end
