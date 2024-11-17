use "collections"
use "time"
use "random"
use "format"

class SimulateCommentsAndVotes is TimerNotify
  let _simulator: RedditSimulator tag

  new iso create(simulator: RedditSimulator tag) =>
    _simulator = simulator

  fun ref apply(timer: Timer, count: U64): Bool =>
    _simulator.simulate_comments_and_votes()
    false

actor Main
  new create(env: Env) =>
    let reddit = RedditEngine(env)
    let simulator = RedditSimulator(env, reddit)
    simulator.start(100, 5)

actor RedditSimulator
  let _env: Env
  let _reddit: RedditEngine
  let _rng: Random
  var _users: Array[UserData] = Array[UserData]
  var _subreddits: Array[SubredditData] = Array[SubredditData]
  var _posts: Array[PostData] = Array[PostData]
  var _user_count: USize = 0
  var _subreddit_count: USize = 0
  var _registered_users: USize = 0
  var _created_subreddits: USize = 0

  new create(env: Env, reddit: RedditEngine) =>
    _env = env
    _reddit = reddit
    _rng = Rand(Time.now()._1.u64())

  be user_registered(result: RegistrationResult) =>
    match result
    | (Success, let user: UserData) =>
      _users.push(user)
      _registered_users = _registered_users + 1
      _env.out.print("Registered user: " + user.username)
      if _registered_users == _user_count then
        create_subreddits()
      end
    else
      _env.out.print("Failed to register user")
    end

  be subreddit_created(result: SubredditResult) =>
    match result
    | (Success, let subreddit: SubredditData) =>
      _subreddits.push(subreddit)
      _created_subreddits = _created_subreddits + 1
      _env.out.print("Created subreddit: " + subreddit.name)
      if _created_subreddits == _subreddit_count then
        simulate_activities()
      end
    else
      _env.out.print("Failed to create subreddit")
    end

  be join_result(result: JoinResult, username: String, subreddit_name: String) =>
    match result
    | (Success, let message: String) =>
      _env.out.print(username + " joined " + subreddit_name)
    else
      _env.out.print(username + " failed to join " + subreddit_name)
    end

  be post_created(result: PostResult, username: String, subreddit_name: String) =>
    match result
    | (Success, let post: PostData) =>
      _posts.push(post)
      _env.out.print("Created post: " + post.title + " in " + subreddit_name)
    else
      _env.out.print("Failed to create post by " + username)
    end

  be comment_added(result: CommentResult, post_title: String) =>
    match result
    | (Success, let comment: CommentData) =>
      _env.out.print("Added comment to post: " + post_title)
    else
      _env.out.print("Failed to add comment to post: " + post_title)
    end

  be vote_recorded(result: VoteResult, username: String, post_title: String, is_upvote: Bool) =>
    match result
    | (Success, let message: String) =>
      _env.out.print(username + " " + (if is_upvote then "upvoted" else "downvoted" end) + " post: " + post_title)
    else
      _env.out.print("Failed to record vote by " + username)
    end

  be display_feed(result: FeedResult, username: String) =>
    match result
    | (Success, let feed: Array[PostData] val) =>
      _env.out.print("Feed for " + username + ":")
      for post in feed.values() do
        _env.out.print("  - " + post.title)
      end
    else
      _env.out.print("Failed to get feed for " + username)
    end

  be start(user_count: USize, subreddit_count: USize) =>
    _env.out.print("Starting simulation with " + user_count.string() + " users")
    _user_count = user_count
    _subreddit_count = subreddit_count
    simulate_users()

  be simulate_users() =>
    for i in Range(0, _user_count) do
      let username = recover val "user_" + i.string() end
      let password = recover val "password_" + i.string() end
      let simulator: RedditSimulator tag = this
      _reddit.register_user(username, password, {(result: RegistrationResult) => simulator.user_registered(result)})
    end

  be create_subreddits() =>
    _env.out.print("Creating " + _subreddit_count.string() + " subreddits")
    
    for i in Range(0, _subreddit_count) do
      try
        let name = recover val "subreddit_" + i.string() end
        let description = recover val "This is subreddit " + i.string() end
        let idx = _rng.int[USize](_users.size())
        let creator = _users(idx)?
        let simulator: RedditSimulator tag = this
        _reddit.create_subreddit(name, description, creator.id, 
          {(result: SubredditResult) => simulator.subreddit_created(result)})
      end
    end

  be simulate_activities() =>
    _env.out.print("Simulating user activities")
    let simulator: RedditSimulator tag = this
    
    // Simulate joining subreddits
    for user in _users.values() do
        try
        let join_count = _rng.int[USize](4) + 1 // Generate 1-4
        for _ in Range(0, join_count) do
            let idx = _rng.int[USize](_subreddits.size())
            let subreddit = _subreddits(idx)?
            _reddit.join_subreddit(user.id, subreddit.id, 
            {(result: JoinResult) => simulator.join_result(result, user.username, subreddit.name)})
        end
        end
    end

    // Simulate creating posts
    try
        for _ in Range(0, 50) do
        let user = _users(_rng.int[USize](_users.size()))?
        let subreddit = _subreddits(_rng.int[USize](_subreddits.size()))?
        let title = recover val "Post by " + user.username end
        let content = recover val "This is a test post in " + subreddit.name + "by " + user.username end
        _reddit.create_post(title, content, user.id, subreddit.id, 
            {(result: PostResult) => simulator.post_created(result, user.username, subreddit.name)})
        end
    end

    // Simulate comments and votes after a delay
    let timers = Timers
    let timer = Timer(SimulateCommentsAndVotes(simulator), 1_000_000_000)
    timers(consume timer)

  be simulate_comments_and_votes() =>
    let simulator: RedditSimulator tag = this
    
    try
        // Simulate comments
        for post in _posts.values() do
        let comment_count = _rng.int[USize](5) // 0-4 comments
        for _ in Range(0, comment_count) do
            let user = _users(_rng.int[USize](_users.size()))?
            let content = recover val "Comment by " + user.username end
            _reddit.add_comment(content, user.id, post.id, None, 
            {(result: CommentResult) => simulator.comment_added(result, post.title)})
        end
        end

        // Simulate voting
        for _ in Range(0, 100) do
        let user = _users(_rng.int[USize](_users.size()))?
        let post = _posts(_rng.int[USize](_posts.size()))?
        let is_upvote: Bool = _rng.next() < (U64.max_value() / 2)
        _reddit.vote(user.id, post.id, is_upvote, 
            {(result: VoteResult) => simulator.vote_recorded(result, user.username, post.title, is_upvote)})
        end

        // Get feed for a random user
        let random_user = _users(_rng.int[USize](_users.size()))?
        _reddit.get_feed(random_user.id, 
        {(result: FeedResult) => simulator.display_feed(result, random_user.username)})
    end