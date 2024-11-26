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
