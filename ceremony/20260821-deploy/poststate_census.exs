# post_state_hash CENSUS — how many commits in the corpus carry a post_state_hash?
# Decides [6]-wiring sizing: mint is opt-in per call site, so the verified-projection
# layer only yields MEANINGFUL verdicts (:witnessed/:corroborated) for commits that
# were minted with a hash. If ~0 carry one, [6]-wiring alone makes tamper-blindness
# HONEST (export carries :declared/:conflicted) but not DETECTED — [5]-mint-coverage
# must ride with it for actual detection. Read-only, offline, controlled.

alias Commonplace.Store.CommitStore

copy_dir = System.argv() |> Enum.reject(&(&1 == "--")) |> List.first()
Application.put_env(:commonplace, :reader_lazy_snapshot_enabled, false)
{:ok, _} = CommitStore.start_link(name: :probe_store, data_dir: copy_dir)
store = :probe_store
db = CommitStore.db_handle(store)

# ---- positive control: the reader CAN see a present hash and CAN see its absence ----
present = %Commonplace.Store.Commit{post_state_hash: {1, "deadbeef"}}
absent = %Commonplace.Store.Commit{post_state_hash: nil}
unless Map.get(present, :post_state_hash) != nil and Map.get(absent, :post_state_hash) == nil do
  IO.puts(:stderr, "CENSUS CONTROL FAILED — reader cannot distinguish present/absent hash"); System.halt(3)
end
IO.puts("control OK: post_state_hash reader distinguishes present (#{inspect(Map.get(present, :post_state_hash))}) from nil")

# ---- enumerate all commits via the {:doc_commit} index (authoritative commit population) ----
pop = CommitStore.population_scan(store)
all_ids = pop.doc_commit_ids |> Map.values() |> Enum.reduce(MapSet.new(), &MapSet.union(&2, &1)) |> MapSet.to_list()
IO.puts("commits enumerated (from {:doc_commit} index): #{length(all_ids)}")

# signature-coverage control: a signed commit has signer_id AND signature non-nil
sig_present = %Commonplace.Store.Commit{signer_id: "n", signature: "s"}
unless Map.get(sig_present, :signer_id) != nil, do: (IO.puts(:stderr, "sig control failed"); System.halt(3))
IO.puts("control OK: signer_id reader distinguishes signed from unsigned")

t0 = System.monotonic_time(:millisecond)
acc =
  Enum.reduce(all_ids, %{total: 0, with_hash: 0, without_hash: 0, missing_row: 0,
                         signed: 0, unsigned: 0, by_kind_signed: %{}, by_kind_total: %{}}, fn id, acc ->
    case CubDB.get(db, {:commit, id}) do
      nil -> %{acc | missing_row: acc.missing_row + 1}
      commit ->
        kind = get_in(Map.get(commit, :metadata) || %{}, [:kind]) || :unknown
        has = Map.get(commit, :post_state_hash) != nil
        signed = Map.get(commit, :signer_id) != nil and Map.get(commit, :signature) != nil
        %{acc |
          total: acc.total + 1,
          with_hash: acc.with_hash + (if has, do: 1, else: 0),
          without_hash: acc.without_hash + (if has, do: 0, else: 1),
          signed: acc.signed + (if signed, do: 1, else: 0),
          unsigned: acc.unsigned + (if signed, do: 0, else: 1),
          by_kind_total: Map.update(acc.by_kind_total, kind, 1, &(&1 + 1)),
          by_kind_signed: (if signed, do: Map.update(acc.by_kind_signed, kind, 1, &(&1 + 1)), else: acc.by_kind_signed)
        }
    end
  end)

hpct = if acc.total > 0, do: Float.round(acc.with_hash * 100 / acc.total, 2), else: 0.0
spct = if acc.total > 0, do: Float.round(acc.signed * 100 / acc.total, 2), else: 0.0
IO.puts("\n================ POST_STATE_HASH + SIGNATURE CENSUS ================")
IO.puts("elapsed: #{System.monotonic_time(:millisecond) - t0}ms")
IO.puts("commits examined       : #{acc.total}  (missing_row: #{acc.missing_row})")
IO.puts("carry post_state_hash  : #{acc.with_hash}  = #{hpct}%   (gives tier-(i) :witnessed)")
IO.puts("SIGNED (signer+sig)    : #{acc.signed}  = #{spct}%   (gives tier-(ii) sig-based :corroborated / loud-tamper catch per acceptance #1)")
IO.puts("unsigned               : #{acc.unsigned}")
IO.puts("by kind (signed / total):")
Enum.each(Enum.sort(acc.by_kind_total), fn {k, tot} ->
  IO.puts("  #{inspect(k)}: #{Map.get(acc.by_kind_signed, k, 0)} / #{tot}")
end)
IO.puts("POSTSTATE_CENSUS_DONE")
System.halt(0)
