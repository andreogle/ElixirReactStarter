defmodule ElixirReactStarter.Ecto.UUIDv7 do
  @moduledoc """
  An Ecto type for **monotonic** UUID v7 primary keys.

  UUID v7 values embed a millisecond timestamp, so they sort chronologically —
  which is why we use them for primary keys and as the tie-breaker in
  `order_by [asc: inserted_at, asc: id]` queries. Plain v7 generators fill the
  sub-millisecond bits with pure randomness, so two ids minted in the *same*
  millisecond sort in a random order. That makes id-based ordering
  non-deterministic under load (and intermittently in fast async tests — the
  failure window is a full second wide here, since timestamps are
  `:utc_datetime`).

  This generator follows RFC 9562's "monotonic random" guidance: it keeps a
  process-global, lock-free counter (an `:atomics` cell) holding the last
  60-bit ordering prefix — the 48-bit timestamp plus the 12-bit `rand_a`
  field — and guarantees the next value is strictly greater, even within the
  same millisecond and even if the wall clock steps backwards. The remaining
  `rand_b` bits stay random for uniqueness.

  Monotonicity is per BEAM node. Across a cluster, two nodes can mint same-ms
  ids that sort arbitrarily relative to each other; the 62 random `rand_b`
  bits still keep them unique.

  ## Usage

      @primary_key {:id, ElixirReactStarter.Ecto.UUIDv7, autogenerate: true}
      @foreign_key_type ElixirReactStarter.Ecto.UUIDv7
  """

  use Ecto.Type

  import Bitwise

  # Width of the v7 `rand_a` field that sits directly after the timestamp; the
  # ordering prefix is `unix_ts_ms (48) <<< 12 ||| rand_a (12)` = 60 bits.
  @rand_a_bits 12
  @rand_a_mask 0xFFF

  @counter_key {__MODULE__, :counter}

  @impl true
  def type, do: :uuid

  @impl true
  def cast(value), do: Ecto.UUID.cast(value)

  @impl true
  def dump(value), do: Ecto.UUID.dump(value)

  @impl true
  def load(value), do: Ecto.UUID.load(value)

  @impl true
  def autogenerate, do: generate()

  @doc """
  Initializes the monotonic counter. Idempotent — call once from the
  application's `start/2` so the very first id minted under concurrency is
  already monotonic. `generate/0` also initializes lazily as a fallback.
  """
  def init do
    case :persistent_term.get(@counter_key, nil) do
      nil -> :persistent_term.put(@counter_key, :atomics.new(1, signed: false))
      _ref -> :ok
    end
  end

  @doc """
  Generates a monotonic UUID v7 as a canonical lowercase string. Successive
  calls always return strictly increasing values.
  """
  @spec generate() :: String.t()
  def generate do
    prefix = next_prefix()
    time = prefix >>> @rand_a_bits
    rand_a = prefix &&& @rand_a_mask
    <<rand_b::62, _::2>> = :crypto.strong_rand_bytes(8)

    {:ok, uuid} = Ecto.UUID.load(<<time::48, 7::4, rand_a::12, 2::2, rand_b::62>>)
    uuid
  end

  # Atomically advances the global counter to the larger of "now" and
  # "last + 1", so the returned prefix is always strictly greater than the
  # previous one regardless of clock resolution or regression.
  defp next_prefix do
    ref = counter_ref()
    candidate = System.system_time(:millisecond) <<< @rand_a_bits ||| :rand.uniform(0x1000) - 1
    bump(ref, candidate)
  end

  defp bump(ref, candidate) do
    last = :atomics.get(ref, 1)
    next = max(candidate, last + 1)

    case :atomics.compare_exchange(ref, 1, last, next) do
      :ok -> next
      _current -> bump(ref, candidate)
    end
  end

  defp counter_ref do
    case :persistent_term.get(@counter_key, nil) do
      nil ->
        init()
        :persistent_term.get(@counter_key)

      ref ->
        ref
    end
  end
end
