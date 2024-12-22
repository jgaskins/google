require "http_client"
require "json-schema"

require "./api"
require "./list"
require "./resource"
require "./error"

module Google
  module GenerativeAI
    class Client
      private DEFAULT_URI = URI.parse("https://generativelanguage.googleapis.com/")
      @api_key : String

      def initialize(@api_key, @base_uri = DEFAULT_URI)
        @http = HTTPClient.new(base_uri)
        @http.before_request do |request|
          # request.headers["authorization"] = "Bearer #{api_key}"
          params = request.query_params
          params["key"] = api_key
          request.query = params.to_s
        end
      end

      def models(page_size : Int? = nil, page_token : String? = nil, response_schema = nil)
        result = get "/v1beta/models", return: ModelsResponse(typeof(response_schema))
        result.models.map(&.with_client(client: self))
      end

      def model(name : String, system_instruction = nil, temperature : Float64? = nil, response_schema = nil)
        if name.starts_with? "models/"
          name = name.lchop "models/"
        end
        system_instruction = Content.new(system_instruction) if system_instruction.is_a? String

        model = get("/v1beta/models/#{name}", return: Model::V1Beta(typeof(response_schema)))
        model.client = self
        model.system_instruction = ContentTransformer.new.content(system_instruction)
        model.temperature = temperature
        model.response_schema = response_schema.to_json if response_schema

        model
      end

      {% for method in %w[get post] %}
        def {{method.id}}(path : String, headers : HTTP::Headers? = nil, *, retries : Int = 5, return type : T.class) forall T
          response = @http.{{method.id}} path, headers: headers
          if response.success?
            T.from_json response.body
          elsif response.status.server_error? && retries > 0
            HTTPClient::Log.error &.emit "Server error, retrying", status: response.status.code, retries_remaining: retries
            {{method.id}}(path, headers, retries: retries - 1, return: type)
          else
            raise Error.new(response.body)
          end
        end

        def {{method.id}}(path : String, headers : HTTP::Headers? = nil, *, body, retries : Int = 3, return type : T.class) forall T
          response = @http.{{method.id}} path, headers: headers, body: body.to_json
          if response.success?
            T.from_json response.body
          elsif response.status.server_error? && retries > 0
            HTTPClient::Log.error &.emit "Server error, retrying", status: response.status.code, retries_remaining: retries
            {{method.id}}(path, headers, body: body, retries: retries - 1, return: type)
          else
            raise Error.new(response.body)
          end
        end
      {% end %}
    end

    struct ModelsResponse(ResponseSchema)
      include Resource

      getter models : Array(Model::V1Beta(ResponseSchema))
    end

    struct Model::V1Beta(ResponseSchema)
      include Resource

      # https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$API_KEY

      field name : String
      field temperature : Float64?
      setter temperature
      field output_token_limit : Int64
      field input_token_limit : Int64
      field system_instruction : Content?
      setter system_instruction
      @[JSON::Field(converter: String::RawConverter)]
      field response_schema : String?

      @[JSON::Field(ignore: true)]
      protected property! client : Client
      @[JSON::Field(ignore: true)]
      @prefix = "/v1beta"
      @[JSON::Field(ignore: true)]
      @headers = HTTP::Headers{
        "accept"       => "application/json",
        "content-type" => "application/json",
        "user-agent"   => "https://github.com/jgaskins/google",
      }

      def generate(contents : String | Array, generation_config : GenerationConfig? = self.generation_config, tools : Tools? = nil)
        contents = ContentTransformer.new.contents(contents)
        # converted_tools = Tools.new(tools) if tools

        response = client.post "#{@prefix}/#{name}:generateContent",
          headers: @headers,
          body: GenerateContentRequest.new(
            contents: contents,
            generation_config: generation_config,
            tools: tools,
            system_instruction: system_instruction,
          ),
          return: GenerateContentResponse

        if tools && (calls = response.candidates.flat_map(&.content.parts.compact_map(&.function_call)).compact).any?
          new_contents = contents.dup + response.candidates.flat_map(&.content)

          parts = calls.not_nil!.map do |call|
            tool = tools.function_declarations.find! { |t| t.name == call.name }
            result = tool.from_json(call.args).call

            Content::Part.new(
              Content::FunctionResponse.new(
                name: tool.name,
                response: result.to_json,
              ),
            ).as(Content::Part)
          end

          new_contents << Content.new(role: :function, parts: parts)

          # # Doesn't look like we can run tools concurrently because sometimes
          # # Gemini can return tool calls with dependencies on other tools
          # # returned in the same response. Need to investigate whether that's
          # # something that can be worked around.
          # WaitGroup.wait do |wg|
          #   calls.not_nil!.each do |call|
          #     wg.spawn do
          #       tool = tools.function_declarations.find! { |t| t.name == call.name }
          #       result = tool.from_json(call.args).call

          #       new_contents << Content.new(
          #         role: :function,
          #         parts: [Content::Part.new(
          #           function_response: Content::FunctionResponse.new(
          #             name: tool.name,
          #             response: result.to_json,
          #           ),
          #         )],
          #       )
          #     end
          #   end
          # end

          generate new_contents,
            generation_config: generation_config,
            tools: tools
        else
          response
        end
      end

      def count_tokens(contents : String | Array, generation_config : GenerationConfig? = nil, tools = nil)
        contents = ContentTransformer.new.contents(contents)

        response = client.post "#{@prefix}/#{name}:countTokens",
          headers: @headers,
          body: GenerateContentRequest.new(
            contents: contents,
            # generation_config: generation_config,
            # tools: tools,
            # system_instruction: system_instruction,
          ),
          return: TokenCount
      end

      def generation_config
        GenerationConfig.new(
          temperature: temperature,
        )
      end

      protected def with_client(@client) : self
        self
      end
    end

    Resource.define GenerationConfig,
      temperature : Float64? = nil,
      top_p : Float64? = nil,
      top_k : Float64? = nil,
      max_output_tokens : Int32? = nil,
      stop_sequences : Array(String)? = nil,
      response_mime_type : String? = nil,
      response_schema : String? = nil,
      candidate_count : Int32? = nil,
      presence_penalty : Float64? = nil,
      frequency_penalty : Float64? = nil,
      response_logprobs : Bool? = nil,
      logprobs : Int32? = nil do
      @[JSON::Field(converter: ::String::RawConverter)]
      @response_schema : String?
    end

    struct GenerateContentRequest(Tools)
      include Resource

      field contents : String | Array(Content)
      field tools : Tools
      field generation_config : GenerationConfig?
      field system_instruction : Content?

      def self.new(*, contents)
        new(
          contents: contents,
          generation_config: nil,
          tools: nil,
          system_instruction: nil,
        )
      end

      def initialize(*, @contents, @generation_config, @tools, @system_instruction)
      end
    end

    struct GenerateContentResponse
      include Resource

      field candidates : Array(Candidate)
      field usage_metadata : UsageMetadata

      def to_s(io) : Nil
        candidates.each do |candidate|
          io.puts candidate
        end
      end

      struct Candidate
        include Resource

        field content : Content = Content.new
        field finish_reason : String # FIXME: make this an enum
        field index : Int64? = nil
        field safety_ratings : Array(SafetyRating) { [] of SafetyRating }

        def to_s(io) : Nil
          io << content
        end
      end

      struct SafetyRating
        include Resource

        field category : String    # FIXME: make this an enum
        field probability : String # FIXME: make this an enum
      end

      struct UsageMetadata
        include Resource

        field prompt_token_count : Int64
        field candidates_token_count : Int64
        field total_token_count : Int64
      end
    end

    struct Content
      include Resource
      field role : Role?
      field parts : Array(Part)

      def self.new(text : String)
        new parts: Array(Part){
          Part.new(text: text),
        }
      end

      def initialize(@parts = [] of Part, @role = :user)
      end

      def to_s(io) : Nil
        parts.each do |part|
          io.puts part
        end
      end

      struct Part
        include Resource

        field text : String?
        field inline_data : InlineData?
        field function_call : FunctionCall?
        field function_response : FunctionResponse?
        field file_data : FileData?
        field executable_code : ExecutableCode?
        field code_execution_result : CodeExecutionResult?

        def initialize(@text : String)
        end

        def initialize(@inline_data : InlineData)
        end

        def initialize(@function_call : FunctionCall)
        end

        def initialize(@function_response : FunctionResponse)
        end

        def initialize(@file_data : FileData)
        end

        def initialize(@executable_code : ExecutableCode)
        end

        def initialize(@code_execution_result : CodeExecutionResult)
        end

        def to_s(io : IO) : Nil
          # pp "Part": self
          io << text || inline_data || function_call || function_response || file_data || executable_code || code_execution_result
        end
      end

      macro define(type, *vars)
        struct {{type}}
          include Resource

          {% for var in vars %}
            field {{var}}
          {% end %}

          def initialize(
            {% for var in vars %}
              @{{var.var}},
            {% end %}
          )
          end

          {{yield}}
        end
      end

      define Text, text : String

      struct InlineData
        include Resource
        field mime_type : String
        {% begin %}
        field data : Bytes, converter: {{@type}}::Blob
        {% end %}

        def initialize(*, @mime_type, @data)
        end

        module Blob
          extend self

          def from_json(json : JSON::PullParser) : Bytes
            Base64.decode json.read_string
          end

          def to_json(value : Bytes, json : JSON::Builder) : Nil
            json.string { |io| Base64.encode value, io }
          end
        end
      end

      define FileData, mime_type : String, file_uri : String
      define ExecutableCode, language : Language, code : String do
        enum Language
          LanguageUnspecified
          Python
        end
      end
      define CodeExecutionResult, outcome : Outcome, output : String do
        enum Outcome
          # Unspecified status. This value should not be used.
          OutcomeUnspecified

          # Code execution completed successfully.
          OutcomeOK

          #	Code execution finished but with a failure. stderr should contain
          # the reason.
          OutcomeFailed

          # Code execution ran for too long, and was cancelled. There may or may
          # not be a partial output present.
          OutcomeDeadlineExceeded
        end
      end

      struct FunctionCall
        include Resource

        field name : String
        @[JSON::Field(converter: String::RawConverter)]
        field args : String

        def self.new(json : JSON::PullParser)
          name = ""
          args = ""
          json.read_object do |key|
            case key
            when "name"
              name = json.read_string
            when "args"
              args = json.read_raw
            end
          end

          new(name: name, args: args)
        end

        def self.new(name, args : JSON::Serializable)
          new(name, args: args.to_json)
        end

        def initialize(@name, @args)
        end

        def to_json(json : JSON::Builder)
          json.object do
            json.field "name", name
            json.field "args" { json.raw args }
          end
        end
      end

      struct FunctionResponse
        include Resource

        getter name : String
        @[JSON::Field(converter: String::RawConverter)]
        getter response : String

        def initialize(@name, @response)
        end
      end

      enum Role
        User
        Model
        System # Is this a thing?
        Function
      end
    end

    struct TokenCount
      include Resource

      field total_tokens : Int64 = 0
      field cached_content_token_count : Int64 = 0
    end

    private struct ContentTransformer
      def contents(contents : Array(Content)) : Array(Content)
        contents
      end

      def contents(array : Array) : Array(Content)
        array.map do |stuff|
          content stuff
        end
      end

      def contents(string : String) : Array(Content)
        contents [string]
      end

      def content(strings : Array(String)) : Content
        content parts(strings)
      end

      def content(string : String) : Content
        content part(string)
      end

      def content(part : Content::Part) : Content
        content [part]
      end

      def content(parts : Array(Content::Part)) : Content
        content Content.new(parts: parts)
      end

      def content(content : Content) : Content
        content
      end

      def parts(strings : Array(String)) : Array(Content::Part)
        strings.map { |string| part string }
      end

      def part(string : String)
        Content::Part.new string
      end
    end

    struct Tools(T)
      include Resource

      field function_declarations : Array(T)

      def initialize(@function_declarations)
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "function_declarations" do
            json.array do
              function_declarations.each do |function|
                json.object do
                  json.field "name", function.name
                  if function.responds_to? :description
                    json.field "description", function.description
                  end
                  json.field "parameters", function.json_schema(openapi: true)
                end
              end
            end
          end
        end
      end
    end
  end
end
