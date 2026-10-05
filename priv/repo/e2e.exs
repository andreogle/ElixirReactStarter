# =============================================================================
# E2E reset, run by the Playwright global setup (assets/e2e/global-setup.ts)
# before the suite.
#
# Each test deletes the accounts it made when it ends, pass or fail, through
# the dev-only `DELETE /dev/e2e/users` (see assets/e2e/fixtures.ts), so a
# clean run leaves nothing behind. This removes what a crashed or interrupted
# run left: every account with an `e2e-test-…` email
# (`ElixirReactStarter.E2EFixtures.reset/0`). Nothing else is touched, so
# ordinary dev data survives.
#
# If your app grows fixtures that every spec relies on (an admin account,
# reference data, …), create them here idempotently (get-or-create).
#
# Separate from seeds.exs because it deletes data — seeds.exs must stay safe
# to run in any environment. Refuses to run outside dev/test, and without
# :dev_routes (the same flag that exposes the /dev/e2e endpoints).
# =============================================================================

unless Mix.env() in [:dev, :test] do
  raise """
  priv/repo/e2e.exs is a destructive fixture script and must NEVER run in \
  production. Refusing to run in MIX_ENV=#{Mix.env()}.
  """
end

unless Application.get_env(:elixir_react_starter, :dev_routes, false) do
  raise """
  priv/repo/e2e.exs requires :dev_routes to be enabled (the same config that \
  exposes the /dev/e2e endpoints). Refusing to run.
  """
end

require Logger

count = ElixirReactStarter.E2EFixtures.reset()
Logger.info("E2E reset: removed #{count} leftover test account(s).")
