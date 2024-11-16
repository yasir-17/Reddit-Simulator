use "collections"
use "time"
use "random"
use "format"

type MessageType is (String | None)

primitive Success
primitive Failure

type RegistrationResult is ((Success, UserData) | (Failure, String))
type SubredditResult is ((Success, SubredditData) | (Failure, String))
type PostResult is ((Success, PostData) | (Failure, String))

class val UserData
  let id: String
  let username: String
  let password: String
  let created_at: I64
  let subreddits: Array[String] val
  let posts: Array[String] val
  let comments: Array[String] val
  let karma: I64

  new val create(
    id': String,
    username': String,
    password': String,
    created_at': I64,
    subreddits': Array[String] val,
    posts': Array[String] val,
    comments': Array[String] val,
    karma': I64
  ) =>
    id = id'
    username = username'
    password = password'
    created_at = created_at'
    subreddits = subreddits'
    posts = posts'
    comments = comments'
    karma = karma'

class val SubredditData
  let id: String
  let name: String
  let description: String
  let creator_id: String
  let created_at: I64
  let members: Array[String] val
  let posts: Array[String] val

  new val create(
    id': String,
    name': String,
    description': String,
    creator_id': String,
    created_at': I64,
    members': Array[String] val,
    posts': Array[String] val
  ) =>
    id = id'
    name = name'
    description = description'
    creator_id = creator_id'
    created_at = created_at'
    members = members'
    posts = posts'

class val PostData
  let id: String
  let title: String
  let content: String
  let author_id: String
  let subreddit_id: String
  let created_at: I64
  let upvotes: Array[String] val
  let downvotes: Array[String] val
  let comments: Array[String] val
  let score: I64

  new val create(
    id': String,
    title': String,
    content': String,
    author_id': String,
    subreddit_id': String,
    created_at': I64,
    upvotes': Array[String] val,
    downvotes': Array[String] val,
    comments': Array[String] val,
    score': I64
  ) =>
    id = id'
    title = title'
    content = content'
    author_id = author_id'
    subreddit_id = subreddit_id'
    created_at = created_at'
    upvotes = upvotes'
    downvotes = downvotes'
    comments = comments'
    score = score'

actor RedditEngine
  let _users: Map[String, UserData] = _users.create()
  let _subreddits: Map[String, SubredditData] = _subreddits.create()
  let _posts: Map[String, PostData] = _posts.create()
  let _env: Env
  let _rng: Random

  new create(env: Env) =>
    _env = env
    _rng = Rand(Time.now()._1.u64())

  be register_user(
    username: String,
    password: String,
    callback: {(RegistrationResult)} val
    ) =>
    // Check if username exists
    for user in _users.values() do
      if user.username == username then
        callback((Failure, "Username already exists"))
        return
      end
    end

    // Create new user
    let user_id = _generate_id()
    let user = UserData(
      user_id,
      username,
      password,
      Time.now()._1,
      recover Array[String] end,
      recover Array[String] end,
      recover Array[String] end,
      0
    )
    _users(user_id) = user
    callback((Success, user))

  be create_subreddit(
    name: String,
    description: String,
    creator_id: String,
    callback: {(SubredditResult)} val
  ) =>
    // Verify creator exists
    if not _users.contains(creator_id) then
      callback((Failure, "User not found"))
      return
    end

    // Check if subreddit name exists
    for subreddit in _subreddits.values() do
      if subreddit.name == name then
        callback((Failure, "Subreddit name already exists"))
        return
      end
    end

    // Create new subreddit
    let subreddit_id = _generate_id()
    let members = recover Array[String] end
    members.push(creator_id)
    let subreddit = SubredditData(
      subreddit_id,
      name,
      description,
      creator_id,
      Time.now()._1,
      consume members,
      recover Array[String] end
    )
    _subreddits(subreddit_id) = subreddit
    callback((Success, subreddit))

  be create_post(
    title: String,
    content: String,
    author_id: String,
    subreddit_id: String,
    callback: {(PostResult)} val
  ) =>
    // Verify author and subreddit exist
    if not (_users.contains(author_id) and _subreddits.contains(subreddit_id)) then
      callback((Failure, "User or Subreddit not found"))
      return
    end

    // Create new post
    let post_id = _generate_id()
    let post = PostData(
      post_id,
      title,
      content,
      author_id,
      subreddit_id,
      Time.now()._1,
      recover Array[String] end,
      recover Array[String] end,
      recover Array[String] end,
      0
    )
    _posts(post_id) = post
    callback((Success, post))

  fun ref _generate_id(): String =>
    let id_bytes = Array[U8].create(16)
    for i in Range(0, 16) do
      id_bytes.push(_rng.u8())
    end
    
    // Convert bytes to hexadecimal string
    let hex_chars = Array[String](32)
    for byte in id_bytes.values() do
      let hi = (byte and 0xF0) >> 4
      let lo = byte and 0x0F
      hex_chars.push(_to_hex(hi))
      hex_chars.push(_to_hex(lo))
    end
    String.join(hex_chars.values())

  fun _to_hex(n: U8): String =>
    match n
    | 0 => "0"
    | 1 => "1"
    | 2 => "2"
    | 3 => "3"
    | 4 => "4"
    | 5 => "5"
    | 6 => "6"
    | 7 => "7"
    | 8 => "8"
    | 9 => "9"
    | 10 => "a"
    | 11 => "b"
    | 12 => "c"
    | 13 => "d"
    | 14 => "e"
    | 15 => "f"
    else
      "0"
    end

actor Main
  new create(env: Env) =>
    let reddit = RedditEngine(env)
    
    // Test user registration
    reddit.register_user("test_user", "password", 
      {(result: RegistrationResult) =>
        match result
        | (let s: Success, let user: UserData) =>
          env.out.print("User registered successfully: " + user.username)
        | (let f: Failure, let msg: String) =>
          env.out.print("Failed to register user: " + msg)
        end
      })