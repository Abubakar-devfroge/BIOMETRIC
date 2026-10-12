defmodule Once.Biotime.Client do
  @moduledoc """
  HTTP Client for communicating with the BioTime Cloud API.
  """

  @doc """
  Builds a base `Req.Request` struct, attaching the JWT authorization header when provided.
  """
  def client(token \\ nil) do
    config = Application.get_env(:once, :biotime, [])
    base_url = Keyword.get(config, :base_url, "https://thetribe.biotimecloud.com")
    headers = if token, do: [{"authorization", "JWT #{token}"}], else: []

    Req.new(base_url: base_url, headers: headers)
  end

  @doc """
  Authenticates using company, email, and password loaded from application runtime config.
  """
  def authenticate do
    config = Application.fetch_env!(:once, :biotime)
    authenticate(config[:company], config[:email], config[:password])
  end

  @doc """
  Authenticates with explicit company, email, and password to retrieve a JWT session token.
  """
  def authenticate(company, email, password) do
    payload = %{
      company: company,
      email: email,
      password: password
    }

    Req.post(client(), url: "/jwt-api-token-auth/", json: payload)
    |> handle_response(fn body ->
      case body do
        %{"token" => token} -> {:ok, token}
        _ -> {:error, {:unexpected_payload, body}}
      end
    end)
  end

  @doc """
  Lists attendance transactions / punch records.
  Supports params: `start_time`, `end_time`, `emp_code`, `page`, `page_size`, etc.
  """
  def list_transactions(token, params \\ %{}) do
    Req.get(client(token), url: "/iclock/api/transactions/", params: params)
    |> handle_response()
  end

  @doc """
  Lists employees with their basic profile details (emp_code, names, department, card_no).
  Supports params: `page`, `page_size`, `emp_code`, `department`, etc.
  """
  def list_employees(token, params \\ %{}) do
    Req.get(client(token), url: "/personnel/api/employees/", params: params)
    |> handle_response()
  end

  @doc """
  Lists company departments/branches.
  """
  def list_departments(token, params \\ %{}) do
    Req.get(client(token), url: "/personnel/api/departments/", params: params)
    |> handle_response()
  end

  @doc """
  Lists terminal devices registered in BioTime.
  """
  def list_terminals(token, params \\ %{}) do
    Req.get(client(token), url: "/iclock/api/terminals/", params: params)
    |> handle_response()
  end

  # --- Internal Helpers ---

  defp handle_response(req_result, custom_extractor \\ fn body -> {:ok, body} end) do
    case req_result do
      {:ok, %{status: 200, body: body}} ->
        custom_extractor.(body)

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, exception} ->
        {:error, exception}
    end
  end
end
