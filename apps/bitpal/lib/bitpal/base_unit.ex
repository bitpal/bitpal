defprotocol BitPal.BaseUnit do
  @spec to_decimal(t) :: Decimal.t()
  def to_decimal(data)

  @spec to_smallest_unit(t) :: non_neg_integer
  def to_smallest_unit(data)
end
