# TONIGHT'S DEPLOY GATE (plan #14380): are any of the 116 F2/hard-fail docs under
# the GitBridge mount (6fd72a7f...)? Conservative SUPERSET walk: recurse EVERY :dir
# entry (ignoring the exporter's eligibility filters + capability-gating, which only
# SHRINK the real walk), collect every schema uuid + every :doc node_id. Zero of 116
# in the superset => zero in the real export walk, a fortiori => deploy-safe.
# PLUS the containment check (plan): are the 116 == "dangling_latest" (zero OWN
# {:doc_commit} rows)? Offline copy, read-only.

alias Commonplace.Store.CommitStore
alias Commonplace.Tree.{DocBuilder, Schema}
alias Yelixer.Doc

copy_dir = System.argv() |> Enum.reject(&(&1 == "--")) |> List.first()
mount = "6fd72a7f-0f4c-4e31-8d2f-3b27312ecf4a"
Application.put_env(:commonplace, :reader_lazy_snapshot_enabled, false)
{:ok, _} = CommitStore.start_link(name: :probe_store, data_dir: copy_dir)
store = :probe_store

# --- recompute the 116 (same predicate as the census; self-contained denominator) --
docs = CommitStore.all_doc_uuids(store) |> MapSet.to_list()
f2 =
  Enum.filter(docs, fn uuid ->
    case CommitStore.latest_commit(store, uuid) do
      {:ok, c} -> c.doc_uuid != uuid
      :none -> false
    end
  end)
IO.puts("F2 population recomputed: #{length(f2)} (expect 116)")

# --- positive control: the walk must actually reach docs (mount subtree non-empty) --
walk = fn walk, uuid, acc ->
  if MapSet.member?(acc.seen, uuid) do
    acc
  else
    acc = %{acc | seen: MapSet.put(acc.seen, uuid)}
    case DocBuilder.reconstruct_snapshot(store, uuid) do
      {:ok, doc} ->
        if Doc.has_type?(doc, "entries") do
          acc = %{acc | schemas: MapSet.put(acc.schemas, uuid)}
          Schema.list_entries(doc)
          |> Enum.reduce(acc, fn e, acc ->
            case e.type do
              :dir -> walk.(walk, e.node_id, acc)
              :doc -> %{acc | leaves: MapSet.put(acc.leaves, e.node_id)}
              _ -> acc
            end
          end)
        else
          %{acc | leaves: MapSet.put(acc.leaves, uuid)}
        end
      :none -> acc
    end
  end
end

acc = walk.(walk, mount, %{seen: MapSet.new(), schemas: MapSet.new(), leaves: MapSet.new()})
under_mount = MapSet.union(acc.schemas, acc.leaves)
IO.puts("mount subtree (SUPERSET walk): #{MapSet.size(acc.schemas)} schemas + #{MapSet.size(acc.leaves)} leaf docs = #{MapSet.size(under_mount)} total")

if MapSet.size(under_mount) < 2 do
  IO.puts(:stderr, "POSITIVE CONTROL FAILED: mount walk found <2 docs — walk blind or wrong mount uuid")
  System.halt(3)
end
IO.puts("positive control OK: mount subtree non-trivial")

# --- THE GATE ---
hits = Enum.filter(f2, &MapSet.member?(under_mount, &1))
IO.puts("\n============ DEPLOY GATE ============")
IO.puts("F2/hard-fail docs UNDER THE MOUNT: #{length(hits)} of #{length(f2)}")
IO.puts("hits: #{inspect(hits)}")

# --- containment: dangling_latest (zero OWN {:doc_commit} rows)? ---
own_counts = Enum.map(f2, fn uuid -> MapSet.size(CommitStore.all_commit_ids_for_doc(store, uuid)) end)
zero = Enum.count(own_counts, &(&1 == 0))
nonzero = length(f2) - zero
IO.puts("\n--- containment check (dangling_latest claim) ---")
IO.puts("of #{length(f2)} F2 docs: #{zero} have ZERO own {:doc_commit} rows; #{nonzero} have >0")
if nonzero > 0 do
  nz = Enum.zip(f2, own_counts) |> Enum.filter(fn {_, n} -> n > 0 end) |> Enum.take(5)
  IO.puts("  >0 examples: #{inspect(nz)}")
end
IO.puts("MOUNT_GATE_DONE")
System.halt(0)
