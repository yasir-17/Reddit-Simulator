# Functionality
1) Registering of the users on Reddit. Each users are assigned with unique hexadecimal id on registering.
2) Creation of subreddit. Each users can join and leave any of the subreddit.
3) Users have the ability to post on the subreddit.
4) Ability to hierarchical comment in the subreddit.
5) Users can upvote and downvote post and comments. Karma are compute using this.
6) Users have the capability to message directly other users.
7) Options to display feeds and direct messages have been added.

# Simulation
1) Get number of users from command line.
2) Get number of subreddit to be created from the command line.
3) Users are online when they registered and they become offline after some time. 
3) The number of posts and comments are directly added in the code. Its also possible to get these from the command line.
4) Zipf distribution have been implmented. The subreddit with more users have more posts and viceversa.

# Steps to run.
1) Clone the repository or unzip the directory.
2) Run ponyc to compile.
3) Run .\reddit.exe <number_of_users> <number_of_subreddits>

# Output
1) Added the print statement for the creation and registration of users.
2) Added print statement for the creation of subreddit.
3) Users are commenting, upvoting and downvoting posts/comments.
4) Users are messaging directly to other users. 
5) For random users we see its feeds and direct messages (if any)
6) For some subreddit, we see the posts in it, their comments (if any) and the users in the subreddit.

# Maximum network running
The maximum network I was able to run was 64000 users and 4000 subreddits. 



### 4.2

I have used corral which is a dependency management tool for Pony. See the following link for more information and its installation
https://github.com/ponylang/corral

## Compilation
Use the command corral run -- ponyc --define openssl_0.9.0 

## Demonstration
The following curl command could be used to verify the functionality

- Register user
    curl -Uri "http://localhost:8080/register" -Method POST -Headers @{"Content-Type"="application/json"} -Body '{"username": "testuser1", "password": "securepassword"}'

- Create Subreddit
    curl -Uri "http://localhost:8080/subreddit" -Method POST -Headers @{"Content-Type"="application/json"} -Body '{"name": "funny", "description": "A place for laughs", "creator_id": "user1"}'

- Join Subreddit
    curl -Uri "http://localhost:8080/join_subreddit" -Method POST -Headers @{"Content-Type"="application/json"} -Body '{"user_id": "user1", "subreddit_id": "subreddit1"}'

- Create Post
    curl -Uri "http://localhost:8080/create_post" -Method POST -Headers @{"Content-Type"="application/json"} -Body '{"title": "First Post", "content": "Hello, world!", "author_id": "user1", "subreddit_id": "subreddit1"}'

- Add Comment
    curl -Uri "http://localhost:8080/add_comment" -Method POST -Headers @{"Content-Type"="application/json"} -Body '{"content": "This is a comment", "author_id": "user1", "post_id": "post1", "parent_comment_id": null}'

- Send Message
    curl -Uri "http://localhost:8080/send_message" -Method POST -Headers @{"Content-Type"="application/json"} -Body '{"content": "Hello!", "sender_id": "user1", "receiver_id": "user2", "parent_message_id": null}'

- Get Message
    curl -Uri "http://localhost:8080/get_messages" -Method POST -Headers @{"Content-Type"="application/json"} -Body '{"user_id": "user1"}'

- Get subreddit post
    curl -Uri "http://localhost:8080/subreddit_posts" -Method POST -Headers @{"Content-Type"="application/json"} -Body '{"subreddit_id": "subreddit1"}'

- Get subreddit user
    curl -Uri "http://localhost:8080/subreddit_users" -Method POST -Headers @{"Content-Type"="application/json"} -Body '{"subreddit_id": "subreddit1"}'

- Get user feed
    curl -Uri "http://localhost:8080/user_feed" -Method POST -Headers @{"Content-Type"="application/json"} -Body '{"user_id": "user1"}'

- Vote
    curl -Uri "http://localhost:8080/vote" -Method POST -Headers @{"Content-Type"="application/json"} -Body '{"user_id": "user1", "target_id": "post_or_comment_id", "is_upvote": true}'


## Demo
https://youtu.be/Ep6kw1Z9QvM
