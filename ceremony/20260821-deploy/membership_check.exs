# Are the 116 fork-lineage heads {:doc_commit} MEMBERS of their key doc?
# Decides whether the fact-keyed fix (struct-mismatch -> consult doc_has_commit?)
# would pass them (member) or still refuse (non-member).
alias Commonplace.Store.CommitStore

copy_dir = System.argv() |> Enum.reject(&(&1 == "--")) |> List.first()
Application.put_env(:commonplace, :reader_lazy_snapshot_enabled, false)
{:ok, _} = CommitStore.start_link(name: :probe_store, data_dir: copy_dir)
store = :probe_store

docs = CommitStore.all_doc_uuids(store) |> MapSet.to_list()

# find all heads whose struct doc_uuid mismatches (the F2 set), then check membership
res =
  Enum.reduce(docs, %{mismatch: 0, member: 0, nonmember: 0, nonmember_ex: []}, fn uuid, acc ->
    case CommitStore.latest_commit(store, uuid) do
      {:ok, c} when c.doc_uuid != uuid ->
        acc = %{acc | mismatch: acc.mismatch + 1}
        if CommitStore.doc_has_commit?(store, uuid, c.id) do
          %{acc | member: acc.member + 1}
        else
          ex = if length(acc.nonmember_ex) < 5, do: [uuid | acc.nonmember_ex], else: acc.nonmember_ex
          %{acc | nonmember: acc.nonmember + 1, nonmember_ex: ex}
        end
      _ -> acc
    end
  end)

IO.puts("F2 struct-mismatch heads: #{res.mismatch}")
IO.puts("  {:doc_commit} MEMBERS   : #{res.member}   (fact-keyed fix passes these)")
IO.puts("  NON-members             : #{res.nonmember} (fix still refuses — genuinely foreign)")
IO.puts("  nonmember examples: #{inspect(res.nonmember_ex)}")
IO.puts("MEMBERSHIP_DONE")
System.halt(0)
