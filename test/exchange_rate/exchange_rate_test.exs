defmodule BitPal.ExchangeRateTest do
  use ExUnit.Case, async: false
  alias BitPal.ExchangeRate
  alias BitPal.ExchangeRate.Result

  @bchusd {:bch, :usd}
  @bchusd_rate Decimal.from_float(815.27)
  @bcheur {:bch, :eur}
  @bcheur_rate Decimal.from_float(741.62)

  @supervisor BitPal.ExhangeRate.TaskSupervisor

  defmodule TestSubscriber do
    use GenServer

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    def subscribe(pair, opts \\ []) do
      GenServer.call(__MODULE__, {:subscribe, pair, opts})
    end

    def received() do
      GenServer.call(__MODULE__, :received)
    end

    def await_msg_count(count) do
      Task.async(__MODULE__, :sleep_until_count, [count])
      |> Task.await(50)

      {:ok, received()}
    end

    def sleep_until_count(count) do
      if Enum.count(received()) >= count do
        :ok
      else
        Process.sleep(5)
        sleep_until_count(count)
      end
    end

    @impl true
    def init(_opts) do
      {:ok, %{received: []}}
    end

    @impl true
    def handle_call({:subscribe, pair, opts}, _from, state) do
      ExchangeRate.subscribe(pair, opts)
      {:reply, :ok, state}
    end

    @impl true
    def handle_call(:received, _from, state) do
      {:reply, state.received, state}
    end

    @impl true
    def handle_info(msg, state) do
      {:noreply, Map.update!(state, :received, &[msg | &1])}
    end
  end

  defmodule TestBackend do
    @behaviour BitPal.ExchangeRate.Backend

    @impl true
    def name(), do: "test"

    @impl true
    def supported_pairs(), do: [{:bch, :usd}, {:bch, :eur}]

    @impl true
    def compute(_, opts) do
      if timeout = opts[:test_timeout] do
        Process.sleep(timeout)
      end

      if opts[:test_crash] do
        raise "boom"
      else
        score = Keyword.get(opts, :test_score, 2.0)

        {:ok,
         %Result{
           score: score,
           backend: __MODULE__,
           rate: Decimal.from_float(score)
         }}
      end
    end
  end

  setup tags do
    start_supervised!({Phoenix.PubSub, name: BitPal.PubSub})
    start_supervised!(BitPal.ProcessRegistry)
    start_supervised!({ExchangeRate, clear_interval: tags[:cache_clear_interval]})
    start_supervised!(TestSubscriber)
    :ok
  end

  test "direct request" do
    assert ExchangeRate.request(@bchusd) == {:ok, @bchusd_rate}
    assert ExchangeRate.require!(@bchusd) == @bchusd_rate
  end

  test "receive after subscribe" do
    TestSubscriber.subscribe(@bchusd)
    TestSubscriber.await_msg_count(1)
    assert TestSubscriber.received() == [{:exchange_rate, @bchusd, @bchusd_rate}]
    assert Enum.empty?(Task.Supervisor.children(@supervisor))
  end

  test "multiple rates" do
    TestSubscriber.subscribe(@bchusd)
    TestSubscriber.subscribe(@bcheur)
    TestSubscriber.await_msg_count(2)

    assert Enum.sort(TestSubscriber.received()) == [
             {:exchange_rate, @bcheur, @bcheur_rate},
             {:exchange_rate, @bchusd, @bchusd_rate}
           ]
  end

  test "multiple backends" do
    TestSubscriber.subscribe(@bchusd, backends: [BitPal.ExchangeRate.Kraken, TestBackend])
    TestSubscriber.await_msg_count(1)

    assert Enum.sort(TestSubscriber.received()) == [
             {:exchange_rate, @bchusd, @bchusd_rate}
           ]
  end

  test "multiple requests but only one response until done" do
    TestSubscriber.subscribe(@bchusd,
      backends: [TestBackend],
      test_timeout: :infinity,
      timeout: :infinity
    )

    Process.sleep(10)

    {:already_started, _} = ExchangeRate.async_request(@bchusd)
  end

  test "crashing" do
    TestSubscriber.subscribe(@bchusd, backends: [TestBackend], test_crash: true)
    Process.sleep(20)
    assert TestSubscriber.received() == []
    assert Enum.empty?(Task.Supervisor.children(@supervisor))
  end

  test "timeout" do
    TestSubscriber.subscribe(@bchusd,
      backends: [TestBackend],
      test_timeout: :infinity,
      timeout: 10
    )

    Process.sleep(20)
    assert TestSubscriber.received() == []
    assert Enum.empty?(Task.Supervisor.children(@supervisor))
  end

  @tag cache_clear_interval: 1
  test "permanent cache failsafe" do
    TestSubscriber.subscribe(@bchusd, backends: [TestBackend])
    TestSubscriber.await_msg_count(1)
    assert TestSubscriber.received() == [{:exchange_rate, @bchusd, Decimal.from_float(2.0)}]
    assert Enum.empty?(Task.Supervisor.children(@supervisor))

    ExchangeRate.async_request(@bchusd, backends: [TestBackend], test_crash: true)
    TestSubscriber.await_msg_count(2)

    assert TestSubscriber.received() == [
             {:exchange_rate, @bchusd, Decimal.from_float(2.0)},
             {:exchange_rate, @bchusd, Decimal.from_float(2.0)}
           ]
  end
end
