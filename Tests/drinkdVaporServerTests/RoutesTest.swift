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

@Suite("Routes Tests")
struct RoutesTest {

    private let createParty = CreatePartyRequest(username: "User007", userID: UUID(uuidString: "df456789-1234-5678-90ab-cdef12345678")!, restaurants_url: "https://api.yelp.com/v3/businesses/search?categories=bars&latitude=37.774292458506686&longitude=-122.21621476154564&limit=10", partyName: "Party007")

//    @Test("Create a Party")
//    func createaParty_Test() async throws {
//
//        try await withApp(configure: configure) { app in
//
//            let data = try JSONEncoder().encode(createParty)
//            let buffer = ByteBuffer(data: data)
//
//            try await app.testing().test(.POST, "createParty", body: buffer) { res async in
//                do {
//                    let response = try JSONDecoder().decode(CreatePartyResponse.self, from: res.body)
//                    #expect(res.status == .ok)
//                } catch {
//                    Issue.record(error)
//                }
//
//
//            }
//
//
//
//        }
//    }

}
