require "./api"
require "./list"
require "./resource"

module Google
  # API.discover "https://www.googleapis.com/discovery/v1/apis/tasks/v1/rest"

  struct Tasks::V1 < API
    private abstract struct API < Google::API
      def http_get(path : String, token : String, as type = JSON::Any)
        headers = HTTP::Headers{"host" => "tasks.googleapis.com"}

        client.get("/tasks/v1/#{path}", headers: headers, token: token) do |response|
          if response.success?
            type.from_json response.body_io
          else
            raise response.body_io.gets_to_end
          end
        end
      end
    end

    struct TaskLists < API
      def list(token : String, max_results : Int32? = nil, page_token : String? = nil)
        http_get "users/@me/lists", token: token, as: List(TaskList)
      end

      def get(id : String, token : String)
        id = URI.encode_path_segment(id)
        http_get("users/@me/lists/#{id}", token: token, as: Calendar)
      end
    end

    struct Tasks < API
      private alias TimeRange = Range(Time?, Time?) | Range(Time, Nil) | Range(Nil, Time)

      def list(
        task_list : TaskList,
        token : String,
        *,
        max_results : Int32? = nil,
        page_token : String? = nil,
        completed : TimeRange? = nil,
        show_completed : Bool? = nil,
        show_hidden : Bool? = nil,
        show_deleted : Bool? = nil,
      )
        list task_list.id, token,
          max_results: max_results,
          page_token: page_token,
          completed: completed,
          show_completed: show_completed,
          show_hidden: show_hidden,
          show_deleted: show_deleted
      end

      def list(
        task_list : String,
        token : String,
        *,
        max_results : Int32? = nil,
        page_token : String? = nil,
        completed : TimeRange? = nil,
        show_completed : Bool? = nil,
        show_hidden : Bool? = nil,
        show_deleted : Bool? = nil,
      )
        params = URI::Params.new
        params["maxResults"] = max_results.to_s if max_results
        params["pageToken"] = page_token if page_token
        params["showCompleted"] = show_completed.to_s unless show_completed.nil?
        params["showHidden"] = show_hidden.to_s unless show_hidden.nil?
        params["showDeleted"] = show_deleted.to_s unless show_deleted.nil?

        if completed
          if min = completed.begin
            params["completedMin"] = min.to_rfc3339(fraction_digits: 9)
          end
          if max = completed.end
            params["completedMax"] = max.to_rfc3339(fraction_digits: 9)
          end
        end

        list = http_get "lists/#{task_list}/tasks?#{params}", token: token, as: List(Task)
        if (next_page_token = list.next_page_token)
          list.api = self
          list.token = token
          list.max_results = max_results
          list.task_list = task_list
          list.completed = completed
        end
        list
      end

      struct List(T)
        include Resource
        include Enumerable(T)

        field kind : String
        field etag : String
        field items : Array(T)
        field next_page_token : String?
        @[JSON::Field(ignore: true)]
        protected property api : Tasks?
        @[JSON::Field(ignore: true)]
        protected property task_list : String?
        @[JSON::Field(ignore: true)]
        protected property token : String?
        @[JSON::Field(ignore: true)]
        protected property max_results : Int32?
        @[JSON::Field(ignore: true)]
        protected property completed : TimeRange?

        def to_a
          lists = [] of TaskList
          each { |list| lists << list }
          lists
        end

        def each(page_count : Int32? = nil, &block : T ->) : Nil
          items.each do |item|
            yield item
          end

          if page_count && page_count > 1 && (api = self.api) && (token = self.token) && (task_list = self.task_list) && (next_page_token = self.next_page_token)
            api
              .list(
                task_list: task_list,
                token: token,
                max_results: max_results,
                page_token: next_page_token,
                completed: completed,
              )
              .each(page_count: page_count - 1, &block)
          end
        end
      end
    end

    def task_lists
      TaskLists.new(client)
    end

    def tasks
      Tasks.new(client)
    end
  end

  struct TaskList
    include Resource

    field kind : String
    field id : String
    field etag : String
    field title : String
    field updated : Time
    field self_link : URI
  end

  struct Task
    include Resource

    field kind : String
    field id : String
    field etag : String
    field title : String
    field updated : Time
    field self_link : URI
    field parent : String?
    field position : String
    field notes : String?
    field due : Time?
    field completed : Time?
    field? deleted : Bool?
    field? hidden : Bool?
    field status : Status
    field links : Array(Link)
    field web_view_link : URI

    enum Status
      NeedsAction
      Completed
    end

    struct Link
      include Resource

      field type : String
      field description : String
      field link : String
    end
  end

  class Client
    def tasks
      Tasks::V1.new(self)
    end
  end
end
