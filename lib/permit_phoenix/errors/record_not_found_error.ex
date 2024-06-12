defmodule PermitPhoenix.RecordNotFoundError do
  defexception [:message, plug_status: 404]
end
