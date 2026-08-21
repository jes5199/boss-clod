# [6] deploy-certification probe: classify EVERY head doc under the NEW exporter's
# verdict semantics. The exporter renders {:ok,_,_}; warns on commit_not_found/
# commit_not_on_chain; HARD-FAILS the whole export on any other {:error,_} or any
# {:unknown,_}. If the live corpus (superset of the GitBridge mount) has 0 hard-fail
# docs at head, [6] is deploy-safe a fortiori; else each offender is named + shaped.
# Offline copy, read-only. head_path mirrors the exporter: schema-> :direct, else :chain.

alias Commonplace.Store.CommitStore
alias Commonplace.Tree.DocBuilder
alias Commonplace.Projection
alias Yelixer.Doc

copy_dir = System.argv() |> Enum.reject(&(&1 == "--")) |> List.first()
Application.put_env(:commonplace, :reader_lazy_snapshot_enabled, false)
{:ok, _} = CommitStore.start_link(name: :probe_store, data_dir: copy_dir)
store = :probe_store

# positive control: the classifier must be able to say HARDFAIL (a synthetic
# tamper-shaped verdict classifies as hard-fail) and RENDER (an :ok classifies clean).
classify = fn
  {:ok, _d, _v} -> :render
  {:error, r} when r in [:commit_not_found, :commit_not_on_chain] -> :warn
  {:error, {:commit_not_found, _}} -> :warn
  {:error, {:commit_not_on_chain, _}} -> :warn
  {:error, other} -> {:hardfail, {:error, other}}
  {:unknown, other} -> {:hardfail, {:unknown, other}}
end

unless classify.({:error, :signature_invalid}) == {:hardfail, {:error, :signature_invalid}} and
         classify.({:ok, nil, :witnessed}) == :render and
         classify.({:error, {:commit_not_found, "x"}}) == :warn do
  IO.puts(:stderr, "CLASSIFIER SELF-TEST FAILED"); System.halt(3)
end
IO.puts("classifier self-test OK (hardfail + render + warn arms)")

docs = CommitStore.all_doc_uuids(store) |> MapSet.to_list()
n = length(docs)
IO.puts("head docs: #{n}")
t0 = System.monotonic_time(:millisecond)

acc =
  docs
  |> Enum.with_index()
  |> Enum.reduce(%{render: 0, warn: 0, hardfail: 0, none: 0, shapes: %{}, offenders: []}, fn {uuid, idx}, acc ->
    if rem(idx, 1000) == 0 and idx > 0, do: IO.puts("  #{idx}/#{n}")

    case CommitStore.latest_commit(store, uuid) do
      :none ->
        %{acc | none: acc.none + 1}

      {:ok, latest} ->
        # mirror the exporter's head_path choice: schema docs :direct, content :chain
        head_path =
          case DocBuilder.reconstruct_snapshot(store, uuid) do
            {:ok, d} -> if Doc.has_type?(d, "entries"), do: :direct, else: :chain
            _ -> :chain
          end

        verdict =
          try do
            Projection.project_doc_at(uuid, latest.id, store: store, head_path: head_path)
          rescue
            e -> {:error, {:probe_raise, Exception.message(e)}}
          catch
            k, r -> {:error, {:probe_catch, k, r}}
          end

        case classify.(verdict) do
          :render -> %{acc | render: acc.render + 1}
          :warn -> %{acc | warn: acc.warn + 1}
          {:hardfail, shape} ->
            key =
              case shape do
                {_kind, t} when is_tuple(t) -> elem(t, 0)
                {_kind, a} -> a
              end
            ex = if length(acc.offenders) < 12, do: [{uuid, shape} | acc.offenders], else: acc.offenders
            %{acc |
              hardfail: acc.hardfail + 1,
              shapes: Map.update(acc.shapes, key, 1, &(&1 + 1)),
              offenders: ex}
        end
    end
  end)

IO.puts("\n============ [6] DEPLOY-CERT: EXPORTER-SEMANTICS HEAD CENSUS ============")
IO.puts("elapsed #{System.monotonic_time(:millisecond) - t0}ms; docs #{n} (sum check: #{acc.render + acc.warn + acc.hardfail + acc.none})")
IO.puts("RENDER (ok, incl :declared) : #{acc.render}")
IO.puts("WARN (absence, like old)    : #{acc.warn}")
IO.puts("HARDFAIL (would halt export): #{acc.hardfail}")
IO.puts("hardfail shapes: #{inspect(acc.shapes)}")
IO.puts("offender samples: #{inspect(acc.offenders, limit: :infinity, printable_limit: 200)}")
IO.puts("EXPORT_CERT_DONE")
System.halt(0)
