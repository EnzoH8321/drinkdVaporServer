//
//  Test.swift
//  drinkdVaporServer
//
//  Created by Enzo Herrera on 9/10/25.
//

import Testing
import Vapor
import Supabase
import drinkdSharedModels
@testable import drinkdVaporServer

@Suite("Supabase Tests", .serialized)
struct SupaBaseTests {

    let supabase: SupaBase
    let client: SupabaseClient

    init() {
        let client = SupabaseClient(supabaseURL: URL(string: "http://localhost:54321")!, supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0")

        let supabase = SupaBase(client: client)

        self.supabase = supabase
        self.client = client
    }

    @Test("Create a party")
    func createParty_Test() async throws {
        let userID = UUID()
        let restaurantURL = "https://api.yelp.com/v3/businesses/search?categories=bars&latitude=37.774292458506686&longitude=-122.21621476154564&limit=10"
        let req = CreatePartyRequest(username: "Test007", userID: userID, restaurants_url: restaurantURL, partyName: "Party007")

        do {
            let party = try await supabase.createAParty(req)
            #expect(party.party_name == req.partyName)
            #expect(party.party_leader == req.userID)
            #expect(party.restaurants_url == req.restaurants_url)

            try await stubCleanupUser(userID)
            try await stubCleanupParty(partyID: party.id)
        } catch {
            Issue.record(error)
        }

    }

    @Test("Leave party as host")
    func leavePartyAsHost_Test() async throws {

        do {

            try await stubCreateAParty()
            try await stubCreateAGuest()

            let req = LeavePartyRequest(userID: FakePartyLeader.id)

            try await supabase.leavePartyAsHost(req, partyID: FakeParty.id)

            try await stubCleanupUser(FakeGuest.id)
            try await stubCleanupParty()
        } catch {
            Issue.record(error)
        }

    }

    @Test("Leave party as guest")
    func leavePartyAsGuest_Test() async throws {

        do {

            try await stubCreateAParty()
            try await stubCreateAGuest()
            let req = LeavePartyRequest(userID: FakeGuest.id)

            try await supabase.leavePartyAsGuest(req)

            try await stubCleanupParty()
            try await stubCleanupUser(FakeGuest.id)
        } catch {
            Issue.record(error)
        }

    }

    @Test("Join a Party")
    func joinParty_Test() async throws {
        do {
            let _ = try await stubCreateAParty()
            let req = JoinPartyRequest(userID: FakeGuest.id, username: FakeGuest.username, partyCode: FakeParty.code)

            let parties = try await supabase.joinParty(req)
            #expect(parties.code == FakeParty.code)
            #expect(parties.party_leader == FakePartyLeader.id)
            #expect(parties.party_name == "Party007")
            #expect(parties.id == FakeParty.id)

            try await stubCleanupParty()
            try await stubCleanupUser(FakeGuest.id)

        } catch {
            Issue.record(error)
        }

    }

    @Test("Update restaurant rating")
    func updateRestaurantRating_Test() async throws {

        do {
            try await stubCreateAParty()
            try await stubCreateARestaurant()
            let req = UpdateRatingRequest(partyID: FakeParty.id, userID: FakePartyLeader.id, userName: FakePartyLeader.username, restaurantName: FakeRestaurant.name, rating: FakeRestaurant.rating, imageURL: FakeRestaurant.imageURL)

            try await supabase.updateRestaurantRating(req)

            try await stubCleanupRestaurant()
            try await stubCleanupParty()
        } catch {
            Issue.record(error)
        }
    }

    @Test("Send a Message")
    func sendMessage_Test() async throws {

        do {
            try await stubCreateAParty()
            try await stubCreateAGuest()

            let req = SendMessageRequest(userID: FakeGuest.id, username: FakeGuest.username, partyID: FakeParty.id, message: "TestMessage007")
            let messageID = UUID()

            try await supabase.sendMessage(req, messageID: messageID)

            try await stubCleanupParty()
            try await stubCleanupUser(FakeGuest.id)
        } catch {
            Issue.record(error)
        }

    }

}

extension SupaBaseTests {


    // Stub create a party
    private func stubCreateAParty() async throws  {
        let table = PartiesTable(id: FakeParty.id, party_name: FakeParty.name, party_leader: FakePartyLeader.id, date_created: Date().ISO8601Format(), code: FakeParty.code, restaurants_url: FakeParty.restaurantURL)

        do {
            try await client.from(TableTypes.parties.tableName).upsert(table).execute()
        }

    }

    // Stub create a host
    private func stubCreateAHost() async throws  {
        let host = UsersTable(id: FakePartyLeader.id, username: FakePartyLeader.username, date_created: Date().ISO8601Format(), memberOfParty: FakeParty.id)
        try await client.from(TableTypes.users.tableName).upsert(host).execute()
    }

    private func stubCreateAGuest() async throws  {
        let guest = UsersTable(id: FakeGuest.id, username: FakeGuest.username, date_created: Date().ISO8601Format(), memberOfParty: FakeParty.id)
        try await client.from(TableTypes.users.tableName).upsert(guest).execute()
     }

    private func stubCreateARestaurant() async throws {
        let restaurant = RatedRestaurantsTable(id: FakeRestaurant.id, partyID: FakeRestaurant.partyID, userID: FakePartyLeader.id, userName: FakePartyLeader.username, restaurantName: FakeRestaurant.name, rating: FakeRestaurant.rating, imageURL: FakeRestaurant.imageURL)

        try await client.from(TableTypes.ratedRestaurants.tableName).upsert(restaurant).execute()
    }

    // Delete created row
    private func stubCleanup(_ userLevel: UserLevel) async {
        let userID = (userLevel == .leader) ? FakePartyLeader.id : FakeGuest.id

        do {
            try await client.from(TableTypes.parties.tableName).delete().eq("id", value: FakeParty.id).execute()
            try await client.from(TableTypes.users.tableName).delete().eq("id", value: userID).execute()
        } catch {
            Issue.record("deleteDataFromTable failed: \(error)")
        }
    }

    private func stubCleanupParty(partyID: UUID = FakeParty.id) async throws {
        do {
            try await client.from(TableTypes.parties.tableName).delete().eq("id", value: partyID).execute()
        }
    }

    private func stubCleanupUser(_ userID: UUID) async throws {
        do {
            try await client.from(TableTypes.users.tableName).delete().eq("id", value: userID).execute()
        }
    }

    private func stubCleanupRestaurant() async throws {
        do {
            try await client.from(TableTypes.users.tableName).delete().eq("id", value: FakeRestaurant.id).execute()
        }
    }
}

extension SupaBaseTests {
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

    enum UserLevel {
        case leader
        case guest
    }
}
