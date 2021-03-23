defprotocol BitPal.BaseUnit do
  @spec to_decimal(t) :: Decimal
  def to_decimal(data)
end
