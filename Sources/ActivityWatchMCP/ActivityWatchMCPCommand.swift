import ArgumentParser
import Foundation
import Logging

/// Command-line interface for the ActivityWatch MCP Server.
///
/// This executable provides a Model Context Protocol server that connects to
/// ActivityWatch and exposes its time tracking data to AI assistants like Claude.
///
/// ## Usage
/// ```bash
/// activitywatch-mcp --log-level debug --server-url http://localhost:5600
/// ```
@main
struct ActivityWatchMCPCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "activitywatch-mcp",
        abstract: "MCP server that provides access to ActivityWatch time tracking data",
        version: "2.6.0-alpha"
    )
    
    @Option(help: "Log level (debug, info, warning, error, critical)")
    var logLevel: String = "info"
    
    @Option(help: "ActivityWatch server URL")
    var serverUrl: String = "http://localhost:5600"
    
    mutating func run() async throws {
        // Configure logging
        let logLevelValue = logLevel.lowercased()
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardError(label: label)
            
            let level: Logger.Level = switch logLevelValue {
            case "debug": .debug
            case "info": .info
            case "warning": .warning
            case "error": .error
            case "critical": .critical
            default: .info
            }
            
            handler.logLevel = level
            return handler
        }
        
        let logger = Logger(label: "activitywatch-mcp")
        logger.info("Starting ActivityWatch MCP Server v2.6.0-alpha")
        logger.debug("Connecting to ActivityWatch at: \(serverUrl)")
        
        // Initialize and run server
        let server = try ActivityWatchMCPServer(
            logger: logger,
            serverUrl: serverUrl
        )
        try await server.run()
    }
}