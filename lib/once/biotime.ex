defmodule Once.Biotime do
  use Ash.Domain

  resources do
    resource Once.Biotime.Employee
    resource Once.Biotime.Punch
  end
end
