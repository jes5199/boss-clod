# Finding 5 — determinism. Same (doc, commit) projected to canonical export bytes;
# run this script in TWO fresh OS processes and diff the outputs. Byte-identical
# across processes = deterministic (the export-SHA precondition). The sample is
# DETERMINISTIC (sorted + fixed stride) so both runs project exactly the same pairs.

alias Commonplace.Store.CommitStore
alias Commonplace.Tree.DocBuilder
alias Commonplace.Projection

[copy_dir, outfile] = System.argv() |> Enum.reject(&(&1 == "--"))
Application.put_env(:commonplace, :reader_lazy_snapshot_enabled, false)
{:ok, _} = CommitStore.start_link(name: :probe_store, data_dir: copy_dir)
store = :probe_store

docs = CommitStore.all_doc_uuids(store) |> MapSet.to_list() |> Enum.sort()

# deterministic sample: every 40th doc + the first 60 (dense) to include diverse
# classes; for each doc take head, middle, oldest commit (dedup).
sample_docs =
  (Enum.take(docs, 60) ++ (docs |> Enum.with_index() |> Enum.filter(fn {_, i} -> rem(i, 40) == 0 end) |> Enum.map(&elem(&1, 0))))
  |> Enum.uniq()

pairs =
  Enum.flat_map(sample_docs, fn uuid ->
    log = CommitStore.commit_log(store, uuid, limit: CommitStore.max_commit_log_limit())
    ids = Enum.map(log, & &1.id)  # newest-first
    n = length(ids)
    picks =
      cond do
        n == 0 -> []
        n == 1 -> [Enum.at(ids, 0)]
        true -> [Enum.at(ids, 0), Enum.at(ids, div(n, 2)), Enum.at(ids, n - 1)] |> Enum.uniq()
      end
    Enum.map(picks, &{uuid, &1})
  end)

lines =
  Enum.map(pairs, fn {uuid, cid} ->
    {status, sha} =
      case Projection.project_at(uuid, cid, store: store, required: :any) do
        {:ok, bytes, _v} -> {"ok", Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)}
        {:unknown, term} -> {"unknown:" <> inspect(term) |> String.replace(~r/\s+/, ""), "-"}
        {:error, term} -> {"error:" <> inspect(term) |> String.replace(~r/\s+/, ""), "-"}
      end
    "#{uuid} #{Base.encode16(cid, case: :lower)} #{status} #{sha}"
  end)
  |> Enum.sort()

File.write!(outfile, Enum.join(lines, "\n") <> "\n")

ok_shas = lines |> Enum.filter(&String.contains?(&1, " ok ")) |> Enum.map(&List.last(String.split(&1, " ")))
distinct = ok_shas |> Enum.uniq() |> length()
IO.puts("pairs=#{length(pairs)} ok=#{length(ok_shas)} distinct_ok_shas=#{distinct}")
# diversity control: if every ok projection hashed the same, the instrument is vacuous
if length(ok_shas) > 1 and distinct <= 1 do
  IO.puts("⚠️ DIVERSITY CONTROL FAILED — all ok projections share one sha (instrument vacuous)")
else
  IO.puts("diversity control OK: #{distinct} distinct shas among #{length(ok_shas)} ok projections")
end
IO.puts("DETERMINISM_RUN_DONE -> #{outfile}")
System.halt(0)
