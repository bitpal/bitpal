defmodule BitPalSchemas.InvoiceStatusTest do
  use ExUnit.Case
  alias BitPalSchemas.InvoiceStatus

  describe "casts" do
    test "straight up valid casts" do
      ok = [
        :draft,
        :open,
        {:open, :underpaid},
        {:processing, :verifying},
        {:processing, :confirming},
        {:uncollectible, :expired},
        {:uncollectible, :canceled},
        {:uncollectible, :timed_out},
        {:uncollectible, :double_spent},
        {:uncollectible, :failed},
        :void,
        {:void, :expired},
        {:void, :canceled},
        {:void, :double_spent},
        {:void, :timed_out},
        {:void, :verifying},
        {:void, :confirming},
        {:void, :failed},
        :draft,
        :paid,
        {:paid, :overpaid}
      ]

      for x <- ok do
        assert {:ok, ^x} = InvoiceStatus.cast(x)
      end
    end

    test "transformative casts" do
      assert {:ok, :draft} = InvoiceStatus.cast({:draft, nil})
      assert :draft = InvoiceStatus.cast!({:draft, nil})
    end

    test "invalid casts" do
      invalid = [
        :xx,
        "open",
        :processing,
        :uncollectible,
        {:open, :overpaid},
        {:paid, :underpaid},
        {:uncollectible, :confirming},
        {:xx, :expired},
        {:void, :xx}
      ]

      for x <- invalid do
        assert :error = InvoiceStatus.cast(x)
      end
    end
  end

  describe "transitions" do
    test "validate_transition" do
      {:ok, _} = InvoiceStatus.validate_transition(:draft, :open)
      {:ok, _} = InvoiceStatus.validate_transition(:open, {:processing, :verifying})
      {:ok, _} = InvoiceStatus.validate_transition(:open, {:processing, :confirming})
      {:ok, _} = InvoiceStatus.validate_transition({:open, :underpaid}, {:processing, :verifying})

      {:ok, _} =
        InvoiceStatus.validate_transition({:open, :underpaid}, {:processing, :confirming})

      {:ok, _} = InvoiceStatus.validate_transition({:processing, :confirming}, :paid)
      {:ok, _} = InvoiceStatus.validate_transition({:processing, :confirming}, {:paid, :overpaid})

      {:ok, _} =
        InvoiceStatus.validate_transition({:processing, :confirming}, {:uncollectible, :expired})

      {:ok, _} = InvoiceStatus.validate_transition({:uncollectible, :expired}, {:void, :expired})
      {:ok, _} = InvoiceStatus.validate_transition({:uncollectible, :expired}, :void)

      {:error, _} = InvoiceStatus.validate_transition(:xxx, :open)
      {:error, _} = InvoiceStatus.validate_transition(:open, :processing)
      {:error, _} = InvoiceStatus.validate_transition(:draft, :xxx)
      {:error, _} = InvoiceStatus.validate_transition(:open, {:processing, :xxx})
      {:error, _} = InvoiceStatus.validate_transition({:uncollectible, :expired}, {:void, :xxx})
    end

    test "validate_state_transition" do
      states = [:draft, :open, :processing, :uncollectible, :void, :paid]

      valid = %{
        :draft => [:open],
        :open => [:processing, :paid, :uncollectible, :void],
        :processing => [:paid, :uncollectible],
        :uncollectible => [:paid, :void]
      }

      for from <- states do
        for to <- states do
          expected = from == to || Enum.member?(Map.get(valid, from, []), to)
          got = InvoiceStatus.validate_state_transition(from, to)

          if expected do
            assert :ok = got
          else
            assert {:error, _} = got
          end
        end
      end
    end
  end
end
