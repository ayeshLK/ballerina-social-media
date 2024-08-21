import ballerina/http;
import ballerina/time;

type User record {|
    readonly int id;
    string name;
    time:Date birthDate;
    string mobileNumber;
|};
table<User> key(id) userTable = table [
    {id: 1, name: "John Doe", birthDate: {year:1987, month:2, day:6 }, mobileNumber: "0712345678"},
    {id: 2, name: "Jane Doe", birthDate: {year:1988, month:3, day:7 }, mobileNumber: "0712345679"}
];

type NewUser record {|
    string name;
    time:Date birthDate;
    string mobileNumber;
|};

type Post record {|
    readonly int id;
    int userId;
    string description;
    string tags;
    string category;
    time:Civil createdTimeStamp;
|};
table<Post> key(id) postTable = table [];

public type NewPost record {|
    string description;
    string tags;
    string category;
|};

type PostWithMeta record {|
    int id;
    string description;
    string author;
    record {|
        string[] tags;
        string category;
        @sql:Column {name: "created_time_stamp"}
        time:Civil createdTimeStamp;
    |} meta;
|};

type Probability record {
    decimal neg;
    decimal neutral;
    decimal pos;
};

type Sentiment record {
    Probability probability;
    string label;
};
final http:Client sentimentEp = check new("localhost:9098/text-processing");

@http:ServiceConfig {
    cors: {
        allowOrigins: ["*"]
    }
}
service /social\-media on new http:Listener(9095) { 
    resource function get users() returns User[]|error {
        return userTable.toArray();
    }

    resource function get users/[int id]() returns User|http:NotFound|error {
        User? user = userTable[id];
        if user is () {
            return http:NOT_FOUND;
        }
        return user;
    }

    resource function post users(NewUser newUser) returns http:Created|error {
        User user = { 
            id: userTable.length() + 1, 
            name: newUser.name,
            birthDate: newUser.birthDate,
            mobileNumber: newUser.mobileNumber
        };
        userTable.add(user);
        return http:CREATED;
    }

    resource function get posts() returns PostWithMeta[]|error {
        PostWithMeta[] allUserPosts = [];
        foreach User user in userTable {
            Post[] userPosts = from Post post in postTable 
                where post.userId == user.id select post;
            PostWithMeta[] postsWithMeta = mapPostToPostWithMeta(check userPosts, user.name);
            allUserPosts.push(...postsWithMeta);
        }
        return postTable.toArray();
    }

    resource function post users/[int id]/posts(NewPost newPost) returns http:Created|http:NotFound|http:Forbidden|error {
        User? user = userTable[id];
        if user is () {
            return http:NOT_FOUND;
        }

        Sentiment sentiment = check sentimentEp->/api/sentiment.post({ "text": newPost.description });
        if sentiment.label == "neg" {
            return http:FORBIDDEN;
        }

        Post post = {
            id: postTable.length() + 1,
            userId: id,
            createdTimeStamp: time:utcToCivil(time:utcNow()),
            description: newPost.description,
            tags: newPost.tags,
            category: newPost.category
        };
        postTable.add(post);
        return http:CREATED;
    }
}

function mapPostToPostWithMeta(Post[] posts, string author) returns PostWithMeta[] => from var postItem in posts
    select {
        id: postItem.id,
        description: postItem.description,
        author,
        meta: {
            tags: regex:split(postItem.tags, ","),
            category: postItem.category,
            createdTimeStamp: postItem.createdTimeStamp
        }
    };
