use "collections"
use "time"
use "random"
use "format"

class UserConnectionStatus
  let username: String
  var is_online: Bool = false

  new create(name: String) =>
    username = name
    is_online = false

class SimulateCommentsAndVotes is TimerNotify
  let _simulator: RedditSimulator tag

  new iso create(simulator: RedditSimulator tag) =>
    _simulator = simulator

  fun ref apply(timer: Timer, count: U64): Bool =>
    _simulator.simulate_comments_and_votes()
    false

// actor Main
//   new create(env: Env) =>
//     try
//       // Parse command line arguments
//       if env.args.size() < 3 then
//         env.out.print("Usage: program <number_of_users> <number_of_subreddits>")
//         error
//       end
      
//       let user_count = env.args(1)?.usize()?
//       let subreddit_count = env.args(2)?.usize()?
      
//       // Validate input
//       if (user_count == 0) or (subreddit_count == 0) then
//         env.out.print("Error: Number of users and subreddits must be greater than 0")
//         error
//       end
      
//       let reddit = RedditEngine(env)
//       let simulator = RedditSimulator(env, reddit)
//       simulator.start(user_count, subreddit_count)
//     else
//       env.out.print("Error: Invalid input. Please provide valid positive numbers for users and subreddits.")
//     end

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
  var _connection_statuses: Array[UserConnectionStatus] = Array[UserConnectionStatus]

  new create(env: Env, reddit: RedditEngine) =>
    _env = env
    _reddit = reddit
    _rng = Rand(Time.now()._1.u64())
  
  fun ref calculate_zipf_probabilities(n: USize): Array[F64] =>
    """
    Calculate Zipf probabilities for n items.
    Returns normalized probabilities that sum to 1.0
    """
    let probs = Array[F64](n)
    var sum: F64 = 0.0
    
    for i in Range(0, n) do
      let rank = (i + 1).f64()
      let prob = 1.0 / rank  // Zipf's law: probability ∝ 1/rank
      probs.push(prob)
      sum = sum + prob
    end
    
    // Normalize probabilities to sum to 1
    for i in Range(0, n) do
      try
        probs(i)? = probs(i)? / sum
      end
    end
    probs

  fun ref choose_subreddit_with_zipf(): (SubredditData | None) =>
    """
    Choose a subreddit using Zipf distribution
    """
    try
      let probs = calculate_zipf_probabilities(_subreddits.size())
      let rand = _rng.real()
      var cumsum: F64 = 0.0
      
      for i in Range(0, _subreddits.size()) do
        cumsum = cumsum + probs(i)?
        if rand < cumsum then
          return _subreddits(i)?
        end
      end
    end
    None

  be user_registered(result: RegistrationResult) =>
    match result
    | (Success, let user: UserData) =>
      _users.push(user)
      
      // Create and track connection status
      let status = UserConnectionStatus(user.username)
      status.is_online = true  // Immediately set to online when created
      _connection_statuses.push(status)
      
      _registered_users = _registered_users + 1
      _env.out.print("Registered user: " + user.username + " (Online)")
      
      if _registered_users == _user_count then
        print_online_status()
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

  be display_post_comments(result: PostDetailsResult, post_title: String) =>
  match result
  | (Success, let details: PostDetails) =>
    _env.out.print("  Comments on \"" + post_title + "\":")
    for comment in details.comments.values() do
      _env.out.print("    - " + comment.author_name + ": " + comment.comment.content)
    end
  | (Failure, let error_val: String) =>
    _env.out.print("Failed to get comments for post \"" + post_title + "\": " + error_val)
  end

  be display_subreddit_info(subreddit_id: String) =>
    let simulator: RedditSimulator tag = this
    _reddit.get_subreddit_posts(subreddit_id, 
      {(result: SubredditPostsResult) => simulator.display_subreddit_posts(result, subreddit_id)})
    _reddit.get_subreddit_users(subreddit_id, 
      {(result: SubredditUsersResult) => simulator.display_subreddit_users(result, subreddit_id)})

  be display_subreddit_posts(result: SubredditPostsResult, subreddit_id: String) =>
  match result
  | (Success, let posts: Array[PostData] val) =>
    _env.out.print("Posts in subreddit " + subreddit_id + ":")
    for post in posts.values() do
      _env.out.print("  - " + post.title)

      // Fetch and display comments for each post
      let simulator: RedditSimulator tag = this
      _reddit.get_post_details(post.id, 
        {(result: PostDetailsResult) => simulator.display_post_comments(result, post.title)})
    end
  | (Failure, let error_name: String) =>
    _env.out.print("Failed to get posts for subreddit " + subreddit_id + ": " + error_name)
  end

  be display_subreddit_users(result: SubredditUsersResult, subreddit_id: String) =>
    match result
    | (Success, let users: Array[UserData] val) =>
      _env.out.print("Users in subreddit " + subreddit_id + ":")
      for user in users.values() do
        _env.out.print("  - " + user.username)
      end
    | (Failure, let error_name: String) =>
      _env.out.print("Failed to get users for subreddit " + subreddit_id + ": " + error_name)
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
  
  be display_post_details(result: PostDetailsResult, post_id: String) =>
    match result
    | (Success, let details: PostDetails) =>
      _env.out.print("\nPost Details for post " + post_id + ":")
      _env.out.print("Title: " + details.post.title)
      _env.out.print("Content: " + details.post.content)
      _env.out.print("Author: " + details.author_name)
      _env.out.print("Upvotes: " + details.post.upvotes.size().string())
      _env.out.print("Downvotes: " + details.post.downvotes.size().string())
      _env.out.print("Score: " + details.post.score.string())
      _env.out.print("\nComments:")
      for comment in details.comments.values() do
        _env.out.print("  - " + comment.author_name + ": " + comment.comment.content)
      end
    | (Failure, let error_val: String) =>
      _env.out.print("Failed to get post details: " + error_val)
    end
  
  be message_sent(result: MessageResult, sender_name: String, receiver_name: String) =>
    match result
    | (Success, let message: MessageData) =>
      _env.out.print(sender_name + " sent a message to " + receiver_name + ": " + message.content)
    else
      _env.out.print("Failed to send message from " + sender_name + " to " + receiver_name)
    end

  be display_messages(result: MessageListResult, username: String) =>
    match result
    | (Success, let messages: Array[MessageWithSender] val) =>
      _env.out.print("\nMessages for " + username + ":")
      for msg in messages.values() do
        _env.out.print("From " + msg.sender_name + ": " + msg.message.content)
        //_env.out.print("The direct message count is: " + msg.message.size().string())
      end
    else
      _env.out.print("Failed to get messages for " + username)
    end
  
  be print_online_status() =>
    _env.out.print("\n--- User Connection Status ---")
    var online_count: USize = 0
    for status in _connection_statuses.values() do
      if status.is_online then
        _env.out.print(status.username + ": Online")
        online_count = online_count + 1
      end
    end
    _env.out.print("Total Online Users: " + online_count.string() + " / " + _user_count.string())

  be go_offline() =>
    _env.out.print("\n--- Going Offline ---")
    for status in _connection_statuses.values() do
      status.is_online = false
      _env.out.print(status.username + ": Offline")
    end
    
    _env.out.print("All users are now offline.")


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

    // Create more posts for popular subreddits
    
      for subreddit in _subreddits.values() do
        // Calculate number of posts based on member count
        let member_count = subreddit.members.size()
        
        // Define post count based on popularity
        let post_count = if member_count < 100 then
          _rng.int[USize](10) + 1 // 
        elseif member_count < 500 then
          _rng.int[USize](50) + 3 // 3-5 posts
        else
          _rng.int[USize](250) + 6 // 6-10 posts
        end
        
        // Create posts
        for i in Range(0, post_count) do
          // Choose a random member of the subreddit to be the post author
          if subreddit.members.size() > 0 then
            let author_idx = _rng.int[USize](subreddit.members.size())
            try
              let author_id = subreddit.members(author_idx)?
              
              // Find author username for the callback
              var author_username: String = ""
              for user in _users.values() do
                if user.id == author_id then
                  author_username = user.username
                  break
                end
              end

              let final_username = author_username

              let post_num = i + 1
              let title = recover val "Post " + post_num.string() + " in " + subreddit.name end
              let content = recover val "This is post number " + post_num.string() + " in subreddit " + subreddit.name + " by " + final_username end
              
              _reddit.create_post(title, content, author_id, subreddit.id,
                {(result: PostResult) => simulator.post_created(result, final_username, subreddit.name)})
            end
          end
        end
      
    end

    try
      // Simulate direct messages
      for _ in Range(0, 20) do // Send 20 random messages
        let sender = _users(_rng.int[USize](_users.size()))?
        let receiver = _users(_rng.int[USize](_users.size()))?
        if sender.id != receiver.id then
          let content = recover val "Hello from " + sender.username + "!" end
          _reddit.send_message(content, sender.id, receiver.id, None,
            {(result: MessageResult) => simulator.message_sent(result, sender.username, receiver.username)})
        end
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

      // Simulate direct messages to this user
      let message_count = _rng.int[USize](5) + 1 // 1-5 messages
      for _ in Range(0, message_count) do
        let sender = _users(_rng.int[USize](_users.size()))?
        if sender.id != random_user.id then
          let content = recover val "Direct message from " + sender.username + " to " + random_user.username end
          _reddit.send_message(content, sender.id, random_user.id, None,
            {(result: MessageResult) => simulator.message_sent(result, sender.username, random_user.username)})
        end
      end

      // Get feed for the random user
      _reddit.get_feed(random_user.id, 
        {(result: FeedResult) => simulator.display_feed(result, random_user.username)})

      // Display messages for the same random user
      _reddit.get_messages(random_user.id,
        {(result: MessageListResult) => simulator.display_messages(result, random_user.username)})

      // Display info for the second subreddit (if it exists)
      if _subreddits.size() > 1 then
        let second_subreddit = _subreddits(1)?
        display_subreddit_info(second_subreddit.id)
      else
        _env.out.print("Not enough subreddits to display the second one")
      end

      // Select a random post and display its details
      if _posts.size() > 0 then
        let random_post = _posts(_rng.int[USize](_posts.size()))?
        _reddit.get_post_details(random_post.id, 
          {(result: PostDetailsResult) => simulator.display_post_details(result, random_post.id)})
      else
        _env.out.print("No posts available to display details")
      end
      
    else
      _env.out.print("An error occurred during simulation")
    end
