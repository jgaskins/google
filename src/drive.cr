require "./api"
require "./list"
require "./resource"

module Google
  struct Drive::V3 < API
    def files
      Files.new(client)
    end

    def comments
      Comments.new(client)
    end

    private abstract struct API < Google::API
      def http_get(path : String, token : String, as type = CommentList)
        client.get("/drive/v3/#{path}", token: token) do |response|
          if response.success?
            type.from_json response.body_io
          else
            raise response.body_io.gets_to_end
          end
        end
      end
    end

    private FILE_FIELDS = %w[
      kind
      id
      mimeType
      name
      parents
      driveId
      copyRequiresWriterPermission
      viewedByMe
      shared
      thumbnailLink
      iconLink
      lastModifyingUser
      owners
      size
      description
      starred
      trashed
      resourceKey
      webViewLink
      webContentLink
    ].join(',')
    private FILE_LIST_FIELDS = (
      %w[
        kind
        nextPageToken
        incompleteSearch
      ] << "files(#{FILE_FIELDS})"
    ).join(',')

    struct Files < API
      def list(token : String, page_size : Int32? = nil, page_token : String? = nil)
        file_list = http_get "files?fields=#{FILE_LIST_FIELDS}", token: token, as: FileList
        if file_list.next_page_token
          file_list.api = self
          file_list.token = token
          file_list.page_size = page_size
        end
        file_list
      end

      def get(file : File, token : String)
        get file.id, token: token
      end

      def get(id : String, token : String)
        http_get "files/#{id}?fields=#{FILE_FIELDS}", token: token, as: File
      end
    end

    struct Comments < API
      def list(
        file : File,
        token : String,
        *,
        page_size : Int32? = nil,
        page_token : String? = nil
      )
        list file.id, token: token, page_size: page_size, page_token: page_token
      end

      def list(
        file_id : String,
        token : String,
        *,
        page_size : Int32? = nil,
        page_token : String? = nil
      )
        params = URI::Params{"fields" => "*"}
        params["pageSize"] = page_size.to_s if page_size
        params["pageToken"] = page_token.to_s if page_token

        list = http_get "files/#{file_id}/comments?#{params}", token: token, as: CommentList
        if list.next_page_token
          list.api = self
          list.token = token
          list.file_id = file_id
          list.page_size = page_size
        end
        list
      end
    end

    struct FileList
      include Resource
      include Enumerable(File)

      field next_page_token : String?
      field kind : String
      field incomplete_search : Bool
      field files : Array(File)
      @[JSON::Field(ignore: true)]
      protected property api : Files?
      @[JSON::Field(ignore: true)]
      protected property token : String?
      @[JSON::Field(ignore: true)]
      protected property page_size : Int32?

      def to_a
        files = [] of File
        each { |file| files << file }
        files
      end

      def each : Nil
        files.each do |item|
          yield item
        end

        if (api = self.api) && (token = self.token) && (page_token = next_page_token)
          api.list(token: token, page_size: page_size, page_token: page_token)
        end
      end
    end

    struct File
      include Resource
      include JSON::Serializable::Unmapped

      field kind : String
      field id : String
      field mime_type : String
      field name : String

      # Fields requested via the `fields` HTTP query parameter
      field parents : Array(String) { [] of String }
      field drive_id : String?
      field? copy_requires_writer_permission : Bool
      field? viewed_by_me : Bool
      field? shared : Bool
      field thumbnail_link : String?
      field icon_link : String
      field last_modifying_user : User
      field owners : Array(User)
      field size : String?
      field description : String?
      field? starred : Bool
      field? trashed : Bool
      field resource_key : String?
      field web_view_link : String
      field web_content_link : String?
    end

    module CommentData
      include Resource

      field id : String
      field kind : String
      field created_time : Time
      field modified_time : Time
      field author : User
      field? deleted : Bool
      field html_content : String
      field content : String
    end

    struct Comment
      include Resource
      include CommentData

      field anchor : String
      field? resolved : Bool
      field replies : Array(Reply)
      field quoted_file_content : QuotedFileContent
    end

    struct Reply
      include Resource
      include CommentData

      field action : String
    end

    struct CommentList
      include Resource
      include Enumerable(Comment)

      field next_page_token : String?
      field kind : String
      field comments : Array(Comment)

      @[JSON::Field(ignore: true)]
      protected property api : Comments?
      @[JSON::Field(ignore: true)]
      protected property token : String?
      @[JSON::Field(ignore: true)]
      protected property file_id : String?
      @[JSON::Field(ignore: true)]
      protected property page_size : Int32?

      def each : Nil
        comments.each do |item|
          yield item
        end

        if (api = self.api) && (token = self.token) && (file_id = self.file_id) && (page_token = next_page_token)
          api.list(
            file_id: file_id,
            token: token,
            page_size: page_size,
            page_token: page_token,
          )
        end
      end
    end

    struct User
      include Resource

      field display_name : String
      field kind : String
      field? me : Bool
      field permission_id : String?
      field email_address : String?
      field photo_link : String
    end

    struct QuotedFileContent
      include Resource

      field mime_type : String
      field value : String
    end
  end

  class Client
    def drive
      Drive::V3.new(self)
    end
  end
end
