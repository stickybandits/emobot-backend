import Foundation
import HTTP
import Models
import Vapor

class Bot {
    let token: String
    let webClient: SlackWebClient
    
    private func webSocketURL() throws -> String {
        let rtmResponse = try BasicClient.loadRealtimeApi(token: token)
        guard let webSocketURL = rtmResponse.data["url"]?.string else { throw BotError.invalidResponse }
        return webSocketURL
    }
    
    init(token: String) {
        self.token = token
        self.webClient = SlackWebClient(token: token)
    }
    
    func run() throws {
        let webSocketURL = try self.webSocketURL()
        try WebSocket.connect(to: webSocketURL) { ws in
            print("Connected to \(webSocketURL)")
            
            ws.onText = { ws, text in
                print("[event] - \(text)")
                
                let event = try JSON(bytes: text.utf8.array)
                guard
                    let fromUserID = event["user"]?.string,
                    let channelID = event["channel"]?.string,
                    let text = event["text"]?.string
                    else { return }
                
                do {
                    if text.hasPrefix("hello") {
                        let response = SlackMessage(to: channelID, text: "Hi there 👋")
                        try ws.send(response)
                        return
                    } else if text.hasPrefix("version") {
                        let response = SlackMessage(to: channelID, text: "Current Version: \(VERSION)")
                        try ws.send(response)
                        return
                    }
                    
                    let kudoRegex = try NSRegularExpression(pattern: "(\\w+)\\+\\+\\s+(.*)", options: [])
                    if let match = kudoRegex.actuallyUsableMatch(in: text) {
                        let toUser = match.captures[0]
                        let description = match.captures[1]
                        guard
                            let channel = try self.webClient.getChannelName(forID: channelID),
                            let fromUser = try self.webClient.getUserName(forID: fromUserID) else {
                                return
                        }

                        var kudo = Kudo(fromUser: fromUser, toUser: toUser, description: description, channel: channel)
                        try kudo.save()
                        let response = SlackMessage(to: channelID, text: "\(fromUser) sent kudos to \(toUser) in \(channel): \(description)")
                        try ws.send(response)

                        let values = try Value.all()
                        for value in values where text.contains(":\(value.emojiAlphaCode):") {
                            var reaction = Reaction(kudoID: kudo.id, valueID: value.id, fromUser: fromUser)
                            try reaction.save()

                            let response = SlackMessage(to: channelID, text: "Recorded \(value.name) reaction from \(fromUser)")
                            try ws.send(response)
                        }
                    }
                } catch {
                    print("Error: \(error)")
                    let response = SlackMessage(to: channelID, text: "Error: \(error)")
                    try ws.send(response)
                }
            }
            
            ws.onClose = { ws, _, _, _ in
                print("\n[CLOSED]\n")
            }
        }
    }
}

extension NSRegularExpression {
    func actuallyUsableMatch(in string: String) -> (fullMatch: String, captures: [String])? {
        let nsString = NSString(string: string)
        let range = NSMakeRange(0, nsString.length)
        guard let match = firstMatch(in: string, options: [], range: range) else {
            return nil
        }
        
        let fullMatch = nsString.substring(with: match.range)
        var captures: [String] = []
        for i in 1 ..< match.numberOfRanges {
            #if os(Linux)
                let range = match.range(at: i)
            #else
                let range = match.rangeAt(i)
            #endif
            captures.append(nsString.substring(with: range))
        }
        return (fullMatch, captures)
    }
}
