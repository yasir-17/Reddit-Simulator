use "http_server"
use "net"
use "valbytes"
use "json"

actor Main
  new create(env: Env) =>
    let port = "8080"
    let limit: USize = 100
    let host = "localhost"

    let server = Server(
      TCPListenAuth(env.root),
      LoggingServerNotify(env),
      BackendMaker.create(env)
      where config = ServerConfig(
        where host' = host,
              port' = port,
              max_concurrent_connections' = limit)
    )

class LoggingServerNotify is ServerNotify
  let _env: Env

  new iso create(env: Env) =>
    _env = env

  fun ref listening(server: Server ref) =>
    try
      (let host, let service) = server.local_address().name()?
      _env.out.print("Server listening on " + host + ":" + service)
    else
      _env.out.print("Couldn't get local address.")
      _env.exitcode(1)
      server.dispose()
    end

  fun ref not_listening(server: Server ref) =>
    _env.out.print("Failed to listen.")
    _env.exitcode(1)

  fun ref closed(server: Server ref) =>
    _env.out.print("Shutdown.")

actor ResponseHandler
  let _session: Session tag

  new create(session: Session tag) =>
    _session = session

  be send_response(status: Status, body: String, request_id: RequestID) =>
    let response = Responses.builder()
      .set_status(status)
      .add_header("Content-Type", "application/json")
      .add_header("Content-Length", body.size().string())
      .finish_headers()
      .add_chunk(body.array())
      .build()

    _session.send_raw(response, request_id)
    _session.send_finished(request_id)

class val BackendMaker
  let _env: Env
  let _reddit_engine: RedditEngine

  new val create(env: Env) =>
    _env = env
    _reddit_engine = RedditEngine(env)

  fun apply(session: Session): Handler ref^ =>
    BackendHandler(_env, session, _reddit_engine)

class BackendHandler is Handler
  let _env: Env
  let _session: Session tag
  let _reddit_engine: RedditEngine
  var _request_body: String = ""
  let _response_handler: ResponseHandler tag
  var _current_request: (Request val | None) = None
  var _current_request_id: (RequestID | None) = None

  new ref create(env: Env, session: Session tag, reddit_engine: RedditEngine) =>
    _env = env
    _session = session
    _reddit_engine = reddit_engine
    _response_handler = ResponseHandler(session)

  fun ref apply(request: Request val, request_id: RequestID) =>
    _current_request = request
    _current_request_id = request_id
    _request_body = ""  // Reset request body for new request
    _env.out.print("Received request for path: " + request.uri().path)

  fun ref chunk(data: ByteSeq val, request_id: RequestID) =>
    _env.out.print("Received chunk size: " + data.size().string())
    match data
    | let s: String => _request_body = _request_body + s
    | let a: Array[U8] val => _request_body = _request_body + String.from_array(a)
    end

  fun ref finished(request_id: RequestID) =>
    _env.out.print("Complete request body: " + _request_body)
    _env.out.print("Complete request body size: " + _request_body.size().string())
    
    match (_current_request, _current_request_id)
    | (let request: Request val, let rid: RequestID) =>
      let path = request.uri().path
      match request.method()
      | POST =>
        match path
        | "/register" => process_register(rid)
        | "/subreddit" => process_create_subreddit(rid)
        | "/join_subreddit" => process_join_subreddit(rid)
        | "/create_post" => process_create_post(rid)
        | "/add_comment" => process_add_comment(rid)
        | "/send_message" => process_send_message(rid)
        | "/get_messages" => process_get_messages(rid)
        | "/subreddit_posts" => process_get_subreddit_posts(rid)
        | "/subreddit_users" => process_get_subreddit_users(rid)
        | "/user_feed" => process_get_feed(rid)
        else
          _response_handler.send_response(StatusNotFound, """{"error": "Not Found"}""", rid)
        end
      else
        _response_handler.send_response(StatusMethodNotAllowed, """{"error": "Method Not Allowed"}""", rid)
      end
    else
      _env.out.print("Error: No current request")
    end
  
  fun ref process_get_feed(request_id: RequestID) =>
    try
      let json = JsonDoc.>parse(_request_body)?
      let obj = json.data as JsonObject
      let user_id = obj.data("user_id")? as String

      _env.out.print("Fetching feed for user: " + user_id)
      
      _reddit_engine.get_feed(user_id, { (result: FeedResult) =>
        match result
        | (Success, let feed: Array[PostData] val) =>
          let response = JsonArray
          for post in feed.values() do
            let post_obj = JsonObject
            post_obj.data("id") = post.id
            post_obj.data("title") = post.title
            post_obj.data("content") = post.content
            response.data.push(post_obj)
          end
          _response_handler.send_response(StatusOK, response.string(), request_id)
        | (Failure, let error_string: String) =>
          _response_handler.send_response(StatusBadRequest, """{"error": """ + error_string + """}""", request_id)
        end
      })
    else
      _response_handler.send_response(StatusBadRequest, """{"error": "Invalid request body"}""", request_id)
    end


  fun ref process_get_subreddit_posts(request_id: RequestID) =>
    try
      let json = JsonDoc.>parse(_request_body)?
      let obj = json.data as JsonObject
      let subreddit_id = obj.data("subreddit_id")? as String

      _env.out.print("Fetching posts for subreddit: " + subreddit_id)
      
      _reddit_engine.get_subreddit_posts(subreddit_id, { (result: SubredditPostsResult) =>
        match result
        | (Success, let posts: Array[PostData] val) =>
          let response = JsonArray
          for post in posts.values() do
            let post_obj = JsonObject
            post_obj.data("id") = post.id
            post_obj.data("title") = post.title
            post_obj.data("content") = post.content
            response.data.push(post_obj)
          end
          _response_handler.send_response(StatusOK, response.string(), request_id)
        | (Failure, let error_string: String) =>
          _response_handler.send_response(StatusBadRequest, """{"error": """ + error_string + """}""", request_id)
        end
      })
    else
      _response_handler.send_response(StatusBadRequest, """{"error": "Invalid request body"}""", request_id)
    end

  fun ref process_get_subreddit_users(request_id: RequestID) =>
    try
      let json = JsonDoc.>parse(_request_body)?
      let obj = json.data as JsonObject
      let subreddit_id = obj.data("subreddit_id")? as String

      _env.out.print("Fetching users for subreddit: " + subreddit_id)
      
      _reddit_engine.get_subreddit_users(subreddit_id, { (result: SubredditUsersResult) =>
        match result
        | (Success, let users: Array[UserData] val) =>
          let response = JsonArray
          for user in users.values() do
            let user_obj = JsonObject
            user_obj.data("id") = user.id
            user_obj.data("username") = user.username
            response.data.push(user_obj)
          end
          _response_handler.send_response(StatusOK, response.string(), request_id)
        | (Failure, let error_string: String) =>
          _response_handler.send_response(StatusBadRequest, """{"error": """ + error_string + """}""", request_id)
        end
      })
    else
      _response_handler.send_response(StatusBadRequest, """{"error": "Invalid request body"}""", request_id)
    end



  fun ref process_add_comment(request_id: RequestID) =>
    try
      let json = JsonDoc.>parse(_request_body)?
      let obj = json.data as JsonObject
      let content = obj.data("content")? as String
      let author_id = obj.data("author_id")? as String
      let post_id = obj.data("post_id")? as String
      let parent_comment_id = try obj.data("parent_comment_id")? as (String | None) else None end

      _env.out.print("Adding comment by user " + author_id + " on post " + post_id)
      
      _reddit_engine.add_comment(content, author_id, post_id, parent_comment_id, { (result: CommentResult) =>
        match result
        | (Success, let comment: CommentData) =>
          let response = JsonObject
          response.data("id") = comment.id
          response.data("content") = comment.content
          response.data("author_id") = comment.author_id
          response.data("post_id") = comment.post_id
          
          // Only add parent_comment_id if it exists
          match comment.parent_comment_id
          | let p: String => response.data("parent_comment_id") = p
          end
          
          response.data("created_at") = comment.created_at
          _response_handler.send_response(StatusOK, response.string(), request_id)
        | (Failure, let error_string: String) =>
          _response_handler.send_response(StatusBadRequest, """{"error": """ + error_string + """}""", request_id)
        end
      })
    else
      _response_handler.send_response(StatusBadRequest, """{"error": "Invalid request body"}""", request_id)
    end

  // Updated method to process sending a message
  fun ref process_send_message(request_id: RequestID) =>
    try
      let json = JsonDoc.>parse(_request_body)?
      let obj = json.data as JsonObject
      let content = obj.data("content")? as String
      let sender_id = obj.data("sender_id")? as String
      let receiver_id = obj.data("receiver_id")? as String
      let parent_message_id = try obj.data("parent_message_id")? as (String | None) else None end

      _env.out.print("Sending message from user " + sender_id + " to user " + receiver_id)
      
      _reddit_engine.send_message(content, sender_id, receiver_id, parent_message_id, { (result: MessageResult) =>
        match result
        | (Success, let message: MessageData) =>
          let response = JsonObject
          response.data("id") = message.id
          response.data("content") = message.content
          response.data("sender_id") = message.sender_id
          response.data("receiver_id") = message.receiver_id
          
          // Only add parent_message_id if it exists
          match message.parent_message_id
          | let p: String => response.data("parent_message_id") = p
          end
          
          response.data("created_at") = message.created_at
          _response_handler.send_response(StatusOK, response.string(), request_id)
        | (Failure, let error_string: String) =>
          _response_handler.send_response(StatusBadRequest, """{"error": """ + error_string + """}""", request_id)
        end
      })
    else
      _response_handler.send_response(StatusBadRequest, """{"error": "Invalid request body"}""", request_id)
    end

  // Updated method to process getting messages for a user
  fun ref process_get_messages(request_id: RequestID) =>
    try
      let json = JsonDoc.>parse(_request_body)?
      let obj = json.data as JsonObject
      let user_id = obj.data("user_id")? as String

      _env.out.print("Fetching messages for user " + user_id)
      
      _reddit_engine.get_messages(user_id, { (result: MessageListResult) =>
        match result
        | (Success, let messages: Array[MessageWithSender] val) =>
          let response = JsonArray
          for msg in messages.values() do
            let message_obj = JsonObject
            message_obj.data("id") = msg.message.id
            message_obj.data("content") = msg.message.content
            message_obj.data("sender_id") = msg.message.sender_id
            message_obj.data("sender_name") = msg.sender_name
            message_obj.data("receiver_id") = msg.message.receiver_id
            
            // Only add parent_message_id if it exists
            match msg.message.parent_message_id
            | let p: String => message_obj.data("parent_message_id") = p
            end
            
            message_obj.data("created_at") = msg.message.created_at
            response.data.push(message_obj)
          end
          _response_handler.send_response(StatusOK, response.string(), request_id)
        | (Failure, let error_string: String) =>
          _response_handler.send_response(StatusBadRequest, """{"error": """ + error_string + """}""", request_id)
        end
      })
    else
      _response_handler.send_response(StatusBadRequest, """{"error": "Invalid request body"}""", request_id)
    end

  fun ref process_join_subreddit(request_id: RequestID) =>
    try
      let json = JsonDoc.>parse(_request_body)?
      let obj = json.data as JsonObject
      let user_id = obj.data("user_id")? as String
      let subreddit_id = obj.data("subreddit_id")? as String

      _env.out.print("User " + user_id + " is attempting to join subreddit " + subreddit_id)
      
      _reddit_engine.join_subreddit(user_id, subreddit_id, { (result: JoinResult) =>
        match result
        | (Success, let message: String) =>
          _response_handler.send_response(StatusOK, """{"message": """ + message + """}""", request_id)
        | (Failure, let error_string: String) =>
          _response_handler.send_response(StatusBadRequest, """{"error": """ + error_string + """}""", request_id)
        end
      })
    else
      _response_handler.send_response(StatusBadRequest, """{"error": "Invalid request body"}""", request_id)
    end

  fun ref process_create_post(request_id: RequestID) =>
    try
      let json = JsonDoc.>parse(_request_body)?
      let obj = json.data as JsonObject
      let title = obj.data("title")? as String
      let content = obj.data("content")? as String
      let author_id = obj.data("author_id")? as String
      let subreddit_id = obj.data("subreddit_id")? as String

      _env.out.print("Creating post titled '" + title + "' by user " + author_id + " in subreddit " + subreddit_id)
      
      _reddit_engine.create_post(title, content, author_id, subreddit_id, { (result: PostResult) =>
        match result
        | (Success, let post: PostData) =>
          let response = JsonObject
          response.data("id") = post.id
          response.data("title") = post.title
          response.data("content") = post.content
          _response_handler.send_response(StatusOK, response.string(), request_id)
        | (Failure, let error_string: String) =>
          _response_handler.send_response(StatusBadRequest, """{"error": """ + error_string + """}""", request_id)
        end
      })
    else
      _response_handler.send_response(StatusBadRequest, """{"error": "Invalid request body"}""", request_id)
    end


  fun ref process_register(request_id: RequestID) =>
    _env.out.print("Processing register request")
    _env.out.print("Attempting to parse JSON: " + _request_body)
    try
      let json = JsonDoc.>parse(_request_body)?
      let obj = json.data as JsonObject
      let username = obj.data("username")? as String
      let password = obj.data("password")? as String
      _env.out.print("Registering user: " + username)
      _env.out.print("Password: " + password)

      _reddit_engine.register_user(username, password, { (result: RegistrationResult) =>
        match result
        | (Success, let user: UserData) =>
          let response = JsonObject
          response.data("id") = user.id
          response.data("username") = user.username
          _response_handler.send_response(StatusOK, response.string(), request_id)
        | (Failure, let error_string: String) =>
          _response_handler.send_response(StatusBadRequest, """{"error": """ + error_string + """}""", request_id)
        end
      })
    else
      _env.out.print("Parsing error: " + _request_body)
      _response_handler.send_response(
        StatusBadRequest, 
        """{"error": "Invalid request body", "details": """ + _request_body + """}""", 
        request_id
      )
    end

  fun ref process_create_subreddit(request_id: RequestID) =>
    try
      let json = JsonDoc.>parse(_request_body)?
      let obj = json.data as JsonObject
      let name = obj.data("name")? as String
      let description = obj.data("description")? as String
      let creator_id = obj.data("creator_id")? as String

      _reddit_engine.create_subreddit(name, description, creator_id, { (result: SubredditResult) =>
        match result
        | (Success, let subreddit: SubredditData) =>
          let response = JsonObject
          response.data("id") = subreddit.id
          response.data("name") = subreddit.name
          _response_handler.send_response(StatusOK, response.string(), request_id)
        | (Failure, let error_string: String) =>
          _response_handler.send_response(StatusBadRequest, """{"error": """ + error_string + """}""", request_id)
        end
      })
    else
      _response_handler.send_response(StatusBadRequest, """{"error": "Invalid request body"}""", request_id)
    end