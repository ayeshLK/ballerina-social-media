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
}
