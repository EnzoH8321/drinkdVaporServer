import Vapor
import drinkdSharedModels

func routes(_ app: Application, supabase: SupaBase, yelpAPIKey: String) throws {
    // For Testing the server is up and running
    app.get("hello") { req in
        return "HELLO VAPOR"
    }

    // MARK: Post Routes
    for route in HTTP.PostRoutes.allCases {
        switch route {

        case .createParty:
            // If successful, return a party ID
            // If unsuccessful, return an error string
            app.post("createParty") { req async -> Response in
                do {
                    guard let reqBody = req.body.data else { return Response(status: .badRequest) }
                    let req = try JSONDecoder().decode(CreatePartyRequest.self, from: reqBody)

                    let newParty = try await supabase.createAParty(req)

                    let respObj = CreatePartyResponse(partyID: newParty.id, partyCode: newParty.code)
                    return try RouteHelper.createResponse(data: respObj)

                } catch {
                    return RouteHelper.createErrorResponse(error: error, "Error on createParty route - \(error)")
                }

            }

        case .joinParty:
            // Join Party
            app.post("joinParty") { req async -> Response in

                do {
                    guard let reqBody = req.body.data else { return Response(status: .badRequest) }
                    let req = try JSONDecoder().decode(JoinPartyRequest.self, from: reqBody)
                    let party = try await supabase.joinParty(req)

                    let respObj = JoinPartyResponse(partyID: party.id, partyName: party.party_name, partyCode: party.code, yelpURL: party.restaurants_url ?? "")
                    return try RouteHelper.createResponse(data: respObj)

                } catch {

                    return RouteHelper.createErrorResponse(error: error, "Error on joinParty route - \(error)")
                }
            }

        case .leaveParty:
            // Leave Party
            app.post("leaveParty") { req async -> Response in

                do {
                    guard let reqBody = req.body.data else { return Response(status: .badRequest) }

                    let req = try JSONDecoder().decode(LeavePartyRequest.self, from: reqBody)

                    let partyData = try await supabase.fetchRows(tableType: .parties, dictionary: ["party_leader": "\(req.userID)"]).first as? PartiesTable

                    // Check if party leader
                    let partyRow = try await supabase.fetchRows(tableType: .parties, dictionary: ["party_leader": req.userID])

                    if !partyRow.isEmpty {
                        guard let partyData else { throw SharedErrors.supabase(error: .rowIsEmpty) }
                        try await supabase.leavePartyAsHost(req, partyID: partyData.id)
                    } else {
                        try await supabase.leavePartyAsGuest(req)
                    }

                    return Response()

                } catch {
                    return RouteHelper.createErrorResponse(error: error, "Error on leaveParty route - \(error)")
                }

            }

        case .sendMessage:
            // Send Message
            app.post("sendMessage") { req async -> Response in

                do {
                    guard let reqBody = req.body.data else { return Response(status: .badRequest) }
                    let msgReq = try JSONDecoder().decode(SendMessageRequest.self, from: reqBody)

                    //Message ID, same ID for both the MessageTable id & WSMessage
                    let id = UUID()

                    // Send Message to Messages Table
                    try await supabase.sendMessage(msgReq, messageID: id)

                    return Response()
                } catch {
                    return RouteHelper.createErrorResponse(error: error, "Error on leaveParty route - \(error)")
                }

            }

        case .updateRating:
            // Update Rating
            app.post("updateRating") { req async -> Response in

                do {
                    guard let reqBody = req.body.data else { return Response(status: .badRequest) }
                    let msgReq = try JSONDecoder().decode(UpdateRatingRequest.self, from: reqBody)

                    try await supabase.updateRestaurantRating(msgReq)

                    return Response()

                } catch {
                    return RouteHelper.createErrorResponse(error: error, "Error on updateRating route - \(error)")
                }
            }

        }
    }

    //MARK: Get Route
    for route in HTTP.GetRoutes.allCases {
        switch route {

        case .ratedRestaurants:
            app.get("ratedRestaurants") { req async -> Response in

                do {
                    guard let path = req.url.query else { return Response(status: .badRequest) }
                    let pathComponents = path.components(separatedBy: "&")
                    let userIDString = pathComponents[0].components(separatedBy: "=")[1]
                    let partyIDString = pathComponents[1].components(separatedBy: "=")[1]

                    guard let userID = pathComponents.count == 2 ? userIDString : nil else { throw SharedErrors.internalServerError(error: "Server was unable to parse the user id") }

                    guard let partyID = pathComponents.count == 2 ? partyIDString : nil else { throw SharedErrors.internalServerError(error: "Server was unable to parse the party id")}

                    let restaurants: [RatedRestaurantsTable] = try await supabase.getRatedRestaurants(userID: userID, partyID: partyID)

                    let responseObj = RatedRestaurantsGetResponse(ratedRestaurants: restaurants)

                    return try RouteHelper.createResponse(data: responseObj)
                } catch {
                    return RouteHelper.createErrorResponse(error: error, "Error on topChoices route - \(error)")
                }

            }

        case .topRestaurants:
            app.get("topRestaurants") { req async -> Response in

                do {
                    guard let path = req.url.query else { return Response(status: .badRequest) }
                    let pathComponents = path.components(separatedBy: "=")
                    guard let partyID = pathComponents.count == 2 ? pathComponents[1] : nil else { throw SharedErrors.internalServerError(error: "Server was unable to parse the party id")}

                    let topRestaurants: [RatedRestaurantsTable] = try await supabase.getTopChoices(partyID: partyID)

                    let responseObj = TopRestaurantsGetResponse(restaurants: topRestaurants)

                    return try RouteHelper.createResponse(data: responseObj)
                } catch {
                    return RouteHelper.createErrorResponse(error: error, "Error on topChoices route - \(error)")
                }

            }
        case .rejoinParty:
            app.get("rejoinParty") { req async -> Response in

                do {
                    guard let path = req.url.query else { return Response(status: .badRequest) }
                    let pathComponents = path.components(separatedBy: "=")
                    guard let userID = pathComponents.count == 2 ? pathComponents[1] : nil else { throw SharedErrors.internalServerError(error: "Server was unable to parse the user id")}

                    // Get Party associated with the user
                    let party = try await supabase.rejoinParty(userID: userID)
                    let userTable = try await supabase.fetchRows(tableType: .users, dictionary: ["id": userID]).first as? UsersTable
                    guard let userTable else { throw SharedErrors.internalServerError(error: "Server was unable to retrieve the correct user with the id of \(userID)")}

                    let responseObj = RejoinPartyGetResponse(username: userTable.username, partyID: party.id, partyCode: party.code, yelpURL: party.restaurants_url ?? "", partyName: party.party_name)

                    return try RouteHelper.createResponse(data: responseObj)

                } catch {
                    return RouteHelper.createErrorResponse(error: error, "Error on topChoices route - \(error)")
                }
            }
        case .getMessages:
            app.get("getMessages") { req async -> Response in

                do {
                    guard let path = req.url.query else { return Response(status: .badRequest) }
                    let pathComponents = path.components(separatedBy: "=")
                    guard let partyID = pathComponents.count == 2 ? pathComponents[1] : nil else { throw SharedErrors.internalServerError(error: "Server was unable to correctly parse the party ID")}


                    guard let messages = try await supabase.fetchRows(tableType: .messages, dictionary: ["party_id": partyID]) as? [MessagesTable] else {
                        throw SharedErrors.internalServerError(error: "Server was unable to retrieve the correct message using the party id \(partyID)")
                    }

                    let responseObj = MessagesGetResponse(messages: messages)

                    return try RouteHelper.createResponse(data: responseObj)

                } catch {
                    return RouteHelper.createErrorResponse(error: error, "Error on getMessages route - \(error)")
                }

            }
        case .yelpRestaurants:
            app.get("yelpRestaurants") { req async -> Response in

                do {
                    guard let path = req.url.query else { return Response(status: .badRequest) }

                    let pathComponents = path.components(separatedBy: "=")
                    guard let encodedUrlString = pathComponents.count == 2 ? pathComponents[1] : nil else { throw SharedErrors.internalServerError(error: "Server was unable to parse the provided Yelp URL")}

                    let decodedUrlString = encodedUrlString.replacingOccurrences(of: "%3D", with: "=").replacingOccurrences(of: "%26", with: "&")

                    let uri = URI(string: decodedUrlString)

                    let yelpResponse = try await req.client.get(uri) { outgoingReq in
                        outgoingReq.headers.bearerAuthorization = BearerAuthorization(token: yelpAPIKey)
                        Log.general.log("Outgoing Req- \(outgoingReq)")
                    }

                    Log.general.log("Yelp response - \(yelpResponse)")

                    if !(200...299).contains(yelpResponse.status.code) {
                        Log.error.log("Yelp server returned with an invalid status code: \(yelpResponse.status.code)")
                    }

                    guard let validData = yelpResponse.body else {
                        return RouteHelper.createErrorResponse(error: SharedErrors.internalServerError(error: "Server was unable to retrieve a valid yelp response body"), "Server was unable to retrieve a valid yelp response body")
                    }

                    return Response(body: Response.Body(data: Data(buffer: validData)))

                } catch {
                    return RouteHelper.createErrorResponse(error: error, "Error on yelpRestaurants route - \(error)")
                }

            }
        }
    }

}
