import Vapor
import Fluent
import Foundation

final class Kudo: Model {
    var id: Node?
    var fromUser: String
    var toUser: String
    var description: String
    var channel: String
    var dateSent: String
    
    init(from: String, to: String, description: String, channel: String, date: String) {
        self.id = UUID().uuidString.makeNode()
        self.fromUser = from
        self.toUser = to
        self.description = description
        self.channel = channel
        self.dateSent = date
    }

    init(node: Node, in context: Context) throws {
        id = try node.extract("id")
        fromUser = try node.extract("from_user")
        toUser = try node.extract("to_user")
        description = try node.extract("description")
        channel = try node.extract("channel")
        dateSent = try node.extract("date_sent")
    }

    func makeNode(context: Context) throws -> Node {
        return try Node(node: [
            "id": id,
            "from_user": fromUser,
            "to_user": toUser,
            "description": description,
            "channel": channel,
            "date_sent": dateSent,
        ])
    }
}

extension Kudo: Preparation {
    static func prepare(_ database: Database) throws {
        try database.create("kudos") { kudos in
            kudos.id()
            kudos.string("from_user")
            kudos.string("to_user")
            kudos.string("description")
            kudos.string("channel")
            kudos.string("date_sent")
        }
    }

    static func revert(_ database: Database) throws {
        try database.delete("kudos")
    }
}