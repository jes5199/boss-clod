# Finding 3 (pin leg) — full history sweep: project_at EVERY commit of every doc; a pin
# that trips returns {:unknown,{:mixed_plane,_}} and is emitted as a HIT. This is the
# authoritative live pin count. The run() gate runs the fixture positive control first
# (head CLEAN / history TRIPS) and aborts if the tripwire can't fire.
alias Commonplace.Store.CommitStore
alias Commonplace.Projection.MixedPlaneHistory

copy_dir = System.argv() |> Enum.reject(&(&1 == "--")) |> List.first()
Application.put_env(:commonplace, :reader_lazy_snapshot_enabled, false)
{:ok, _} = CommitStore.start_link(name: :probe_store, data_dir: copy_dir)

cp = "#{copy_dir}/../mp_checkpoint.json"

case MixedPlaneHistory.run(
       store: :probe_store,
       checkpoint_path: cp,
       expected_known_positives: [],
       scan_strategy: :incremental,
       max_concurrency: 6,
       progress_every: 500
     ) do
  {:ok, summary} -> IO.puts("MP_SWEEP_SUMMARY: #{inspect(summary, limit: :infinity)}")
  {:error, reason} -> IO.puts("MP_SWEEP_ERROR: #{inspect(reason)}")
end
IO.puts("MP_SWEEP_DONE")
System.halt(0)
