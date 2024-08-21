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
        if user is User {
            return user;
        } else {
            return http:NOT_FOUND;
        }
    }

    resource function post users(NewUser newUser) returns http:Created|error {
        User user = { 
            id: userTable.length() + 1, 
            ...newUser
        };
        userTable.add(user);
        return http:CREATED;
    }

    resource function get posts() returns Post[]|error {
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
            createdTimeStamp: time:utcToCivil(time:utcNow()),
            ...newPost
        };
        postTable.add(post);
        return http:CREATED;
    }
}
