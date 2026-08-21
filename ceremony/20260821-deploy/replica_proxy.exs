# Replica-proxy leg: confirm the offline copy faithfully mirrors the live store.
# For a small deterministic subsample, compare :latest commit (id + update bytes)
# between the local copy and the live serve (erpc CommitStore.latest_commit — a
# RESIDENT fn, no force-load). A mismatch is checked for post-backup DRIFT (the
# copy is a point-in-time snapshot; the serve may have advanced) vs corruption.

alias Commonplace.Store.CommitStore

copy_dir = System.argv() |> Enum.reject(&(&1 == "--")) |> List.first()
serve_node = :commonplace_dev@commonplace

Application.put_env(:commonplace, :reader_lazy_snapshot_enabled, false)
{:ok, _} = CommitStore.start_link(name: :probe_store, data_dir: copy_dir)
store = :probe_store

:application.set_env(:kernel, :prevent_overlapping_partitions, false)
:application.set_env(:kernel, :inet_dist_use_interface, {127, 0, 0, 1})
probe_name = :"chit_replica_probe_#{:erlang.unique_integer([:positive])}@commonplace"
{:ok, _} = Node.start(probe_name, :shortnames)
unless Node.connect(serve_node), do: (IO.puts(:stderr, "connect failed"); System.halt(2))

# guard: CommitStore must be resident on the serve (else the call force-loads = write)
case :erpc.call(serve_node, :code, :is_loaded, [CommitStore], 15_000) do
  {:file, _} -> :ok
  false -> (IO.puts(:stderr, "CommitStore NOT loaded on serve — refusing"); System.halt(2))
end

docs = CommitStore.all_doc_uuids(store) |> MapSet.to_list() |> Enum.sort()
# deterministic subsample: every 200th doc (~30)
sample = docs |> Enum.with_index() |> Enum.filter(fn {_, i} -> rem(i, 200) == 0 end) |> Enum.map(&elem(&1, 0))

res =
  Enum.reduce(sample, %{match: 0, drift: 0, mismatch: 0, live_none: 0, copy_none: 0, examples: []}, fn uuid, acc ->
    copy_latest = CommitStore.latest_commit(store, uuid)
    live_latest = :erpc.call(serve_node, CommitStore, :latest_commit, [CommitStore, uuid], 20_000)

    case {copy_latest, live_latest} do
      {{:ok, c}, {:ok, l}} ->
        cond do
          c.id == l.id and c.update == l.update -> %{acc | match: acc.match + 1}
          # drift: live advanced past copy — copy's head is an ANCESTOR reachable from live head
          true ->
            drift? =
              case :erpc.call(serve_node, Commonplace.Store.CommitStoreClient, :commit_log_from, [l.id], 20_000) do
                log when is_list(log) -> Enum.any?(log, &(&1.id == c.id))
                _ -> false
              end
            if drift? do
              %{acc | drift: acc.drift + 1}
            else
              ex = if length(acc.examples) < 5, do: [%{doc: uuid, copy: Base.encode16(c.id), live: Base.encode16(l.id)} | acc.examples], else: acc.examples
              %{acc | mismatch: acc.mismatch + 1, examples: ex}
            end
        end
      {:none, {:ok, _}} -> %{acc | copy_none: acc.copy_none + 1}
      {{:ok, _}, :none} -> %{acc | live_none: acc.live_none + 1}
      {:none, :none} -> %{acc | match: acc.match + 1}
    end
  end)

IO.puts("\n================ REPLICA-PROXY (live vs copy) ================")
IO.puts("subsample: #{length(sample)} docs")
IO.puts("exact match (id+bytes)     : #{res.match}")
IO.puts("drift (live advanced past) : #{res.drift}  (copy head is ancestor of live head — expected)")
IO.puts("TRUE MISMATCH (corruption?): #{res.mismatch}  (MUST be 0)")
IO.puts("live_none/copy_none        : #{res.live_none}/#{res.copy_none}")
IO.puts("mismatch examples: #{inspect(res.examples)}")
IO.puts("REPLICA_PROXY_DONE")
System.halt(0)
