# Finding 4 — projection tamper-blindness. Flip ONE byte in a fetched commit's
# `update` IN MEMORY (never writes any store), re-run the SAME reduce the reconstruction
# does, and ask: did the canonical output change (CAUGHT) or not (ABSORBED)?
# 76% absorbed on 2026-08-06 ⇒ the reconstruction layer cannot self-detect corruption,
# so the verified-projection layer is a DEPENDENCY, not an enhancement.

alias Commonplace.Store.CommitStore
alias Commonplace.Tree.DocBuilder
alias Commonplace.Projection.PostState
alias Yelixer.{Doc, Encoding}

copy_dir = System.argv() |> Enum.reject(&(&1 == "--")) |> List.first()
Application.put_env(:commonplace, :reader_lazy_snapshot_enabled, false)
{:ok, _} = CommitStore.start_link(name: :probe_store, data_dir: copy_dir)
store = :probe_store

# reduce a commit list to canonical bytes exactly as reconstruction does
reduce_bytes = fn commits ->
  try do
    Enum.reduce_while(commits, {:ok, Doc.new([])}, fn c, {:ok, d} ->
      case Encoding.apply_update(d, c.update) do
        {:ok, d2} -> {:cont, {:ok, d2}}
        other -> {:halt, {:err, other}}
      end
    end)
    |> case do
      {:ok, doc} -> {:ok, PostState.canonical_bytes(doc)}
      {:err, other} -> {:caught_error, other}
    end
  rescue
    e -> {:caught_error, {:raise, Exception.message(e)}}
  catch
    k, r -> {:caught_error, {k, r}}
  end
end

flip = fn bin, pos ->
  <<pre::binary-size(pos), b, rest::binary>> = bin
  <<pre::binary, Bitwise.bxor(b, 0x01), rest::binary>>
end

docs = CommitStore.all_doc_uuids(store) |> MapSet.to_list() |> Enum.sort()
# deterministic sample: every 15th doc (~400) — spans schema (full-state) and text (delta)
sample = docs |> Enum.with_index() |> Enum.filter(fn {_, i} -> rem(i, 15) == 0 end) |> Enum.map(&elem(&1, 0))

# ---- positive controls -----------------------------------------------------
# (a) identity: not flipping must reproduce identical bytes (comparison can say "same")
# (b) a flip must actually change the input bytes (else "absorbed" is a non-flip)
# (c) caught arm must be reachable (some flip changes output OR errors)

result =
  Enum.reduce(sample, %{n: 0, absorbed: 0, caught_diff: 0, caught_err: 0, skipped_empty: 0,
                        flip_noop: 0, identity_ok: 0, examples: []}, fn uuid, acc ->
    case CommitStore.latest_commit(store, uuid) do
      :none -> acc
      {:ok, latest} ->
        case DocBuilder.chain_to(store, uuid, latest.id, []) do
          {:ok, commits} when commits != [] ->
            # baseline
            case reduce_bytes.(commits) do
              {:ok, baseline} ->
                # identity control
                acc = if reduce_bytes.(commits) == {:ok, baseline}, do: %{acc | identity_ok: acc.identity_ok + 1}, else: acc
                # pick a non-empty-update commit deterministically (last such)
                idx = Enum.find_index(Enum.reverse(commits), fn c -> byte_size(c.update) > 0 end)
                if idx == nil do
                  %{acc | skipped_empty: acc.skipped_empty + 1}
                else
                  real_idx = length(commits) - 1 - idx
                  target = Enum.at(commits, real_idx)
                  pos = div(byte_size(target.update), 2)
                  flipped_update = flip.(target.update, pos)
                  acc = if flipped_update != target.update, do: acc, else: %{acc | flip_noop: acc.flip_noop + 1}
                  tampered = List.replace_at(commits, real_idx, %{target | update: flipped_update})
                  case reduce_bytes.(tampered) do
                    {:ok, tbytes} ->
                      if tbytes == baseline do
                        ex = if length(acc.examples) < 5, do: [%{doc: uuid, verdict: :absorbed} | acc.examples], else: acc.examples
                        %{acc | n: acc.n + 1, absorbed: acc.absorbed + 1, examples: ex}
                      else
                        %{acc | n: acc.n + 1, caught_diff: acc.caught_diff + 1}
                      end
                    {:caught_error, _} ->
                      %{acc | n: acc.n + 1, caught_err: acc.caught_err + 1}
                  end
                end
              {:caught_error, _} -> acc
            end
          _ -> acc
        end
    end
  end)

r = result
total = r.n
absorbed_pct = if total > 0, do: Float.round(r.absorbed * 100 / total, 1), else: 0.0
IO.puts("\n================ FINDING 4: TAMPER-BLINDNESS ================")
IO.puts("flips measured (n)         : #{total}")
IO.puts("ABSORBED (silent, no change): #{r.absorbed}  = #{absorbed_pct}%  (was 76%)")
IO.puts("caught (output differs)     : #{r.caught_diff}")
IO.puts("caught (reduce errored)     : #{r.caught_err}")
IO.puts("skipped (all-empty updates) : #{r.skipped_empty}")
IO.puts("--- controls ---")
IO.puts("identity control (same->same): #{r.identity_ok}/#{total} reproduced baseline")
IO.puts("flip_noop (flip changed nothing in input): #{r.flip_noop}  (MUST be 0)")
caught_total = r.caught_diff + r.caught_err
IO.puts("caught-arm reachable: #{caught_total > 0} (#{caught_total} flips caught — proves comparison can report CAUGHT)")
IO.puts("examples: #{inspect(r.examples)}")
IO.puts("TAMPER_DONE")
System.halt(0)
