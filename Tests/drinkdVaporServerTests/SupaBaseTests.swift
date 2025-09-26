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
        let client = SupaBase.setClient()
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

            try await SupabaseUtils.stubCleanupUser(userID, client: client)
            try await SupabaseUtils.stubCleanupParty(partyID: party.id, client: client)
        } catch {
            Issue.record(error)
        }

    }

    @Test("Leave party as host")
    func leavePartyAsHost_Test() async throws {

        do {

            try await SupabaseUtils.stubCreateAParty(client: client)
            try await SupabaseUtils.stubCreateAGuest(client: client)

            let req = LeavePartyRequest(userID: FakePartyLeader.id)

            try await supabase.leavePartyAsHost(req, partyID: FakeParty.id)

            try await SupabaseUtils.stubCleanupUser(FakeGuest.id, client: client)
            try await SupabaseUtils.stubCleanupParty(client: client)
        } catch {
            Issue.record(error)
        }

    }

    @Test("Leave party as guest")
    func leavePartyAsGuest_Test() async throws {

        do {

            try await SupabaseUtils.stubCreateAParty(client: client)
            try await SupabaseUtils.stubCreateAGuest(client: client)
            let req = LeavePartyRequest(userID: FakeGuest.id)

            try await supabase.leavePartyAsGuest(req)

            try await SupabaseUtils.stubCleanupParty(client: client)
            try await SupabaseUtils.stubCleanupUser(FakeGuest.id, client: client)
        } catch {
            Issue.record(error)
        }

    }

    @Test("Join a party")
    func joinParty_Test() async throws {
        do {
            let _ = try await SupabaseUtils.stubCreateAParty(client: client)
            let req = JoinPartyRequest(userID: FakeGuest.id, username: FakeGuest.username, partyCode: FakeParty.code)

            let parties = try await supabase.joinParty(req)
            #expect(parties.code == FakeParty.code)
            #expect(parties.party_leader == FakePartyLeader.id)
            #expect(parties.party_name == "Party007")
            #expect(parties.id == FakeParty.id)

            try await SupabaseUtils.stubCleanupParty(client: client)
            try await SupabaseUtils.stubCleanupUser(FakeGuest.id, client: client)

        } catch {
            Issue.record(error)
        }

    }

    @Test("Update restaurant rating")
    func updateRestaurantRating_Test() async throws {

        do {
            try await SupabaseUtils.stubCreateAParty(client: client)
            try await SupabaseUtils.stubCreateAHost(client: client)
            try await SupabaseUtils.stubCreateARestaurant(client: client)
            let req = UpdateRatingRequest(partyID: FakeParty.id, userID: FakePartyLeader.id, userName: FakePartyLeader.username, restaurantName: FakeRestaurant.name, rating: FakeRestaurant.rating, imageURL: FakeRestaurant.imageURL)

            try await supabase.updateRestaurantRating(req)

            try await SupabaseUtils.stubCleanupRestaurant(client: client)
            try await SupabaseUtils.stubCleanupParty(client: client)
            try await SupabaseUtils.stubCleanupUser(FakePartyLeader.id, client: client)
        } catch {
            Issue.record(error)
        }
    }

    @Test("Send a message")
    func sendMessage_Test() async throws {

        do {
            try await SupabaseUtils.stubCreateAParty(client: client)
            try await SupabaseUtils.stubCreateAGuest(client: client)

            let req = SendMessageRequest(userID: FakeGuest.id, username: FakeGuest.username, partyID: FakeParty.id, message: "TestMessage007")
            let messageID = UUID()

            try await supabase.sendMessage(req, messageID: messageID)

            try await SupabaseUtils.stubCleanupParty(client: client)
            try await SupabaseUtils.stubCleanupUser(FakeGuest.id, client: client)
        } catch {
            Issue.record(error)
        }

    }

    @Test("Top choices")
    func getTopChoices_Test() async throws {
        do {
            try await SupabaseUtils.stubCreateAParty(client: client)
            try await SupabaseUtils.stubCreateARestaurant(client: client)
            let restaurants = try await supabase.getTopChoices(partyID: FakeParty.id.uuidString)
            let restaurant = try #require(restaurants.first)

            #expect(restaurants.count == 1)
            #expect(restaurant.restaurant_name == FakeRestaurant.name)
            #expect(restaurant.rating == FakeRestaurant.rating)
            #expect(restaurant.id == FakeRestaurant.id)
            #expect(restaurant.image_url == FakeRestaurant.imageURL)
            #expect(restaurant.party_id == FakeRestaurant.partyID)

            try await SupabaseUtils.stubCleanupRestaurant(client: client)
            try await SupabaseUtils.stubCleanupParty(client: client)
        } catch {
            Issue.record(error)
        }

    }

    @Test("Rated restaurants")
    func getRatedRestaurants_Test() async throws {
        do {
            try await SupabaseUtils.stubCreateAParty(client: client)
            try await SupabaseUtils.stubCreateARestaurant(client: client)

            let restaurants = try await supabase.getRatedRestaurants(userID: FakePartyLeader.id.uuidString, partyID: FakeParty.id.uuidString)
            let restaurant = try #require(restaurants.first)

            #expect(restaurants.count == 1)
            #expect(restaurant.restaurant_name == FakeRestaurant.name)
            #expect(restaurant.rating == FakeRestaurant.rating)
            #expect(restaurant.id == FakeRestaurant.id)
            #expect(restaurant.image_url == FakeRestaurant.imageURL)
            #expect(restaurant.party_id == FakeRestaurant.partyID)

            try await SupabaseUtils.stubCleanupRestaurant(client: client)
            try await SupabaseUtils.stubCleanupParty(client: client)
        } catch {
            Issue.record(error)
        }
    }

    @Test("Rejoin party")
    func rejoinParty_Test() async throws {
        do {
            try await SupabaseUtils.stubCreateAParty(client: client)
            try await SupabaseUtils.stubCreateAHost(client: client)

            let party = try await supabase.rejoinParty(userID: FakePartyLeader.id.uuidString)

            #expect(party.id == FakeParty.id)
            #expect(party.party_name == FakeParty.name)
            #expect(party.party_leader == FakePartyLeader.id)
            #expect(party.code == FakeParty.code)
            #expect(party.restaurants_url == FakeParty.restaurantURL)

            try await SupabaseUtils.stubCleanupUser(FakePartyLeader.id, client: client)
            try await SupabaseUtils.stubCleanupParty(client: client)
        } catch {
            Issue.record(error)
        }
    }

}

