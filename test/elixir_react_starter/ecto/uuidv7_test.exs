defmodule ElixirReactStarter.Ecto.UUIDv7Test do
  use ExUnit.Case, async: true

  alias ElixirReactStarter.Ecto.UUIDv7

  # Byte-order (big-endian) comparison of two canonical UUID strings. UUID v7
  # ids are time-sortable, so "b sorts after a" means b's bytes are greater.
  defp dump(uuid) do
    {:ok, bin} = Ecto.UUID.dump(uuid)
    bin
  end

  describe "Ecto.Type callbacks" do
    test "type/0 stores as :uuid" do
      assert UUIDv7.type() == :uuid
    end

    test "cast/dump/load delegate to Ecto.UUID and round-trip" do
      uuid = UUIDv7.generate()

      assert {:ok, ^uuid} = UUIDv7.cast(uuid)
      assert {:ok, dumped} = UUIDv7.dump(uuid)
      assert {:ok, ^uuid} = UUIDv7.load(dumped)
    end

    test "cast/2 rejects invalid values" do
      assert :error = UUIDv7.cast("not-a-uuid")
    end
  end

  describe "generate/0 produces well-formed UUID v7" do
    test "is a canonical lowercase v7 UUID with the RFC variant" do
      uuid = UUIDv7.generate()

      # Canonical lowercase string form.
      assert uuid =~ ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/

      # Version nibble is 7 and the variant bits are the RFC 4122/9562 `10`.
      assert <<_ts::48, version::4, _rand_a::12, variant::2, _rand_b::62>> = dump(uuid)
      assert version == 7
      assert variant == 2
    end

    test "embeds the current millisecond timestamp" do
      before_ms = System.system_time(:millisecond)
      <<ts::48, _::80>> = dump(UUIDv7.generate())
      after_ms = System.system_time(:millisecond)

      # The embedded time can run one tick ahead of the clock under burst (the
      # monotonic counter borrows from the next ms), so allow a small slack.
      assert ts >= before_ms
      assert ts <= after_ms + 1
    end
  end

  describe "monotonicity" do
    test "successive calls are strictly increasing within the same process" do
      # 5_000 calls run well within a single millisecond on modern hardware, so
      # nearly every call has `candidate <= last` and falls back to `last + 1`.
      # That is the *same* code path that handles a backwards clock step
      # (`max(candidate, last + 1)`), so this also covers clock regression.
      uuids = for _ <- 1..5_000, do: UUIDv7.generate()
      bins = Enum.map(uuids, &dump/1)

      # Strictly increasing: every id sorts after the previous one, and the
      # sequence is already sorted (no reordering needed).
      assert bins == Enum.sort(bins)
      assert length(Enum.uniq(bins)) == length(bins)

      Enum.zip(bins, tl(bins))
      |> Enum.each(fn {a, b} -> assert a < b end)
    end

    test "ordering prefixes stay unique under concurrent generation across processes" do
      count = 50
      per_task = 1_000
      total = count * per_task

      uuids =
        1..count
        |> Task.async_stream(fn _ -> for _ <- 1..per_task, do: UUIDv7.generate() end,
          max_concurrency: count,
          ordered: false
        )
        |> Enum.flat_map(fn {:ok, batch} -> batch end)

      assert length(uuids) == total

      # Assert uniqueness of the 60-bit ordering prefix (timestamp + rand_a),
      # not the whole UUID. Full-UUID uniqueness is trivially true via the 62
      # random `rand_b` bits even if the counter were broken; only prefix
      # uniqueness proves the lock-free CAS counter never hands the same
      # ordering slot to two concurrent processes.
      prefixes =
        Enum.map(uuids, fn uuid ->
          <<ts::48, 7::4, rand_a::12, _variant::2, _rand_b::62>> = dump(uuid)
          ts * 4096 + rand_a
        end)

      assert length(Enum.uniq(prefixes)) == total
    end
  end

  describe "init/0" do
    test "is idempotent" do
      # The application already initializes the counter at startup, so both
      # calls hit the already-initialized branch and return :ok.
      assert UUIDv7.init() == :ok
      assert UUIDv7.init() == :ok
      # Generation still works after re-initializing.
      assert is_binary(UUIDv7.generate())
    end
  end
end
