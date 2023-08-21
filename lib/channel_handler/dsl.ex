defmodule ChannelHandler.Dsl do
  defmodule Scope do
    @moduledoc false
    defstruct [:prefix, :plugs, :handlers]
  end

  defmodule Delegate do
    @moduledoc false
    defstruct [:prefix, :module]
  end

  defmodule Handle do
    @moduledoc false
    defstruct [:name, :function]
  end

  defmodule Event do
    @moduledoc false
    defstruct [:name, :module, :function]
  end

  defmodule Info do
    @moduledoc false
    defstruct [:message, :module, :function]
  end

  defmodule HandleMessage do
    @moduledoc false
    defstruct [:message, :function]
  end

  defmodule Plug do
    @moduledoc false
    defstruct [:plug, :options]
  end

  @plug %Spark.Dsl.Entity{
    name: :plug,
    describe: """
    Registers a plug for the current router/scope. Plugs are run in the
    order they are defined before the event handler.

    An optional argument can be passed as the options for the plug.
    """,
    target: Plug,
    args: [:plug, {:optional, :options, []}],
    schema: [
      plug: [
        type: {:spark_function_behaviour, ChannelHandler.Plug, {ChannelHandler.Plug.Function, 4}},
        required: true
      ],
      options: [type: :any, required: false]
    ],
    modules: [:plug]
  }

  @event %Spark.Dsl.Entity{
    name: :event,
    target: Event,
    args: [:name, :module, :function],
    schema: [
      name: [type: :string, required: true],
      module: [type: :atom, required: true],
      function: [type: :atom, required: true]
    ],
    modules: [:module]
  }

  @info %Spark.Dsl.Entity{
    name: :info,
    target: Info,
    args: [:message, :module, {:optional, :function, :handle_info}],
    schema: [
      message: [type: :any, required: true],
      module: [type: :atom, required: true],
      function: [type: :atom, required: true]
    ],
    modules: [:module]
  }

  @handle_message %Spark.Dsl.Entity{
    name: :handle_message,
    describe: """
    Defines a handler for the `message`. `function` must be an arity 2
    function taking the message, context and socket.

    #### Example

        handle_message {:created, post}, fn _context, socket ->
          Phoenix.Channel.push(socket, "posts", post)

          {:noreply, socket}
        end
    """,
    target: HandleMessage,
    args: [:message, :function],
    schema: [
      message: [type: :any, required: true],
      function: [type: {:fun, 2}, required: true]
    ]
  }

  @delegate %Spark.Dsl.Entity{
    name: :delegate,
    describe: """
    Defines a handler that delegates all events matching the `prefix` to the
    specified `module`'s `c:ChannelHandler.Handler.handle_in/4` callback.

    #### Example

        delegate "posts:", PostsHandler

        defmodule PostsHandler do
          def handle_in("create", payload, _context, socket) do
            post = Posts.create(payload)

            {:reply, {:ok, post}, socket}
          end
        end
    """,
    target: Delegate,
    args: [{:optional, :prefix, ""}, :module],
    schema: [
      prefix: [type: :string, required: true],
      module: [type: :atom, required: true]
    ],
    modules: [:module]
  }

  @handle %Spark.Dsl.Entity{
    name: :handle,
    describe: """
    Defines a handler for the `event`. `function` must be an arity 3 function
    taking the payload, context and socket.any()

    #### Example

        handle "create", fn payload, _context, socket ->
          post = create_post(payload)

          {:reply, post}
        end
    """,
    target: Handle,
    args: [:name, :function],
    schema: [
      name: [type: :string, required: true],
      function: [type: {:or, [{:fun, 3}, {:fun, 4}]}, required: true]
    ]
  }

  @scope %Spark.Dsl.Entity{
    name: :scope,
    target: Scope,
    args: [{:optional, :prefix, ""}],
    entities: [plugs: [@plug], handlers: [@event, @delegate, @handle]],
    schema: [
      prefix: [type: :string, required: false]
    ]
  }

  @join %Spark.Dsl.Section{
    name: :join,
    top_level?: true,
    describe: """
    Defines the `join/3` function for a Phoenix channel.

    If `channel/1` is also used, the channel name will be store in the socket
    assigns under the `:__channel__` key. This is useful if you have multiple
    channels and you need to perform runtime introspection, for example to map
    a channel name to an AsyncAPI channel name.
    """,
    schema: [
      channel: [
        type: :string,
        required: false,
        doc: """
        The channel path for this handler. By default this has no runtime effect,
        but can be used by plugs and handlers if necessary.

        The channel value is stored in the socket's `:__channel__` assign.
        """
      ],
      join: [
        type: {:fun, 3},
        required: false,
        doc: """
        The function to run in the channel's `join` callback.
        """
      ]
    ]
  }

  @router %Spark.Dsl.Section{
    name: :router,
    top_level?: true,
    describe: """
    Defines the `handle_in/3` functions for a Phoenix channel by matching on exact
    event names, or prefixes.

    #### Example

        # Adds a module plug to the list of plugs to be run before each event
        plug MyApp.ChannelPlugs.EnsureAuthenticated

        # Delegate all events starting with `"foo:"` to the `FooHandler` module
        delegate "foo:", FooHandler

        # Delegates `"create"` events to the `FooHandler.create/3` function
        event "create", FooHandler, :create

        # Defines an inline handler
        handle "delete", fn payload, context, socket ->
          result delete_post(payload)

          {:reply, result, socket}
        end

        # Defines a scope, which is useful to add plugs for a specific scope of
        # events
        scope "comments:" do
          # Adds a capture function as a plug to be run before each event in the
          scope
          plug &check_permission/4, :comment

          event "create", CommentsHandler, :create
        end
    """,
    entities: [
      @plug,
      @event,
      @delegate,
      @handle,
      @info,
      @handle_message,
      @scope
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@join, @router]

  @moduledoc """
  ## Index
  #{Spark.Dsl.Extension.doc_index([@join, @router])}

  ## Docs
  #{Spark.Dsl.Extension.doc([@join, @router])}
  """
end
