defmodule WebTemplate.Context do
  @moduledoc """
  A macro to inject common CRUD functions into a Context module.

  It normalizes return values using `WebTemplate.Ecto.OKRepo` patterns (e.g., returning `{:ok, struct}` or `{:error, :not_found}`).

  ## Options

  * `:repo` (required) - The Ecto Repo module (e.g., `WebTemplate.Repo`).
  * `:schema` (required) - The Schema module (e.g., `WebTemplate.Accounts.User`).
  * `:preloads` (optional) - A list of associations to preload by default on read operations.
  * `:changeset` (optional) - The atom name of the changeset function to use for `change_*` helpers. Defaults to `:changeset`.

  ## Generated Functions

  Assuming the schema is `User`, the following functions are generated:

  **Read Operations:**
  * `list_users(filters \\ [])` - Returns `[User]`
  * `list_users_ok(filters \\ [])` - Returns `{:ok, [User]}`
  * `get_user_ok(id)` - Returns `{:ok, User}` or `{:error, :not_found}`
  * `get_user!(id)` - Returns `User` or raises `Ecto.NoResultsError`
  * `get_user(id)` - Returns `User` or `nil`
  * `get_user_by_ok(clauses)` - Returns `{:ok, User}` or `{:error, :not_found}`
  * `get_user_by!(clauses)` - Returns `User` or raises `Ecto.NoResultsError`

  **Write Operations:**
  * `delete_user(struct)` - Deletes the user.

  **Helpers:**
  * `change_user(struct, attrs \\ %{})` - Returns an `Ecto.Changeset`.
  * `count_users(filters \\ [])` - Returns an integer count.

  **Overridable Callbacks:**
  * `filter_users(query, filters)` - Override this to implement custom filtering logic.

  ## Usage Example

      defmodule WebTemplate.Accounts do
        use WebTemplate.Context,
          repo: WebTemplate.Repo,
          schema: WebTemplate.Accounts.User,
          preloads: [:profile]

        # Implement Create/Update manually
        def create_user(attrs) do
          %User{}
          |> User.create_changeset(attrs)
          |> Repo.insert()
        end

        # Custom filtering override
        def filter_users(query, filters) do
          Enum.reduce(filters, query, fn
            {:email, email}, q -> where(q, [u], u.email == ^email)
            _, q -> q
          end)
        end
      end
  """

  defmacro __using__(opts) do
    # 1. Parse Options (Run at compile time)
    repo = Keyword.fetch!(opts, :repo)
    schema = Keyword.fetch!(opts, :schema)
    default_preloads = Keyword.get(opts, :preloads, [])
    changeset_fn = Keyword.get(opts, :changeset, :changeset)

    # 2. Calculate Names (Run at compile time)
    # We expand the schema alias to get the last part (e.g., WebTemplate.User -> "User")
    schema_module = Macro.expand(schema, __CALLER__)

    singular_str =
      schema_module
      |> Module.split()
      |> List.last()
      |> Macro.underscore()
      |> Exflect.singularize()

    plural_str = Exflect.pluralize(singular_str)

    # Pre-calculate function names as atoms
    list_fn = String.to_atom("list_#{plural_str}")
    list_ok_fn = String.to_atom("list_#{plural_str}_ok")
    filter_fn = String.to_atom("filter_#{plural_str}")
    count_fn = String.to_atom("count_#{plural_str}")

    get_ok_fn = String.to_atom("get_#{singular_str}_ok")
    get_bang_fn = String.to_atom("get_#{singular_str}!")
    get_fn = String.to_atom("get_#{singular_str}")

    get_by_ok_fn = String.to_atom("get_#{singular_str}_by_ok")
    get_by_bang_fn = String.to_atom("get_#{singular_str}_by!")
    get_by_fn = String.to_atom("get_#{singular_str}_by")

    delete_fn = String.to_atom("delete_#{singular_str}")
    change_fn = String.to_atom("change_#{singular_str}")

    quote do
      require Ecto.Query
      alias WebTemplate.Context

      # ========================================================================
      # 1. READ Operations
      # ========================================================================
      def unquote(list_fn)(filters \\ []) do
        unquote(schema)
        |> Ecto.Query.preload(^unquote(default_preloads))
        |> unquote(filter_fn)(filters)
        |> unquote(repo).all()
      end

      def unquote(list_ok_fn)(filters \\ []) do
        unquote(schema)
        |> Ecto.Query.preload(^unquote(default_preloads))
        |> unquote(filter_fn)(filters)
        |> unquote(repo).all_ok()
      end

      def unquote(get_ok_fn)(id) do
        unquote(schema)
        |> Ecto.Query.preload(^unquote(default_preloads))
        |> unquote(repo).get_ok(id)
      end

      def unquote(get_bang_fn)(id) do
        unquote(schema)
        |> Ecto.Query.preload(^unquote(default_preloads))
        |> unquote(repo).get!(id)
      end

      def unquote(get_fn)(id) do
        unquote(schema)
        |> Ecto.Query.preload(^unquote(default_preloads))
        |> unquote(repo).get(id)
      end

      def unquote(get_by_ok_fn)(clauses) do
        unquote(schema)
        |> Ecto.Query.preload(^unquote(default_preloads))
        |> unquote(repo).get_by_ok(clauses)
      end

      def unquote(get_by_bang_fn)(clauses) do
        unquote(schema)
        |> Ecto.Query.preload(^unquote(default_preloads))
        |> unquote(repo).get_by!(clauses)
      end

      def unquote(get_by_fn)(clauses) do
        unquote(schema)
        |> Ecto.Query.preload(^unquote(default_preloads))
        |> unquote(repo).get_by(clauses)
      end

      # ========================================================================
      # 2. DELETE Operation
      # ========================================================================
      def unquote(delete_fn)(%unquote(schema){} = struct) do
        unquote(repo).delete(struct)
      end

      # ========================================================================
      # 3. HELPER Operations
      # ========================================================================
      def unquote(change_fn)(%unquote(schema){} = struct, attrs \\ %{}) do
        unquote(schema).unquote(changeset_fn)(struct, attrs)
      end

      def unquote(count_fn)(filters \\ []) do
        unquote(schema)
        |> unquote(filter_fn)(filters)
        |> unquote(repo).aggregate(:count, :id)
      end

      # ========================================================================
      # 4. OVERRIDES
      # ========================================================================
      def unquote(filter_fn)(query, _filters), do: query
      defoverridable [{unquote(filter_fn), 2}]
    end
  end
end
