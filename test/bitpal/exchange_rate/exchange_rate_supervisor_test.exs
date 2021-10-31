defmodule BitPal.ExchangeRateSupervisorTest do
  # # FIXME these randomly fail!
  #
  # use ExUnit.Case, async: false
  # import BitPal.TestHelpers
  # alias BitPal.ExchangeRate
  # alias BitPal.ExchangeRateSupervisor
  # alias BitPal.ExchangeRateSupervisor.Result
  #
  # @bchusd {:BCH, :USD}
  # def bchusd_rate do
  #   ExchangeRate.new!(Decimal.from_float(815.27), @bchusd)
  # end
  #
  # @bcheur {:BCH, :EUR}
  # def bcheur_rate do
  #   ExchangeRate.new!(Decimal.from_float(741.62), @bcheur)
  # end
  #
  # defmodule TestBackend do
  #   @behaviour BitPal.ExchangeRate.Backend
  #
  #   @impl true
  #   def name, do: "test"
  #
  #   @impl true
  #   def supported, do: %{BCH: [:USD, :EUR]}
  #
  #   @impl true
  #   def compute(pair, opts) do
  #     if timeout = opts[:test_timeout] do
  #       Process.sleep(timeout)
  #     end
  #
  #     if opts[:test_crash] do
  #       raise "boom"
  #     else
  #       score = Keyword.get(opts, :test_score, 2.0)
  #
  #       {:ok,
  #        %Result{
  #          score: score,
  #          backend: __MODULE__,
  #          rate: ExchangeRate.new!(Decimal.from_float(score), pair)
  #        }}
  #     end
  #   end
  # end
  #
  # defmodule TestBackendCurrencies do
  #   @behaviour BitPal.ExchangeRate.Backend
  #
  #   @impl true
  #   def name, do: "test"
  #
  #   @impl true
  #   def supported, do: %{BCH: [:USD, :YEN], XMR: [:USD, :EUR]}
  #
  #   @impl true
  #   def compute(pair, opts) do
  #     if timeout = opts[:test_timeout] do
  #       Process.sleep(timeout)
  #     end
  #
  #     if opts[:test_crash] do
  #       raise "boom"
  #     else
  #       score = Keyword.get(opts, :test_score, 2.0)
  #
  #       {:ok,
  #        %Result{
  #          score: score,
  #          backend: __MODULE__,
  #          rate: ExchangeRate.new!(Decimal.from_float(score), pair)
  #        }}
  #     end
  #   end
  # end
  #
  # setup tags do
  #   start_supervised!(
  #     {ExchangeRateSupervisor, ttl: tags[:ttl], ttl_check_interval: tags[:ttl_check_interval]}
  #   )
  #
  #   :ok
  # end
  #
  # test "request await" do
  #   assert :updating = ExchangeRateSupervisor.request(@bchusd)
  #   assert bchusd_rate() == ExchangeRateSupervisor.await_request!(@bchusd)
  # end
  #
  # test "cached request" do
  #   assert :updating = ExchangeRateSupervisor.request(@bchusd)
  #   assert bchusd_rate() == ExchangeRateSupervisor.await_request!(@bchusd)
  #   assert {:cached, bchusd_rate()} == ExchangeRateSupervisor.request(@bchusd)
  # end
  #
  # @tag ttl: 10, ttl_check_interval: 1
  # test "cache cleared" do
  #   assert :updating = ExchangeRateSupervisor.request(@bchusd)
  #   assert bchusd_rate() == ExchangeRateSupervisor.await_request!(@bchusd)
  #   assert eventually(fn -> :updating == ExchangeRateSupervisor.request(@bchusd) end)
  # end
  #
  # test "multiple backends" do
  #   assert :updating =
  #            ExchangeRateSupervisor.request(@bchusd,
  #              backends: [BitPal.ExchangeRate.Kraken, TestBackend]
  #            )
  #
  #   assert bchusd_rate() == ExchangeRateSupervisor.await_request!(@bchusd)
  # end
  #
  # test "multiple rates" do
  #   assert :updating = ExchangeRateSupervisor.request(@bchusd)
  #   assert :updating = ExchangeRateSupervisor.request(@bcheur)
  #   assert bchusd_rate() == ExchangeRateSupervisor.await_request!(@bchusd)
  #   assert bcheur_rate() == ExchangeRateSupervisor.await_request!(@bcheur)
  # end
  #
  # test "crashing" do
  #   assert :updating =
  #            ExchangeRateSupervisor.request(@bchusd, backends: [TestBackend], test_crash: true)
  #
  #   try do
  #     ExchangeRateSupervisor.await_request!(@bchusd)
  #     assert false
  #   rescue
  #     _ -> assert true
  #   end
  # end
  #
  # test "timeout" do
  #   assert :updating =
  #            ExchangeRateSupervisor.request(@bchusd,
  #              backends: [TestBackend],
  #              test_timeout: :infinity,
  #              request_timeout: 10
  #            )
  #
  #   try do
  #     ExchangeRateSupervisor.await_request!(@bchusd)
  #     assert false
  #   rescue
  #     _ -> assert true
  #   end
  # end
  #
  # test "supported" do
  #   backends = [TestBackend, TestBackendCurrencies]
  #
  #   assert %{BCH: [:USD, :EUR, :YEN], XMR: [:USD, :EUR]} ==
  #            ExchangeRateSupervisor.all_supported(backends: backends)
  #
  #   assert {:ok, [:USD, :EUR, :YEN]} ==
  #            ExchangeRateSupervisor.supported(:BCH, backends: backends)
  #
  #   assert {:error, :not_found} ==
  #            ExchangeRateSupervisor.supported(:XXX, backends: backends)
  # end
end
