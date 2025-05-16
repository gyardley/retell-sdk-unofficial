# RetellAI Ruby SDKUnofficial

This unofficial Ruby library for the RetellAI SDK provides convenient access to the Retell REST API from any Ruby 3.0+ application. See the [official API documentation](https://docs.retellai.com/api-references/) for conplete details.

Unofficial means unofficial - no one involved with this SDK is affiliated with RetellAI in any way, apart from being happy customers and consumers of their API.

I believe this SDK is compliant with the OpenAPI specification for the RetellAI API, which is used by their Python and Node.js SDKs. However, I don't personally use every endpoint and the SDK has not been formally audited for correctness. Your corrections and contributions are welcome.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add retell-sdk-unofficial

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install retell-sdk-unofficial

## Usage

```ruby
require 'retell/sdk/unofficial'

# Initialize the client with your API key
client = Retell::SDK::Unofficial.new(api_key: 'your_api_key')
```

See the [official API documentation](https://docs.retellai.com/api-references/) for all API endpoints and their required and optional parameters, but here's the basic API calls (without parameters):

```ruby
client.agent.create
client.agent.retrieve
client.agent.list
client.agent.update
client.agent.delete

client.call.create_phone_call
client.call.create_web_call
client.call.register
client.call.retrieve
client.call.list

client.retell_llm.create
client.retell_llm.retrieve
client.retell_llm.list
client.retell_llm.update
client.retell_llm.delete

client.phone_number.create
client.phone_number.import
client.phone_number.retrieve
client.phone_number.list
client.phone_number.update
client.phone_number.delete

client.webhook.verify

client.voice.retrieve
client.voice.list

client.concurrency.retrieve
```

API path parameters are positional arguments, while parameters to be included in the query string (if a GET) or as JSON inthe body of the request (if a POST or PATCH) are keyword arguments.

Examples:

```ruby
# List all RetellAI agents
agents = client.agent.list

# Retrieve a specific agent
agent = client.agent.retrieve('agent_id_here') # URL path parameter, positional argument

# Update an agent
agent = client.agent.update('agent_id_here', name: 'New Agent Name') # name is sent as JSON
```

The `retrieve`, `update`, and `delete` methods for each resource can accept either the resource object itself or the resource's ID as a parameter. For example:

```ruby
# Retrieve a specific agent
agent = client.agent.retrieve('agent_id_here')

# Update that agent, passing in the agent object instead of the agent ID
agent = client.agent.update(agent, name: 'New Agent Name')
```

Note that not every resource supports every method.

When supported, the `retrieve`, `update`, and `delete` methods can also be called directly on the resource object itself.

```ruby
# Retrieve a specific agent
agent = client.agent.retrieve('agent_id_here')

# Update that agent by calling the `update` method on the agent directly
agent.update(name: 'New Agent Name')

# Delete that agent by calling the `delete` method on the agent directly
agent.delete
```

If the resource supports an `update` method, instances of that resource can be updated locally and then `update` called to persist the changes with an API call.

```ruby
# Create an agent
agent = client.agent.create(
  name: 'Boring Agent Name',
  llm_websocket_url: "wss://your-websocket-endpoint",
  voice_id: "11labs-Adrian"
)

# Update the agent's name locally
agent.name = 'Better Agent Name'

# Changes to local objects are not automatically sent to the RetellAI API
agent = agent.retrieve
agent.name # => 'Boring Agent Name'

# To push the changes to the RetellAI API, call `update`
agent.name = 'Even Better Agent Name'
agent.update

agent.name # => 'Even Better Agent Name'
agent = agent.retrieve
agent.name # => 'Even Better Agent Name'
```

It's possible to update an instance of a resource locally and then call `update` with additional updates; both updates will be applied. Parameters passed to `update` will overwrite local changes.

```ruby
phone_number.nickname = "New Nickname "
phone_number.update(inbound_agent_id: "new_agent_id")

phone_number.nickname # => "New Nickname"
phone_number.inbound_agent_id # => "new_agent_id"

agent.agent_name = "Also new"
agent.update(agent_name: "None more new")
agent.agent_name # => "None more new"
```

A few things have been given aliases for ease of use.

First, calling the plural form of an object is the same as calling `list` on that object:

```ruby
# These do the same thing:
client.agent.list
client.agents

# So do these:
client.voice.list
client.voices
```

Second, a few redundant attribute names have been given aliases.

```ruby
client.agent.id # an alias for client.agent.agent_id

client.agent.name # an alias for client.agent.agent_name
client.agent.name = "New Name" # equivalent to client.agent.agent_name = "New Name"

client.agent.voice # an alias for client.agent.voice_id
client.agent.voice = "voice-id" # equivalent to client.agent.voice_id = "voice-id"

client.agent.fallback_voices # an alias for client.agent.fallback_voice_ids
# equivalent to client.agent.fallback_voice_ids = ["voice-id-1", "voice-id-2"]
client.agent.fallback_voices = ["voice-id-1", "voice-id-2"]

client.call.id # an alias for client.call.call_id
client.call.agent # an alias for client.call.agent_id
client.call.status # an alias for client.call.call_status
client.call.type # an alias for client.call.call_type
client.call.analysis # an alias for client.call.call_analysis

client.retell_llm.id # an alias for client.retell_llm.llm_id
client.retell_llm.websocket_url # an alias for client.retell_llm.llm_websocket_url
client.retell_llm.url # another alias for client.retell_llm.llm_websocket_url

client.phone_number.inbound_agent # an alias for client.phone_number.inbound_agent_id
 # equivalent to client.phone_number.inbound_agent_id = "agent-id"
client.phone_number.inbound_agent = "agent-id"

client.phone_number.outbound_agent # an alias for client.phone_number.outbound_agent_id
# equivalent to client.phone_number.outbound_agent_id = "agent-id"
client.phone_number.outbound_agent = "agent-id"

client.voice.id # an alias for client.voice.voice_id
client.voice.name # an alias for client.voice.voice_name
```

### Webhooks
Unique to this library, an interface similar to Stripe's to get a message out of a webhook and verifiy its authenticity in one pass.
```ruby
request = client.webhook.sanitize raw_request_body, ENV["RETELL_WEBHOOK_SECRET"], request.headers["X-Retell-Signature"]
```

### Contributions

Suggestions for additional quality-of-life improvements are always welcome. Pull requests are especially welcome.

## Limitations (aka 'What about WebSockets?')

This SDK covers the RetellAI REST API, and not the handling of the websocket connection between RetellAI and a custom LLM.

There's multiple ways to handle the websocket connection between RetellAI and a custom LLM. Personally, I like [async-websocket](https://github.com/socketry/async-websocket).

## Development

After checking out the repo, run bundle install to install dependencies.

### Running tests

Running tests requires a local copy of the OpenAPI specification for RetellAI's API, which can be fetched by running `rake fetch_api_spec`. Should the URL to the OpenAPI specification be out of date, you can optionally provide an alternate URL as an argument to the Rake task, like so:

```ruby
rake fetch_api_spec[https://new.path.to.openapi.yml]
```

Running tests also requires a [Prism mock server](https://github.com/stoplightio/prism), which mocks the RetellAI API locally.

The particular fork of the Prism server used in RetellAI's official SDKs, and therefore this unofficial project, is `@stainless-api/prism-cli` - you'll need to install that package rather than `@stoplight/prism-cli`:

```
npm install -g @stainless-api/prism-cli
```

Assuming that particular fork of Prism is installed, the `spec_helper.rb` file and `scripts/mock.rb` file should start the Prism server automatically when tests are run.

### Type checking

All files in the `lib` directory are fully typed using [RBS](https://github.com/ruby/rbs) and [Steep](https://github.com/soutaro/steep).

You'll need to fetch RBS files for this project's dependencies by running `rbs collection init` from within the project directory. This will download the necessary RBS files into the `.gem_rbs_collection` directory.

The RBS files for this project itself are in the `sig` directory. Before submitting a pull request, you should type check the project by running `steep check` from within the project directory.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/gyardley/retell-ruby-sdk.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
