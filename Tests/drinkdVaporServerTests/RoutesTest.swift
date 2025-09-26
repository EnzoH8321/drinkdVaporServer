//
//  Test.swift
//  drinkdVaporServer
//
//  Created by Enzo Herrera on 9/10/25.
//

import Testing
import VaporTesting
import drinkdSharedModels
@testable import drinkdVaporServer

@Suite("Routes Tests", .serialized)
struct RoutesTest {

    let client = SupaBase.setClient()

//    @Test("Create a party")
//    func createaParty_Test() async throws {
//
//        try await withApp(configure: configure) { app in
//            let party = CreatePartyRequest(username: FakePartyLeader.username, userID: FakePartyLeader.id, restaurants_url: FakeParty.restaurantURL, partyName: FakeParty.name)
//            let data = try JSONEncoder().encode(party)
//            let buffer = ByteBuffer(data: data)
//
//            try await app.testing().test(.POST, "createParty", body: buffer) { res async in
//
//                do {
//
//                    let resp = try JSONDecoder().decode(CreatePartyResponse.self, from: res.body)
//                    try await SupabaseUtils.stubCleanupParty(partyID: resp.partyID, client: client)
//                    try await SupabaseUtils.stubCleanupUser(FakePartyLeader.id, client: client)
//
//                    let partyResponse = try JSONDecoder().decode(CreatePartyResponse.self, from: res.body)
//
//                } catch {
//                    Issue.record(error)
//                }
//
//            }
//        }
//    }

    @Test("Join a party")
    func joinParty_Test() async throws {


        try await withApp(configure: configure) { app in
            let party = JoinPartyRequest(userID: FakePartyLeader.id, username: FakePartyLeader.username, partyCode: FakeParty.code)
            let data = try JSONEncoder().encode(party)
            let buffer = ByteBuffer(data: data)
            try await SupabaseUtils.stubCreateAParty(client: client)

            defer {
                Task {
                    try await SupabaseUtils.stubCleanupParty(client: client)
                    try await SupabaseUtils.stubCleanupUser(FakePartyLeader.id, client: client)
                }
            }


            try await app.testing().test(.POST, "joinParty", body: buffer) { res async in
                do {

                    let response = try JSONDecoder().decode(JoinPartyResponse.self, from: res.body)

                    #expect(response.partyID == FakeParty.id)
                    #expect(response.partyName == FakeParty.name)
                    #expect(response.partyCode == FakeParty.code)
                    #expect(response.yelpURL == FakeParty.restaurantURL)

                } catch {
                    Issue.record(error)
                }

            }

        }
    }

    @Test("Leave a party")
    func leaveParty_Test() async throws {

        try await withApp(configure: configure) { app in
            let party = LeavePartyRequest(userID: FakePartyLeader.id)
            let data = try JSONEncoder().encode(party)
            let buffer = ByteBuffer(data: data)
            try await SupabaseUtils.stubCreateAParty(client: client)
            try await SupabaseUtils.stubCreateAHost(client: client)

            defer {
                Task {
                    try await SupabaseUtils.stubCleanupUser(FakePartyLeader.id, client: client)
                    try await SupabaseUtils.stubCleanupRestaurant(client: client)
                }
            }

            try await app.testing().test(.POST, "leaveParty", body: buffer) { res async in

                do {

                    #expect((200...299).contains(res.status.code))

                } catch {
                    Issue.record(error)
                }

            }

        }

    }

    @Test("Send a message")
    func sendMessage_Test() async throws {

        try await withApp(configure: configure) { app in
                let messageReq = SendMessageRequest(userID: FakePartyLeader.id, username: FakePartyLeader.username, partyID: FakeParty.id, message: FakeMessage.text)
            let data = try JSONEncoder().encode(messageReq)
            let buffer = ByteBuffer(data: data)

            try await SupabaseUtils.stubCreateAParty(client: client)
            try await SupabaseUtils.stubCreateAHost(client: client)

            defer {
                Task {
                    try await SupabaseUtils.stubCleanupParty(client: client)
                    try await SupabaseUtils.stubCleanupUser(FakeParty.id, client: client)
                }
            }

            try await app.testing().test(.POST, "sendMessage", body: buffer) { res async in
                #expect((200...299).contains(res.status.code))
            }

        }

    }

    @Test("Update rating")
    func updateRating_Test() async throws {

        try await withApp(configure: configure) { app in
            let updateReq = UpdateRatingRequest(partyID: FakeParty.id, userID: FakePartyLeader.id, userName: FakePartyLeader.username, restaurantName: FakeRestaurant.name, rating: FakeRestaurant.rating, imageURL: FakeRestaurant.imageURL)
            let data = try JSONEncoder().encode(updateReq)
            let buffer = ByteBuffer(data: data)
            try await SupabaseUtils.stubCreateAParty(client: client)
            try await SupabaseUtils.stubCreateAHost(client: client)
            try await SupabaseUtils.stubCreateARestaurant(client: client)

            defer {
                Task {
                    try await SupabaseUtils.stubCleanupUser(FakePartyLeader.id, client: client)
                    try await SupabaseUtils.stubCleanupParty(client: client)
                    try await SupabaseUtils.stubCleanupRestaurant(client: client)
                }
            }


            try await app.testing().test(.POST, "updateRating", body: buffer) { res async in
                do {
                    #expect((200...299).contains(res.status.code))
                }
            }



        }

    }

    @Test("Rated restaurants")
    func ratedRestaurants_Test() async throws {

        try await withApp(configure: configure) { app in

            try await SupabaseUtils.stubCreateAHost(client: client)
            try await SupabaseUtils.stubCreateAParty(client: client)
            try await SupabaseUtils.stubCreateARestaurant(client: client)

            defer {
                Task {
                    try await SupabaseUtils.stubCleanupUser(FakePartyLeader.id, client: client)
                    try await SupabaseUtils.stubCleanupParty(client: client)
                    try await SupabaseUtils.stubCleanupRestaurant(client: client)
                }
            }


            try await app.testing().test(.GET, "ratedRestaurants?userID=\(FakePartyLeader.id.uuidString)&partyID=\(FakeParty.id.uuidString)") { res async in
                do {
                    #expect((200...299).contains(res.status.code))
                    let restaurantResponse = try JSONDecoder().decode(RatedRestaurantsGetResponse.self, from: res.body)
                    let restaurant = try #require(restaurantResponse.ratedRestaurants.first)
                    #expect(restaurant.id == FakeRestaurant.id)
                    #expect(restaurant.rating == FakeRestaurant.rating)
                    #expect(restaurant.username == FakePartyLeader.username)
                    #expect(restaurant.user_id == FakePartyLeader.id)
                    #expect(restaurant.party_id == FakeParty.id)
                    #expect(restaurant.restaurant_name == FakeRestaurant.name)
                    #expect(restaurant.image_url == FakeRestaurant.imageURL)
                } catch {
                    Issue.record(error)
                }

            }

        }
    }

    @Test("Top restaurants")
    func topRestaurants_Test() async throws {

        try await withApp(configure: configure) { app in

            try await SupabaseUtils.stubCreateAHost(client: client)
            try await SupabaseUtils.stubCreateAParty(client: client)
            try await SupabaseUtils.stubCreateARestaurant(client: client)

            defer {
                Task {
                    try await SupabaseUtils.stubCleanupUser(FakePartyLeader.id, client: client)
                    try await SupabaseUtils.stubCleanupParty(client: client)
                    try await SupabaseUtils.stubCleanupRestaurant(client: client)
                }
            }

            try await app.testing().test(.GET, "topRestaurants?partyID=\(FakeParty.id)") { res async in
                do {
                    #expect((200...299).contains(res.status.code))
                    let response = try JSONDecoder().decode(TopRestaurantsGetResponse.self, from: res.body)
                    let restaurant = try #require(response.restaurants.first)

                    #expect(restaurant.id == FakeRestaurant.id)
                    #expect(restaurant.rating == FakeRestaurant.rating)
                    #expect(restaurant.username == FakePartyLeader.username)
                    #expect(restaurant.user_id == FakePartyLeader.id)
                    #expect(restaurant.party_id == FakeParty.id)
                    #expect(restaurant.restaurant_name == FakeRestaurant.name)
                    #expect(restaurant.image_url == FakeRestaurant.imageURL)
                } catch {
                    Issue.record(error)
                }


            }

        }
    }

    @Test("Rejoin party")
    func rejoinParty_Test() async throws {
        
        try await withApp(configure: configure) { app in


            try await SupabaseUtils.stubCreateAHost(client: client)
            try await SupabaseUtils.stubCreateAGuest(client: client)
            try await SupabaseUtils.stubCreateAParty(client: client)

            defer {
                Task {
                    try await SupabaseUtils.stubCleanupUser(FakePartyLeader.id, client: client)
                    try await SupabaseUtils.stubCleanupUser(FakeGuest.id, client: client)
                    try await SupabaseUtils.stubCleanupParty(client: client)
                }
            }

            try await app.testing().test(.GET, "rejoinParty?userID=\(FakeGuest.id)") { res async in


                do {
                    #expect((200...299).contains(res.status.code))
                    let response = try JSONDecoder().decode(RejoinPartyGetResponse.self, from: res.body)
                    #expect(response.username == FakeGuest.username)
                    #expect(response.partyID == FakeParty.id)
                    #expect(response.partyCode == FakeParty.code)
                    #expect(response.yelpURL == FakeParty.restaurantURL)
                    #expect(response.partyName == FakeParty.name)
                } catch {
                    Issue.record(error)
                }

            }


        }
    }

    @Test("Get messages")
    func getMessages_Test() async throws {
        try await withApp(configure: configure) { app in
            
            
            try await SupabaseUtils.stubCreateAHost(client: client)
            try await SupabaseUtils.stubCreateAParty(client: client)
            try await SupabaseUtils.stubCreateAMessage(userID: FakePartyLeader.id, userName: FakePartyLeader.username, client: client)

            defer {
                Task {
                    try await SupabaseUtils.stubCleanupUser(FakePartyLeader.id, client: client)
                    try await SupabaseUtils.stubCleanupParty(client: client)
                    try await SupabaseUtils.stubCleanupMessage(client: client)
                }
            }

            try await app.testing().test(.GET, "getMessages?partyID=\(FakeParty.id)") { res async in

                do {
                    #expect((200...299).contains(res.status.code))
                    let messages = try JSONDecoder().decode(MessagesGetResponse.self, from: res.body).messages
                    let firstMessage = try #require(messages.first)

                    #expect(messages.count == 1)
                    #expect(firstMessage.id == FakeMessage.id)
                    #expect(firstMessage.party_id == FakeParty.id)
                    #expect(firstMessage.text == FakeMessage.text)
                    #expect(firstMessage.user_id == FakePartyLeader.id)
                    #expect(firstMessage.user_name == FakePartyLeader.username)

                } catch {
                    Issue.record(error)
                }

            }
        }
    }


}

