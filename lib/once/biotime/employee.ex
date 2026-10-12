defmodule Once.Biotime.Employee do
  use Ash.Resource,
    domain: Once.Biotime,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "biotime_employees"
    repo Once.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      upsert? true
      upsert_identity :unique_emp_code

      upsert_fields [
        :first_name,
        :last_name,
        :department_name,
        :area_name,
        :enable_att,
        :biotime_id
      ]
    end

    update :update do
      primary? true
      accept [:first_name, :last_name, :department_name, :area_name, :enable_att]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :emp_code, :string do
      allow_nil? false
      public? true
    end

    attribute :first_name, :string, public?: true
    attribute :last_name, :string, public?: true
    attribute :department_name, :string, public?: true
    attribute :area_name, :string, public?: true
    attribute :biotime_id, :string, public?: true
    attribute :enable_att, :boolean, default: true, public?: true

    create_timestamp :inserted_at, public?: true
    update_timestamp :updated_at, public?: true
  end

  relationships do
    has_many :punches, Once.Biotime.Punch do
      destination_attribute :emp_code
      source_attribute :emp_code
      public? true
    end
  end

  calculations do
    calculate :full_name,
              :string,
              expr(
                if is_nil(last_name) or last_name == "" do
                  first_name
                else
                  first_name <> " " <> last_name
                end
              ), public?: true

    calculate :today_clock_in, :naive_datetime, {Once.Biotime.Calculations.ClockIn, []} do
      argument :start_date, :date, allow_nil?: true
      argument :end_date, :date, allow_nil?: true
      public? true
    end

    calculate :today_clock_out, :naive_datetime, {Once.Biotime.Calculations.ClockOut, []} do
      argument :start_date, :date, allow_nil?: true
      argument :end_date, :date, allow_nil?: true
      public? true
    end
  end

  identities do
    identity :unique_emp_code, [:emp_code]
  end
end
