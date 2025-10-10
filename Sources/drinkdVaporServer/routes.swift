import Vapor
import drinkdSharedModels

func routes(_ app: Application, supabase: SupaBase) throws {
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
                    Log.error.log("Error on createParty route - \(error)")
                    return RouteHelper.createErrorResponse(error: error)
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
                    Log.error.log("Error on joinParty route - \(error)")
                    return RouteHelper.createErrorResponse(error: error)
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
                    Log.error.log("Error on leaveParty route - \(error)")
                    return RouteHelper.createErrorResponse(error: error)
                }

            }

        case .sendMessage:
            // Send Message
            app.post("sendMessage") { req async -> Response in

                do {
                    guard let reqBody = req.body.data else { return Response(status: .badRequest) }
                    let msgReq = try JSONDecoder().decode(SendMessageRequest.self, from: reqBody)

//                    guard let userData = try await supabase.fetchRows(tableType: .users, dictionary: ["id": "\(msgReq.userID)"]).first as? UsersTable else {
//                        throw SharedErrors.supabase(error: .rowIsEmpty)
//                    }
                    //Message ID, same ID for both the MessageTable id & WSMessage
                    let id = UUID()

                    // Send Message to Messages Table
                    try await supabase.sendMessage(msgReq, messageID: id)

                    return Response()
                } catch {
                    Log.error.log("Error on leaveParty route - \(error)")
                    return RouteHelper.createErrorResponse(error: error)
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
                    Log.error.log("Error on updateRating route - \(error)")
                    return RouteHelper.createErrorResponse(error: error)
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

                    guard let userID = pathComponents.count == 2 ? userIDString : nil else {
                        throw SharedErrors.general(error: .generalError("Unable to parse user id"))
                    }

                    guard let partyID = pathComponents.count == 2 ? partyIDString : nil else { throw SharedErrors.general(error: .generalError("Unable to parse partyID"))}

                    let restaurants: [RatedRestaurantsTable] = try await supabase.getRatedRestaurants(userID: userID, partyID: partyID)

                    let responseObj = RatedRestaurantsGetResponse(ratedRestaurants: restaurants)

                    return try RouteHelper.createResponse(data: responseObj)
                } catch {
                    Log.error.log("Error on topChoices route - \(error)")
                    return RouteHelper.createErrorResponse(error: error)
                }

            }

        case .topRestaurants:
            app.get("topRestaurants") { req async -> Response in

                do {
                    guard let path = req.url.query else { return Response(status: .badRequest) }
                    let pathComponents = path.components(separatedBy: "=")
                    guard let partyID = pathComponents.count == 2 ? pathComponents[1] : nil else { throw SharedErrors.general(error: .generalError("Unable to parse partyID"))}

                    let topRestaurants: [RatedRestaurantsTable] = try await supabase.getTopChoices(partyID: partyID)

                    let responseObj = TopRestaurantsGetResponse(restaurants: topRestaurants)

                    return try RouteHelper.createResponse(data: responseObj)
                } catch {
                    Log.error.log("Error on topChoices route - \(error)")
                    return RouteHelper.createErrorResponse(error: error)
                }

            }
        case .rejoinParty:
            app.get("rejoinParty") { req async -> Response in

                do {
                    guard let path = req.url.query else { return Response(status: .badRequest) }
                    let pathComponents = path.components(separatedBy: "=")
                    guard let userID = pathComponents.count == 2 ? pathComponents[1] : nil else { throw SharedErrors.general(error: .generalError("Unable to parse User ID"))}

                    // Get Party associated with the user
                    let party = try await supabase.rejoinParty(userID: userID)
                    let userTable = try await supabase.fetchRows(tableType: .users, dictionary: ["id": userID]).first as? UsersTable
                    guard let userTable else { throw SharedErrors.general(error: .missingValue("UsersTable is nil"))}

                    let responseObj = RejoinPartyGetResponse(username: userTable.username, partyID: party.id, partyCode: party.code, yelpURL: party.restaurants_url ?? "", partyName: party.party_name)

                    return try RouteHelper.createResponse(data: responseObj)

                } catch {
                    Log.error.log("Error on topChoices route - \(error)")
                    return RouteHelper.createErrorResponse(error: error)
                }
            }
        case .getMessages:
            app.get("getMessages") { req async -> Response in

                do {
                    guard let path = req.url.query else { return Response(status: .badRequest) }
                    let pathComponents = path.components(separatedBy: "=")
                    guard let partyID = pathComponents.count == 2 ? pathComponents[1] : nil else { throw SharedErrors.general(error: .generalError("Unable to parse party ID"))}


                    guard let messages = try await supabase.fetchRows(tableType: .messages, dictionary: ["party_id": partyID]) as? [MessagesTable] else { throw SharedErrors.general(error: .missingValue("MessagesTable is nil")) }

                    let responseObj = MessagesGetResponse(messages: messages)

                    return try RouteHelper.createResponse(data: responseObj)

                } catch {
                    Log.error.log("Error on getMessages route - \(error)")
                    return RouteHelper.createErrorResponse(error: error)
                }

            }
        case .yelpRestaurants:
            app.get("yelpRestaurants") { req async -> Response in

                do {
                    guard let path = req.url.query else { return Response(status: .badRequest) }

                    let pathComponents = path.components(separatedBy: "=")
                    guard let encodedUrlString = pathComponents.count == 2 ? pathComponents[1] : nil else { throw SharedErrors.general(error: .generalError("Unable to parse yelp url"))}

                    let decodeUrlString = encodedUrlString.replacingOccurrences(of: "%3D", with: "=").replacingOccurrences(of: "%26", with: "&")

                    guard let yelpKey = Environment.get("YELP_KEY") else {
                        Log.error.log("Unable to retrieve yelp key")
                        return RouteHelper.createErrorResponse(error: SharedErrors.internalServerError(error: "Server was unable to retrieve the yelp key"))
                    }

                    let uri = URI(string: decodeUrlString)

                    let yelpResponse = try await req.client.get(uri) { outgoingReq in
                        outgoingReq.headers.bearerAuthorization = BearerAuthorization(token: yelpKey)
                    }

                    guard let validData = yelpResponse.body else {
                        return RouteHelper.createErrorResponse(error: SharedErrors.internalServerError(error: "Unable to get yelp data"))
                    }

                    return Response(body: Response.Body(data: Data(buffer: validData)))

                } catch {
                    Log.error.log("Error on getMessages route - \(error)")
                    return RouteHelper.createErrorResponse(error: error)
                }

            }
        }
    }

}
