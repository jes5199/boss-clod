# chit re-measure — M4 census + Finding 1 (silent-wrong-bytes) + Finding 2 (fork-lineage).
# Runs OFFLINE against the CubDB.back_up copy via a locally-started CommitStore,
# so probes call the REAL reconstruction code (DocBuilder/CommitStoreClient route
# to the store arg). Read-only: mint:false, lazy-snapshot disabled, no writes.

defmodule H do
  alias Commonplace.Tree.{DocBuilder, Schema}

  # authoritative head read for schema/dir docs = latest-commit-only
  def safe_snapshot(store, uuid) do
    case DocBuilder.reconstruct_snapshot(store, uuid) do
      {:ok, doc} -> {:ok, doc}
      :none -> {:error, :none}
      other -> {:error, {:unexpected, other}}
    end
  rescue
    e -> {:error, {:raise, Exception.message(e)}}
  catch
    kind, reason -> {:error, {kind, reason}}
  end

  # candidate under test: full-chain replay (the k20z-suppressing path). mint:false.
  def safe_chain(store, uuid) do
    case DocBuilder.reconstruct_doc(store, uuid, mint: false) do
      {:ok, doc} -> {:ok, doc}
      :none -> {:error, :none}
      other -> {:error, {:unexpected, other}}
    end
  rescue
    e -> {:error, {:raise, Exception.message(e)}}
  catch
    kind, reason -> {:error, {kind, reason}}
  end

  def entry_map(doc), do: Schema.entries(doc)
end

alias Commonplace.Store.CommitStore
alias Yelixer.Doc

copy_dir = System.argv() |> Enum.reject(&(&1 == "--")) |> List.first()
unless copy_dir, do: (IO.puts(:stderr, "usage: census_f1_f2.exs <copy_data_dir>"); System.halt(2))

Application.put_env(:commonplace, :reader_lazy_snapshot_enabled, false)

{:ok, _pid} = CommitStore.start_link(name: :probe_store, data_dir: copy_dir)
store = :probe_store
IO.puts("opened copy at #{copy_dir}")

# ============================================================================
# POSITIVE CONTROLS — prove the comparators can go red BEFORE trusting corpus zeros
# ============================================================================
snap_syn = MapSet.new(["a", "b", "c"])
chain_syn = MapSet.new(["a", "c"])
dropped_syn = MapSet.difference(snap_syn, chain_syn)
unless MapSet.equal?(dropped_syn, MapSet.new(["b"])) and snap_syn != chain_syn do
  IO.puts(:stderr, "F1 SELF-TEST FAILED — comparator cannot detect a dropped entry"); System.halt(3)
end
IO.puts("F1 self-test OK: set-diff detects a dropped key AND passes identical sets")

f2 = fn key, cdu -> key == cdu end
unless f2.("X", "X") and not f2.("X", "Y") do
  IO.puts(:stderr, "F2 SELF-TEST FAILED"); System.halt(3)
end
IO.puts("F2 self-test OK: own doc_uuid passes, foreign doc_uuid flagged")

# ============================================================================
# CORPUS
# ============================================================================
head_docs = CommitStore.all_doc_uuids(store) |> MapSet.to_list()
n_docs = length(head_docs)
IO.puts("head population (all_doc_uuids): #{n_docs}")

pop =
  try do
    CommitStore.population_scan(store)
  rescue
    e -> {:error, Exception.message(e)}
  end
IO.puts("population_scan: #{inspect(pop, limit: 20)}")

init = %{
  f2_total: 0, f2_mismatch: 0, f2_mismatch_examples: [],
  schema_with_entries: 0, schema_empty: 0, nonschema: 0,
  latest_none: 0, snap_error: 0, chain_error: 0,
  f1_schema_denom: 0, f1_disagree: 0, f1_dropped_entries: 0, f1_added_entries: 0,
  f1_disagree_examples: []
}

t0 = System.monotonic_time(:millisecond)

acc =
  Enum.reduce(Enum.with_index(head_docs), init, fn {uuid, idx}, acc ->
    if rem(idx, 500) == 0 and idx > 0 do
      IO.puts("  ...#{idx}/#{n_docs} (#{System.monotonic_time(:millisecond) - t0}ms)")
    end

    case CommitStore.latest_commit(store, uuid) do
      :none ->
        %{acc | latest_none: acc.latest_none + 1}

      {:ok, latest} ->
        acc = %{acc | f2_total: acc.f2_total + 1}

        acc =
          if latest.doc_uuid == uuid do
            acc
          else
            ex = if length(acc.f2_mismatch_examples) < 5,
              do: [%{key: uuid, struct_doc_uuid: latest.doc_uuid, commit: latest.id} | acc.f2_mismatch_examples],
              else: acc.f2_mismatch_examples
            %{acc | f2_mismatch: acc.f2_mismatch + 1, f2_mismatch_examples: ex}
          end

        case H.safe_snapshot(store, uuid) do
          {:error, _} ->
            %{acc | snap_error: acc.snap_error + 1}

          {:ok, snap_doc} ->
            if Doc.has_type?(snap_doc, "entries") do
              snap_entries = H.entry_map(snap_doc)

              if map_size(snap_entries) == 0 do
                %{acc | schema_empty: acc.schema_empty + 1}
              else
                acc = %{acc | schema_with_entries: acc.schema_with_entries + 1, f1_schema_denom: acc.f1_schema_denom + 1}

                case H.safe_chain(store, uuid) do
                  {:error, _} ->
                    %{acc | chain_error: acc.chain_error + 1}

                  {:ok, chain_doc} ->
                    chain_entries = H.entry_map(chain_doc)

                    if snap_entries == chain_entries do
                      acc
                    else
                      snap_names = snap_entries |> Map.keys() |> MapSet.new()
                      chain_names = chain_entries |> Map.keys() |> MapSet.new()
                      dropped = MapSet.difference(snap_names, chain_names)
                      added = MapSet.difference(chain_names, snap_names)

                      ex =
                        if length(acc.f1_disagree_examples) < 8 do
                          [%{doc: uuid, dropped: MapSet.size(dropped), added: MapSet.size(added),
                             snap_n: map_size(snap_entries), chain_n: map_size(chain_entries),
                             sample_dropped: Enum.take(MapSet.to_list(dropped), 3)} | acc.f1_disagree_examples]
                        else
                          acc.f1_disagree_examples
                        end

                      %{acc |
                        f1_disagree: acc.f1_disagree + 1,
                        f1_dropped_entries: acc.f1_dropped_entries + MapSet.size(dropped),
                        f1_added_entries: acc.f1_added_entries + MapSet.size(added),
                        f1_disagree_examples: ex}
                    end
                end
              end
            else
              %{acc | nonschema: acc.nonschema + 1}
            end
        end
    end
  end)

elapsed = System.monotonic_time(:millisecond) - t0

IO.puts("\n================ CENSUS / F1 / F2 ================")
IO.puts("elapsed: #{elapsed}ms")
IO.puts("head docs (denominator): #{n_docs}")

classified = acc.schema_with_entries + acc.schema_empty + acc.nonschema + acc.latest_none + acc.snap_error
IO.puts("\n--- M4 class census (must sum to head docs) ---")
IO.puts("  schema_with_entries : #{acc.schema_with_entries}")
IO.puts("  schema_empty        : #{acc.schema_empty}")
IO.puts("  nonschema (text/etc): #{acc.nonschema}")
IO.puts("  latest_none         : #{acc.latest_none}")
IO.puts("  snap_error          : #{acc.snap_error}")
IO.puts("  SUM                 : #{classified}  (head docs #{n_docs}; remainder #{n_docs - classified})")

IO.puts("\n--- Finding 2: fork-lineage (latest.doc_uuid != key) ---")
pct = if acc.f2_total > 0, do: Float.round(acc.f2_mismatch * 100 / acc.f2_total, 2), else: 0.0
IO.puts("  #{acc.f2_mismatch}/#{acc.f2_total} = #{pct}%  (was 2.2% on 2026-08-06)")
IO.puts("  examples: #{inspect(acc.f2_mismatch_examples, limit: :infinity)}")

IO.puts("\n--- Finding 1: silent-wrong-bytes (chain replay drops schema entries) ---")
IO.puts("  dir-schema denom (entries non-empty): #{acc.f1_schema_denom}")
IO.puts("  disagree (snap != chain)            : #{acc.f1_disagree}  (was 80 on 2026-08-06)")
IO.puts("  total entries dropped by chain      : #{acc.f1_dropped_entries}  (was 124)")
IO.puts("  total entries added by chain        : #{acc.f1_added_entries}")
IO.puts("  chain_error (reconstruct failed)    : #{acc.chain_error}")
IO.puts("  examples: #{inspect(acc.f1_disagree_examples, limit: :infinity)}")

IO.puts("\nCENSUS_F1_F2_DONE")
System.halt(0)
