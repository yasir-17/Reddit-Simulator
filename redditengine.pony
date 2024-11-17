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
type CommentResult is ((Success, CommentData) | (Failure, String))
type VoteResult is ((Success, String) | (Failure, String))
type FeedResult is ((Success, Array[PostData] val) | (Failure, String))
type JoinResult is ((Success, String) | (Failure, String))

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

class val CommentData
  let id: String
  let content: String
  let author_id: String
  let post_id: String
  let parent_comment_id: (String | None)
  let created_at: I64
  let upvotes: Array[String] val
  let downvotes: Array[String] val
  let replies: Array[String] val
  let score: I64

  new val create(
    id': String,
    content': String,
    author_id': String,
    post_id': String,
    parent_comment_id': (String | None),
    created_at': I64,
    upvotes': Array[String] val,
    downvotes': Array[String] val,
    replies': Array[String] val,
    score': I64
  ) =>
    id = id'
    content = content'
    author_id = author_id'
    post_id = post_id'
    parent_comment_id = parent_comment_id'
    created_at = created_at'
    upvotes = upvotes'
    downvotes = downvotes'
    replies = replies'
    score = score'

actor RedditEngine
  let _users: Map[String, UserData] = _users.create()
  let _subreddits: Map[String, SubredditData] = _subreddits.create()
  let _posts: Map[String, PostData] = _posts.create()
  let _env: Env
  let _rng: Random
  let _comments: Map[String, CommentData] = _comments.create()

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

  be join_subreddit(
    user_id: String,
    subreddit_id: String,
    callback: {(JoinResult)} val
    ) =>
    if not (_users.contains(user_id) and _subreddits.contains(subreddit_id)) then
        callback((Failure, "User or Subreddit not found"))
        return
    end

    try
        let subreddit = _subreddits(subreddit_id)?
        let members = recover Array[String] end
        for member in subreddit.members.values() do
        members.push(member)
        end

        if not members.contains(user_id) then
        members.push(user_id)
        let new_subreddit = SubredditData(
            subreddit.id,
            subreddit.name,
            subreddit.description,
            subreddit.creator_id,
            subreddit.created_at,
            consume members,
            subreddit.posts
        )
        _subreddits(subreddit_id) = new_subreddit
        callback((Success, "Successfully joined subreddit"))
        else
        callback((Failure, "User already member of subreddit"))
        end
    else
        callback((Failure, "Error accessing subreddit data"))
    end

    be leave_subreddit(
    user_id: String,
    subreddit_id: String,
    callback: {(JoinResult)} val
    ) =>
    if not (_users.contains(user_id) and _subreddits.contains(subreddit_id)) then
        callback((Failure, "User or Subreddit not found"))
        return
    end

    try
        let subreddit = _subreddits(subreddit_id)?
        let members = recover Array[String] end
        var user_was_member = false
        for member in subreddit.members.values() do
        if member != user_id then
            members.push(member)
        else
            user_was_member = true
        end
        end

        if user_was_member then
        let new_subreddit = SubredditData(
            subreddit.id,
            subreddit.name,
            subreddit.description,
            subreddit.creator_id,
            subreddit.created_at,
            consume members,
            subreddit.posts
        )
        _subreddits(subreddit_id) = new_subreddit
        callback((Success, "Successfully left subreddit"))
        else
        callback((Failure, "User was not a member of the subreddit"))
        end
    else
        callback((Failure, "Error accessing subreddit data"))
    end

  be add_comment(
    content: String,
    author_id: String,
    post_id: String,
    parent_comment_id: (String | None),
    callback: {(CommentResult)} val
  ) =>
    try
      if not (_users.contains(author_id) and _posts.contains(post_id)) then
        callback((Failure, "User or Post not found"))
        return
      end

      match parent_comment_id
      | let id: String =>
        if not _comments.contains(id) then
          callback((Failure, "Parent comment not found"))
          return
        end
      end

      let comment_id = _generate_id()
      let comment = CommentData(
        comment_id,
        content,
        author_id,
        post_id,
        parent_comment_id,
        Time.now()._1,
        recover Array[String] end,
        recover Array[String] end,
        recover Array[String] end,
        0
      )
      
      _comments(comment_id) = comment

      // Update parent post or comment
      match parent_comment_id
      | None =>
        let post = _posts(post_id)?
        let comments = recover Array[String] end
        for c in post.comments.values() do
          comments.push(c)
        end
        comments.push(comment_id)
        
        let new_post = PostData(
          post.id,
          post.title,
          post.content,
          post.author_id,
          post.subreddit_id,
          post.created_at,
          post.upvotes,
          post.downvotes,
          consume comments,
          post.score
        )
        _posts(post_id) = new_post
      | let parent_id: String =>
        let parent = _comments(parent_id)?
        let replies = recover Array[String] end
        for r in parent.replies.values() do
          replies.push(r)
        end
        replies.push(comment_id)
        
        let new_parent = CommentData(
          parent.id,
          parent.content,
          parent.author_id,
          parent.post_id,
          parent.parent_comment_id,
          parent.created_at,
          parent.upvotes,
          parent.downvotes,
          consume replies,
          parent.score
        )
        _comments(parent_id) = new_parent
      end

      callback((Success, comment))
    else
      callback((Failure, "Failed to add comment"))
    end

  be vote(
    user_id: String,
    target_id: String,
    is_upvote: Bool,
    callback: {(VoteResult)} val
    ) =>
    if not _users.contains(user_id) then
        callback((Failure, "User not found"))
        return
    end

    if _posts.contains(target_id) then
        _vote_post(user_id, target_id, is_upvote, callback)
    elseif _comments.contains(target_id) then
        _vote_comment(user_id, target_id, is_upvote, callback)
    else
        callback((Failure, "Target not found"))
    end

    be get_feed(
    user_id: String,
    callback: {(FeedResult)} val
    ) =>
    if not _users.contains(user_id) then
        callback((Failure, "User not found"))
        return
    end

    try
        let user = _users(user_id)?
        let feed = recover Array[PostData] end
        
        for subreddit_id in user.subreddits.values() do
        if _subreddits.contains(subreddit_id) then
            let subreddit = _subreddits(subreddit_id)?
            for post_id in subreddit.posts.values() do
            if _posts.contains(post_id) then
                feed.push(_posts(post_id)?)
            end
            end
        end
        end

        callback((Success, consume feed))
    else
        callback((Failure, "Error accessing user data"))
    end

    be leave_result(result: JoinResult, username: String, subreddit_name: String) =>
      match result
      | (Success, let message: String) =>
        _env.out.print(username + " left " + subreddit_name)
      else
        _env.out.print(username + " failed to leave " + subreddit_name)
      end

    fun ref _vote_post(
    user_id: String,
    post_id: String,
    is_upvote: Bool,
    callback: {(VoteResult)} val
    ) =>
    try
        let post = _posts(post_id)?
        let upvotes = recover Array[String] end
        let downvotes = recover Array[String] end
        
        for v in post.upvotes.values() do
        if v != user_id then
            upvotes.push(v)
        end
        end
        
        for v in post.downvotes.values() do
        if v != user_id then
            downvotes.push(v)
        end
        end

        if is_upvote then
        upvotes.push(user_id)
        else
        downvotes.push(user_id)
        end

        let new_score = upvotes.size().i64() - downvotes.size().i64()
        
        let new_post = PostData(
        post.id,
        post.title,
        post.content,
        post.author_id,
        post.subreddit_id,
        post.created_at,
        consume upvotes,
        consume downvotes,
        post.comments,
        new_score
        )
        
        _posts(post_id) = new_post
        callback((Success, "Vote recorded"))
    else
        callback((Failure, "Failed to vote on post"))
    end

    fun ref _vote_comment(
    user_id: String,
    comment_id: String,
    is_upvote: Bool,
    callback: {(VoteResult)} val
    ) =>
    try
        let comment = _comments(comment_id)?
        let upvotes = recover Array[String] end
        let downvotes = recover Array[String] end
        
        for v in comment.upvotes.values() do
        if v != user_id then
            upvotes.push(v)
        end
        end
        
        for v in comment.downvotes.values() do
        if v != user_id then
            downvotes.push(v)
        end
        end

        if is_upvote then
        upvotes.push(user_id)
        else
        downvotes.push(user_id)
        end

        let new_score = upvotes.size().i64() - downvotes.size().i64()
        
        let new_comment = CommentData(
        comment.id,
        comment.content,
        comment.author_id,
        comment.post_id,
        comment.parent_comment_id,
        comment.created_at,
        consume upvotes,
        consume downvotes,
        comment.replies,
        new_score
        )
        
        _comments(comment_id) = new_comment
        callback((Success, "Vote recorded"))
    else
        callback((Failure, "Failed to vote on comment"))
    end


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