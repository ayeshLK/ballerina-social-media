import ballerina/http;
import ballerina/time;
import ballerinax/mysql;
import ballerina/sql;
import ballerinax/mysql.driver as _;

type User record {|
    readonly int id;
    string name;
    @sql:Column {
        name: "birth_date"
    }
    time:Date birthDate;
    @sql:Column {
        name: "mobile_number"
    }
    string mobileNumber;
|};

type NewUser record {|
    string name;
    time:Date birthDate;
    string mobileNumber;
|};

type Post record {|
    int id;
    string description;
    string tags;
    string category;
    @sql:Column {name: "created_time_stamp"}
    time:Civil createdTimeStamp;
|};

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

configurable string host = ?;
configurable string user = ?;
configurable string password = ?;
configurable string database = ?;
configurable int port = ?;
final mysql:Client socialMediaDb = check new (host, user, password, database, port);

@http:ServiceConfig {
    cors: {
        allowOrigins: ["*"]
    }
}
service /social\-media on new http:Listener(9095) { 
    resource function get users() returns User[]|error {
        stream<User, sql:Error?> query = socialMediaDb->query(`SELECT * FROM users`);
        User[] users = check from User user in query select user;
        return users;
    }

    resource function get users/[int id]() returns User|http:NotFound|error {
        User|sql:Error queryRow = socialMediaDb->queryRow(`SELECT * FROM users WHERE id = ${id}`);
        if queryRow is sql:NoRowsError {
            return http:NOT_FOUND;
        } else {
            return queryRow;
        }
    }

    resource function post users(NewUser newUser) returns http:Created|error {
        _ = check socialMediaDb->execute(`
            INSERT INTO users(birth_date, name, mobile_number)
            VALUES (${newUser.birthDate}, ${newUser.name}, ${newUser.mobileNumber});`);
        return http:CREATED;
    }

    resource function get posts() returns PostWithMeta[]|error {
        stream<User, sql:Error?> userStream = socialMediaDb->query(`SELECT * FROM users`);
        PostWithMeta[] posts = [];
        User[] users = check from User user in userStream
            select user;

        foreach User user in users {
            stream<Post, sql:Error?> postStream = socialMediaDb->query(`SELECT id, description, category, created_time_stamp, tags FROM posts WHERE user_id = ${user.id}`);
            Post[]|error userPosts = from Post post in postStream
                select post;
            PostWithMeta[] postsWithMeta = mapPostToPostWithMeta(check userPosts, user.name);
            posts.push(...postsWithMeta);
        }
        return posts;
    }

    resource function post users/[int id]/posts(NewPost newPost) returns http:Created|http:NotFound|http:Forbidden|error {
        User|error user = socialMediaDb->queryRow(`SELECT * FROM users WHERE id = ${id}`);
        if user is sql:NoRowsError {
            return http:NOT_FOUND;
        }
        if user is error {
            return user;
        }

        Sentiment sentiment = check sentimentEp->/api/sentiment.post({ "text": newPost.description });
        if sentiment.label == "neg" {
            return http:FORBIDDEN;
        }

        _ = check socialMediaDb->execute(`
            INSERT INTO posts(description, category, created_time_stamp, tags, user_id)
            VALUES (${newPost.description}, ${newPost.category}, CURRENT_TIMESTAMP(), ${newPost.tags}, ${id});`);
        return http:CREATED;
    }
}

function mapPostToPostWithMeta(Post[] posts, string author) returns PostWithMeta[] => from var postItem in posts
    select {
        id: postItem.id,
        description: postItem.description,
        author,
        meta: {
            tags: re `,`.split(postItem.tags),
            category: postItem.category,
            createdTimeStamp: postItem.createdTimeStamp
        }
    };
