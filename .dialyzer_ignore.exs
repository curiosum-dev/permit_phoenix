[
  # Ecto types are from optional dependencies
  ~r/unknown_type.*Ecto\.Query\.t\/0/,
  ~r/unknown_type.*Permit\.Ecto\.Types\.base_query\/0/,
  ~r/unknown_type.*Permit\.Ecto\.Types\.finalize_query\/0/,

  # These functions are designed to always raise - not an error
  ~r/Function handle_not_found\/2 only terminates with explicit exception/,

  # Mix.Project.config/0 is called in macros at compile time, not runtime
  ~r/Function Mix\.Project\.config\/0 does not exist/,

  # @permit_ecto_available? is always true in test env but false positive in dialyzer
  ~r/lib\/permit_phoenix\/plug\.ex:1:pattern_match/,

  # Test support files use optional dependencies (Ecto, Permit.Ecto)
  # that are not in the PLT when running in test mode
  ~r/test\/support.*unknown_function/,
  ~r/test\/support.*unknown_type/,
  ~r/test\/support.*callback_info_missing/
]
