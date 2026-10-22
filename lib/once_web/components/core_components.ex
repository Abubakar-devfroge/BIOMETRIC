defmodule OnceWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as tables, forms, and
  inputs. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The foundation for styling is Tailwind CSS, a utility-first CSS framework,
  augmented with daisyUI, a Tailwind CSS plugin that provides UI components
  and themes. Here are useful references:

    * [daisyUI](https://daisyui.com/docs/intro/) - a good place to get
      started and see the available components.

    * [Tailwind CSS](https://tailwindcss.com) - the foundational framework
      we build on. You will use it for layout, sizing, flexbox, grid, and
      spacing.

    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

    * [Phoenix.Component](https://phoenix-live-view.hexdocs.pm/Phoenix.Component.html) -
      the component system used by Phoenix. Some components, such as `<.link>`
      and `<.form>`, are defined there.

  """
  use Phoenix.Component
  use Gettext, backend: OnceWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash
        id="welcome-back"
        kind={:info}
        phx-mounted={show("#welcome-back") |> JS.remove_attribute("hidden")}
        hidden
      >
        Welcome Back!
      </.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="fixed top-4 right-4 z-50"
      {@rest}
    >
      <div class={[
        "flex w-80 sm:w-96 max-w-80 sm:max-w-96 text-wrap items-start gap-3 rounded-lg border p-4 shadow-lg backdrop-blur cursor-pointer",
        "bg-white/95 dark:bg-zinc-900/95",
        @kind == :info && "border-zinc-200 dark:border-zinc-700",
        @kind == :error && "border-red-200 dark:border-red-900"
      ]}>
        <.icon
          :if={@kind == :info}
          name="hero-check-circle"
          class="size-5 shrink-0 text-emerald-600 dark:text-emerald-400"
        />
        <.icon
          :if={@kind == :error}
          name="hero-exclamation-triangle"
          class="size-5 shrink-0 text-red-600 dark:text-red-400"
        />
        <div>
          <p :if={@title} class="font-semibold text-zinc-900 dark:text-zinc-100">{@title}</p>
          <p class="text-sm text-zinc-700 dark:text-zinc-300">{msg}</p>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled type)
  attr :class, :any
  attr :variant, :string, values: ~w(primary)
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variants = %{
      "primary" =>
        "bg-indigo-600 border border-indigo-600 text-white shadow-xs hover:bg-indigo-500 focus-visible:outline-indigo-600",
      nil =>
        "border border-zinc-300 bg-white text-zinc-800 shadow-xs hover:bg-zinc-50 focus-visible:outline-indigo-600 dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-100 dark:hover:bg-zinc-700"
    }

    assigns =
      assign_new(assigns, :class, fn ->
        [
          "inline-flex cursor-pointer items-center justify-center gap-2 rounded-lg px-3.5 py-2 text-sm font-semibold transition-colors duration-150 focus-visible:outline-2 focus-visible:outline-offset-2 disabled:pointer-events-none disabled:opacity-50",
          Map.fetch!(variants, assigns[:variant])
        ]
      end)

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as radio, are best
  written directly in your templates.

  ## Examples

  ```heex
  <.input field={@form[:email]} type="email" />
  <.input name="my-input" errors={["oh no!"]} />
  ```

  ## Select type

  When using `type="select"`, you must pass the `options` and optionally
  a `value` to mark which option should be preselected.

  ```heex
  <.input field={@form[:user_type]} type="select" options={["Admin": "admin", "User": "user"]} />
  ```

  For more information on what kind of data can be passed to `options` see
  [`options_for_select`](https://phoenix-html.hexdocs.pm/Phoenix.HTML.Form.html#options_for_select/2).
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :any, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :any, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="mb-2">
      <label for={@id} class="flex items-center gap-2">
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class={@class || "h-4 w-4 cursor-pointer rounded accent-indigo-600"}
          {@rest}
        />
        <span :if={@label} class="text-sm font-medium text-zinc-700 dark:text-zinc-300">{@label}</span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="mb-2">
      <label for={@id}>
        <span :if={@label} class="mb-1 block text-sm font-medium text-zinc-700 dark:text-zinc-300">{@label}</span>
        <select
          id={@id}
          name={@name}
          class={[
            @class ||
              "w-full cursor-pointer rounded-lg border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-900 shadow-xs focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/30 focus:outline-none dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-100",
            @errors != [] && (@error_class || "border-red-400 dark:border-red-500")
          ]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="mb-2">
      <label for={@id}>
        <span :if={@label} class="mb-1 block text-sm font-medium text-zinc-700 dark:text-zinc-300">{@label}</span>
        <textarea
          id={@id}
          name={@name}
          class={[
            @class ||
              "w-full rounded-lg border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-900 shadow-xs placeholder:text-zinc-400 focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/30 focus:outline-none dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-100",
            @errors != [] && (@error_class || "border-red-400 dark:border-red-500")
          ]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div class="mb-2">
      <label for={@id}>
        <span :if={@label} class="mb-1 block text-sm font-medium text-zinc-700 dark:text-zinc-300">{@label}</span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            @class ||
              "w-full rounded-lg border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-900 shadow-xs placeholder:text-zinc-400 focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/30 focus:outline-none dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-100",
            @errors != [] && (@error_class || "border-red-400 dark:border-red-500")
          ]}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # Helper used by inputs to generate form errors
  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex gap-2 items-center text-sm text-red-600 dark:text-red-400">
      <.icon name="hero-exclamation-circle" class="size-5" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  slot :inner_block, required: true
  attr :subtitle, :string, default: nil
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[
      @actions != [] && "flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between sm:gap-6",
      "pb-2"
    ]}>
      <div>
        <h1 class="text-2xl font-semibold tracking-tight text-zinc-900 dark:text-zinc-100">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle} class="mt-1 text-sm text-zinc-500 dark:text-zinc-400">
          {@subtitle}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-xs dark:border-zinc-800 dark:bg-zinc-900">
      <table class="w-full text-sm text-left text-zinc-900 dark:text-zinc-100">
        <thead>
          <tr class="border-b border-zinc-200 bg-zinc-50 text-xs font-medium uppercase tracking-wider text-zinc-500 dark:border-zinc-800 dark:bg-zinc-800/60 dark:text-zinc-400">
            <th :for={col <- @col} class="px-4 py-3">{col[:label]}</th>
            <th :if={@action != []}>
              <span class="sr-only">{gettext("Actions")}</span>
            </th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}
          class="divide-y divide-zinc-200 dark:divide-zinc-800"
        >
          <tr
            :for={row <- @rows}
            id={@row_id && @row_id.(row)}
            class="transition-colors duration-100 hover:bg-zinc-50 dark:hover:bg-zinc-800/50"
          >
            <td
              :for={col <- @col}
              phx-click={@row_click && @row_click.(row)}
              class={[@row_click && "hover:cursor-pointer", "px-4 py-3.5"]}
            >
              {render_slot(col, @row_item.(row))}
            </td>
            <td :if={@action != []} class="w-0 px-4 py-3.5 font-medium">
              <div class="flex gap-3">
                <%= for action <- @action do %>
                  {render_slot(action, @row_item.(row))}
                <% end %>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <div class="rounded-xl border border-zinc-200 bg-white shadow-xs dark:border-zinc-800 dark:bg-zinc-900">
      <ul class="flex flex-col divide-y divide-zinc-200 dark:divide-zinc-800">
        <li
          :for={item <- @item}
          class="flex flex-col gap-1 px-5 py-4 sm:flex-row sm:items-center sm:justify-between sm:gap-6"
        >
          <span class="text-sm text-zinc-500 dark:text-zinc-400">{item.title}</span>
          <span class="text-sm font-medium text-zinc-900 dark:text-zinc-100 sm:text-right">
            {render_slot(item)}
          </span>
        </li>
      </ul>
    </div>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(OnceWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(OnceWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
