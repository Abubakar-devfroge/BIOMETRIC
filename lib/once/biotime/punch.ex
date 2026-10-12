defmodule Once.Biotime.Punch do
  use Ash.Resource,
    otp_app: :once,
    domain: Once.Biotime,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "biotime_punches"
    repo Once.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :upsert do
      primary? true
      upsert? true
      upsert_identity :unique_biotime_id

      argument :biotime_id, :integer, allow_nil?: false
      argument :emp_code, :string, allow_nil?: false
      argument :punch_time, :naive_datetime, allow_nil?: false
      argument :punch_state, :string
      argument :verify_type, :integer
      argument :terminal_sn, :string
      argument :area_alias, :string

      change set_attribute(:biotime_id, arg(:biotime_id))
      change set_attribute(:emp_code, arg(:emp_code))
      change set_attribute(:punch_time, arg(:punch_time))
      change set_attribute(:punch_state, arg(:punch_state))
      change set_attribute(:verify_type, arg(:verify_type))
      change set_attribute(:terminal_sn, arg(:terminal_sn))
      change set_attribute(:area_alias, arg(:area_alias))
    end

    update :update do
      primary? true
      accept [:punch_time, :punch_state, :verify_type, :terminal_sn, :area_alias]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :biotime_id, :integer do
      allow_nil? false
      public? true
    end

    attribute :emp_code, :string do
      allow_nil? false
      public? true
    end

    attribute :punch_time, :naive_datetime do
      allow_nil? false
      public? true
    end

    attribute :punch_state, :string, public?: true
    attribute :verify_type, :integer, public?: true
    attribute :terminal_sn, :string, public?: true
    attribute :area_alias, :string, public?: true

    create_timestamp :inserted_at, public?: true
    update_timestamp :updated_at, public?: true
  end

  relationships do
    belongs_to :employee, Once.Biotime.Employee do
      destination_attribute :emp_code
      source_attribute :emp_code
      define_attribute? false
      public? true
    end
  end

  calculations do
    @doc """
    Calculates true Nairobi time (UTC+3) directly from inserted_at.
    Guarantees reliable timestamps even if physical hardware clocks drift.
    """
    calculate :effective_punch_time, :naive_datetime, expr(datetime_add(inserted_at, 3, :hour)),
      public?: true
  end

  identities do
    identity :unique_biotime_id, [:biotime_id]
  end
end
