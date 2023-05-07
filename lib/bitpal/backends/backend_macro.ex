# defmodule BitPal.BackendMacro do
#   defmacro def_call(name, args) do
#     quote do
#       def unquote(name)(unquote_splicing(args)) do
#         try do
#           backend.unquote(name)(pid, unquote_splicing(args))
#         catch
#           :exit, _reason -> {:error, :not_found}
#         end
#       end
#     end
#   end
# end
#
