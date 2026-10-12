import Config

# ## BioTime Cloud Configuration
config :once, :biotime,
  base_url: System.get_env("BIOTIME_BASE_URL", "https://thetribe.biotimecloud.com"),
  company: System.get_env("BIOTIME_COMPANY", "thetribe"),
  email: System.get_env("BIOTIME_EMAIL", "abubakar@craftinc.dev"),
  password: System.get_env("BIOTIME_PASSWORD", "Abuyezma44@abu")

# ## Web Server Port & Process Handling
# Automatically run the web server if PHX_SERVER is set or if running in prod release
if System.get_env("PHX_SERVER") || config_env() == :prod do
  config :once, OnceWeb.Endpoint, server: true
end

if config_env() == :dev do
  config :once, OnceWeb.Endpoint,
    http: [port: String.to_integer(System.get_env("PORT", "4000"))],
    live_reload: [
      web_console_logger: true,
      patterns: [
        ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$"E,
        ~r"priv/gettext/.*\.po$"E,
        ~r"lib/once_web/router\.ex$"E,
        ~r"lib/once_web/(controllers|live|components)/.*\.(ex|heex)$"E
      ]
    ]
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  # DigitalOcean databases typically require SSL. If DATABASE_URL specifies sslmode or ECTO_SSL=true,
  # enable SSL options without breaking plain local postgres connections.
  use_ssl? =
    System.get_env("ECTO_SSL") in ~w(true 1) or
      String.contains?(database_url, "sslmode=require")

  ssl_opts =
    if use_ssl? do
      [ssl: true, ssl_opts: [verify: :verify_none]]
    else
      []
    end

  config :once, Once.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6,
    parameters: [timezone: "UTC"] ++ ssl_opts

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  token_signing_secret =
    System.get_env("TOKEN_SIGNING_SECRET") || secret_key_base

  config :once,
    token_signing_secret: token_signing_secret

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "8080")

  config :once, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :once, OnceWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base
end