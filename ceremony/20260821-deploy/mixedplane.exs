# Finding 3 — mixed-plane hazard is PIN-ONLY (0 at head, >=1 at a pin ⇒ the integrity
# tripwire must run at PIN reads, not head). project_at returns {:unknown,{:mixed_plane,_}}
# when a pin trips, so it IS the oracle. Positive control: the fixture proves the tripwire
# can fire (head CLEAN / history TRIPS) before we trust a corpus zero at head.

alias Commonplace.Store.CommitStore
alias Commonplace.Projection
alias Commonplace.Projection.MixedPlaneHistory

copy_dir = System.argv() |> Enum.reject(&(&1 == "--")) |> List.first()
Application.put_env(:commonplace, :reader_lazy_snapshot_enabled, false)
{:ok, _} = CommitStore.start_link(name: :probe_store, data_dir: copy_dir)
store = :probe_store

# ---- positive control: tripwire CAN trip (fixture head CLEAN / history TRIPS) ----
case MixedPlaneHistory.positive_control() do
  {:ok, ctrl} -> IO.puts("POSITIVE CONTROL OK: mixed-plane tripwire fires on fixture — #{inspect(ctrl)} (head CLEAN, history TRIPS)")
  {:error, reason} -> (IO.puts(:stderr, "POSITIVE CONTROL FAILED: #{inspect(reason)} — aborting, a corpus zero would be meaningless"); System.halt(3))
end

# ---- head scan: every doc at its :latest commit; count mixed-plane trips ----
docs = CommitStore.all_doc_uuids(store) |> MapSet.to_list()
t0 = System.monotonic_time(:millisecond)

acc =
  docs
  |> Enum.with_index()
  |> Enum.reduce(%{trips: 0, ok: 0, unknown_other: 0, error: 0, none: 0, examples: []}, fn {uuid, idx}, acc ->
    if rem(idx, 1000) == 0 and idx > 0, do: IO.puts("  head-scan #{idx}/#{length(docs)}")
    case CommitStore.latest_commit(store, uuid) do
      :none -> %{acc | none: acc.none + 1}
      {:ok, latest} ->
        case Projection.project_at(uuid, latest.id, store: store, required: :any) do
          {:ok, _b, _v} -> %{acc | ok: acc.ok + 1}
          {:unknown, {:mixed_plane, _d}} ->
            ex = if length(acc.examples) < 5, do: [uuid | acc.examples], else: acc.examples
            %{acc | trips: acc.trips + 1, examples: ex}
          {:unknown, _} -> %{acc | unknown_other: acc.unknown_other + 1}
          {:error, _} -> %{acc | error: acc.error + 1}
        end
    end
  end)

IO.puts("\n================ FINDING 3: MIXED-PLANE (HEAD) ================")
IO.puts("elapsed: #{System.monotonic_time(:millisecond) - t0}ms  docs=#{length(docs)}")
IO.puts("head mixed-plane trips : #{acc.trips}  (was 0 live-at-head on 2026-08-06)")
IO.puts("ok=#{acc.ok} unknown_other=#{acc.unknown_other} error=#{acc.error} none=#{acc.none}")
IO.puts("trip examples: #{inspect(acc.examples)}")
IO.puts("MIXEDPLANE_HEAD_DONE")
System.halt(0)
