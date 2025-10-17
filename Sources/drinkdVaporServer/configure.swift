import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    let client = SupaBase.setClient()
    let supabase = SupaBase(client: client)

    guard let yelpKey = Environment.get("YELP_KEY") else { fatalError("Server must be configured with a valid Yelp API Key") }

    // register routes
    try routes(app, supabase: supabase, yelpAPIKey: yelpKey)
}
