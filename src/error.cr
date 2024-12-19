module Google
  class Error < ::Exception
    macro define(name, *properties)
      class {{name}} < ::Google::Error
        def initialize(
          message : String? = nil,
          *,
          {% for property in properties %}
            @{{property}},
          {% end %}
        )
          super message
        end

        {{yield}}
      end
    end
  end

  Error.define RequestError, status : HTTP::Status
end
