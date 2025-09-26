//
//  File.swift
//  drinkdVaporServer
//
//  Created by Enzo Herrera on 9/18/25.
//
import Testing
import Foundation
import drinkdSharedModels
import Supabase

final class SupabaseUtils {
    // Stub create a party
    static func stubCreateAParty(client: SupabaseClient) async throws  {
        let table = PartiesTable(id: FakeParty.id, party_name: FakeParty.name, party_leader: FakePartyLeader.id, date_created: Date().ISO8601Format(), code: FakeParty.code, restaurants_url: FakeParty.restaurantURL)

            try await client.from(TableTypes.parties.tableName).upsert(table).execute()
    }

    // Stub create a host
    static  func stubCreateAHost(client: SupabaseClient) async throws  {
        let host = UsersTable(id: FakePartyLeader.id, username: FakePartyLeader.username, date_created: Date().ISO8601Format(), memberOfParty: FakeParty.id)
        try await client.from(TableTypes.users.tableName).upsert(host).execute()
    }

    static  func stubCreateAGuest(client: SupabaseClient) async throws  {
        let guest = UsersTable(id: FakeGuest.id, username: FakeGuest.username, date_created: Date().ISO8601Format(), memberOfParty: FakeParty.id)
        try await client.from(TableTypes.users.tableName).upsert(guest).execute()
    }

    static  func stubCreateARestaurant(client: SupabaseClient) async throws {
        let restaurant = RatedRestaurantsTable(id: FakeRestaurant.id, partyID: FakeRestaurant.partyID, userID: FakePartyLeader.id, userName: FakePartyLeader.username, restaurantName: FakeRestaurant.name, rating: FakeRestaurant.rating, imageURL: FakeRestaurant.imageURL)

        try await client.from(TableTypes.ratedRestaurants.tableName).upsert(restaurant).execute()
    }

    static func stubCreateAMessage(userID: UUID, userName: String, client: SupabaseClient) async throws {
        let message = MessagesTable(id: FakeMessage.id, partyId: FakeParty.id, date_created: Date().ISO8601Format(), text: FakeMessage.text, userId: userID, user_name: userName)

        try await client.from(TableTypes.messages.tableName).upsert(message).execute()
    }

    // Delete created row
    static  func stubCleanup(_ userLevel: UserLevel, client: SupabaseClient) async {
        let userID = (userLevel == .leader) ? FakePartyLeader.id : FakeGuest.id

        do {
            try await client.from(TableTypes.parties.tableName).delete().eq("id", value: FakeParty.id).execute()
            try await client.from(TableTypes.users.tableName).delete().eq("id", value: userID).execute()
        } catch {
            Issue.record("deleteDataFromTable failed: \(error)")
        }
    }

    static  func stubCleanupParty(partyID: UUID = FakeParty.id, client: SupabaseClient) async throws {
        do {
            try await client.from(TableTypes.parties.tableName).delete().eq("id", value: partyID).execute()
        }
    }

    static  func stubCleanupUser(_ userID: UUID, client: SupabaseClient) async throws {
        do {
            try await client.from(TableTypes.users.tableName).delete().eq("id", value: userID).execute()
        }
    }

    static  func stubCleanupRestaurant(client: SupabaseClient) async throws {
        do {
            try await client.from(TableTypes.ratedRestaurants.tableName).delete().eq("id", value: FakeRestaurant.id).execute()
        }
    }

    static func stubCleanupMessage(client: SupabaseClient) async throws {
        do {
            try await client.from(TableTypes.messages.tableName).delete().eq("id", value: FakeMessage.id).execute()
        }
    }


}

struct FakePartyLeader {
    static let username = "Leader007"
    static let id: UUID = UUID(uuidString: "F47AC10B-58CC-4372-A567-0E02B2C3D479")!
}

struct FakeGuest {
    static let username = "Guest007"
    static let id: UUID = UUID(uuidString: "C3D4E5F6-1A2B-4C7D-8E9F-0A1B2C3D4E5F")!
}

struct FakeParty {
    static let id: UUID = UUID(uuidString: "C3D3E5F6-1A2B-4C7D-8E9F-0A2B2C3D4E6F")!
    static let restaurantURL = "https://api.yelp.com/v3/businesses/search?categories=bars&latitude=37.774292458506686&longitude=-122.21621476154564&limit=10"
    static let name = "Party007"
    static let code = 345789
}

struct FakeRestaurant {
    static let name = "BestRestaurant007"
    static let rating = 4
    static let imageURL = "https://s3-media0.fl.yelpcdn.com/bphoto/rKctRFj8diqswEkATTDC5g/o.jpg"
    static let partyID = FakeParty.id
    static let id = UUID(uuidString: "B3D3A5F6-1A3B-5C7D-8E9F-0A3B2C3D4E6F")!
}

struct FakeMessage {
    static let text = "Hi how are you?"
    static let id = UUID(uuidString: "A1D3E5F6-2A2B-3C7D-8E9A-0A2B5C3D4E6F")!
}

enum UserLevel {
    case leader
    case guest
}
