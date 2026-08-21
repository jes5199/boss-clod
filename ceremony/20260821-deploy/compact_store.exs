# §3-model deliberate compaction of the commits store. STOPPED serve, sole
# flock holder. Usage: mix run --no-start compact_store.exs -- <PARENT data_dir>
#
# The 17G is append-only write amplification from the pass-4 chunked
# migration (~198 put_multi transactions, each appending its btree path
# rewrites), NOT data: the run wrote 395,307 tiny rows. Compaction rewrites
# ONLY live data into the next-generation .cub file, then removes the old
# one. Scratch space needed ~= live data size (~2.4G).
#
# Controls: CubDB.size (ENTRY COUNT) must be IDENTICAL before and after —
# that is the data-preserved verdict. File size is the reclaim reading,
# expected 17G -> ~2.4G. A count mismatch is STOP-THE-LINE.

data_dir = System.argv() |> Enum.reject(&(&1 == "--")) |> List.first()
store_dir = Path.join(data_dir, "commits")

unless File.dir?(store_dir), do: raise("no store at #{store_dir} — pass the PARENT dir")

cubs_before = store_dir |> Path.join("*.cub") |> Path.wildcard()
bytes_before = cubs_before |> Enum.map(&File.stat!(&1).size) |> Enum.sum()
IO.puts("cub files before: #{inspect(cubs_before)} total #{bytes_before} bytes")

# auto_compact: false — this run compacts EXPLICITLY, once, observed.
{:ok, db} = CubDB.start_link(data_dir: store_dir, auto_file_sync: true, auto_compact: false)

entries_before = CubDB.size(db)
IO.puts("entry count before: #{entries_before}")

:ok = CubDB.compact(db)
IO.puts("compaction started #{DateTime.utc_now() |> DateTime.to_iso8601()}")

wait = fn wait ->
  if CubDB.compacting?(db) do
    Process.sleep(5_000)
    wait.(wait)
  end
end

wait.(wait)
IO.puts("compaction finished #{DateTime.utc_now() |> DateTime.to_iso8601()}")

entries_after = CubDB.size(db)
current = CubDB.current_db_file(db)
IO.puts("entry count after: #{entries_after}")
IO.puts("current db file: #{current} (#{File.stat!(current).size} bytes)")

CubDB.stop(db)

cubs_after = store_dir |> Path.join("*.cub") |> Path.wildcard()
bytes_after = cubs_after |> Enum.map(&File.stat!(&1).size) |> Enum.sum()
IO.puts("cub files after: #{inspect(cubs_after)} total #{bytes_after} bytes")

if entries_after == entries_before do
  IO.puts("DATA-PRESERVED: entry count #{entries_before} == #{entries_after}")
  IO.puts("COMPACT_DONE reclaimed #{bytes_before - bytes_after} bytes")
  System.halt(0)
else
  IO.puts(:stderr, "STOP-THE-LINE: entry count CHANGED #{entries_before} -> #{entries_after}")
  System.halt(3)
end
