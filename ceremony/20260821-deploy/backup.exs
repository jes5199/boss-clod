# chit re-measure — step 1: take a read-consistent OFFLINE copy of the live
# store via CubDB.back_up/2, the way the 2026-08-06 sizing did. Non-perturbing:
# reads the serve's db handle and copies; NEVER writes to the live store.
#
# Discipline (CLAUDE.md live-serve rules):
#   * :code.is_loaded/1 BEFORE calling any module on the serve — an erpc to an
#     UNLOADED module force-loads working-tree code = a WRITE. CommitStore and
#     CubDB are both core/loaded; we verify, we don't assume.
#   * :code.all_loaded count before/after — proves the back_up didn't force-load
#     working-tree app modules. (CubDB.* dep submodules loading is benign and
#     reported honestly, not asserted away.)

serve_node = :commonplace_dev@commonplace
target = System.argv() |> Enum.reject(&(&1 == "--")) |> List.first()

unless target, do: (IO.puts(:stderr, "usage: backup.exs <target_dir>"); System.halt(2))

:application.set_env(:kernel, :prevent_overlapping_partitions, false)
:application.set_env(:kernel, :inet_dist_use_interface, {127, 0, 0, 1})

probe_name = :"chit_backup_probe_#{:erlang.unique_integer([:positive])}@commonplace"

fail = fn msg ->
  IO.puts(:stderr, "backup: #{msg}")
  System.halt(2)
end

case Node.start(probe_name, :shortnames) do
  {:ok, _} -> :ok
  {:error, reason} -> fail.("Node.start failed: #{inspect(reason)}")
end

unless Node.connect(serve_node) do
  fail.("Node.connect(#{inspect(serve_node)}) returned false — serve up?")
end

# --- (1) load-state guard: both modules MUST already be resident ------------
cs = Commonplace.Store.CommitStore

is_loaded? = fn mod ->
  case :erpc.call(serve_node, :code, :is_loaded, [mod], 15_000) do
    {:file, _} -> true
    false -> false
  end
end

unless is_loaded?.(cs), do: fail.("CommitStore NOT loaded on serve — refusing (calling it would force-load working-tree code)")
unless is_loaded?.(CubDB), do: fail.("CubDB NOT loaded on serve — refusing")
IO.puts("load-state OK: CommitStore resident, CubDB resident (no force-load)")

# --- (2) all_loaded SET before ---------------------------------------------
before_set = :erpc.call(serve_node, :code, :all_loaded, [], 30_000) |> Enum.map(&elem(&1, 0)) |> MapSet.new()
IO.puts("serve :code.all_loaded BEFORE: #{MapSet.size(before_set)}")

# --- (3) db handle (resident fn since 2026-07-04, ancestor of deploy) -------
db = :erpc.call(serve_node, cs, :db_handle, [cs], 30_000)
IO.puts("db handle: #{inspect(db)}")

# --- (4) back_up (runs on the serve; db pid is local there) ----------------
t0 = System.monotonic_time(:millisecond)
res = :erpc.call(serve_node, CubDB, :back_up, [db, target], 600_000)
dt = System.monotonic_time(:millisecond) - t0
IO.puts("CubDB.back_up -> #{inspect(res)} in #{dt}ms")

# --- (5) all_loaded SET after + diff ---------------------------------------
after_set = :erpc.call(serve_node, :code, :all_loaded, [], 30_000) |> Enum.map(&elem(&1, 0)) |> MapSet.new()
IO.puts("serve :code.all_loaded AFTER:  #{MapSet.size(after_set)}  (delta #{MapSet.size(after_set) - MapSet.size(before_set)})")

newly = MapSet.difference(after_set, before_set) |> Enum.sort()
IO.puts("newly loaded during back_up: #{inspect(newly)}")

app_perturb = Enum.filter(newly, &String.starts_with?(Atom.to_string(&1), "Elixir.Commonplace."))
if app_perturb == [] do
  IO.puts("NON-PERTURBATION OK: zero working-tree Commonplace.* modules force-loaded by back_up")
else
  IO.puts("⚠️ PERTURBATION: back_up force-loaded working-tree app modules: #{inspect(app_perturb)}")
end

IO.puts("BACKUP_DONE target=#{target} result=#{inspect(res)}")
System.halt(0)
