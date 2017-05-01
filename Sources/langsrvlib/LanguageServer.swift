/*
 * Copyright (c) Kiad Studios, LLC. All rights reserved.
 * Licensed under the MIT License. See License in the project root for license information.
 */

/// The type of data that is send from the `MessageSource`.
public typealias MessageData = [UInt8]

/// The bottom layer in the messaging stack that is the source of the raw message data.
public protocol MessageSource {
    /// Starts listening for new messages to come in. Whenever a message comes in, the `received`
    /// closure is invoked. This function is not intended to return execution back to its thread.
    func run(received: (MessageData) -> ()) -> Never
}

/// Used to convert data from the `SourceDataType` layer to the `TargetDataType` layer.
/// This adapter is the key to providing truly pluggable interfaces through the stack.
protocol MessageProtocolDataAdapter {
    /// The incoming type of data that will need to be translated.
    associatedtype SourceDataType

    /// The outgoing type of data that the `SourceDataType` will be translated to.
    associatedtype TargetDataType

    /// Translates the data from the raw `MessageData` to a valid `ProtocolDataType`.
    /// This function can throw, providing detailed error information about why the
    /// transformation could not be done.
    func translate(data: SourceDataType) throws -> TargetDataType
}

/// The base requirements for all language servers to implement within the system.
protocol LanguageServer {
    associatedtype MessageProtocol

    /// Used to create a new language server and provide the mechanism to receive messages.
    init(_ messageProtocol: MessageProtocol)

    /// Runs the language server. This waits for input, parses it, and then triggers the
    /// appropriately registered handler.
    /// SwiftBug(SR-2729) - This will cause a compiler warning for all conforming types.
    func run() -> Never
}

/// Defines the API to describe a command for the language server.
/// These currently have a very tight 1:1 mapping with the commands as dictated in the
/// JSONRPC spec. This is by-design to allow for easier development. However, this coupling
/// does **NOT** preclude a different serialization strategy. The only thing it binds is
/// the semantics of the API, which is deemed appropriate at this time.
protocol LanguageServerCommand {
    var type: CommandType { get }
    var source: CommandSource { get }
}

/// Each language server command has a specific type that requires different logic
/// to handle how it's processed and if it requires a response.
enum CommandType {
    /// A 1-way message that requires no response.
    case notification

    /// A request that requires a response.
    case request

    /// A response to a particular request.
    case response
}

/// The source that created the message.
enum CommandSource {
    /// The language server instance.
    case languageServer

    /// The host, usually an editor or IDE.
    case host
}