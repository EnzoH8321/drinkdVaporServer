import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    let client = SupaBase.setClient()
    let supabase = SupaBase(client: client)
    // register routes
    try routes(app, supabase: supabase)
}
