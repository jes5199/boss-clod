# Finding 4 (faithful) — tamper-blindness ON FULL-STATE CHAINS. The finding's scope is
# "76% of byte flips absorbed on full-state chains": corruption in a SUPERSEDED region of
# a full-state-rewrite chain is invisible in the reconstructed output. So we flip EVERY
# commit in the chain (one deterministic byte each), reduce the WHOLE chain the way
# reconstruction does, and count how many flips leave the canonical output byte-identical
# (ABSORBED = silent) vs change it or error (CAUGHT). In-memory only; no store writes.
#
# Scoped to schema-with-entries docs (the full-state-rewrite population). A text/delta
# contrast sample is reported separately so the "on full-state chains" qualifier is visible.

alias Commonplace.Store.CommitStore
alias Commonplace.Tree.DocBuilder
alias Commonplace.Projection.PostState
alias Yelixer.{Doc, Encoding}

copy_dir = System.argv() |> Enum.reject(&(&1 == "--")) |> List.first()
Application.put_env(:commonplace, :reader_lazy_snapshot_enabled, false)
{:ok, _} = CommitStore.start_link(name: :probe_store, data_dir: copy_dir)
store = :probe_store

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
      {:err, o} -> {:caught_error, o}
    end
  rescue e -> {:caught_error, {:raise, Exception.message(e)}}
  catch k, r -> {:caught_error, {k, r}}
  end
end

flip = fn bin, pos ->
  <<pre::binary-size(pos), b, rest::binary>> = bin
  <<pre::binary, Bitwise.bxor(b, 0x01), rest::binary>>
end

# classify a doc as full-state schema by structural entries type
alias Commonplace.Tree.Schema
is_schema = fn uuid ->
  case DocBuilder.reconstruct_snapshot(store, uuid) do
    {:ok, d} -> Doc.has_type?(d, "entries")
    _ -> false
  end
end

docs = CommitStore.all_doc_uuids(store) |> MapSet.to_list() |> Enum.sort()

# measure ALL flips (every commit, deterministic byte) over a chain; cap flips/doc to bound cost
measure = fn uuid, acc ->
  case CommitStore.latest_commit(store, uuid) do
    :none -> acc
    {:ok, latest} ->
      case DocBuilder.chain_to(store, uuid, latest.id, []) do
        {:ok, commits} when commits != [] ->
          case reduce_bytes.(commits) do
            {:ok, baseline} ->
              n = length(commits)
              # cap at 40 flips/doc, evenly spaced over commit indices
              idxs = if n <= 40, do: 0..(n-1)//1, else: (0..39 |> Enum.map(&(div(&1 * (n-1), 39)))) |> Enum.uniq()
              Enum.reduce(idxs, acc, fn i, acc ->
                c = Enum.at(commits, i)
                if byte_size(c.update) == 0 do
                  %{acc | skipped_empty: acc.skipped_empty + 1}
                else
                  pos = div(byte_size(c.update), 2)
                  fu = flip.(c.update, pos)
                  if fu == c.update do
                    %{acc | flip_noop: acc.flip_noop + 1}
                  else
                    tampered = List.replace_at(commits, i, %{c | update: fu})
                    case reduce_bytes.(tampered) do
                      {:ok, tb} when tb == baseline -> %{acc | flips: acc.flips + 1, absorbed: acc.absorbed + 1}
                      {:ok, _} -> %{acc | flips: acc.flips + 1, caught_diff: acc.caught_diff + 1}
                      {:caught_error, _} -> %{acc | flips: acc.flips + 1, caught_err: acc.caught_err + 1}
                    end
                  end
                end
              end)
            {:caught_error, _} -> acc
          end
        _ -> acc
      end
  end
end

z = %{flips: 0, absorbed: 0, caught_diff: 0, caught_err: 0, skipped_empty: 0, flip_noop: 0, docs: 0}

# full-state schema sample: every 8th schema doc
schema_docs = Enum.filter(docs, is_schema)
schema_sample = schema_docs |> Enum.with_index() |> Enum.filter(fn {_, i} -> rem(i, 8) == 0 end) |> Enum.map(&elem(&1, 0))
IO.puts("schema docs total=#{length(schema_docs)} sample=#{length(schema_sample)}")
r_schema = Enum.reduce(schema_sample, z, fn u, a -> measure.(u, %{a | docs: a.docs + 1}) end)

# text/delta contrast: every 60th non-schema doc
text_docs = docs -- schema_docs
text_sample = text_docs |> Enum.with_index() |> Enum.filter(fn {_, i} -> rem(i, 60) == 0 end) |> Enum.map(&elem(&1, 0))
r_text = Enum.reduce(text_sample, z, fn u, a -> measure.(u, %{a | docs: a.docs + 1}) end)

pct = fn a, b -> if b > 0, do: Float.round(a * 100 / b, 1), else: 0.0 end

IO.puts("\n============ FINDING 4 (faithful): TAMPER-BLINDNESS ============")
IO.puts("--- FULL-STATE (schema) chains — the finding's scope ---")
IO.puts("docs=#{r_schema.docs} flips=#{r_schema.flips}")
IO.puts("ABSORBED (silent): #{r_schema.absorbed} = #{pct.(r_schema.absorbed, r_schema.flips)}%  (was 76%)")
IO.puts("caught_diff=#{r_schema.caught_diff} caught_err=#{r_schema.caught_err} skipped_empty=#{r_schema.skipped_empty} flip_noop(MUST be 0)=#{r_schema.flip_noop}")
caught = r_schema.caught_diff + r_schema.caught_err
IO.puts("controls: caught-arm reachable=#{caught > 0} (#{caught}); absorbed-arm reachable=#{r_schema.absorbed > 0} (#{r_schema.absorbed})")
IO.puts("--- TEXT/delta chains (contrast) ---")
IO.puts("docs=#{r_text.docs} flips=#{r_text.flips} ABSORBED=#{r_text.absorbed} = #{pct.(r_text.absorbed, r_text.flips)}% caught_diff=#{r_text.caught_diff} caught_err=#{r_text.caught_err}")
IO.puts("TAMPER2_DONE")
System.halt(0)
