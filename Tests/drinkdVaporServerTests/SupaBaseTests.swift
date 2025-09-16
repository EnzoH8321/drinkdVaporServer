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

    let partyLeader = FakePartyLeader()
    let guest = FakeGuest()
    let party = FakeParty()
    let restaurant = FakeRestaurant()

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
            try await stubCreateAGuest(partyID: party.id)

            let req = LeavePartyRequest(userID: partyLeader.id)

            try await supabase.leavePartyAsHost(req, partyID: party.id)

            try await stubCleanupUser(guest.id)
            try await stubCleanupParty()
        } catch {
            Issue.record(error)
        }

    }

    @Test("Leave party as guest")
    func leavePartyAsGuest_Test() async throws {

        do {

            try await stubCreateAParty()
            try await stubCreateAGuest(partyID: party.id)
            let req = LeavePartyRequest(userID: guest.id)

            try await supabase.leavePartyAsGuest(req)

            try await stubCleanupParty()
            try await stubCleanupUser(guest.id)
        } catch {
            Issue.record(error)
        }

    }

    @Test("Join a Party")
    func joinParty_Test() async throws {
        do {
            let _ = try await stubCreateAParty()
            let req = JoinPartyRequest(userID: guest.id, username: guest.username, partyCode: party.code)

            let parties = try await supabase.joinParty(req)
            #expect(parties.code == party.code)
            #expect(parties.party_leader == partyLeader.id)
            #expect(parties.party_name == "Party007")
            #expect(parties.id == party.id)

            try await stubCleanupParty()
            try await stubCleanupUser(guest.id)

        } catch {
            Issue.record(error)
        }

    }

    @Test("Update restaurant rating")
    func updateRestaurantRating_Test() async throws {

        do {
            try await stubCreateAParty()
            try await stubCreateARestaurant()
            let req = UpdateRatingRequest(partyID: party.id, userID: partyLeader.id, userName: partyLeader.username, restaurantName: restaurant.name, rating: restaurant.rating, imageURL: restaurant.imageURL)

            try await supabase.updateRestaurantRating(req)

            try await stubCleanupRestaurant()
            try await stubCleanupParty()
        } catch {
            Issue.record(error)
        }

    }


}

extension SupaBaseTests {


    // Stub create a party
    private func stubCreateAParty() async throws  {
        let table = PartiesTable(id: party.id, party_name: party.name, party_leader: partyLeader.id, date_created: Date().ISO8601Format(), code: party.code, restaurants_url: party.restaurantURL)

        do {
            try await client.from(TableTypes.parties.tableName).upsert(table).execute()

        }

    }

    // Stub create a host
    private func stubCreateAHost(partyID: UUID) async throws  {
        let host = UsersTable(id: partyLeader.id, username: partyLeader.username, date_created: Date().ISO8601Format(), memberOfParty: partyID)
        try await client.from(TableTypes.users.tableName).upsert(host).execute()
    }

    private func stubCreateAGuest(partyID: UUID) async throws  {
        let guest = UsersTable(id: guest.id, username: guest.username, date_created: Date().ISO8601Format(), memberOfParty: partyID)
        try await client.from(TableTypes.users.tableName).upsert(guest).execute()
     }

    private func stubCreateARestaurant() async throws {
        let restaurant = RatedRestaurantsTable(id: restaurant.id, partyID: restaurant.partyID, userID: partyLeader.id, userName: partyLeader.username, restaurantName: restaurant.name, rating: restaurant.rating, imageURL: restaurant.imageURL)

        try await client.from(TableTypes.ratedRestaurants.tableName).upsert(restaurant).execute()

    }

    // Delete created row
    private func stubCleanup(_ userLevel: UserLevel) async {
        let userID = (userLevel == .leader) ? partyLeader.id : guest.id

        do {
            try await client.from(TableTypes.parties.tableName).delete().eq("id", value: party.id).execute()
            try await client.from(TableTypes.users.tableName).delete().eq("id", value: userID).execute()
        } catch {
            Issue.record("deleteDataFromTable failed: \(error)")
        }
    }

    private func stubCleanupParty(partyID: UUID = FakeParty().id) async throws {
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
            try await client.from(TableTypes.users.tableName).delete().eq("id", value: restaurant.id).execute()
        }
    }
}

extension SupaBaseTests {
    struct FakePartyLeader {
        let username = "Leader007"
        let id: UUID = UUID(uuidString: "F47AC10B-58CC-4372-A567-0E02B2C3D479")!
    }

    struct FakeGuest {
        let username = "Guest007"
        let id: UUID = UUID(uuidString: "C3D4E5F6-1A2B-4C7D-8E9F-0A1B2C3D4E5F")!
    }

    struct FakeParty {
        let id: UUID = UUID(uuidString: "C3D3E5F6-1A2B-4C7D-8E9F-0A2B2C3D4E6F")!
        let restaurantURL = "https://api.yelp.com/v3/businesses/search?categories=bars&latitude=37.774292458506686&longitude=-122.21621476154564&limit=10"
        let name = "Party007"
        let code = 345789
    }

    struct FakeRestaurant {
        let name = "BestRestaurant007"
        let rating = 4
        let imageURL = "https://s3-media0.fl.yelpcdn.com/bphoto/rKctRFj8diqswEkATTDC5g/o.jpg"
        let partyID = UUID(uuidString: "C3D3E5F6-1A2B-4C7D-8E9F-0A2B2C3D4E6F")!
        let id = UUID(uuidString: "B3D3A5F6-1A3B-5C7D-8E9F-0A3B2C3D4E6F")!
    }

    enum UserLevel {
        case leader
        case guest
    }
}
